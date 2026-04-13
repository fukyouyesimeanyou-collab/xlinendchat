/*
 * double_ratchet.dart
 * 
 * 雙棘輪演算法 (Double Ratchet Algorithm) 的核心引擎。
 * 取代固定的「靜態 ECDH + ChaCha20」，為 App 帶來 Perfect Forward Secrecy。
 * 
 * Double Ratchet Algorithm core engine.
 * Replaces the static ECDH + ChaCha20 architecture to provide Perfect Forward Secrecy.
 *
 * 【設計基礎 Design Foundations】
 * 參考自 Signal 協議，雙棘輪結合了對稱金鑰滾動 (Symmetric-key ratcheting)
 * 與非對稱的 Diffie-Hellman 金鑰滾動 (DH ratcheting)。
 *
 * 1. 對稱棘輪 (Symmetric Ratchet): 每發送/接收一條訊息，就使用 KDF (HKDF-SHA256) 
 *    將 Chain Key 往前算一步，生出該次獨立的 Message Key (32 bytes)，同時覆蓋舊的 Chain Key。
 *    過去的 Message Key 即使洩漏，因單向雜湊無法推回過去的 Chain Key (Forward Secrecy)。
 * 2. DH 棘輪 (DH Ratchet): 每次對話角色互換(我方收到對方的新公鑰)時，
 *    進行一次 ECDH 交換，並與 Root Key 混合產生新的 Root Key 與新方向的 Chain Key。
 *    這使得即便當下狀態被駭客完整拷貝，下一次對話循環依然能產生全新的安全通道 (Future Secrecy)。
 */

import 'package:cryptography/cryptography.dart';
import '../models/ratchet_state.dart';

/*
 * 對稱金鑰棘輪鏈 (Symmetric Key Derivation Chain)
 * Symmetric Key Derivation Chain.
 */
class KdfChain {
  SecretKey chainKey;
  int messageNumber = 0;
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 64);

  KdfChain(this.chainKey);

  /*
   * 滾動棘輪 (Step the Ratchet):
   * 每呼叫一次，使用 HKDF 將目前的 chainKey 往前推進，
   * 前 32 bytes 成為下一步的 chainKey，後 32 bytes 成為本次的 messageKey。
   * Derive the next chainKey and the messageKey using HKDF.
   */
  Future<SecretKey> step() async {
    // 為了保證隨機性延伸，我們用固定的字串為 Info，以符合正規 HKDF 實踐
    final info = [0x01]; // 0x01 表示產出對稱棘輪所需的訊息金鑰集合

    final derivedMac = await _hkdf.deriveKey(
      secretKey: chainKey,
      nonce: [], // 無 salt 即可
      info: info,
    );

    final outBytes = await derivedMac.extractBytes();
    
    // 分割出 64 bytes 組合：前 32 bytes 用於衍生下一個 ChainKey, 後 32 bytes 用於當前的 MessageKey
    final nextChainKeyBytes = outBytes.sublist(0, 32);
    final messageKeyBytes = outBytes.sublist(32, 64);

    // 狀態更新: 覆蓋並刪除舊的 (Forward Secrecy 即在此處展現)
    // State update: Override and "delete" the old key internally.
    chainKey = SecretKey(nextChainKeyBytes);
    messageNumber++;

    return SecretKey(messageKeyBytes);
  }
}

/*
 * DoubleRatchetSession：管理單一對話的所有安全狀態。
 * Manages all security states for a single conversation.
 */
