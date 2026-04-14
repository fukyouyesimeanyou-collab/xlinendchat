/*
 * database_service.dart
 *
 * 這是專案的硬體加密資料庫核心服務。
 * 利用 `flutter_secure_storage` 索取作業系統底層 (iOS Keychain / Android Keystore) 給予的
 * 最高權限 AES 金鑰，再將此金鑰餵給 Hive 資料庫作為全域加密器 (HiveAesCipher)。
 * 
 * Database Service: hardware-encrypted local storage core.
 * Uses `flutter_secure_storage` to fetch a high-level AES key from the OS native 
 * Keystore/Keychain, feeding it to Hive as a global cipher.
 */

import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/chat_message.dart';
import '../models/ratchet_state.dart';
import '../models/contact.dart';

class DatabaseService {
  static const _secureStorage = FlutterSecureStorage();
  static const _keyPrefix = 'hive_encryption_key';
  
  // 提供給外部直接存取的 Boxes (Boxes exposed for external access)
  static late Box vaultBox;
  static late Box<ChatMessage> chatHistoryBox;
  static late Box<RatchetState> ratchetBox;
  static late Box<Contact> contactsBox;
  static late Box stickersBox; // 為貼圖庫新增的 Box (Added for sticker library)

  /*
   * 在 App 啟動時必須先呼叫的非同步初始化函式
   * Async initialization function that must be called upon App startup.
   */
  static Future<void> initialize() async {
    // 1. 初始化 Hive 本地檔案結構 (Init Hive local file paths)
    await Hive.initFlutter();

    /* 
     * 註冊生成的 TypeAdapters (Register generated adapters)
     */
    Hive.registerAdapter(ChatMessageAdapter());
    Hive.registerAdapter(MessageStatusAdapter());
    Hive.registerAdapter(RatchetStateAdapter());
    Hive.registerAdapter(ContactAdapter());
    Hive.registerAdapter(ContactStatusAdapter());

    // 2. 向硬體請求或生成 256 位元 AES 金鑰 (Retrieve or generate 256-bit AES key from hardware)
    String? base64EncryptionKey = await _secureStorage.read(key: _keyPrefix);
    if (base64EncryptionKey == null) {
      // 產生 32 bytes (256 bits) 的高強度安全隨機數
      // Generate 32 bytes (256 bits) cryptographically secure random number
      final secureRandom = Random.secure();
      final keyBytes = List<int>.generate(32, (i) => secureRandom.nextInt(256));
      base64EncryptionKey = base64UrlEncode(keyBytes);
      
      // 存回硬體安全儲存區存檔 (Save to native secure storage)
      await _secureStorage.write(key: _keyPrefix, value: base64EncryptionKey);
      print('🔒 [DatabaseService] 產生新的硬體 AES 金鑰 (Generated new hardware AES key)');
    }

    final encryptionKeyBytes = base64Url.decode(base64EncryptionKey);

    // 3. 定義 AES Cipher (Define AES Cipher)
    final cipher = HiveAesCipher(encryptionKeyBytes);

    // 4. 開啟被 AES 加密保護的箱子 (Open AES-encrypted boxes)
    // - vault: 用來存放 X25519 數位身分金鑰與雙棘輪推演狀態。 (For Identity keys & Ratchet states)
    // - chat_history: 用來存放已經解密的敏感對話內容。 (For decrypted sensitive chat histories)
    
    vaultBox = await Hive.openBox('vault', encryptionCipher: cipher);
    chatHistoryBox = await Hive.openBox<ChatMessage>('chat_history', encryptionCipher: cipher);
    ratchetBox = await Hive.openBox<RatchetState>('ratchet', encryptionCipher: cipher);
    contactsBox = await Hive.openBox<Contact>('contacts', encryptionCipher: cipher);
    stickersBox = await Hive.openBox('stickers', encryptionCipher: cipher);
    
    print('✅ [DatabaseService] 成功載入受硬體保護的加密資料庫 (Successfully loaded hardware-encrypted databases)');
    
    // 執行過期 BAR 對話檢查 (Perform expired BAR session check)
    await _checkExpiredBarSessions();
  }

  /*
   * 補執行機制：檢查是否有在 App 關閉期間過期的 BAR 對話。
   * Startup check: Clean up BAR sessions that expired while the app was closed.
   */
  static Future<void> _checkExpiredBarSessions() async {
    final now = DateTime.now();
    final contacts = contactsBox.values.toList();
    
    for (var contact in contacts) {
      if (contact.isBarActive && contact.barSessionExpiry != null) {
        if (contact.barSessionExpiry!.isBefore(now)) {
          print('🚨 [BARCheck] 偵測到過期對話 (${contact.displayName})，啟動自動銷毀...');
          
          // 1. 物理粉碎訊息 (Shred messages)
          // Note: ShredderService needs to be imported or use its logic here.
          // Since we are in DatabaseService, we can access chatHistoryBox directly.
          final keysToDelete = <dynamic>[];
          for (var key in chatHistoryBox.keys) {
            final msg = chatHistoryBox.get(key);
            if (msg?.chatId == contact.publicKeyBase64) {
              keysToDelete.add(key);
            }
          }
          if (keysToDelete.isNotEmpty) {
            await chatHistoryBox.deleteAll(keysToDelete);
          }
          
          // 2. 重置狀態 (Reset state)
          contact.isBarActive = false;
          contact.barSessionExpiry = null;
          await contact.save();
          
          print('🔥 [BARCheck] 過期對話已銷毀。');
        }
      }
    }
  }
}
