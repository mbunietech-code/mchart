package com.mbunietech.mchart

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createMessageChannel()
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
