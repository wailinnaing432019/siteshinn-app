package com.siteshinn.site_shinn

import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "com.siteshinn.site_shinn/device_settings"
    private var testMediaPlayer: MediaPlayer? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val stopPreviewRunnable = Runnable { stopTestSound() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleAlarmIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleAlarmIntent(intent)
    }

    private fun handleAlarmIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("stop_alarm", false) == true) {
            val stopIntent = Intent(this, AlarmPlaybackService::class.java).apply {
                action = AlarmPlaybackService.ACTION_STOP
            }
            startService(stopIntent)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openBatterySettings" -> {
                        openBatteryOptimizationSettings()
                        result.success(true)
                    }
                    "openAppSettings" -> {
                        openAppDetailsSettings()
                        result.success(true)
                    }
                    "openNotificationSettings" -> {
                        openAppNotificationSettings()
                        result.success(true)
                    }
                    "getAlarmSoundUri" -> {
                        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        result.success(uri?.toString())
                    }
                    "playTestAlarmSound" -> {
                        val alarmMode = call.argument<Boolean>("alarmMode") ?: true
                        val customPath = call.argument<String>("customAudioPath")
                        playTestAudio(alarmMode, customPath)
                        result.success(true)
                    }
                    "stopTestAlarmSound" -> {
                        stopTestSound()
                        val stopIntent = Intent(this, AlarmPlaybackService::class.java).apply {
                            action = AlarmPlaybackService.ACTION_STOP
                        }
                        try {
                            startService(stopIntent)
                        } catch (_: Exception) {
                        }
                        result.success(true)
                    }
                    "syncNativeAlarms" -> {
                        val rawAlarms = call.argument<List<Map<String, Any>>>("alarms") ?: emptyList()
                        val specs = rawAlarms.mapNotNull { map ->
                            val id = (map["id"] as? Number)?.toInt() ?: return@mapNotNull null
                            val hour = (map["hour"] as? Number)?.toInt() ?: return@mapNotNull null
                            val minute = (map["minute"] as? Number)?.toInt() ?: return@mapNotNull null
                            NativeAlarmSpec(id, hour, minute)
                        }
                        val title = call.argument<String>("title") ?: "SiteShinn"
                        val body = call.argument<String>("body") ?: ""
                        val stopLabel = call.argument<String>("stopLabel") ?: "Stop Alarm"
                        val customPath = call.argument<String>("customAudioPath")
                        AlarmScheduler.syncAlarms(
                            this,
                            specs,
                            title,
                            body,
                            stopLabel,
                            customPath
                        )
                        result.success(true)
                    }
                    "cancelNativeAlarm" -> {
                        AlarmScheduler.cancelAll(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun playTestAudio(alarmMode: Boolean, customPath: String?) {
        stopTestSound()
        val player = MediaPlayer()
        try {
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(
                        if (alarmMode) AudioAttributes.USAGE_ALARM
                        else AudioAttributes.USAGE_NOTIFICATION
                    )
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            if (customPath != null && File(customPath).exists()) {
                player.setDataSource(customPath)
            } else {
                val uri = if (alarmMode) {
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                } else {
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                }
                if (uri == null) {
                    player.release()
                    return
                }
                player.setDataSource(applicationContext, uri)
            }
            player.prepare()
            player.start()
            testMediaPlayer = player
            mainHandler.removeCallbacks(stopPreviewRunnable)
            mainHandler.postDelayed(stopPreviewRunnable, 5000)
        } catch (_: Exception) {
            try {
                player.release()
            } catch (_: Exception) {
            }
        }
    }

    private fun stopTestSound() {
        mainHandler.removeCallbacks(stopPreviewRunnable)
        try {
            testMediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.release()
            }
        } catch (_: Exception) {
        }
        testMediaPlayer = null
    }

    override fun onDestroy() {
        stopTestSound()
        super.onDestroy()
    }

    private fun openBatteryOptimizationSettings() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                startActivity(intent)
                return
            }
        } catch (_: Exception) {
        }
        openAppDetailsSettings()
    }

    private fun openAppNotificationSettings() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                }
                startActivity(intent)
                return
            }
        } catch (_: Exception) {
        }
        openAppDetailsSettings()
    }

    private fun openAppDetailsSettings() {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", packageName, null)
        )
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }
}
