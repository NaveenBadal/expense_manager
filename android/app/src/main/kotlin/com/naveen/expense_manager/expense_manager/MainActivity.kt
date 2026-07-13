package com.naveen.expense_manager.expense_manager

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Telephony
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val updateChannel = "com.naveen.expense_manager/updater"
    private val notificationChannel = "com.naveen.expense_manager/notifications"
    private val smsHistoryChannel = "com.naveen.expense_manager/sms_history"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canRequestInstalls" -> result.success(canRequestInstalls())
                    "openInstallPermission" -> {
                        openInstallPermission()
                        result.success(null)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("missing_path", "APK path is required", null)
                        } else {
                            try {
                                installApk(path)
                                result.success(null)
                            } catch (error: Exception) {
                                result.error("install_failed", error.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationChannel)
            .setMethodCallHandler { call, result ->
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, smsHistoryChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "querySince" -> {
                        val since = call.argument<Number>("since")?.toLong()
                        if (since == null || since < 0) {
                            result.error("invalid_cutoff", "A valid SMS cutoff is required", null)
                        } else {
                            Thread {
                                try {
                                    val messages = queryInboxSince(since)
                                    runOnUiThread { result.success(messages) }
                                } catch (error: SecurityException) {
                                    runOnUiThread {
                                        result.error(
                                            "permission_denied",
                                            "SMS permission is unavailable",
                                            null,
                                        )
                                    }
                                } catch (error: Exception) {
                                    runOnUiThread {
                                        result.error("query_failed", error.message, null)
                                    }
                                }
                            }.start()
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun canRequestInstalls(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()

    private fun openInstallPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ),
            )
        }
    }

    private fun installApk(path: String) {
        val apk = File(path)
        require(apk.exists()) { "Downloaded APK does not exist" }
        val uri = FileProvider.getUriForFile(this, "$packageName.updater", apk)
        startActivity(
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
    }

    private fun queryInboxSince(since: Long): List<Map<String, Any?>> {
        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.THREAD_ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.READ,
            Telephony.Sms.DATE,
            Telephony.Sms.DATE_SENT,
            Telephony.Sms.SUBSCRIPTION_ID,
        )
        val messages = mutableListOf<Map<String, Any?>>()
        contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            projection,
            "${Telephony.Sms.DATE} >= ?",
            arrayOf(since.toString()),
            "${Telephony.Sms.DATE} DESC",
        )?.use { cursor ->
            val id = cursor.getColumnIndexOrThrow(Telephony.Sms._ID)
            val threadId = cursor.getColumnIndexOrThrow(Telephony.Sms.THREAD_ID)
            val address = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val body = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val read = cursor.getColumnIndexOrThrow(Telephony.Sms.READ)
            val date = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)
            val dateSent = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE_SENT)
            val subscriptionId = cursor.getColumnIndexOrThrow(Telephony.Sms.SUBSCRIPTION_ID)
            while (cursor.moveToNext()) {
                messages.add(
                    mapOf(
                        "_id" to cursor.getLong(id),
                        "thread_id" to cursor.getLong(threadId),
                        "address" to cursor.getString(address),
                        "body" to cursor.getString(body),
                        "read" to cursor.getInt(read),
                        "date" to cursor.getLong(date),
                        "date_sent" to cursor.getLong(dateSent),
                        "sub_id" to cursor.getInt(subscriptionId),
                    ),
                )
            }
        }
        return messages
    }
}
