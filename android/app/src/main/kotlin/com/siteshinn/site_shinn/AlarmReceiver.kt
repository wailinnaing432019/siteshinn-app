package com.siteshinn.site_shinn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            AlarmScheduler.ACTION_TRIGGER_ALARM -> {
                val serviceIntent = Intent(context, AlarmPlaybackService::class.java).apply {
                    action = AlarmPlaybackService.ACTION_START
                }
                try {
                    ContextCompat.startForegroundService(context, serviceIntent)
                } catch (_: Exception) {
                }
                AlarmScheduler.rescheduleAll(context)
            }
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                AlarmScheduler.rescheduleAll(context)
            }
        }
    }
}
