package com.ironvault.app

import android.os.Bundle
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private lateinit var lifecycleChannel: MethodChannel

    override fun onCreate(savedInstanceState: Bundle?) {
        // Set secure flag before activity finishes initialization so recents
        // snapshot/content are protected from the start.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        lifecycleChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ironvault/lifecycle"
        )
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (::lifecycleChannel.isInitialized) {
            lifecycleChannel.invokeMethod("userLeaveHint", null)
        }
    }

    override fun onPause() {
        super.onPause()
        if (::lifecycleChannel.isInitialized) {
            lifecycleChannel.invokeMethod("appPaused", null)
        }
    }

    override fun onStop() {
        super.onStop()
        if (::lifecycleChannel.isInitialized) {
            lifecycleChannel.invokeMethod("appBackgrounded", null)
        }
    }
}
