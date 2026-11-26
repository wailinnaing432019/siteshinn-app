import 'dart:convert';

class ReminderAlarm {
  final int id;
  final int hour;
  final int minute;
  final bool enabled;
  final String label;

  const ReminderAlarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.enabled = true,
    this.label = '',
  });

  ReminderAlarm copyWith({
    int? id,
    int? hour,
    int? minute,
    bool? enabled,
    String? label,
  }) {
    return ReminderAlarm(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
      label: label ?? this.label,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'enabled': enabled,
        'label': label,
      };

  factory ReminderAlarm.fromJson(Map<String, dynamic> json) {
    return ReminderAlarm(
      id: json['id'] as int,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      enabled: json['enabled'] as bool? ?? true,
      label: json['label'] as String? ?? '',
    );
  }

  static String encodeList(List<ReminderAlarm> alarms) {
    return jsonEncode(alarms.map((a) => a.toJson()).toList());
  }

  static List<ReminderAlarm> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => ReminderAlarm.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
