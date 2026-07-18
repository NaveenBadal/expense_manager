package com.naveen.fund_flow

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.provider.Telephony
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "fund_flow/sms_history",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "queryPage" -> {
                    val after = call.argument<Number>("after")?.toLong() ?: 0L
                    val start = (call.argument<Number>("start")?.toInt() ?: 0).coerceAtLeast(0)
                    val count = (call.argument<Number>("count")?.toInt() ?: 500)
                        .coerceIn(1, 500)
                    try {
                        val messages = mutableListOf<Map<String, Any?>>()
                        contentResolver.query(
                            Telephony.Sms.Inbox.CONTENT_URI,
                            arrayOf(
                                Telephony.Sms._ID,
                                Telephony.Sms.ADDRESS,
                                Telephony.Sms.BODY,
                                Telephony.Sms.DATE,
                            ),
                            "${Telephony.Sms.DATE} >= ?",
                            arrayOf(after.toString()),
                            "${Telephony.Sms.DATE} DESC",
                        )?.use { cursor ->
                            val addressIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
                            val bodyIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
                            val dateIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)
                            val canRead = start == 0 || cursor.moveToPosition(start - 1)
                            var read = 0
                            while (canRead && read < count && cursor.moveToNext()) {
                                messages.add(
                                    mapOf(
                                        "address" to cursor.getString(addressIndex),
                                        "body" to cursor.getString(bodyIndex),
                                        "date" to cursor.getLong(dateIndex),
                                    ),
                                )
                                read++
                            }
                        }
                        result.success(messages)
                    } catch (error: SecurityException) {
                        result.error("sms_permission", error.message, null)
                    } catch (error: Exception) {
                        result.error("sms_query_failed", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "fund_flow/updater",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestInstalls" -> result.success(
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                        packageManager.canRequestPackageInstalls(),
                )
                "openInstallPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                    }
                    result.success(null)
                }
                "installApk" -> {
                    val rawPath = call.argument<String>("path")
                    if (rawPath.isNullOrBlank()) {
                        result.error("missing_path", "APK path is required", null)
                    } else {
                        try {
                            val apk = File(rawPath).canonicalFile
                            val cache = cacheDir.canonicalFile
                            require(apk.exists() && apk.path.startsWith(cache.path)) {
                                "APK must exist inside Fund Flow's cache"
                            }
                            val uri = FileProvider.getUriForFile(
                                this,
                                "$packageName.updates",
                                apk,
                            )
                            startActivity(
                                Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(uri, "application/vnd.android.package-archive")
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                },
                            )
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("install_failed", error.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
