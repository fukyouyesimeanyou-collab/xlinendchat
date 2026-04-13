/* 
 * 引入加密相關的第三方程式庫與資料庫：
 * 1. cryptography: 用於產生高安全性的 X25519 橢圓曲線金鑰對。
 * 2. database_service: 提供受硬體級 AES 加密保護的本地儲存機制。
 * 
 * Imports third-party cryptography libraries and local DB:
 * 1. cryptography: Used for generating highly secure X25519 elliptic curve key pairs.
 * 2. database_service: Provides hardware-AES encrypted local storage mechanism.
 */
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import '../encryption/encryption_service.dart';
import '../security/shredder_service.dart';
import '../storage/database_service.dart';

/* 
 * IdentityManager 類別：負責管理使用者的數位身分。
 * 
 * IdentityManager class: Manages the user's digital identity.
 */
class IdentityManager implements KeyGeneratorInterface {
  SimpleKeyPair? _identityKeyPair;
  String? _identityPublicKeyBase64;
  String? _identityPrivateKeyBase64;

  @override
  /* 
   * 產生或還原長期的身分金鑰對。如果儲存庫已有金鑰，則直接讀取還原。
   * Generates or restores long-term identity key pairs. Reads from DB if already exists.
   */
  Future<void> generateIdentityKeys() async {
    final vault = DatabaseService.vaultBox;
    final x25519 = X25519();

    // 嘗試從硬體保護的 Vault 讀取已存在的金鑰字串
    // Attempt to read existing key strings from hardware-protected Vault
    final existingPubKey = vault.get('identity_public_key_base64');
    final existingPrivKey = vault.get('identity_private_key_base64');

    if (existingPubKey != null && existingPrivKey != null) {
      _identityPublicKeyBase64 = existingPubKey;
      _identityPrivateKeyBase64 = existingPrivKey;
      
      // 將 Base64 還原成 cryptography 套件需要的 SimpleKeyPair
      // Restore Base64 strings into SimpleKeyPair required by the cryptography package
      final privBytes = base64Decode(existingPrivKey);
      final pubBytes = base64Decode(existingPubKey);
      
      _identityKeyPair = SimpleKeyPairData(
        privBytes,
        publicKey: SimplePublicKey(pubBytes, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
      
      print('✅ [Identity] Restored X25519 Keys from Secure Vault: $_identityPublicKeyBase64');
      return;
    }

    // 若無紀錄，產生全新金鑰對 (If no record, generate brand new key pair)
    _identityKeyPair = await x25519.newKeyPair();
    
    final pubKeyBytes = await _identityKeyPair!.extractPublicKey();
    final privKeyBytes = await _identityKeyPair!.extractPrivateKeyBytes();
    
    _identityPublicKeyBase64 = base64Encode(pubKeyBytes.bytes);
    _identityPrivateKeyBase64 = base64Encode(privKeyBytes);
    
    // 安全寫入 Vault (Securely write to Vault)
    await vault.put('identity_public_key_base64', _identityPublicKeyBase64);
    await vault.put('identity_private_key_base64', _identityPrivateKeyBase64);

    print('✅ [Identity] Generated and Stored New X25519 Identity Keys: $_identityPublicKeyBase64');
  }

  @override
  /* 
   * 為 SimpleX 訊息隊列產生臨時使用的金鑰 (X25519)。
   * Generates ephemeral keys for a SimpleX messaging queue (X25519).
   */
  Future<Map<String, String>> generateQueueKeys() async {
    final x25519 = X25519();
    final ephemeralKeyPair = await x25519.newKeyPair();
    
    final pubKeyBytes = await ephemeralKeyPair.extractPublicKey();
    final privKeyBytes = await ephemeralKeyPair.extractPrivateKeyBytes();
    
    return {
      'publicKey': base64Encode(pubKeyBytes.bytes),
      'privateKey': base64Encode(privKeyBytes),
    };
  }

  String? get identityPublicKey => _identityPublicKeyBase64;
  SimpleKeyPair? get identityKeyPair => _identityKeyPair;

  /*
   * 觸發自毀：清空記憶體中的金鑰、抹除 Database，並呼叫 ShredderService 進行物理銷毀。
   * Triggers self-destruct: clears keys in memory, wipes Database, and calls ShredderService for physical destruction.
   */
  Future<void> wipeIdentity() async {
    _identityKeyPair = null;
    _identityPublicKeyBase64 = null;
    _identityPrivateKeyBase64 = null;
    
    // 從資料庫中連根拔起 (Eradicate from Database)
    await DatabaseService.vaultBox.clear();
    await DatabaseService.chatHistoryBox.clear();

    await ShredderService.executeDoubleWipe();
  }
}
