/*
 * ShredderService 類別：
 * 提供最高強度的資料物理與邏輯銷毀機制。
 * 不只是呼叫刪除，還會試圖在檔案上覆寫隨機資料 (Shredding)，提升 SSD 恢復難度。
 *
 * ShredderService class:
 * Provides the highest intensity physical and logical data destruction mechanism.
 * Beyond standard deletion, it attempts to overwrite files with random data (Shredding)
 * to increase the difficulty of SSD data recovery.
 */
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../storage/database_service.dart';

class ShredderService {
  /*
   * 觸發終極自毀程序。
   * Triggers the ultimate self-destruct sequence.
   */
  static Future<void> executeDoubleWipe() async {
    print('WARNING: Initiating complete data shredding and wipe.');
    
    try {
      /* 第一層：關閉所有已開啟的 Hive 資料庫連線 (Level 1: Close all Hive boxes) */
      await Hive.close();
      
      /* 
       * 實體路徑覆寫 (僅限行動裝置，Web 無法如此操作底層檔案系統)
       * Physical path overwrite (Mobile only; Web cannot directly access the file system this way)
       */
      if (!kIsWeb) {
        // Warning: This requires knowing the Hive path, normally set during init.
        // For demonstration, we assume a typical path structure.
        final dir = Directory.current; 
        final List<FileSystemEntity> files = dir.listSync(recursive: true);
        
        final random = Random.secure();
        
        for (var file in files) {
          if (file is File && file.path.endsWith('.hive')) {
            try {
              /* 
               * 第二層：用隨機資料覆寫檔案內容，模擬實體粉碎。
               * Level 2: Overwrite file contents with random data to simulate physical shredding.
               */
              final length = file.lengthSync();
              final garbage = List<int>.generate(length, (i) => random.nextInt(256));
              
              /* 以 Sync 寫入並強制 flush 到磁碟 (Write synchronously and flush to disk) */
              final raf = file.openSync(mode: FileMode.write);
              raf.writeFromSync(garbage);
              raf.flushSync(); 
              raf.closeSync();
              
              /* 邏輯刪除 (Logical delete) */
              file.deleteSync();
            } catch (e) {
              /* 忽略無法覆寫的檔案錯誤 (Ignore errors for un-overwritable files) */
              debugPrint('Failed to shred file: ${file.path}');
            }
          }
        }
      }
      
      /* 最後使用 Hive 原生的刪除指令確保殘留快取清空 (Finally use Hive native delete to ensure cache is cleared) */
      await Hive.deleteFromDisk();
      
      print('Self-destruct sequence completed.');
    } catch (e) {
      print('Critical error during self-destruct: $e');
    }
  }

  /*
   * 銷毀特定的對話 Session。
   * Shreds specific chat session by chatId.
   */
  static Future<void> shredSession(String chatId) async {
    try {
      final box = DatabaseService.chatHistoryBox;
      final keysToDelete = <dynamic>[];
      
      // 找出所有屬於該 chatId 的訊息 (Find all messages for this chatId)
      for (var key in box.keys) {
        final msg = box.get(key);
        if (msg?.chatId == chatId) {
          keysToDelete.add(key);
        }
      }
      
      // 執行刪除 (Execute deletion)
      if (keysToDelete.isNotEmpty) {
        await box.deleteAll(keysToDelete);
        debugPrint('🔥 [ShredderService] 已銷毀對話 Session: $chatId');
      }
    } catch (e) {
      debugPrint('Error shredsing session: $e');
    }
  }
}
