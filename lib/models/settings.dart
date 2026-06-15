class HalaqahSettings {
  String halaqahName;
  String mosqueName;
  String teacherName;
  String teacherPhone;
  
  String normalStartTime;
  String normalEndTime;
  
  bool isRamadanMode;
  String ramadanStartTime;
  String ramadanEndTime;
  
  int absenceDaysBeforeWarning;
  int absenceDaysBeforeExpulsion;
  bool autoExpulsionEnabled;
  
  bool useHijriCalendar;
  String theme;
  int fontSize;
  
  String revisionOrder;
  String currencySymbol;
  
  Map<String, int> pointsConfig;

  HalaqahSettings({
    this.halaqahName = 'حلقتي',
    this.mosqueName = '',
    this.teacherName = '',
    this.teacherPhone = '',
    this.normalStartTime = '16:00',
    this.normalEndTime = '18:00',
    this.isRamadanMode = false,
    this.ramadanStartTime = '21:00',
    this.ramadanEndTime = '23:00',
    this.absenceDaysBeforeWarning = 2,
    this.absenceDaysBeforeExpulsion = 7,
    this.autoExpulsionEnabled = false,
    this.useHijriCalendar = true,
    this.theme = 'light',
    this.fontSize = 16,
    this.revisionOrder = 'ascending',
    this.currencySymbol = 'ر.س',
    Map<String, int>? pointsConfig,
  }) : pointsConfig = pointsConfig ?? defaultPointsConfig;

  static Map<String, int> defaultPointsConfig = {
    'daily_memorization': 5,
    'extra_memorization': 2,
    'early_attendance': 2,
    'revision_complete': 3,
    'monthly_exam_pass': 10,
    'good_appearance': 1,
    'late_penalty': -2,
    'incomplete_penalty': -3,
    'unexcused_absence': -5,
    'appearance_violation': -3,
  };

  Map<String, dynamic> toMap() => {
        'halaqah_name': halaqahName,
        'mosque_name': mosqueName,
        'teacher_name': teacherName,
        'teacher_phone': teacherPhone,
        'normal_start_time': normalStartTime,
        'normal_end_time': normalEndTime,
        'is_ramadan_mode': isRamadanMode ? 1 : 0,
        'ramadan_start_time': ramadanStartTime,
        'ramadan_end_time': ramadanEndTime,
        'absence_days_warning': absenceDaysBeforeWarning,
        'absence_days_expulsion': absenceDaysBeforeExpulsion,
        'auto_expulsion_enabled': autoExpulsionEnabled ? 1 : 0,
        'use_hijri_calendar': useHijriCalendar ? 1 : 0,
        'theme': theme,
        'font_size': fontSize,
        'revision_order': revisionOrder,
        'currency_symbol': currencySymbol,
        'points_config': pointsConfig.entries
            .map((e) => '${e.key}:${e.value}')
            .join(','),
      };

  factory HalaqahSettings.fromMap(Map<String, dynamic> map) {
    Map<String, int> points = {};
    if (map['points_config'] != null) {
      final pairs = (map['points_config'] as String).split(',');
      for (final pair in pairs) {
        final kv = pair.split(':');
        if (kv.length == 2) {
          points[kv[0]] = int.tryParse(kv[1]) ?? 0;
        }
      }
    }

    return HalaqahSettings(
      halaqahName: map['halaqah_name'] ?? 'حلقتي',
      mosqueName: map['mosque_name'] ?? '',
      teacherName: map['teacher_name'] ?? '',
      teacherPhone: map['teacher_phone'] ?? '',
      normalStartTime: map['normal_start_time'] ?? '16:00',
      normalEndTime: map['normal_end_time'] ?? '18:00',
      isRamadanMode: map['is_ramadan_mode'] == 1,
      ramadanStartTime: map['ramadan_start_time'] ?? '21:00',
      ramadanEndTime: map['ramadan_end_time'] ?? '23:00',
      absenceDaysBeforeWarning: map['absence_days_warning'] ?? 2,
      absenceDaysBeforeExpulsion: map['absence_days_expulsion'] ?? 7,
      autoExpulsionEnabled: map['auto_expulsion_enabled'] == 1,
      useHijriCalendar: map['use_hijri_calendar'] != 0,
      theme: map['theme'] ?? 'light',
      fontSize: map['font_size'] ?? 16,
      revisionOrder: map['revision_order'] ?? 'ascending',
      currencySymbol: map['currency_symbol'] ?? 'ر.س',
      pointsConfig: points.isEmpty ? null : points,
    );
  }

  HalaqahSettings copyWith({
    String? halaqahName,
    String? mosqueName,
    String? teacherName,
    String? teacherPhone,
    String? normalStartTime,
    String? normalEndTime,
    bool? isRamadanMode,
    String? ramadanStartTime,
    String? ramadanEndTime,
    int? absenceDaysBeforeWarning,
    int? absenceDaysBeforeExpulsion,
    bool? autoExpulsionEnabled,
    bool? useHijriCalendar,
    String? theme,
    int? fontSize,
    String? revisionOrder,
    String? currencySymbol,
    Map<String, int>? pointsConfig,
  }) {
    return HalaqahSettings(
      halaqahName: halaqahName ?? this.halaqahName,
      mosqueName: mosqueName ?? this.mosqueName,
      teacherName: teacherName ?? this.teacherName,
      teacherPhone: teacherPhone ?? this.teacherPhone,
      normalStartTime: normalStartTime ?? this.normalStartTime,
      normalEndTime: normalEndTime ?? this.normalEndTime,
      isRamadanMode: isRamadanMode ?? this.isRamadanMode,
      ramadanStartTime: ramadanStartTime ?? this.ramadanStartTime,
      ramadanEndTime: ramadanEndTime ?? this.ramadanEndTime,
      absenceDaysBeforeWarning:
          absenceDaysBeforeWarning ?? this.absenceDaysBeforeWarning,
      absenceDaysBeforeExpulsion:
          absenceDaysBeforeExpulsion ?? this.absenceDaysBeforeExpulsion,
      autoExpulsionEnabled: autoExpulsionEnabled ?? this.autoExpulsionEnabled,
      useHijriCalendar: useHijriCalendar ?? this.useHijriCalendar,
      theme: theme ?? this.theme,
      fontSize: fontSize ?? this.fontSize,
      revisionOrder: revisionOrder ?? this.revisionOrder,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      pointsConfig: pointsConfig ?? this.pointsConfig,
    );
  }

  String get currentStartTime =>
      isRamadanMode ? ramadanStartTime : normalStartTime;
  String get currentEndTime => isRamadanMode ? ramadanEndTime : normalEndTime;
}