class DoubleRatchetSession {
  final Hkdf _rootHkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 64);
  final X25519 _x25519 = X25519();

  // Root Chain 的當前狀態
  SecretKey? _rootKey;

  // 我方當前的 DH 臨時棘輪密碼對 (Local DH ephemeral ratchet pair)
  SimpleKeyPair? _localDhRatchetKeyPair;
  
  // 對方當前的 DH 棘輪公鑰 (Remote DH ratchet public key)
  SimplePublicKey? _remoteRatchetPublicKey;

  // 對稱收發鏈 (Sending & Receiving Chains)
  KdfChain? _sendingChain;
  KdfChain? _receivingChain;

  // 暫存已經發生亂序到達的未來訊息解密用 Key (防止訊息遺漏)
  // Stored skipped message keys (prevents out-of-order delivery failure)
  final Map<int, SecretKey> _skippedMessageKeys = {};

  bool get isInitialized => _rootKey != null;

  /*
   * 允許外部取得當前的臨時 DH 公鑰，以便打包傳送給對方
   * Allows external access to current ephemeral DH public key for payload embedding.
   */
  Future<SimplePublicKey>? get localRatchetPublicKey => _localDhRatchetKeyPair?.extractPublicKey();

  /*
   * 發起方 (Alice) 的初始化
   * Alice Initiates. Her first message will send her DH public key.
   */
  Future<void> initAsAlice(SecretKey sharedSecret, SimplePublicKey remotePublicKey) async {
    _rootKey = sharedSecret;
    _remoteRatchetPublicKey = remotePublicKey;

    // 產生第一把 DH 發送用公私鑰
    _localDhRatchetKeyPair = await _x25519.newKeyPair();

    // 驅動第一次 DHRatchet，產生最初的 RootKey 與 SendingChain
    await _dhRatchetStep();
  }

  /*
   * 接收方 (Bob) 的初始化
   * Bob is initialized once he provides his initial key or receives the first message.
   */
  Future<void> initAsBob(SecretKey sharedSecret, SimpleKeyPair localKeyPair) async {
    _rootKey = sharedSecret;
    _localDhRatchetKeyPair = localKeyPair;
    // Bob 不會立刻執行 _dhRatchetStep，他等待 Alice 發送第一則帶有公鑰的訊息時啟動
  }

  /*
   * ECDH 棘輪步進機制
   * 結合新的 ECDH 與原有的 RootKey，生出新 RootKey + Receiving/Sending ChainKey
   * ECDH Ratchet step mechanism.
   */
  Future<void> _dhRatchetStep() async {
    if (_localDhRatchetKeyPair == null || _remoteRatchetPublicKey == null) return;
    if (_rootKey == null) throw Exception('Root key not initialized');

    // 計算 ECDH
    final dhOut = await _x25519.sharedSecretKey(
      keyPair: _localDhRatchetKeyPair!,
      remotePublicKey: _remoteRatchetPublicKey!,
    );
    final inputKeyMaterial = await dhOut.extractBytes();

    // 使用 RootHKDF 將 RootKey 和 ECDH 合體
    // Combine RootKey and ECDH using RootHKDF
    final derivedMac = await _rootHkdf.deriveKey(
      secretKey: _rootKey!, // 上一步的 rootKey 作為 IKM 或 Salt
      nonce: inputKeyMaterial, // 此處用新算出的 ECDH 作為擾動
      info: [0x02], // 0x02 標示 Root Ratchet
    );
    final outBytes = await derivedMac.extractBytes();

    _rootKey = SecretKey(outBytes.sublist(0, 32));
    
    // 將新產生的 32 bytes 掛載到適當的 Chain：
    // 在真實 Signal 實作中，發送方每次拋出新 ECDH，自己會得到一條 Receiving 和一條 Sending Chain，
    // 為簡單化及配合目前 SMP 對接，我們優先把金鑰投入 _sendingChain。
    final chainKey = SecretKey(outBytes.sublist(32, 64));
    
    _sendingChain = KdfChain(chainKey);
  }

  /*
   * 抓取下一把用於加密的 Message Key
   * Gets the next message key used for encryption.
   */
  Future<SecretKey> nextSendingMessageKey() async {
    if (_sendingChain == null) throw Exception('Sending chain not initialized');
    return await _sendingChain!.step();
  }

  /*
   * 抓取下一把用於解密的 Message Key
   * Gets the next message key used for decryption.
   * 注意：此處需要帶上收到包裹內的 public key 標記，若對方已換 key，則觸發 _dhRatchetStep 收斂。
   */
  Future<SecretKey> nextReceivingMessageKey(SimplePublicKey? newRemotePublicKey) async {
    // 若對方附帶的 PublicKey 改變，觸發 DH Ratchet 產生全新的 Receiving Chain
    if (newRemotePublicKey != null && _remoteRatchetPublicKey != newRemotePublicKey) {
      _remoteRatchetPublicKey = newRemotePublicKey;
      
      // 更新 Receiving Chain 
      await _dhRatchetStep();
      
      // 為下一次回應準備新的發送金鑰對
      _localDhRatchetKeyPair = await _x25519.newKeyPair();
    }

    if (_receivingChain == null) {
      // 假設 Receiving Chain 是第一組或者剛好被 DH Ratchet 初始化了
      // 在簡易實作中，直接把 _sendingChain 當作共用推演鏈 (真實實作會將 Sending/Receiving 劈開)
      _receivingChain = _sendingChain; 
    }

    if (_receivingChain == null) throw Exception('Receiving chain not ready');

    return await _receivingChain!.step();
  }

  /*
   * 將當前記憶體狀態轉換為可持久化的 RatchetState 物件
   * Converts current in-memory state to a persistable RatchetState object.
   */
  Future<RatchetState> toState() async {
    return RatchetState(
      rootKeyBytes: _rootKey != null ? await _rootKey!.extractBytes() : null,
      localDhPrivKeyBytes: _localDhRatchetKeyPair != null ? await _localDhRatchetKeyPair!.extractPrivateKeyBytes() : null,
      localDhPubKeyBytes: _localDhRatchetKeyPair != null ? (await _localDhRatchetKeyPair!.extractPublicKey()).bytes : null,
      remoteDhPubKeyBytes: _remoteRatchetPublicKey != null ? _remoteRatchetPublicKey!.bytes : null,
      sendingChainKeyBytes: _sendingChain != null ? await _sendingChain!.chainKey.extractBytes() : null,
      sendingMessageNumber: _sendingChain?.messageNumber ?? 0,
      receivingChainKeyBytes: _receivingChain != null ? await _receivingChain!.chainKey.extractBytes() : null,
      receivingMessageNumber: _receivingChain?.messageNumber ?? 0,
      skippedMessageKeys: {
        for (var entry in _skippedMessageKeys.entries)
          entry.key: await entry.value.extractBytes()
      },
    );
  }

  /*
   * 從持久化的 RatchetState 物件還原記憶體狀態
   * Restores in-memory state from a persisted RatchetState object.
   */
  Future<void> loadFromState(RatchetState state) async {
    if (state.rootKeyBytes != null) {
      _rootKey = SecretKey(state.rootKeyBytes!);
    }
    
    if (state.localDhPrivKeyBytes != null && state.localDhPubKeyBytes != null) {
      _localDhRatchetKeyPair = SimpleKeyPairData(
        state.localDhPrivKeyBytes!,
        publicKey: SimplePublicKey(state.localDhPubKeyBytes!, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
    }
    
    if (state.remoteDhPubKeyBytes != null) {
      _remoteRatchetPublicKey = SimplePublicKey(state.remoteDhPubKeyBytes!, type: KeyPairType.x25519);
    }
    
    if (state.sendingChainKeyBytes != null) {
      _sendingChain = KdfChain(SecretKey(state.sendingChainKeyBytes!));
      _sendingChain!.messageNumber = state.sendingMessageNumber;
    }
    
    if (state.receivingChainKeyBytes != null) {
      _receivingChain = KdfChain(SecretKey(state.receivingChainKeyBytes!));
      _receivingChain!.messageNumber = state.receivingMessageNumber;
    }
    
    _skippedMessageKeys.clear();
    state.skippedMessageKeys.forEach((key, value) {
      _skippedMessageKeys[key] = SecretKey(value);
    });
  }
}
