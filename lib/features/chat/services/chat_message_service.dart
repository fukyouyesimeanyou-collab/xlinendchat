/* 
 * chat_message_service.dart
 * 
 * 負責連接 UI 層與底層通訊/加密層的服務，同時負責對話歷史的持久化存取。
 * Responsible for bridging the UI layer with the underlying transmission/encryption layers, 
 * as well as handling the persistence of chat history.
 */
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/encryption/encryption_service.dart';
import '../../../core/identity/identity_manager.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/security/shredder_service.dart';

class ChatMessageService extends ChangeNotifier {
  final SmpProtocolInterface smpClient;
  final MessageCipherInterface e2eCipher;
  final IdentityManager identityManager;
  
  final String remotePublicKey;
  final String senderQueueId;
  
  final List<ChatMessage> _messages = [];
  StreamSubscription? _smpSubscription;
  
  bool _isScreenshotWarningActive = false;
  bool get isScreenshotWarningActive => _isScreenshotWarningActive;

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  ChatMessageService({
    required this.smpClient,
    required this.e2eCipher,
    required this.identityManager,
    required this.remotePublicKey,
    required this.senderQueueId,
  }) {
    _loadHistoryFromDatabase();
    _smpSubscription = smpClient.onMessage.listen(_onEncryptedMessageReceived);
  }

  /*
   * 進入房間時載入歷史對話 (Load history upon entering room)
   */
  void _loadHistoryFromDatabase() {
    final historyBox = DatabaseService.chatHistoryBox;
    _messages.addAll(historyBox.values);
    notifyListeners();
  }

  void _onEncryptedMessageReceived(SmpMessage smpMessage) async {
    try {
      final base64EncryptedBlob = String.fromCharCodes(smpMessage.encryptedBody);
      final rawText = await e2eCipher.decryptE2E(base64EncryptedBlob, remotePublicKey);
      
      // 檢查是否為信號訊息 (Check for signaling messages)
      if (rawText.startsWith('[SIGNAL:')) {
        _handleSignal(rawText);
        await smpClient.cmdAck("my_rcpt_id", smpMessage.msgId, "sig_mock");
        return;
      }

      final now = DateTime.now();
      final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      
      final newMessage = ChatMessage(
        text: rawText, 
        isMe: false, 
        time: timeStr,
        chatId: remotePublicKey,
      );
      
      _messages.add(newMessage);
      notifyListeners();
      
      await DatabaseService.chatHistoryBox.add(newMessage);
      await smpClient.cmdAck("my_rcpt_id", smpMessage.msgId, "sig_mock");
    } catch (e) {
      print('❌ [ChatMessageService] 處理失敗 Process failed: $e');
    }
  }

  /*
   * 處理內部信號 (Handle internal signals)
   */
  void _handleSignal(String signal) async {
    if (signal == '[SIGNAL:LEAVE_CHAT]') {
      print('🛑 [SIGNAL] 接收到離開對話指令，開始銷毀 Session...');
      await leaveChat(sendSignal: false);
    } else if (signal == '[SIGNAL:SCREENSHOT_DETECTED]') {
      print('📸 [SIGNAL] 偵測到對方截圖！');
      _isScreenshotWarningActive = true;
      notifyListeners();
    }
  }

  void dismissScreenshotWarning() {
    _isScreenshotWarningActive = false;
    notifyListeners();
  }

  /*
   * 發送截圖偵測信號
   */
  Future<void> sendScreenshotSignal() async {
    try {
      final signalBlob = await e2eCipher.encryptE2E('[SIGNAL:SCREENSHOT_DETECTED]', remotePublicKey);
      await smpClient.cmdSend(senderQueueId, signalBlob, "auth_sig_mock");
    } catch (e) {
      print('Error sending screenshot signal: $e');
    }
  }

  /*
   * 離開並銷毀對話 (Leave and shred chat)
   */
  Future<void> leaveChat({bool sendSignal = true}) async {
    try {
      if (sendSignal) {
        final signalBlob = await e2eCipher.encryptE2E('[SIGNAL:LEAVE_CHAT]', remotePublicKey);
        await smpClient.cmdSend(senderQueueId, signalBlob, "auth_sig_mock");
      }
      
      await ShredderService.shredSession(remotePublicKey);
      _messages.clear();
      _isScreenshotWarningActive = false;
      notifyListeners();
      
      // 重置 BAR 狀態 (Reset BAR state)
      try {
        final contact = DatabaseService.contactsBox.values.firstWhere((c) => c.publicKeyBase64 == remotePublicKey);
        contact.isBarActive = false;
        contact.barSessionExpiry = null;
        await contact.save();
      } catch (_) {}
      
      print('🔥 [ChatMessageService] 對話 Session 已徹底銷毀。');
    } catch (e) {
      print('Error during leaveChat: $e');
    }
  }

  Future<void> sendLocalSticker(String stickerPath) async {
    try {
      final now = DateTime.now();
      final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';

      final myMessage = ChatMessage(
        text: "[貼圖]", 
        isMe: true, 
        time: timeStr,
        chatId: remotePublicKey,
        stickerPath: stickerPath,
      );
      
      _messages.add(myMessage);
      notifyListeners();

      await DatabaseService.chatHistoryBox.add(myMessage);
    } catch (e) {
      print('❌ [ChatMessageService] 儲存貼圖失敗: $e');
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    try {
      final now = DateTime.now();
      final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';

      final myMessage = ChatMessage(
        text: text, 
        isMe: true, 
        time: timeStr,
        chatId: remotePublicKey,
      );
      _messages.add(myMessage);
      notifyListeners();

      await DatabaseService.chatHistoryBox.add(myMessage);

      final encryptedBlob = await e2eCipher.encryptE2E(text, remotePublicKey);
      await smpClient.cmdSend(senderQueueId, encryptedBlob, "auth_sig_mock");
      
    } catch (e) {
      print('❌ [ChatMessageService] 發送失敗 Send failed: $e');
      _messages.add(ChatMessage(text: "❌ 訊息發送失敗 (Send failed)", isMe: true, time: "Now"));
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _smpSubscription?.cancel();
    super.dispose();
  }
}
