import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// 包含 Double Ratchet 所需的密碼學基元封裝
/// Contains the cryptographic primitives required for the Double Ratchet sequence.
class CryptoUtils {
  static final _x25519 = X25519();
  static final _chacha20 = Chacha20.poly1305Aead();

  /// 產生 X25519 金鑰對
  /// Generate a new X25519 KeyPair for Diffie-Hellman exchange.
  static Future<SimpleKeyPair> generateKeyPair() async {
    return await _x25519.newKeyPair();
  }

  /// 執行 X25519 Diffie-Hellman 密鑰交換
  /// Perform a Diffie-Hellman exchange using X25519.
  static Future<SecretKey> dh(SimpleKeyPair keyPair, PublicKey otherPublicKey) async {
    return await _x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: otherPublicKey,
    );
  }

  /// 使用 HKDF-SHA256 執行 KDF (Key Derivation Function) 衍生金鑰
  /// KDF function using HKDF-SHA256 to derive new keys from a root key and an input material
  ///
  /// Returns a tuple-like list containing [RootKey, ChainKey].
  static Future<List<SecretKey>> kdfRk(SecretKey rk, SecretKey dhOut) async {
    // HKDF extracts and expands the shared secret, using the existing Root Key (rk) as the salt.
    // The Double Ratchet specification uses HKDF to generate a 64-byte output,
    // which is then split into two 32-byte keys (the new Root Key and the new Chain Key).
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 64,
    );
    
    // In Double Ratchet, dhOut is the IKM (Initial Keying Material), and RK is the salt.
    final derivedBytes = await hkdf.deriveKey(
      secretKey: dhOut,
      nonce: await rk.extractBytes(),
      info: utf8.encode('RatelRoot'), // Info is arbitrary but consistent
    ).then((key) => key.extractBytes());

    final newRk = SecretKey(derivedBytes.sublist(0, 32));
    final newCk = SecretKey(derivedBytes.sublist(32, 64));

    return [newRk, newCk];
  }

  /// 單向鏈路衍生 (Symmetric-key ratchet)
  /// Derives the next Chain Key and the Message Key from the current Chain Key.
  /// 
  /// Returns a tuple-like list containing [NextChainKey, MessageKey].
  static Future<List<SecretKey>> kdfCk(SecretKey ck) async {
    final hmac = Hmac.sha256();
    
    // According to Double Ratchet specs for Symmetric-key ratchet:
    // Message Key (MK) = HMAC-SHA256(CK, 0x01)
    // Next Chain Key (CK) = HMAC-SHA256(CK, 0x02)
    
    final mkMac = await hmac.calculateMac(
      [0x01],
      secretKey: ck,
    );
    final mk = SecretKey(mkMac.bytes);

    final nextCkMac = await hmac.calculateMac(
      [0x02],
      secretKey: ck,
    );
    final nextCk = SecretKey(nextCkMac.bytes);

    return [nextCk, mk];
  }

  /// 使用 ChaCha20-Poly1305 加密訊息
  /// Encrypts plaintext using AEAD (ChaCha20-Poly1305).
  static Future<List<int>> encryptAead(SecretKey mk, List<int> plaintext, List<int> ad) async {
    final secretBox = await _chacha20.encrypt(
      plaintext,
      secretKey: mk,
      aad: ad, // Associated Data
    );
    // Combine nonce, ciphertext, and mac into a single payload
    return secretBox.concatenation();
  }

  /// 使用 ChaCha20-Poly1305 解密訊息
  /// Decrypts a SecretBox payload using AEAD (ChaCha20-Poly1305).
  static Future<List<int>> decryptAead(SecretKey mk, List<int> payload, List<int> ad) async {
    try {
      final secretBox = SecretBox.fromConcatenation(
        payload,
        nonceLength: _chacha20.nonceLength,
        macLength: _chacha20.macAlgorithm.macLength,
      );

      final cleartext = await _chacha20.decrypt(
        secretBox,
        secretKey: mk,
        aad: ad,
      );
      return cleartext;
    } catch (e) {
      throw Exception('AEAD Decryption failed (Authentication failed or corrupted data): $e');
    }
  }

  /// 建立空金鑰序列 (32 bytes of zeros) - 用於初始化第一把 Root Key
  /// Creates an empty secret key (32 bytes of zeros) primarily for initial state.
  static SecretKey createEmptyKey() {
    return SecretKey(List<int>.filled(32, 0));
  }
}
