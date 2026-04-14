import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/chat_message.dart';
import '../../identity/identity_manager.dart';
import '../../encryption/double_ratchet_service.dart';
import 'waku_service.dart';

/// P2PProvider: 整合 Waku 網路層與 Double Ratchet 加密層的中央提供者
/// The central provider that integrates the Waku network layer with the Double Ratchet encryption layer.
class P2PProvider extends ChangeNotifier {
  final WakuService wakuService;
  final DoubleRatchetService cryptoService;
  final IdentityManager identityManager;

  static const String defaultTopic = '/xlinendchat/v1/p2p/proto';

  final _messageController = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get incomingMessages => _messageController.stream;

  // 用於在線狀態檢查 (For presence checks)
  final Map<String, Completer<bool>> _pingCompleters = {};

  P2PProvider({
    required this.wakuService,
    required this.cryptoService,
    required this.identityManager,
  });

  /// 初始化 P2P 環境：啟動 Waku 並訂閱主題
  /// Initializes the P2P environment: starts Waku and subscribes to the topic.
  Future<void> init() async {
    // 確保身分已載入 (Ensure identity is loaded)
    if (identityManager.identityKeyPair == null) {
      await identityManager.generateIdentityKeys();
    }
    
    // 將身分金鑰對注入加密服務 (Inject identity keypair into crypto service)
    final keyPair = identityManager.identityKeyPair;
    if (keyPair != null) {
      cryptoService.setIdentityKeyPair(keyPair);
    }

    // 監聽 Waku 事件流 (Listen to Waku event stream)
    wakuService.events.listen(_handleWakuEvent);

    // 訂閱預設聊天主題 (Subscribe to the default chat topic)
    await wakuService.relaySubscribe(defaultTopic);
    
    print('🚀 [P2PProvider] Initialized and subscribed to $defaultTopic');
  }

  /// 檢查對方是否在線 (Check if peer is online)
  Future<bool> checkPeerOnline(String recipientPubKey) async {
    print('🧐 [Presence] 正在檢查 $recipientPubKey 是否在線...');
    
    _pingCompleters[recipientPubKey] = Completer<bool>();
    
    try {
      // 發送 PING (加密過)
      await sendMessage(recipientPubKey, '[PING:${DateTime.now().millisecondsSinceEpoch}]');
      
      // 等待 5 秒 (Wait 5 seconds)
      return await _pingCompleters[recipientPubKey]!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
    } catch (e) {
      return false;
    } finally {
      _pingCompleters.remove(recipientPubKey);
    }
  }

  /// 發送加密訊息 (Send an encrypted message)
  Future<void> sendMessage(String recipientPubKey, String text) async {
    try {
      // 1. 使用雙棘輪加密明文 (Encrypt plaintext using Double Ratchet)
      final encryptedBody = await cryptoService.encryptE2E(text, recipientPubKey);
      
      // 2. 封裝 P2P 傳輸包 (包含發送者公鑰，讓對方知道是誰寄的)
      // Wrap the P2P transport packet (includes sender pubkey so recipient knows who sent it)
      final myPubKey = identityManager.identityPublicKey;
      if (myPubKey == null) throw Exception("Identity public key missing");

      final p2pPacket = {
        'sender_pub': myPubKey,
        'payload': encryptedBody,
      };

      // 3. 透過 Waku Relay 發佈 (Publish via Waku Relay)
      final packetBytes = utf8.encode(jsonEncode(p2pPacket));
      await wakuService.relayPublish(defaultTopic, packetBytes);
      
      print('📤 [P2PProvider] Message sent to $recipientPubKey');
    } catch (e) {
      print('❌ [P2PProvider] Failed to send message: $e');
      rethrow;
    }
  }

  /// 處理來自 Waku 的原始事件 (Handle raw events from Waku)
  void _handleWakuEvent(String eventJson) async {
    try {
      final event = jsonDecode(eventJson);
      
      // 我們只關心訊息類型的事件 (We only care about 'message' type events)
      if (event['type'] == 'message') {
        final wakuMsg = event['data'];
        final rawPayload = base64Decode(wakuMsg['payload']);
        
        // 1. 解析 P2P 傳輸包 (Parse P2P transport packet)
        final p2pPacket = jsonDecode(utf8.decode(rawPayload));
        final senderPub = p2pPacket['sender_pub'];
        final encryptedPayload = p2pPacket['payload'];

        // 如果是自己發出的訊息，則忽略 (Ignore if it's our own message)
        if (senderPub == identityManager.identityPublicKey) return;

        // 2. 使用雙棘輪解密 (Decrypt using Double Ratchet)
        final decryptedText = await cryptoService.decryptE2E(encryptedPayload, senderPub);

        // 3. 系統信號過濾 (System Signal Filtering)
        if (decryptedText.startsWith('[PING:')) {
          print('🔔 [Presence] 收到 PING，自動回覆 PONG...');
          await sendMessage(senderPub, '[PONG]');
          return;
        }

        if (decryptedText.startsWith('[PONG]')) {
          print('🔔 [Presence] 收到 PONG，確認對方在線！');
          if (_pingCompleters.containsKey(senderPub)) {
            _pingCompleters[senderPub]!.complete(true);
          }
          return;
        }

        // 4. 封裝成 ChatMessage 並發布至 UI 串流
        // Wrap as ChatMessage and emit to UI stream
        final chatMsg = ChatMessage(
          text: decryptedText,
          isMe: false,
          time: DateTime.now().toIso8601String(),
          chatId: senderPub, // 使用對方的公鑰作為對話 ID
        );

        _messageController.add(chatMsg);
        print('📥 [P2PProvider] Received and decrypted message from $senderPub');
      }
    } catch (e) {
      print('⚠️ [P2PProvider] Error handling Waku event: $e');
    }
  }

  @override
  void dispose() {
    _messageController.close();
    super.dispose();
  }
}
