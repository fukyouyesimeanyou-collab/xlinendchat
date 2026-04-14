import 'package:disk_space_2/disk_space_2.dart';
import 'database_service.dart';

class StorageService {
  static const String _quotaKey = 'storage_quota_mb';
  static const String _barEnabledKey = 'global_bar_enabled';

  /* 
   * 獲取目前設備的空閒空間 (MB)
   * Get current free space of the device (MB)
   */
  static Future<double> getFreeSpace() async {
    return (await DiskSpace.getFreeDiskSpace) ?? 0;
  }

  /* 
   * 獲取目前設備的總空間 (MB)
   * Get total space of the device (MB)
   */
  static Future<double> getTotalSpace() async {
    return (await DiskSpace.getTotalDiskSpace) ?? 1;
  }

  /* 
   * 獲取用戶設定的暫存 Quota (MB)
   * Get user-defined temporary quota (MB)
   * 預設為 1024MB (1GB)
   */
  static double getStorageQuota() {
    return DatabaseService.vaultBox.get(_quotaKey, defaultValue: 1024.0);
  }

  /* 
   * 儲存用戶設定的暫存 Quota (MB)
   * Save user-defined temporary quota (MB)
   */
  static Future<void> setStorageQuota(double mb) async {
    await DatabaseService.vaultBox.put(_quotaKey, mb);
  }

  /* 
   * 全局 BAR (閱後即焚) 開關狀態
   * Global BAR (Burn After Reading) toggle status
   */
  static bool isBarEnabled() {
    return DatabaseService.vaultBox.get(_barEnabledKey, defaultValue: true);
  }

  static Future<void> setBarEnabled(bool enabled) async {
    await DatabaseService.vaultBox.put(_barEnabledKey, enabled);
  }

  /* 
   * 檢查目前暫存區是否已滿 (Check if quota is exceeded)
   * 註：這是一個簡化版本，實際應計算 tempDir 的檔案總和。
   */
  static Future<bool> isQuotaExceeded(int incomingFileSizeInBytes) async {
    // 這裡應掃描暫存資料夾，目前先以剩餘空間作為安全網
    final free = await getFreeSpace();
    final quota = getStorageQuota();
    
    // 如果系統總剩餘空間小於 200MB，則強制攔截以保護系統穩定性
    if (free < 200) return true;
    
    return false; // 進階邏輯將在後續對接到 FileTransferService
  }
}
