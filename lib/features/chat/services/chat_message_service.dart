/* 
 * chat_message_service.dart
 * 
 * 負責連接 UI 層與底層通訊/加密層的服務，同時負責對話歷史的持久化存取。
 * Responsible for bridging the UI layer with the underlying transmission/encryption layers, 
 * as well as handling the persistence of chat history.
 */
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/identity/identity_manager.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/sticker.dart';
import '../../../core/security/shredder_service.dart';
import '../../../core/storage/database_service.dart';
import '../../../core/network/waku/p2p_provider.dart';
import '../../stickers/services/sticker_service.dart';
import '../../chat/services/file_transfer_service.dart';
import '../../../core/security/anonymization_service.dart';

class ChatMessageService extends ChangeNotifier {
  final P2PProvider p2pProvider;
  final IdentityManager identityManager;
  
  final String remotePublicKey;
  
  final List<ChatMessage> _messages = [];
  StreamSubscription? _p2pSubscription;
  late FileTransferService _fileTransferService;
  final AnonymizationService _anonymizationService = AnonymizationService();
  
  bool _isScreenshotWarningActive = false;
  bool get isScreenshotWarningActive => _isScreenshotWarningActive;

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  ChatMessageService({
    required this.p2pProvider,
    required this.identityManager,
    required this.remotePublicKey,
  }) {
    _fileTransferService = FileTransferService(
      p2pProvider: p2pProvider,
      remotePublicKey: remotePublicKey,
    );
    _loadHistoryFromDatabase();
    // 監聽來自此對象的 P2P 訊息 (Listen for P2P messages from this contact)
    _p2pSubscription = p2pProvider.incomingMessages.listen(_onChatMessageReceived);
  }

  /*
   * 進入房間時載入歷史對話 (Load history upon entering room)
   */
  void _loadHistoryFromDatabase() {
    final historyBox = DatabaseService.chatHistoryBox;
    // 只載入與此 remotePublicKey 相關的訊息
    _messages.addAll(historyBox.values.where((m) => m.chatId == remotePublicKey));
    notifyListeners();
  }

