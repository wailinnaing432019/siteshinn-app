package com.siteshinn.site_shinn

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import java.io.File

class AlarmPlaybackService : Service() {
    companion object {
        const val ACTION_START = "com.siteshinn.site_shinn.ALARM_START"
        const val ACTION_STOP = "com.siteshinn.site_shinn.ALARM_STOP"
        private const val CHANNEL_ID = "siteshinn_custom_alarm_playback"
        private const val NOTIFICATION_ID = 4202
        private const val AUTO_STOP_MS = 60_000L
    }

    private var mediaPlayer: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private val autoStopRunnable = Runnable { stopSelf() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopPlayback()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        ensureChannel()
        val notification = buildNotification()
        startForeground(NOTIFICATION_ID, notification)

        startPlayback()
        handler.removeCallbacks(autoStopRunnable)
        handler.postDelayed(autoStopRunnable, AUTO_STOP_MS)
        return START_NOT_STICKY
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "SiteShinn Alarm Clock",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Plays your selected alarm song for daily expense logging"
                    setSound(null, null)
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 600, 300, 600)
                }
                manager.createNotificationChannel(channel)
            }
        }
    }

    private fun buildNotification(): android.app.Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("stop_alarm", true)
        }
        val openPending = PendingIntent.getActivity(
            this,
            101,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, AlarmPlaybackService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPending = PendingIntent.getService(
            this,
            102,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_siteshinn)
            .setContentTitle(AlarmScheduler.getTitle(this))
            .setContentText(AlarmScheduler.getBody(this))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setAutoCancel(true)
            .setContentIntent(openPending)
            .setDeleteIntent(stopPending)
            .addAction(0, AlarmScheduler.getStopLabel(this), stopPending)
            .build()
    }

    private fun startPlayback() {
        stopPlayback()
        val customPath = AlarmScheduler.getAudioPath(this)
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()

        val player = MediaPlayer()
        try {
            player.setAudioAttributes(audioAttributes)
            if (customPath != null && File(customPath).exists()) {
                player.setDataSource(customPath)
            } else {
                val defaultUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                player.setDataSource(this, defaultUri)
            }
            player.isLooping = true
            player.prepare()
            player.start()
            mediaPlayer = player
        } catch (_: Exception) {
            try {
                player.release()
            } catch (_: Exception) {
            }
        }
    }

    private fun stopPlayback() {
        handler.removeCallbacks(autoStopRunnable)
        try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.release()
            }
        } catch (_: Exception) {
        }
        mediaPlayer = null
    }

    override fun onDestroy() {
        stopPlayback()
        super.onDestroy()
    }
}
