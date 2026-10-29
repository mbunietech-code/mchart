package com.mbunietech.mchart

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createMessageChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mchart/updater")
            .setMethodCallHandler { call, result ->
                if (call.method == "installApk") {
                    result.success(installApk(call.argument<String>("path")!!))
                } else {
                    result.notImplemented()
                }
            }
    }

    /**
     * Opens the system installer on a downloaded update (see app_updater.dart).
     * Returns false after sending the user to allow "install unknown apps",
     * which Android 8+ requires once per app.
     */
    private fun installApk(path: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ),
            )
            return false
        }
        val uri = FileProvider.getUriForFile(this, "$packageName.updates", File(path))
        startActivity(
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
        return true
    }

    /**
     * High-importance channel so pushes pop up over other apps (heads-up),
     * like WhatsApp. The server sends every FCM message on this channel id
     * (see FcmPushSender), and the manifest makes it FCM's default.
     */
    private fun createMessageChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Messages & alerts",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "New chat messages, tasks and announcements"
            enableVibration(true)
            setShowBadge(true)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    companion object {
        const val CHANNEL_ID = "mchart_messages"
    }
}
