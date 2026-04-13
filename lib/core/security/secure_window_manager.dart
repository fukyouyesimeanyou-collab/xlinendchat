/*
 * SecureWindowManager 類別：
 * 負責呼叫 Android/iOS 系統底層的防截圖與防錄影機制。
 * 利用 no_screenshot 套件，在 Android 啟動 FLAG_SECURE。
 *
 * SecureWindowManager class:
 * Responsible for invoking native Android/iOS anti-screenshot and anti-recording mechanisms.
 * Utilizes the no_screenshot package to enable FLAG_SECURE on Android.
 */
import 'package:no_screenshot/no_screenshot.dart';

class SecureWindowManager {
  /* 初始化 NoScreenshot 實例 (Initialize NoScreenshot instance) */
  static final _noScreenshot = NoScreenshot.instance;

  /*
   * 啟用防截圖保護。
   * Enables anti-screenshot protection.
   */
  static Future<void> enableProtection() async {
    try {
      /* 
       * 關閉該應用的截圖功能 (底層會向 Android WindowManager 註冊 FLAG_SECURE)
       * Turns off screenshots for the app (Registers FLAG_SECURE with Android WindowManager)
       */
      await _noScreenshot.screenshotOff();
      print('Anti-screenshot protection enabled (FLAG_SECURE ON).');
    } catch (e) {
      print('Failed to enable anti-screenshot protection: $e');
    }
  }

  /*
   * 停用防截圖保護。
   * Disables anti-screenshot protection.
   */
  static Future<void> disableProtection() async {
    try {
      await _noScreenshot.screenshotOn();
      print('Anti-screenshot protection disabled (FLAG_SECURE OFF).');
    } catch (e) {
      print('Failed to disable anti-screenshot protection: $e');
    }
  }
}
