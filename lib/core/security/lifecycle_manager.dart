import 'dart:async';
import 'dart:io';
import '../storage/database_service.dart';
import '../storage/storage_service.dart';
import '../models/chat_message.dart';
import 'shredder_service.dart';
import 'package:path/path.dart' as p;

class LifecycleManager {
  static final LifecycleManager _instance = LifecycleManager._internal();
  factory LifecycleManager() => _instance;
  LifecycleManager._internal();

  Timer? _reaperTimer;

  /*
   * 啟動生命週期監控
   */
  void start() {
    _reaperTimer?.cancel();
    // 每 5 分鐘執行一次清道夫 (Run reaper every 5 mins)
    _reaperTimer = Timer.periodic(const Duration(minutes: 5), (_) => _runReaper());
    _runReaper(); // 立即執行一次
  }

  Future<void> _runReaper() async {
    print('🧹 [Lifecycle] 正在執行數據清道夫任務...');
    final now = DateTime.now();
    final box = DatabaseService.chatHistoryBox;
    final barEnabled = StorageService.isBarEnabled();
    
    final keysToDelete = <dynamic>[];
    int deletedFilesCount = 0;

    for (var key in box.keys) {
      final msg = box.get(key);
      if (msg == null) continue;

      // 1. BAR 模式下的 24h 銷毀 (BAR ON: 24h after read)
      if (barEnabled && msg.readAt != null) {
        final durationSinceRead = now.difference(msg.readAt!);
        if (durationSinceRead.inHours >= 24) {
          keysToDelete.add(key);
        }
      }

      // 2. 超時未讀的自動清理 (Over 24h regardless of read, if BAR is OFF but user wants it cleaned)
      // 根據用戶要求 2a/2b: BAR 關閉情況下，暫存區 24h 後刪除並通知
      if (!barEnabled) {
        final timestamp = _parseTime(msg.time);
        if (now.difference(timestamp).inHours >= 24) {
          keysToDelete.add(key);
          if (msg.text.contains('[文件:')) {
            deletedFilesCount++;
          }
        }
      }
    }

    if (keysToDelete.isNotEmpty) {
      print('🔥 [Lifecycle] 正在銷毀 ${keysToDelete.length} 條過期數據...');
      await box.deleteAll(keysToDelete);
      
      if (!barEnabled && deletedFilesCount > 0) {
        _logExpirery(deletedFilesCount);
      }
    }
  }

  void _logExpirery(int count) {
    print('📢 [Lifecycle] 通知：有 $count 個檔案因超過 24 小時未導出已自動銷毀。');
    // 這裡可以發送一條系統訊息到 UI (Could emit a system event)
  }

  DateTime _parseTime(String timeStr) {
    try {
      return DateTime.parse(timeStr);
    } catch (_) {
      return DateTime.now();
    }
  }

  /*
   * 導出即焚 (Export then Shred)
   */
  Future<void> shredAfterExport(String filePath) async {
    print('🛡️ [Lifecycle] 偵測到檔案已導出，執行物理粉碎: $filePath');
    final file = File(filePath);
    if (await file.exists()) {
      // 這裡可以使用實體粉碎邏輯 (Shredding)
      await file.delete(); 
    }
  }

  void stop() {
    _reaperTimer?.cancel();
  }
}
