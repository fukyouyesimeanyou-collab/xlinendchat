/* 
 * 這裡定義了加密與 SMP 協議相關的「介面」 (Interfaces)。
 * 介面就像是一份契約，規定了任何想要提供加密功能的類別必須實作哪些動作，
 * 但不規定具體要怎麼做。這讓未來更換加密演算法時，不需要修改 UI 程式碼。
 * 
 * This file defines the encryption and SMP protocol "Interfaces".
 * An interface is like a contract; it specifies what actions any class providing 
 * encryption services must implement, without dictating how. This allows us to 
 * swap encryption algorithms in the future without changing the UI code.
 */

/*
 * KeyGeneratorInterface: 負責產生加密所需的金鑰。
 * 包含長期身分金鑰與臨時使用的隊列金鑰。
 * 
 * KeyGeneratorInterface: Responsible for generating keys required for encryption.
 * It handles both long-term identity keys and short-term ephemeral queue keys.
 */
abstract class KeyGeneratorInterface {
  /* 
   * 產生長期的身分金鑰對，用於識別使用者。
   * Generates a long-term identity key pair used for user identification.
   */
  Future<void> generateIdentityKeys();
  
  /* 
   * 為特定的 SimpleX 隊列產生臨時金鑰。
   * Generates ephemeral keys for a specific SMP queue.
   */
  Future<Map<String, String>> generateQueueKeys();
}

/*
 * SmpProtocolInterface: 符合 SMP V9 規格的協議介面。
 * 此介面精確反映了 SimpleX Messaging Protocol 第 9 版(2024-06-22)的指令集。
 * 任何實作此介面的類別（無論是模擬實作、純 Dart Socket、或 FFI 綁定）
 * 都必須遵守此契約。
 * 
 * SmpProtocolInterface: Protocol interface conforming to SMP V9 specification.
 * This interface precisely mirrors the command set of SimpleX Messaging Protocol
 * Version 9 (2024-06-22). Any class implementing this interface (whether mock,
 * pure Dart Socket, or FFI binding) must adhere to this contract.
 *
 * 參考文件 (Reference): https://github.com/simplex-chat/simplexmq/blob/stable/protocol/simplex-messaging.md
 */
abstract class SmpProtocolInterface {

  /* 
   * 連線至指定的 SMP 中繼伺服器。
   * 真實實作中，這裡會建立 TLS 1.3 (ChaCha20-Poly1305) 連線，
   * 並完成 ServerHello/ClientHello 握手與伺服器憑證指紋驗證。
   * 
   * Connects to a specified SMP relay server.
   * In a real implementation, this establishes a TLS 1.3 (ChaCha20-Poly1305)
   * connection and completes ServerHello/ClientHello handshake with 
   * server certificate fingerprint validation.
   */
  Future<bool> connect(String serverAddress, String serverIdentityFingerprint);

  /* 
   * 斷開與中繼伺服器的連線。
   * Disconnects from the relay server.
   */
  Future<void> disconnect();

  /* 
   * NEW 指令：在中繼伺服器上建立一個新的單向訊息隊列。
   * 接收方 (Recipient) 呼叫此指令。伺服器回傳 IDS (recipientId, senderId, serverDhKey)。
   * 
   * NEW command: Creates a new unidirectional message queue on the relay.
   * Called by the Recipient. Server responds with IDS (recipientId, senderId, serverDhKey).
   *
   * recipientAuthKey: 接收方的 Ed25519 公鑰，用於驗證後續指令。
   *                   Recipient's Ed25519 public key for authorizing subsequent commands.
   * recipientDhKey:   接收方的 Curve25519 公鑰，用於 DH 交換以加密伺服器傳送的訊息體。
   *                   Recipient's Curve25519 public key for DH exchange to encrypt delivered message bodies.
   * 
   * 回傳值 (Returns): Map 包含 'recipientId', 'senderId', 'serverDhKey'。
   */
  Future<Map<String, String>> cmdNew(String recipientAuthKey, String recipientDhKey);

  /* 
   * SUB 指令：訂閱隊列以開始接收訊息。
   * 接收方在重新連線後呼叫此指令來恢復訊息接收。
   * 
   * SUB command: Subscribes to a queue to start receiving messages.
   * Called by the Recipient after reconnecting to resume message reception.
   *
   * recipientId: 接收方的隊列 ID。(Recipient's queue ID.)
   * authSignature: 用 recipientKey 私鑰對傳輸內容簽章。(Signature using recipientKey private key.)
   */
  Future<bool> cmdSub(String recipientId, String authSignature);

