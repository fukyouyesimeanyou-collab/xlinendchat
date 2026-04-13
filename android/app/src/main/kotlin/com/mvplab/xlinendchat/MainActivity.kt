package com.mvplab.xlinendchat

import android.os.Bundle
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/*
 * MainActivity 擴充版：
 * 攔截原生層的實體音量鍵操作，用作 Panic Button（自毀按鈕）。
 * 
 * MainActivity extended:
 * Intercepts native physical volume key operations to act as a Panic Button.
 */
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.mvplab.xlinendchat/volume_keys"
    private var methodChannel: MethodChannel? = null

    /* 
     * 變數用來追蹤按鍵次數與組合，做為最高強度的「自毀密碼」。
     * Variables to track button press counts and combinations 
     * for the high-security "self-destruct password".
     */
    private var volumeUpPressCount = 0
    private var volumeDownPressCount = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        // 接收來自 Dart 的重置計數器指令 (Receive reset counter command from Dart)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "resetVolumeCounter" -> {
                    volumeUpPressCount = 0
                    volumeDownPressCount = 0
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /*
     * 攔截所有硬體按鍵事件。
     * Intercept all hardware key events.
     */
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            volumeUpPressCount++
            checkPanicSequence()
            return true // 吃掉事件防止音量視窗彈出 (Consume event to prevent volume UI pop-up)
        } else if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            volumeDownPressCount++
            checkPanicSequence()
            return true // 吃掉事件防止音量視窗彈出 (Consume event to prevent volume UI pop-up)
        }
        return super.onKeyDown(keyCode, event)
    }

    /*
     * 定義自毀密碼組合：例如上 3 次，下 3 次。
     * Defines the self-destruct mechanism sequence: e.g. Up 3 times, Down 3 times.
     */
    private fun checkPanicSequence() {
        // 自毀條件判斷 (Self-destruct condition check)
        // 當前設定：音量上鍵大於等於 3 次，音量下鍵大於等於 3 次
        // Current rule: Volume Up >= 3 times AND Volume Down >= 3 times
        if (volumeUpPressCount >= 3 && volumeDownPressCount >= 3) {
             // 呼叫 Dart 層觸發自毀 (Call Dart layer to trigger self-destruct)
             methodChannel?.invokeMethod("triggerSelfDestruct", null)
             
             // 觸發後重置計數器，避免被連續觸發 (Reset after trigger to prevent multiple calls)
             volumeUpPressCount = 0
             volumeDownPressCount = 0
        }
    }
}