  void _onChatMessageReceived(ChatMessage message) async {
    // 過濾出屬於當前對話對象的訊息 (Filter messages for current contact)
    if (message.chatId != remotePublicKey) return;

    try {
      // 檢查是否為信號訊息 (Check for signaling messages)
      if (message.text.startsWith('[SIGNAL:')) {
        _handleSignal(message.text);
        return;
      }

      // 檢查是否為貼圖訊息 (Check for sticker messages)
      if (message.text.startsWith('[STICKER_V1:')) {
        await _handleIncomingSticker(message.text);
        return;
      }

      // 檢查是否為檔案分片 (Check for file chunks)
      if (message.text.startsWith('[FCHUNK:')) {
        final savedPath = await _fileTransferService.handleIncomingChunk(message.text);
        if (savedPath != null) {
          _onFileReceivedCompletely(savedPath);
        }
        return;
      }

      // 檢查是否為檔案確認信號 (Check for file ACKs)
      if (message.text.startsWith('[FACK:')) {
        _fileTransferService.handleAck(message.text);
        return;
      }

      _messages.add(message);
      await DatabaseService.chatHistoryBox.add(message);
      notifyListeners();
      
      // 注意：P2PProvider 可能已經將訊息存入資料庫，
      // 但為了保險起見，我們在這裡確保 UI 同步。
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
      await p2pProvider.sendMessage(remotePublicKey, '[SIGNAL:SCREENSHOT_DETECTED]');
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
        await p2pProvider.sendMessage(remotePublicKey, '[SIGNAL:LEAVE_CHAT]');
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

  /*
   * 處理傳入的貼圖信號 (Handle incoming sticker signal)
   */
  Future<void> _handleIncomingSticker(String signal) async {
    try {
      final base64Data = signal.substring(12, signal.length - 1);
      final fileName = await StickerService().saveReceivedSticker(base64Data);
      final fullPath = await StickerService().getStickerAbsolutePath(fileName);

      final newMessage = ChatMessage(
        text: '[貼圖]',
        isMe: false,
        time: _formatTime(DateTime.now()),
        chatId: remotePublicKey,
        stickerPath: fullPath,
      );

      _messages.add(newMessage);
      await DatabaseService.chatHistoryBox.add(newMessage);
      notifyListeners();
    } catch (e) {
      print('❌ [ChatMessageService] 解碼貼圖失敗: $e');
    }
  }

  Future<void> sendLocalSticker(String stickerPath) async {
    try {
      final now = DateTime.now();
      final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';

      // 1. 讀取並轉換為 Base64 (Read and convert to Base64)
      final bytes = await File(stickerPath).readAsBytes();
      final base64Sticker = base64Encode(bytes);
      final signal = '[STICKER_V1:$base64Sticker]';

      // 2. 更新本地 UI (Update local UI)
      final myMessage = ChatMessage(
        text: "[貼圖]", 
        isMe: true, 
        time: timeStr,
        chatId: remotePublicKey,
        stickerPath: stickerPath,
      );
      
      _messages.add(myMessage);
      await DatabaseService.chatHistoryBox.add(myMessage);
      notifyListeners();

      // 3. 正式發送 (Send via P2P)
      await p2pProvider.sendMessage(remotePublicKey, signal);

    } catch (e) {
      print('❌ [ChatMessageService] 發送貼圖失敗: $e');
    }
  }

  /*
   * 處理檔案接收完成後的 UI 更新 (UI update after file received)
   */
  void _onFileReceivedCompletely(String path) async {
    final fileName = p.basename(path);
    final newMessage = ChatMessage(
      text: '[文件: $fileName]',
      isMe: false,
      time: _formatTime(DateTime.now()),
      chatId: remotePublicKey,
    );
    // 這裡通常會加上一個 fileLocalPath 欄位在 ChatMessage，但我們目前先用 text 表示
    _messages.add(newMessage);
    await DatabaseService.chatHistoryBox.add(newMessage);
    notifyListeners();
  }

  /*
   * 標記訊息為已讀 (Mark message as read)
   */
  Future<void> markAsRead() async {
    final now = DateTime.now();
    bool changed = false;
    for (var msg in _messages) {
      if (!msg.isMe && msg.readAt == null) {
        msg.readAt = now;
        msg.status = MessageStatus.read;
        await msg.save();
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /*
   * 匿名發送檔案 (Anonymous File Send)
   */
  Future<void> sendFile(File originalFile) async {
    // 0. 在線偵查 (Handshake)
    final isOnline = await p2pProvider.checkPeerOnline(remotePublicKey);
    if (!isOnline) {
      print('❌ [FileTransfer] 對方不在線，無法傳送檔案。');
      // 這裡可以丟出一個特定的攔截提示或訊息
      return; 
    }

    // 1. 先進「洗滌管線」 (Sanitize)
    final sanitizedFile = await _anonymizationService.sanitizeFile(originalFile);
    if (sanitizedFile == null) return;

    final fileName = p.basename(sanitizedFile.path);
    
    // 2. 本地紀錄 (Local Record)
    final myMessage = ChatMessage(
      text: '[發送文件: $fileName]',
      isMe: true,
      time: _formatTime(DateTime.now()),
      chatId: remotePublicKey,
    );
    _messages.add(myMessage);
    notifyListeners();

    // 3. 透過分片引擎發送 (Send via chunks)
    await _fileTransferService.sendFile(sanitizedFile);
    
    // 4. 發送完畢後清理暫存檔案 (Clean up)
    await sanitizedFile.delete();
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

      // 正式透過 Waku P2P 發送 (Officially send via Waku P2P)
      await p2pProvider.sendMessage(remotePublicKey, text);
      
    } catch (e) {
      print('❌ [ChatMessageService] 發送失敗 Send failed: $e');
      _messages.add(ChatMessage(text: "❌ 訊息發送失敗 (Send failed)", isMe: true, time: "Now"));
      notifyListeners();
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _p2pSubscription?.cancel();
    super.dispose();
  }
}
