/*
 * VolumeKeyInterceptor 類別：
 * 監聽來自 Android 原生層的音量鍵觸發事件 (Panic Button)。
 * 
 * VolumeKeyInterceptor class:
 * Listens to volume key trigger events from the Android native layer (Panic Button).
 */
import 'package:flutter/services.dart';
import '../identity/identity_manager.dart';

class VolumeKeyInterceptor {
  /* 
   * 定義與 Kotlin 端相同的 Channel 名稱 
   * Same Channel name as Kotlin side 
   */
  static const MethodChannel _channel = MethodChannel('com.mvplab.xlinendchat/volume_keys');

  /*
   * 啟動監聽器，準備接收原生層的自毀信號。
   * Starts the listener, preparing to receive self-destruct signals from native layer.
   */
  static void startListening(IdentityManager identityManager) {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'triggerSelfDestruct') {
        print('CRITICAL: Panic Button sequence detected via Volume Keys!');
        
        /* 
         * 呼叫身分管理器執行終極銷毀指令。
         * Call the identity manager to execute the ultimate destruction command.
         */
        await identityManager.wipeIdentity();
      }
    });
    print('Volume Key Interceptor started mapping Native channels.');
  }

  /*
   * (可選) 提供重置計數器的接口，如果需要讓使用者透過 UI 復原按鍵狀態。
   * (Optional) Interface to reset the counter, if UI needs to reset button state.
   */
  static Future<void> resetCounter() async {
    try {
      await _channel.invokeMethod('resetVolumeCounter');
    } catch (e) {
      print('Failed to reset volume counter: $e');
    }
  }
}
