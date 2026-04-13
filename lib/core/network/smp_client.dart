/* 
 * 引入必要的庫：
 * 1. async: 提供非同步程式設計支援。
 * 2. convert: 提供 JSON 編解碼功能（僅為輔助輸出）。
 * 
 * Imports necessary libraries:
 * 1. async: Provides support for asynchronous programming.
 * 2. convert: Provides JSON encoding and decoding (for debug output only).
 */
import 'dart:async';
import 'dart:convert';
import '../encryption/encryption_service.dart';

/* 
 * SmpClientV9 類別：
 * 這是實現 SimpleX V9 協議介面的模擬客戶端。
 * 在 Phase 2 對接真實的 `libsimplex` FFI 之前，此類別負責保持專案可編譯並模擬非同步的網路行為。
 * 
 * SmpClientV9 class:
 * A mock client implementing the SimpleX V9 protocol interface.
 * Before hooking up the real `libsimplex` FFI in Phase 2, this class ensures 
 * the project compiles and simulates asynchronous network behaviors.
 */
class SmpClientV9 implements SmpProtocolInterface {
  /* 
   * 預設的模擬伺服器。
   * Default mock server.
   */
  static const String defaultRelay = 'smp://mock-relay.simplex.im';

  /* 
   * 訊息流控制器，用於模擬伺服器下發的 MSG 事件。
   * StreamController for simulating MSG events pushed by the server.
   */
  final StreamController<SmpMessage> _messageController = StreamController<SmpMessage>.broadcast();

  @override
  Stream<SmpMessage> get onMessage => _messageController.stream;

  /* 
   * 模擬建立連線。
   * Mocks the connection establishment.
   */
  @override
  Future<bool> connect(String serverAddress, String serverIdentityFingerprint) async {
    // 模擬網路延遲 (Simulate network delay)
    await Future.delayed(const Duration(milliseconds: 500));
    print('✅ [SmpClientV9] Connected to $serverAddress (Mock)');
    return true;
  }

  /* 
   * 模擬斷開連線。
   * Mocks the disconnection.
   */
  @override
  Future<void> disconnect() async {
    print('🔌 [SmpClientV9] Disconnected (Mock)');
  }

  /* 
   * 模擬 NEW 指令：建立接收隊列。
   * Mocks NEW command: Creates a receiving queue.
   */
  @override
  Future<Map<String, String>> cmdNew(String recipientAuthKey, String recipientDhKey) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final mockRecipientId = 'rcpt_${DateTime.now().millisecondsSinceEpoch}';
    final mockSenderId = 'sndr_${DateTime.now().millisecondsSinceEpoch}';
    final mockServerDhKey = 'srv_dh_key_mock_123';
    
    print('📡 [SmpClientV9] NEW command sent. RcptID: $mockRecipientId');
    return {
      'recipientId': mockRecipientId,
      'senderId': mockSenderId,
      'serverDhKey': mockServerDhKey,
    };
  }

  /* 
   * 模擬 SUB 指令：訂閱隊列以開始接收訊息。
   * Mocks SUB command: Subscribes to a queue to start receiving messages.
   */
  @override
  Future<bool> cmdSub(String recipientId, String authSignature) async {
    await Future.delayed(const Duration(milliseconds: 200));
    print('📡 [SmpClientV9] SUB command sent for $recipientId');
    return true;
  }

  /* 
   * 模擬 SKEY 指令：立刻鎖定隊列。
   * Mocks SKEY command: Secures the queue immediately.
   */
  @override
  Future<bool> cmdSkey(String senderId, String senderAuthKey) async {
    await Future.delayed(const Duration(milliseconds: 200));
    print('📡 [SmpClientV9] SKEY command sent for $senderId');
    return true;
  }

  /* 
   * 模擬 SEND 指令：發送加密訊息體。
   * Mocks SEND command: Delivers E2E encrypted blob.
   */
  @override
  Future<bool> cmdSend(String senderId, String encryptedBlob, String authSignature, {bool notifyRecipient = true}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    print('✉️ [SmpClientV9] SEND command completed. Blob size: ${encryptedBlob.length}');
    
    // 如果這是一個本機測試，我們可以嘗試把這條訊息發射到 stream 回來
    // If it's a local test, we might bounce this message back into the stream
    return true;
  }

  /* 
   * 模擬 ACK 指令：確認已收到訊息。
   * Mocks ACK command: Acknowledges message receipt.
   */
  @override
  Future<bool> cmdAck(String recipientId, String msgId, String authSignature) async {
    await Future.delayed(const Duration(milliseconds: 100));
    print('✅ [SmpClientV9] ACK command sent for msg: $msgId');
    return true;
  }

  /* 
   * 模擬 OFF 指令：暫停隊列。
   * Mocks OFF command: Suspends the queue.
   */
  @override
  Future<bool> cmdOff(String recipientId, String authSignature) async {
    await Future.delayed(const Duration(milliseconds: 200));
    print('⏸️ [SmpClientV9] OFF command sent for $recipientId');
    return true;
  }

  /* 
   * 模擬 DEL 指令：刪除隊列。
   * Mocks DEL command: Deletes the queue.
   */
  @override
  Future<bool> cmdDel(String recipientId, String authSignature) async {
    await Future.delayed(const Duration(milliseconds: 200));
    print('🗑️ [SmpClientV9] DEL command sent for $recipientId');
    return true;
  }
}
