/* 
 * 引入 Dart 內建的編碼轉換庫，用於 Base64 編碼。
 * Imports the built-in Dart library for data conversion and Base64 encoding.
 */
import 'dart:convert';
import 'encryption_service.dart';

/* 
 * 這是一個「模擬」的加密服務類別 (Mock Encryption Service)。
 * 在開發初期，我們還不需要真實的複雜加密演算法，先用這個簡單的類別
 * 來模擬加密行為，確保 UI 與通訊流程可以運作。
 * 
 * This is a Mock Encryption Service.
 * During early development, we don't need real, complex cryptographic algorithms.
 * We use this simple class to simulate encryption behavior to ensure the UI 
 * and communication flows work as expected.
 */
class MockEncryptionService implements KeyGeneratorInterface, MessageCipherInterface {
  /* 
   * 儲存模擬的公鑰與私鑰。
   * Stores mock public and private keys.
   */
  String? _publicKey;
  String? _privateKey;

  @override
  /* 
   * 實作端到端加密的模擬。
   * Implementation of the mock end-to-end encryption.
   */
  Future<String> encryptE2E(String plainText, String recipientPublicKey) async {
    /* 
     * 在實際應用中，這裡會使用「雙棘輪協議」產生對話金鑰。
     * 這裡僅簡單地在內容前加上一個標記並轉換為 Base64。
     * In a real app, this would use the Double Ratchet protocol.
     * Here, we simply prepend a tag and encode it to Base64.
     */
    print('Encrypting for $recipientPublicKey');
    return base64.encode(utf8.encode('e2e_encrypted_$plainText'));
  }

  @override
  /* 
   * 實作端到端解密的模擬。
   * Implementation of the mock end-to-end decryption.
   */
  Future<String> decryptE2E(String encryptedBlob, String senderPublicKey) async {
    /* 
     * 將 Base64 資料還原，並移除模擬的加密標記。
     * Decodes the Base64 data and removes the mock encryption tag.
     */
    final decoded = utf8.decode(base64.decode(encryptedBlob));
    return decoded.replaceFirst('e2e_encrypted_', '');
  }

  @override
  /* 
   * 產生模擬的身分金鑰。
   * Generates mock identity keys.
   */
  Future<void> generateIdentityKeys() async {
    _publicKey = 'mock_id_pub_${DateTime.now().millisecondsSinceEpoch}';
    _privateKey = 'mock_id_priv_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  /* 
   * 產生模擬的隊列金鑰。
   * Generates mock queue keys.
   */
  Future<Map<String, String>> generateQueueKeys() async {
    return {
      'publicKey': 'mock_q_pub',
      'privateKey': 'mock_q_priv',
    };
  }
}
