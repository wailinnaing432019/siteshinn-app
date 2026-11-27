package com.siteshinn.site_shinn

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "com.siteshinn.site_shinn/device_settings"
    private var testMediaPlayer: MediaPlayer? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val stopPreviewRunnable = Runnable { stopTestSound() }
    private val pdfExecutor = Executors.newSingleThreadExecutor()

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
                    "openExportedFile" -> {
                        val uriStr = call.argument<String>("uri")
                        val fallbackPath = call.argument<String>("fallbackPath")
                        val mimeType = call.argument<String>("mimeType") ?: "*/*"
                        result.success(openExportedFile(uriStr, fallbackPath, mimeType))
                    }
                    "isNetworkConnected" -> {
                        result.success(isNetworkConnected())
                    }
                    "getAppVersionInfo" -> {
                        result.success(getAppVersionInfo())
                    }
                    "canRequestPackageInstalls" -> {
                        result.success(canInstallUnknownApps())
                    }
                    "openUnknownAppsSettings" -> {
                        result.success(openUnknownAppsSettings())
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Missing APK path", null)
                        } else {
                            result.success(installApk(path))
                        }
                    }
                    "getGoogleWebClientId" -> {
                        val resId = resources.getIdentifier(
                            "default_web_client_id",
                            "string",
                            packageName
                        )
                        result.success(if (resId != 0) getString(resId) else null)
                    }
                    "generateReportPdf" -> {
                        @Suppress("UNCHECKED_CAST")
                        val payload = call.arguments as? Map<String, Any?>
                        if (payload == null) {
                            result.error("INVALID_ARGS", "Missing PDF payload", null)
                        } else {
                            pdfExecutor.execute {
                                try {
                                    NativePdfGenerator.generateReportPdf(applicationContext, payload)
                                    mainHandler.post { result.success(true) }
                                } catch (e: Exception) {
                                    mainHandler.post {
                                        result.error("PDF_ERROR", e.message ?: "PDF generation failed", null)
                                    }
                                }
                            }
                        }
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

    private fun openExportedFile(
        uriStr: String?,
        fallbackPath: String?,
        mimeType: String
    ): Boolean {
        if (uriStr != null && uriStr.startsWith("content://")) {
            try {
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(Uri.parse(uriStr), mimeType)
                    addFlags(
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_ACTIVITY_NEW_TASK
                    )
                }
                startActivity(intent)
                return true
            } catch (_: Exception) {
            }
        }

        val candidatePath = when {
            fallbackPath != null && File(fallbackPath).exists() -> fallbackPath
            uriStr != null && !uriStr.startsWith("content://") && File(uriStr).exists() -> uriStr
            else -> null
        } ?: return false

        return try {
            val fileUri = FileProvider.getUriForFile(
                this,
                "${packageName}.fileprovider",
                File(candidatePath)
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(fileUri, mimeType)
                addFlags(
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_ACTIVITY_NEW_TASK
                )
            }
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun isNetworkConnected(): Boolean {
        return try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                ?: return true
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val network = cm.activeNetwork ?: return false
                val caps = cm.getNetworkCapabilities(network) ?: return false
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            } else {
                @Suppress("DEPRECATION")
                val info = cm.activeNetworkInfo
                @Suppress("DEPRECATION")
                info != null && info.isConnected
            }
        } catch (_: Exception) {
            true
        }
    }

    private fun getAppVersionInfo(): Map<String, Any> {
        return try {
            val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(0)
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0)
            }
            val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                info.versionCode.toLong()
            }
            mapOf(
                "versionName" to (info.versionName ?: "2.0.0"),
                "versionCode" to code,
                "supportedAbis" to Build.SUPPORTED_ABIS.toList()
            )
        } catch (_: Exception) {
            mapOf(
                "versionName" to "2.0.0",
                "versionCode" to 2L,
                "supportedAbis" to Build.SUPPORTED_ABIS.toList()
            )
        }
    }

    private fun canInstallUnknownApps(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
    }

    private fun openUnknownAppsSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        return try {
            val permIntent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName")
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(permIntent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun installApk(path: String): String {
        val file = File(path)
        if (!file.exists()) return "file_missing"

        if (!canInstallUnknownApps()) {
            openUnknownAppsSettings()
            return "needs_permission"
        }

        return try {
            val apkUri = FileProvider.getUriForFile(
                this,
                "${packageName}.fileprovider",
                file
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
                addFlags(
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_ACTIVITY_NEW_TASK
                )
            }
            startActivity(intent)
            "launched"
        } catch (_: Exception) {
            "error"
        }
    }
}
