import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'encryption_service.dart';
import 'crypto_utils.dart';
import 'double_ratchet.dart' as dr;
import '../storage/database_service.dart';
import '../models/ratchet_state.dart' as models;

/// 負責實作端到端加密的真實雙棘輪服務
/// Implements the real Double Ratchet protocol for E2EE.
class DoubleRatchetService implements KeyGeneratorInterface, MessageCipherInterface {
  SimpleKeyPair? _identityKeyPair;
  
  // Stores RatchetState per contact (keyed by contact's public key string)
  final Map<String, dr.RatchetState> _sessions = {};

  final List<int> _associatedData = utf8.encode("XLINE_APP_V1");

  /// 輔助：將 Hive 模型轉換為運算狀態 (Helper: Hive model -> Ops state)
  Future<dr.RatchetState> _fromModels(models.RatchetState model) async {
    return await dr.RatchetState.fromBytes(
      rk: model.rootKeyBytes!,
      localDhPriv: model.localDhPrivKeyBytes,
      localDhPub: model.localDhPubKeyBytes,
      remoteDhPub: model.remoteDhPubKeyBytes,
      cks: model.sendingChainKeyBytes,
      ns: model.sendingMessageNumber,
      ckr: model.receivingChainKeyBytes,
      nr: model.receivingMessageNumber,
      skipped: model.skippedMessageKeys,
    );
  }

  /// 輔助：將運算狀態存入 Hive (Helper: Ops state -> Hive)
  Future<void> _saveSession(String contactId, dr.RatchetState state) async {
    final hiveMap = await state.toHiveState();
    final model = models.RatchetState(
      rootKeyBytes: hiveMap['rootKeyBytes'],
      localDhPrivKeyBytes: hiveMap['localDhPrivKeyBytes'],
      localDhPubKeyBytes: hiveMap['localDhPubKeyBytes'],
      remoteDhPubKeyBytes: hiveMap['remoteDhPubKeyBytes'],
      sendingChainKeyBytes: hiveMap['sendingChainKeyBytes'],
      sendingMessageNumber: hiveMap['sendingMessageNumber'],
      receivingChainKeyBytes: hiveMap['receivingChainKeyBytes'],
      receivingMessageNumber: hiveMap['receivingMessageNumber'],
      skippedMessageKeys: hiveMap['skippedMessageKeys'],
    );
    await DatabaseService.ratchetBox.put(contactId, model);
  }

  @override
  Future<void> generateIdentityKeys() async {
    _identityKeyPair = await CryptoUtils.generateKeyPair();
    print("DoubleRatchetService: Internal identity keys generated.");
  }

  /// 允許從外部設定身分金鑰 (例如從 IdentityManager 注入)
  /// Allows setting the identity keypair from an external source (e.g., IdentityManager).
  void setIdentityKeyPair(SimpleKeyPair keyPair) {
    _identityKeyPair = keyPair;
  }

  @override
  Future<Map<String, String>> generateQueueKeys() async {
    // 這裡原本是用於 SMP 隊列金鑰，雙棘輪中也可復用此概念
    final keyPair = await CryptoUtils.generateKeyPair();
    final pubKeyBytes = await keyPair.extractPublicKey().then((pk) => pk.bytes);
    
    // We only need Base64 strings for the interface at the moment
    // In a real app we'd save the private key associated with this pubkey
    return {
      'publicKey': base64.encode(pubKeyBytes),
      // Dummy private key since the underlying queue logic might not use it directly if E2E overrides it
      'privateKey': 'generated_q_priv', 
    };
  }

  /// 輔助函數：取得我方的 Public Key (Base64)
  Future<String> getMyPublicKey() async {
    if (_identityKeyPair == null) await generateIdentityKeys();
    final pk = await _identityKeyPair!.extractPublicKey();
    return base64.encode(pk.bytes);
  }

  /// 輔助函數：將 Base64 string 轉回 PublicKey
  SimplePublicKey _parsePublicKey(String pubKeyBase64) {
    return SimplePublicKey(
      base64.decode(pubKeyBase64),
      type: KeyPairType.x25519,
    );
  }

  /// 透過雙方的 Identity Keys 進行一般 DH 交換，以此作為 Ratchet 的 Root Key
  /// (簡化版 X3DH，僅作示範使用)
  /// Uses a basic DH exchange between identity keys to establish the initial Root Key
  /// (Simplified X3DH for demonstration purposes)
  Future<SecretKey> _deriveInitialSharedSecret(SimplePublicKey otherKey) async {
    if (_identityKeyPair == null) await generateIdentityKeys();
    return await CryptoUtils.dh(_identityKeyPair!, otherKey);
  }

  @override
  Future<String> encryptE2E(String plainText, String recipientPublicKeyStr) async {
    dr.RatchetState? state = _sessions[recipientPublicKeyStr];
    
    // 試著從資料庫加載 (Try loading from DB)
    if (state == null) {
      final savedModel = DatabaseService.ratchetBox.get(recipientPublicKeyStr);
      if (savedModel != null) {
        state = await _fromModels(savedModel);
        _sessions[recipientPublicKeyStr] = state;
        print("💾 [DoubleRatchet] Loaded saved session for $recipientPublicKeyStr");
      }
    }

    if (state == null) {
      // 假設我們是 Alice，主動發起對話。我們需要對方的公鑰
      final bobPubKey = _parsePublicKey(recipientPublicKeyStr);
      final initialSk = await _deriveInitialSharedSecret(bobPubKey);
      
      // Alice 初始化 Ratchet
      state = await dr.DoubleRatchet.ratchetInitAlice(initialSk, bobPubKey);
      _sessions[recipientPublicKeyStr] = state;
      print("DoubleRatchetService: Initialized Alice Ratchet state for $recipientPublicKeyStr");
    }

    final payload = await dr.DoubleRatchet.ratchetEncrypt(state, utf8.encode(plainText), _associatedData);
    
    // 立即持久化 (Immediate persistence)
    await _saveSession(recipientPublicKeyStr, state);
    
    return base64.encode(payload);
  }

  @override
  Future<String> decryptE2E(String encryptedBlob, String senderPublicKeyStr) async {
    final payloadBytes = base64.decode(encryptedBlob);
    dr.RatchetState? state = _sessions[senderPublicKeyStr];

    // 試著從資料庫加載 (Try loading from DB)
    if (state == null) {
      final savedModel = DatabaseService.ratchetBox.get(senderPublicKeyStr);
      if (savedModel != null) {
        state = await _fromModels(savedModel);
        _sessions[senderPublicKeyStr] = state;
        print("💾 [DoubleRatchet] Loaded saved session for $senderPublicKeyStr");
      }
    }

    if (state == null) {
      // 假設我們是 Bob，收到 Alice 的第一則訊息。
      final alicePubKey = _parsePublicKey(senderPublicKeyStr);
      final initialSk = await _deriveInitialSharedSecret(alicePubKey);
      
      // Bob 要傳入他自己的 identity keypair 讓 Ratchet 計算
      if (_identityKeyPair == null) await generateIdentityKeys();
      state = await dr.DoubleRatchet.ratchetInitBob(initialSk, _identityKeyPair!);
      _sessions[senderPublicKeyStr] = state;
      print("DoubleRatchetService: Initialized Bob Ratchet state for $senderPublicKeyStr");
    }

    final cleartextBytes = await dr.DoubleRatchet.ratchetDecrypt(state, payloadBytes, _associatedData);
    
    // 立即持久化 (Immediate persistence)
    await _saveSession(senderPublicKeyStr, state);
    
    return utf8.decode(cleartextBytes);
  }
}
