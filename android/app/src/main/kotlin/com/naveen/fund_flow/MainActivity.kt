package com.naveen.fund_flow

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "fund_flow/notification_source",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessEnabled" -> result.success(
                    FinancialNotificationListenerService.isAccessEnabled(this),
                )
                "openAccessSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                "setCaptureEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    FinancialNotificationListenerService.setCaptureEnabled(this, enabled)
                    result.success(null)
                }
                "getPending" -> result.success(
                    FinancialNotificationListenerService.getPending(this),
                )
                "acknowledge" -> {
                    val ids = call.argument<List<String>>("ids").orEmpty()
                    FinancialNotificationListenerService.acknowledge(this, ids)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
