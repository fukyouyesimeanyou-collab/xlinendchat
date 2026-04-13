/* 
 * 引入必要的密碼學函式庫：
 * 1. cryptography: 用於 X25519, Blake2b 與 ChaCha20-Poly1305 等進階加解密運算。
 * 2. double_ratchet.dart: 處理金鑰棘輪衍生的核心狀態機。
 * 
 * Imports necessary cryptographic libraries.
 */
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'encryption_service.dart';
import '../identity/identity_manager.dart';
import 'double_ratchet.dart';
import '../storage/database_service.dart';
import '../models/ratchet_state.dart';

/* 
 * E2EeService 類別：實作端到端加解密邏輯 (已全面升級為雙棘輪架構)。
 * 結合了 ECDH (X25519) + Double Ratchet (HKDF) + AEAD (ChaCha20-Poly1305)。
 * 
 * E2EeService class: Implements end-to-end encryption logic (Upgraded to Double Ratchet).
 */
class E2EeService implements MessageCipherInterface {
  final IdentityManager identityManager;
  final DoubleRatchetSession _ratchetSession = DoubleRatchetSession();
  final X25519 _x25519 = X25519();
  final Blake2b _blake2b = Blake2b(); // PQ-Whitening 保留用於初始 RootKey
  final _chacha20 = Chacha20.poly1305Aead(); // AeadCipher — ChaCha20-Poly1305 AEAD

  E2EeService(this.identityManager) {
    _tryRestoreSession();
  }

  /*
   * 嘗試從安全庫恢復先前的對話狀態 (Restore from Hive)
   */
  Future<void> _tryRestoreSession() async {
    final state = DatabaseService.ratchetBox.get('current_session');
    if (state != null) {
      await _ratchetSession.loadFromState(state);
      print('🔄 [DoubleRatchet] Session state restored from secure storage.');
    }
  }

  /*
   * 儲存當前狀態回 Hive (Save to Hive)
   */
  Future<void> _persistSession() async {
    final state = await _ratchetSession.toState();
    await DatabaseService.ratchetBox.put('current_session', state);
  }

  /*
   * 根據對方的身分公鑰與我方的身分私鑰，算出一把能被做為第一個 Root Key 的 Shared Secret。
   * Calculates the initial shared secret from identity keys to act as the first Root Key.
   */
  Future<SecretKey> _computeInitialRootKey(String remotePublicKeyBase64) async {
    final localKeyPair = identityManager.identityKeyPair;
    if (localKeyPair == null) throw Exception('Local identity key not found.');

    final remoteBytes = base64Decode(remotePublicKeyBase64);
    final remotePublicKey = SimplePublicKey(remoteBytes, type: KeyPairType.x25519);

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: localKeyPair,
      remotePublicKey: remotePublicKey,
    );
    final sharedBytes = await sharedSecret.extractBytes();

    // 保留我們的專案特色：使用 Blake2b 將初始秘密進行量子白化
    final hashObj = await _blake2b.hash(sharedBytes);
    return SecretKey(hashObj.bytes.sublist(0, 32)); // 擷取前 32 bytes 做為 RootKey
  }

  @override
  Future<String> encryptE2E(String plainText, String recipientPublicKey) async {
    // 1. 若 雙棘輪 尚未初始化，以 Alice (發起方) 角色初始化
    if (!_ratchetSession.isInitialized) {
      final rootSharedSecret = await _computeInitialRootKey(recipientPublicKey);
      final remoteBytes = base64Decode(recipientPublicKey);
      final remoteKey = SimplePublicKey(remoteBytes, type: KeyPairType.x25519);
      await _ratchetSession.initAsAlice(rootSharedSecret, remoteKey);
      print('🔒 [DoubleRatchet] Initiated as Alice (Sender).');
    }

    // 2. 向對稱鏈 (Sending Chain) 請求本回合的加密 Message Key
    final messageKey = await _ratchetSession.nextSendingMessageKey();
    
    // 3. 滾動後立即儲存狀態 (Persist state after ratchet step)
    await _persistSession();

    // 4. 取出當前的 DH 棘輪公鑰以附加在訊息頭，供對方驗證與金鑰滾動使用
    final localRatchetPub = await _ratchetSession.localRatchetPublicKey;
    final currentDhPublicKeyBytes = localRatchetPub!.bytes;
    final headerDhBase64 = base64Encode(currentDhPublicKeyBytes);

    // 5. ChaCha20 加密
    final messageBytes = utf8.encode(plainText);
    final nonce = _chacha20.newNonce();
    final secretBox = await _chacha20.encrypt(
      messageBytes,
      secretKey: messageKey,
      nonce: nonce,
    );
    final ciphertextBase64 = base64Encode(secretBox.concatenation());

    // 5. 將明文 Header (DH 棘輪公鑰) 與 密文 (加密後的內容) 打包成單一字串
    // 真實的 Signal 會將 header 放進 AEAD 的 associated data 中防篡改，這裡用簡易 JSON 包裝便於傳出 P2P
    final payloadBox = {
      'dh_pub': headerDhBase64,
      'ciphertext': ciphertextBase64,
    };

    return jsonEncode(payloadBox);
  }

  @override
  Future<String> decryptE2E(String encryptedBlob, String senderPublicKey) async {
    // 1. 若 雙棘輪 尚未初始化，以 Bob (接收方) 角色初始化
    if (!_ratchetSession.isInitialized) {
      final rootSharedSecret = await _computeInitialRootKey(senderPublicKey);
      // 身分私鑰兼作為 Bob 的第一把臨時 DH 私鑰 (安全容許)
      await _ratchetSession.initAsBob(rootSharedSecret, identityManager.identityKeyPair!);
      print('🔓 [DoubleRatchet] Initiated as Bob (Receiver).');
    }

    // 2. 剝開封裝，提取明文 Header 與 密文
    final Map<String, dynamic> payloadBox = jsonDecode(encryptedBlob);
    final headerDhBase64 = payloadBox['dh_pub'] as String;
    final ciphertextBase64 = payloadBox['ciphertext'] as String;

    final remoteDhBytes = base64Decode(headerDhBase64);
    final remoteDhKey = SimplePublicKey(remoteDhBytes, type: KeyPairType.x25519);

    // 3. 向接收對稱鏈 (Receiving Chain) 請求本次解密的 Message Key
    final messageKey = await _ratchetSession.nextReceivingMessageKey(remoteDhKey);

    // 4. 若有金鑰滾動，儲存最新狀態 (Persist updated state)
    await _persistSession();

    // 5. ChaCha20 解密
    final encryptedBytes = base64Decode(ciphertextBase64);
    final secretBox = SecretBox.fromConcatenation(
      encryptedBytes,
      nonceLength: _chacha20.nonceLength,
      macLength: _chacha20.macAlgorithm.macLength,
    );
    
    final decryptedBytes = await _chacha20.decrypt(
      secretBox,
      secretKey: messageKey,
    );
    
    return utf8.decode(decryptedBytes);
  }
}
