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
import '../../../core/storage/database_service.dart';
import '../../../core/models/chat_message.dart'; // 使用強型別模型 (Use typed model)

class ChatMessageService extends ChangeNotifier {
  final SmpProtocolInterface smpClient;
  final MessageCipherInterface e2eCipher;
  final IdentityManager identityManager;
  
  final String remotePublicKey;
  final String senderQueueId;
  
  final List<ChatMessage> _messages = [];
  StreamSubscription? _smpSubscription;

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
      final plainText = await e2eCipher.decryptE2E(base64EncryptedBlob, remotePublicKey);
      
      final now = DateTime.now();
      final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      
      final newMessage = ChatMessage(text: plainText, isMe: false, time: timeStr);
      _messages.add(newMessage);
      notifyListeners();
      
      // 直接存入物件 (Direct object storage)
      await DatabaseService.chatHistoryBox.add(newMessage);
      
      await smpClient.cmdAck("my_rcpt_id", smpMessage.msgId, "sig_mock");
    } catch (e) {
      print('❌ [ChatMessageService] 解密失敗 Decryption failed: $e');
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    try {
      final now = DateTime.now();
      final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';

      final myMessage = ChatMessage(text: text, isMe: true, time: timeStr);
      _messages.add(myMessage);
      notifyListeners();

      // 直接存入物件 (Direct object storage)
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
