import 'package:uuid/uuid.dart';

class BehaviorPoint {
  final String id;
  final String studentId;
  final String type;
  final String reason;
  final int points;
  final DateTime date;
  bool resolved;
  DateTime? resolvedDate;
  String? notes;
  DateTime createdAt;

  BehaviorPoint({
    String? id,
    required this.studentId,
    required this.type,
    required this.reason,
    required this.points,
    required this.date,
    this.resolved = false,
    this.resolvedDate,
    this.notes,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  bool get isPositive => points > 0;
  bool get isNegative => points < 0;
  bool get isAppearanceViolation => type == 'appearance';

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'type': type,
        'reason': reason,
        'points': points,
        'date': date.toIso8601String().split('T')[0],
        'resolved': resolved ? 1 : 0,
        'resolved_date': resolvedDate?.toIso8601String(),
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory BehaviorPoint.fromMap(Map<String, dynamic> map) => BehaviorPoint(
        id: map['id'],
        studentId: map['student_id'],
        type: map['type'],
        reason: map['reason'],
        points: map['points'],
        date: DateTime.parse(map['date']),
        resolved: map['resolved'] == 1,
        resolvedDate: map['resolved_date'] != null
            ? DateTime.parse(map['resolved_date'])
            : null,
        notes: map['notes'],
        createdAt: DateTime.parse(map['created_at']),
      );

  BehaviorPoint copyWith({
    bool? resolved,
    DateTime? resolvedDate,
    String? notes,
  }) {
    return BehaviorPoint(
      id: id,
      studentId: studentId,
      type: type,
      reason: reason,
      points: points,
      date: date,
      resolved: resolved ?? this.resolved,
      resolvedDate: resolvedDate ?? this.resolvedDate,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}

class BehaviorReason {
  static const Map<String, Map<String, dynamic>> positive = {
    'daily_memorization': {'label': 'إتمام الحفظ اليومي', 'points': 5},
    'extra_memorization': {'label': 'زيادة عن المقرر', 'points': 2},
    'early_attendance': {'label': 'الحضور المبكر', 'points': 2},
    'revision_complete': {'label': 'إتمام المراجعة', 'points': 3},
    'monthly_exam_pass': {'label': 'النجاح في الامتحان الشهري', 'points': 10},
    'good_appearance': {'label': 'المظهر الحسن', 'points': 1},
    'good_behavior': {'label': 'حسن السلوك', 'points': 2},
    'helping_others': {'label': 'مساعدة الآخرين', 'points': 3},
  };

  static const Map<String, Map<String, dynamic>> negative = {
    'late': {'label': 'التأخير', 'points': -2},
    'incomplete_memorization': {'label': 'عدم إتمام المقرر', 'points': -3},
    'unexcused_absence': {'label': 'الغياب بدون عذر', 'points': -5},
    'bad_haircut': {'label': 'حلاقة غير لائقة', 'points': -3},
    'bad_clothes': {'label': 'ملابس غير مناسبة', 'points': -3},
    'bad_hygiene': {'label': 'عدم النظافة', 'points': -3},
    'bad_behavior': {'label': 'سوء السلوك', 'points': -4},
    'disrespect': {'label': 'عدم الاحترام', 'points': -5},
  };

  static String getLabel(String reason) {
    return positive[reason]?['label'] ??
        negative[reason]?['label'] ??
        reason;
  }

  static int getDefaultPoints(String reason) {
    return positive[reason]?['points'] ??
        negative[reason]?['points'] ??
        0;
  }
}
