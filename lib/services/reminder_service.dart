import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/l10n/app_strings.dart';
import '../data/models/reminder_alarm.dart';

class ReminderService {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  static const int _testReminderId = 9999;
  static const String _normalChannelId = 'siteshinn_daily_reminder_v2';
  static const String _alarmChannelId = 'siteshinn_daily_alarm_v2';
  static const MethodChannel _deviceChannel = MethodChannel(
    'com.siteshinn.site_shinn/device_settings',
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _alarmSoundUri;

  Future<void> initialize({AppStrings? strings}) async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Yangon'));
    }

    try {
      _alarmSoundUri =
          await _deviceChannel.invokeMethod<String>('getAlarmSoundUri');
    } catch (_) {
      _alarmSoundUri = null;
    }

    try {
      const androidInit = AndroidInitializationSettings('ic_stat_siteshinn');
      const settings = InitializationSettings(android: androidInit);
      await _plugin.initialize(settings: settings);
      await _ensureChannels(strings ?? const AppStrings(AppLanguage.en));
    } catch (_) {
      // Safe no-op in widget test / unsupported environments.
    }
    _initialized = true;
  }

  Future<void> _ensureChannels(AppStrings strings) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    final alarmChannel = AndroidNotificationChannel(
      _alarmChannelId,
      strings.alarmChannelName,
      description: strings.alarmChannelDesc,
      importance: Importance.max,
      playSound: true,
      sound: _alarmSoundUri != null
          ? UriAndroidNotificationSound(_alarmSoundUri!)
          : null,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 600, 300, 600, 300, 600]),
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    final normalChannel = AndroidNotificationChannel(
      _normalChannelId,
      strings.notifChannelName,
      description: strings.notifChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.notification,
    );

    await android.createNotificationChannel(alarmChannel);
    await android.createNotificationChannel(normalChannel);
  }

  Future<void> requestPermissions() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await initialize();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  Future<({bool notificationsEnabled, bool exactAlarmsAllowed})>
      checkPermissionStatus() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return (notificationsEnabled: true, exactAlarmsAllowed: true);
    }
    try {
      await initialize();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final notifEnabled = await android?.areNotificationsEnabled() ?? true;
      final exactAllowed =
          await android?.canScheduleExactNotifications() ?? true;
      return (
        notificationsEnabled: notifEnabled,
        exactAlarmsAllowed: exactAllowed,
      );
    } catch (_) {
      return (notificationsEnabled: true, exactAlarmsAllowed: true);
    }
  }

  AndroidNotificationDetails _buildAndroidDetails(
    bool alarmMode,
    AppStrings strings,
  ) {
    if (alarmMode) {
      return AndroidNotificationDetails(
        _alarmChannelId,
        strings.alarmChannelName,
        channelDescription: strings.alarmChannelDesc,
        icon: 'ic_stat_siteshinn',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: _alarmSoundUri != null
            ? UriAndroidNotificationSound(_alarmSoundUri!)
            : null,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 600, 300, 600, 300, 600]),
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        ticker: strings.reminderNotifTitle,
      );
    }

    return AndroidNotificationDetails(
      _normalChannelId,
      strings.notifChannelName,
      channelDescription: strings.notifChannelDesc,
      icon: 'ic_stat_siteshinn',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.notification,
      ticker: strings.reminderNotifTitle,
    );
  }

  Future<void> syncDailyReminders({
    required List<ReminderAlarm> alarms,
    required bool alarmMode,
    String? customAudioPath,
    required AppStrings strings,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await initialize(strings: strings);
      await _ensureChannels(strings);
      await _plugin.cancelAllPendingNotifications();
    } catch (_) {
      return;
    }

    final enabledAlarms = alarms.where((a) => a.enabled).toList();
    if (enabledAlarms.isEmpty) {
      try {
        await _deviceChannel.invokeMethod('cancelNativeAlarm');
      } catch (_) {}
      return;
    }

    if (alarmMode) {
      try {
        await _deviceChannel.invokeMethod('syncNativeAlarms', {
          'alarms': enabledAlarms
              .map((a) => {'id': a.id, 'hour': a.hour, 'minute': a.minute})
              .toList(),
          'title': strings.reminderNotifTitle,
          'body': strings.reminderNotifBody,
          'stopLabel': strings.stopAlarmNotifLabel,
          'customAudioPath': customAudioPath,
        });
        return;
      } catch (_) {}
    } else {
      try {
        await _deviceChannel.invokeMethod('cancelNativeAlarm');
      } catch (_) {}
    }

    final details = NotificationDetails(
      android: _buildAndroidDetails(alarmMode, strings),
    );

    for (final alarm in enabledAlarms) {
      final scheduled = _nextInstanceOfTime(alarm.hour, alarm.minute);
      try {
        await _plugin.zonedSchedule(
          id: alarm.id,
          title: strings.reminderNotifTitle,
          body: strings.reminderNotifBody,
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (_) {
        await _plugin.zonedSchedule(
          id: alarm.id,
          title: strings.reminderNotifTitle,
          body: strings.reminderNotifBody,
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    }
  }

  Future<bool> sendTestReminder({
    required bool alarmMode,
    String? customAudioPath,
    required AppStrings strings,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    await initialize(strings: strings);
    await _ensureChannels(strings);
    await requestPermissions();

    final status = await checkPermissionStatus();

    try {
      await _deviceChannel.invokeMethod('playTestAlarmSound', {
        'alarmMode': alarmMode,
        'customAudioPath': customAudioPath,
      });
    } catch (_) {}

    try {
      await _plugin.show(
        id: _testReminderId,
        title: strings.reminderNotifTitle,
        body: strings.reminderNotifBody,
        notificationDetails: NotificationDetails(
          android: _buildAndroidDetails(alarmMode, strings),
        ),
      );
    } catch (_) {}

    return status.notificationsEnabled;
  }

  Future<void> stopTestSound() async {
    try {
      await _deviceChannel.invokeMethod('stopTestAlarmSound');
    } catch (_) {}
  }

  Future<({String path, String name})?> pickAndSaveCustomAlarmSong() async {
    final picked = await FilePicker.pickFile(type: FileType.audio);
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    final supportDir = await getApplicationSupportDirectory();
    final ext = p.extension(picked.name).isNotEmpty
        ? p.extension(picked.name)
        : '.mp3';
    final destFile = File(p.join(supportDir.path, 'custom_alarm_audio$ext'));
    await destFile.writeAsBytes(bytes, flush: true);
    return (path: destFile.path, name: picked.name);
  }

  Future<void> deleteCustomAlarmFile(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> openBatterySettings() async {
    try {
      await _deviceChannel.invokeMethod('openBatterySettings');
    } catch (_) {}
  }

  Future<void> openAppSettings() async {
    try {
      await _deviceChannel.invokeMethod('openAppSettings');
    } catch (_) {}
  }

  Future<void> openNotificationSettings() async {
    try {
      await _deviceChannel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }
}
