package com.vibe.vibe3

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    // Безопасность: FLAG_SECURE — запрет скриншотов + скрытие содержимого
    // в меню недавних приложений (включается из Настройки -> Безопасность)
    private fun setSecure(on: Boolean) {
        if (on) window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vibe.secure").setMethodCallHandler { call, result ->
            if (call.method == "setSecure") {
                setSecure(call.argument<Boolean>("on") ?: false)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
