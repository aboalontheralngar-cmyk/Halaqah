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
  String gender; // 'male' or 'female'
  String timeFormat; // '12h', '24h', or 'device'
  
  // Timing parameters
  String timingType; // 'fixed' or 'relative'
  String country; // e.g. 'YE', 'SA'
  String city; // e.g. 'صنعاء', 'الرياض'
  double? customLatitude;
  double? customLongitude;
  String calculationMethod; // e.g. 'umm_al_qura'
  String relativeStartPrayer; // e.g. 'asr', 'fajr'
  int relativeStartOffset; // e.g. 15, -10
  int classDurationMinutes; // e.g. 120

  // Ramadan Specific Dynamic timing parameters
  String ramadanTimingType; // 'same', 'fixed', 'relative'
  String ramadanRelativeStartPrayer; // e.g. 'fajr', 'asr'
  int ramadanRelativeStartOffset; // e.g. 30
  int ramadanClassDurationMinutes; // e.g. 90
  String ramadanFixedStartTime; // e.g. '21:00'
  String ramadanFixedEndTime; // e.g. '22:30'

  Map<String, int> pointsConfig;

  // أيام العطلة الأسبوعية (تُعتبر معطّلة تلقائياً). تستخدم ترقيم DateTime.weekday: الإثنين=1 ... الأحد=7، الجمعة=5.
  List<int> holidayWeekdays;
  bool backupReminderEnabled;
  int backupReminderIntervalDays;
  bool automaticBackupEnabled;
  int automaticBackupHour;
  int automaticBackupRetentionCount;
  bool cloudBackupEnabled;
  int cloudBackupRetentionCount;
  int auditLogRetentionDays;

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
    this.theme = 'system',
    this.fontSize = 16,
    this.revisionOrder = 'ascending',
    this.currencySymbol = 'ر.س',
    this.gender = 'male',
    this.timeFormat = '12h',
    this.timingType = 'fixed',
    this.country = 'YE',
    this.city = 'صنعاء',
    this.customLatitude,
    this.customLongitude,
    this.calculationMethod = 'umm_al_qura',
    this.relativeStartPrayer = 'asr',
    this.relativeStartOffset = 15,
    this.classDurationMinutes = 120,
    this.ramadanTimingType = 'same',
    this.ramadanRelativeStartPrayer = 'fajr',
    this.ramadanRelativeStartOffset = 30,
    this.ramadanClassDurationMinutes = 90,
    this.ramadanFixedStartTime = '21:00',
    this.ramadanFixedEndTime = '22:30',
    Map<String, int>? pointsConfig,
    List<int>? holidayWeekdays,
    this.backupReminderEnabled = true,
    this.backupReminderIntervalDays = 3,
    this.automaticBackupEnabled = true,
    this.automaticBackupHour = 2,
    this.automaticBackupRetentionCount = 14,
    this.cloudBackupEnabled = false,
    this.cloudBackupRetentionCount = 30,
    this.auditLogRetentionDays = 730,
  })  : pointsConfig = pointsConfig ?? Map<String, int>.from(defaultPointsConfig),
        holidayWeekdays = holidayWeekdays ?? [5];

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
    'no_thobe': -3,
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
        'gender': gender,
        'time_format': timeFormat,
        'timing_type': timingType,
        'country': country,
        'city': city,
        'custom_latitude': customLatitude?.toString() ?? '',
        'custom_longitude': customLongitude?.toString() ?? '',
        'calculation_method': calculationMethod,
        'relative_start_prayer': relativeStartPrayer,
        'relative_start_offset': relativeStartOffset,
        'class_duration_minutes': classDurationMinutes,
        'ramadan_timing_type': ramadanTimingType,
        'ramadan_relative_start_prayer': ramadanRelativeStartPrayer,
        'ramadan_relative_start_offset': ramadanRelativeStartOffset,
        'ramadan_class_duration_minutes': ramadanClassDurationMinutes,
        'ramadan_fixed_start_time': ramadanFixedStartTime,
        'ramadan_fixed_end_time': ramadanFixedEndTime,
        'points_config': pointsConfig.entries
            .map((e) => '${e.key}:${e.value}')
            .join(','),
        'holiday_weekdays': holidayWeekdays.join(','),
        'backup_reminder_enabled': backupReminderEnabled ? 1 : 0,
        'backup_reminder_interval_days': backupReminderIntervalDays,
        'automatic_backup_enabled': automaticBackupEnabled ? 1 : 0,
        'automatic_backup_hour': automaticBackupHour,
        'automatic_backup_retention_count': automaticBackupRetentionCount,
        'cloud_backup_enabled': cloudBackupEnabled ? 1 : 0,
        'cloud_backup_retention_count': cloudBackupRetentionCount,
        'audit_log_retention_days': auditLogRetentionDays,
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

    bool parseBool(dynamic val, bool defaultVal) {
      if (val == null) return defaultVal;
      if (val is bool) return val;
      if (val is int) return val == 1;
      final s = val.toString();
      return s == '1' || s.toLowerCase() == 'true';
    }

    int parseInt(dynamic val, int defaultVal) {
      if (val == null) return defaultVal;
      if (val is int) return val;
      return int.tryParse(val.toString()) ?? defaultVal;
    }

    double? parseDouble(dynamic val) {
      if (val == null || val.toString().isEmpty) return null;
      return double.tryParse(val.toString());
    }

    List<int>? holidayDays;
    if (map['holiday_weekdays'] != null && map['holiday_weekdays'].toString().trim().isNotEmpty) {
      holidayDays = map['holiday_weekdays']
          .toString()
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>()
          .toList();
    }

    return HalaqahSettings(
      halaqahName: map['halaqah_name'] ?? 'حلقتي',
      mosqueName: map['mosque_name'] ?? '',
      teacherName: map['teacher_name'] ?? '',
      teacherPhone: map['teacher_phone'] ?? '',
      normalStartTime: map['normal_start_time'] ?? '16:00',
      normalEndTime: map['normal_end_time'] ?? '18:00',
      isRamadanMode: parseBool(map['is_ramadan_mode'], false),
      ramadanStartTime: map['ramadan_start_time'] ?? '21:00',
      ramadanEndTime: map['ramadan_end_time'] ?? '23:00',
      absenceDaysBeforeWarning: parseInt(map['absence_days_warning'], 2),
      absenceDaysBeforeExpulsion: parseInt(map['absence_days_expulsion'], 7),
      autoExpulsionEnabled: parseBool(map['auto_expulsion_enabled'], false),
      useHijriCalendar: parseBool(map['use_hijri_calendar'], true),
      theme: const {'system', 'light', 'dark'}.contains(map['theme'])
          ? map['theme']
          : 'system',
      fontSize: parseInt(map['font_size'], 16),
      revisionOrder: map['revision_order'] ?? 'ascending',
      currencySymbol: map['currency_symbol'] ?? 'ر.س',
      gender: map['gender'] ?? 'male',
      timeFormat: map['time_format'] ?? '12h',
      timingType: map['timing_type'] ?? 'fixed',
      country: map['country'] ?? 'YE',
      city: map['city'] ?? 'صنعاء',
      customLatitude: parseDouble(map['custom_latitude']),
      customLongitude: parseDouble(map['custom_longitude']),
      calculationMethod: map['calculation_method'] ?? 'umm_al_qura',
      relativeStartPrayer: map['relative_start_prayer'] ?? 'asr',
      relativeStartOffset: parseInt(map['relative_start_offset'], 15),
      classDurationMinutes: parseInt(map['class_duration_minutes'], 120),
      ramadanTimingType: map['ramadan_timing_type'] ?? 'same',
      ramadanRelativeStartPrayer: map['ramadan_relative_start_prayer'] ?? 'fajr',
      ramadanRelativeStartOffset: parseInt(map['ramadan_relative_start_offset'], 30),
      ramadanClassDurationMinutes: parseInt(map['ramadan_class_duration_minutes'], 90),
      ramadanFixedStartTime: map['ramadan_fixed_start_time'] ?? '21:00',
      ramadanFixedEndTime: map['ramadan_fixed_end_time'] ?? '22:30',
      pointsConfig: points.isEmpty ? null : points,
      holidayWeekdays: holidayDays,
      backupReminderEnabled:
          parseBool(map['backup_reminder_enabled'], true),
      backupReminderIntervalDays:
          parseInt(map['backup_reminder_interval_days'], 3),
      automaticBackupEnabled:
          parseBool(map['automatic_backup_enabled'], true),
      automaticBackupHour: parseInt(map['automatic_backup_hour'], 2),
      automaticBackupRetentionCount:
          parseInt(map['automatic_backup_retention_count'], 14),
      cloudBackupEnabled: parseBool(map['cloud_backup_enabled'], false),
      cloudBackupRetentionCount:
          parseInt(map['cloud_backup_retention_count'], 30),
      auditLogRetentionDays: parseInt(map['audit_log_retention_days'], 730),
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
    String? gender,
    String? timeFormat,
    String? timingType,
    String? country,
    String? city,
    double? customLatitude,
    double? customLongitude,
    String? calculationMethod,
    String? relativeStartPrayer,
    int? relativeStartOffset,
    int? classDurationMinutes,
    String? ramadanTimingType,
    String? ramadanRelativeStartPrayer,
    int? ramadanRelativeStartOffset,
    int? ramadanClassDurationMinutes,
    String? ramadanFixedStartTime,
    String? ramadanFixedEndTime,
    Map<String, int>? pointsConfig,
    List<int>? holidayWeekdays,
    bool? backupReminderEnabled,
    int? backupReminderIntervalDays,
    bool? automaticBackupEnabled,
    int? automaticBackupHour,
    int? automaticBackupRetentionCount,
    bool? cloudBackupEnabled,
    int? cloudBackupRetentionCount,
    int? auditLogRetentionDays,
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
      gender: gender ?? this.gender,
      timeFormat: timeFormat ?? this.timeFormat,
      timingType: timingType ?? this.timingType,
      country: country ?? this.country,
      city: city ?? this.city,
      customLatitude: customLatitude ?? this.customLatitude,
      customLongitude: customLongitude ?? this.customLongitude,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      relativeStartPrayer: relativeStartPrayer ?? this.relativeStartPrayer,
      relativeStartOffset: relativeStartOffset ?? this.relativeStartOffset,
      classDurationMinutes: classDurationMinutes ?? this.classDurationMinutes,
      ramadanTimingType: ramadanTimingType ?? this.ramadanTimingType,
      ramadanRelativeStartPrayer: ramadanRelativeStartPrayer ?? this.ramadanRelativeStartPrayer,
      ramadanRelativeStartOffset: ramadanRelativeStartOffset ?? this.ramadanRelativeStartOffset,
      ramadanClassDurationMinutes: ramadanClassDurationMinutes ?? this.ramadanClassDurationMinutes,
      ramadanFixedStartTime: ramadanFixedStartTime ?? this.ramadanFixedStartTime,
      ramadanFixedEndTime: ramadanFixedEndTime ?? this.ramadanFixedEndTime,
      pointsConfig: pointsConfig ?? this.pointsConfig,
      holidayWeekdays: holidayWeekdays ?? this.holidayWeekdays,
      backupReminderEnabled:
          backupReminderEnabled ?? this.backupReminderEnabled,
      backupReminderIntervalDays:
          backupReminderIntervalDays ?? this.backupReminderIntervalDays,
      automaticBackupEnabled:
          automaticBackupEnabled ?? this.automaticBackupEnabled,
      automaticBackupHour:
          automaticBackupHour ?? this.automaticBackupHour,
      automaticBackupRetentionCount: automaticBackupRetentionCount ??
          this.automaticBackupRetentionCount,
      cloudBackupEnabled: cloudBackupEnabled ?? this.cloudBackupEnabled,
      cloudBackupRetentionCount:
          cloudBackupRetentionCount ?? this.cloudBackupRetentionCount,
      auditLogRetentionDays:
          auditLogRetentionDays ?? this.auditLogRetentionDays,
    );
  }

  bool isHolidayWeekday(DateTime date) => holidayWeekdays.contains(date.weekday);

  String get currentStartTime =>
      isRamadanMode ? ramadanStartTime : normalStartTime;
  String get currentEndTime => isRamadanMode ? ramadanEndTime : normalEndTime;
}
