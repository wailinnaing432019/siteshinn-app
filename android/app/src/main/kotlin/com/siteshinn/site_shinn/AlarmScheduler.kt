package com.siteshinn.site_shinn

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

data class NativeAlarmSpec(val id: Int, val hour: Int, val minute: Int)

object AlarmScheduler {
    private const val PREFS_NAME = "siteshinn_alarm_prefs"
    private const val KEY_ALARMS = "alarms_set"
    private const val KEY_TITLE = "title"
    private const val KEY_BODY = "body"
    private const val KEY_STOP_LABEL = "stop_label"
    private const val KEY_AUDIO_PATH = "audio_path"

    const val ACTION_TRIGGER_ALARM = "com.siteshinn.site_shinn.ACTION_TRIGGER_ALARM"
    const val EXTRA_ALARM_ID = "alarm_id"

    fun syncAlarms(
        context: Context,
        alarms: List<NativeAlarmSpec>,
        title: String,
        body: String,
        stopLabel: String,
        audioPath: String?
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // Cancel every previously scheduled alarm ID before applying the new list.
        val existing = prefs.getStringSet(KEY_ALARMS, emptySet()) ?: emptySet()
        for (entry in existing) {
            parseEntry(entry)?.let { spec ->
                alarmManager.cancel(triggerPendingIntent(context, spec.id))
            }
        }

        val encodedSet = alarms.map { "${it.id}|${it.hour}|${it.minute}" }.toSet()
        prefs.edit().apply {
            putStringSet(KEY_ALARMS, encodedSet)
            putString(KEY_TITLE, title)
            putString(KEY_BODY, body)
            putString(KEY_STOP_LABEL, stopLabel)
            if (audioPath != null) {
                putString(KEY_AUDIO_PATH, audioPath)
            } else {
                remove(KEY_AUDIO_PATH)
            }
            apply()
        }

        for (spec in alarms) {
            scheduleNext(context, spec.id, spec.hour, spec.minute)
        }
    }

    fun rescheduleAll(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val entries = prefs.getStringSet(KEY_ALARMS, emptySet()) ?: emptySet()
        for (entry in entries) {
            parseEntry(entry)?.let { spec ->
                scheduleNext(context, spec.id, spec.hour, spec.minute)
            }
        }
    }

    fun cancelAll(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val existing = prefs.getStringSet(KEY_ALARMS, emptySet()) ?: emptySet()
        for (entry in existing) {
            parseEntry(entry)?.let { spec ->
                alarmManager.cancel(triggerPendingIntent(context, spec.id))
            }
        }
        prefs.edit().remove(KEY_ALARMS).apply()
    }

    fun getTitle(context: Context): String =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_TITLE, null) ?: "SiteShinn • Daily Log Reminder"

    fun getBody(context: Context): String =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_BODY, null) ?: "Don't forget to record today's income & expenses!"

    fun getStopLabel(context: Context): String =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_STOP_LABEL, null) ?: "Stop Alarm"

    fun getAudioPath(context: Context): String? =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_AUDIO_PATH, null)

    private fun parseEntry(entry: String): NativeAlarmSpec? {
        val parts = entry.split("|")
        if (parts.size != 3) return null
        val id = parts[0].toIntOrNull() ?: return null
        val hour = parts[1].toIntOrNull() ?: return null
        val minute = parts[2].toIntOrNull() ?: return null
        return NativeAlarmSpec(id, hour, minute)
    }

    private fun scheduleNext(context: Context, id: Int, hour: Int, minute: Int) {
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            // Keep a 5-second buffer so an alarm triggering right at HH:MM:00
            // always schedules for tomorrow rather than firing again immediately.
            if (timeInMillis <= System.currentTimeMillis() + 5_000L) {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerIntent = triggerPendingIntent(context, id)

        val showIntent = PendingIntent.getActivity(
            context,
            id + 10_000,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val info = AlarmManager.AlarmClockInfo(calendar.timeInMillis, showIntent)
                alarmManager.setAlarmClock(info, triggerIntent)
                return
            }
        } catch (_: SecurityException) {
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                triggerIntent
            )
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, triggerIntent)
        }
    }

    private fun triggerPendingIntent(context: Context, id: Int): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION_TRIGGER_ALARM
            putExtra(EXTRA_ALARM_ID, id)
        }
        return PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