  /* 
   * SKEY 指令 (V9)：由發送方鎖定隊列。
   * 在 SMP V9 中，發送方可以直接向伺服器提交自己的公鑰以鎖定隊列，
   * 不必等待接收方上線執行 KEY 指令。這加速了雙向連線的建立。
   * 
   * SKEY command (V9): Secures the queue by the sender.
   * In SMP V9, the sender can directly submit their public key to the server
   * to secure the queue, without waiting for the recipient to be online for KEY.
   * This accelerates duplex connection establishment.
   *
   * senderId: 發送方的隊列 ID。(Sender's queue ID.)
   * senderAuthKey: 發送方的 Ed25519 公鑰。(Sender's Ed25519 public key.)
   */
  Future<bool> cmdSkey(String senderId, String senderAuthKey);

  /* 
   * SEND 指令：將加密訊息投遞到對方的接收隊列。
   * 訊息體必須已經過 E2E 加密（您的 BLAKE2b + ChaCha20 層）。
   * libsimplex 會再包一層 NaCl crypto_box（標準 SMP 協議要求）。
   * 
   * SEND command: Delivers an encrypted message to the recipient's queue.
   * The message body must already be E2E encrypted (your BLAKE2b + ChaCha20 layer).
   * libsimplex will add another NaCl crypto_box layer (required by SMP protocol).
   *
   * senderId: 發送方的隊列 ID。(Sender's queue ID.)
   * encryptedBlob: 已加密的二進位訊息。(E2E encrypted binary message blob.)
   * authSignature: 用 senderKey 私鑰簽章。(Signature using senderKey private key.)
   * notifyRecipient: 是否觸發推播通知。(Whether to trigger push notification.)
   */
  Future<bool> cmdSend(String senderId, String encryptedBlob, String authSignature, {bool notifyRecipient = true});

  /* 
   * ACK 指令：確認訊息已收到，伺服器即可刪除該訊息。
   * 
   * ACK command: Acknowledges message receipt so the server can delete it.
   *
   * recipientId: 接收方的隊列 ID。(Recipient's queue ID.)
   * msgId: 要確認的訊息 ID。(Message ID to acknowledge.)
   * authSignature: 用 recipientKey 私鑰簽章。(Signature using recipientKey private key.)
   */
  Future<bool> cmdAck(String recipientId, String msgId, String authSignature);

  /* 
   * OFF 指令：暫停隊列（刪除前的前置步驟）。
   * 
   * OFF command: Suspends the queue (pre-step before deletion).
   *
   * recipientId: 接收方的隊列 ID。(Recipient's queue ID.)
   * authSignature: 用 recipientKey 私鑰簽章。(Signature using recipientKey private key.)
   */
  Future<bool> cmdOff(String recipientId, String authSignature);

  /* 
   * DEL 指令：永久刪除隊列及其所有未讀訊息。
   * 
   * DEL command: Permanently deletes the queue and all unread messages.
   *
   * recipientId: 接收方的隊列 ID。(Recipient's queue ID.)
   * authSignature: 用 recipientKey 私鑰簽章。(Signature using recipientKey private key.)
   */
  Future<bool> cmdDel(String recipientId, String authSignature);

  /*
   * 訊息接收回調：當伺服器推送 MSG 事件時觸發。
   * Message reception callback: Triggered when the server pushes a MSG event.
   *
   * 回傳一個串流 (Stream)，每有新訊息進來就會發出事件。
   * Returns a Stream that emits events whenever a new message arrives.
   */
  Stream<SmpMessage> get onMessage;
}

/*
 * SmpMessage 資料類別：封裝從 SMP 中繼站收到的單則訊息。
 * SmpMessage data class: Encapsulates a single message received from an SMP relay.
 */
class SmpMessage {
  /* 伺服器產生的唯一訊息 ID。(Unique message ID generated by server.) */
  final String msgId;

  /* 伺服器收到訊息的 Unix 時間戳 (秒)。(Unix timestamp in seconds when server received the message.) */
  final int timestamp;

  /* 加密後的訊息體（需要您的加密層解密）。(Encrypted message body, needs your crypto layer to decrypt.) */
  final List<int> encryptedBody;

  /* 來源隊列 ID。(Source queue ID.) */
  final String queueId;

  SmpMessage({
    required this.msgId,
    required this.timestamp,
    required this.encryptedBody,
    required this.queueId,
  });
}

/*
 * MessageCipherInterface: 負責訊息的端到端加解密 (E2EE)。
 * 確保只有傳送者與接收者能看到內容。
 * 
 * MessageCipherInterface: Responsible for end-to-end encryption (E2EE).
 * Ensures that only the sender and the receiver can read the message content.
 */
abstract class MessageCipherInterface {
  /* 
   * 使用您的自訂加密堆疊 (BLAKE2b Whitening + ChaCha20-Poly1305) 加密明文。
   * Encrypts plain text using your custom crypto stack (BLAKE2b Whitening + ChaCha20-Poly1305).
   */
  Future<String> encryptE2E(String plainText, String recipientPublicKey);
  
  /* 
   * 將加密後的資料解密回明文。
   * Decrypts an encrypted blob back into plain text (E2EE).
   */
  Future<String> decryptE2E(String encryptedBlob, String senderPublicKey);
}
