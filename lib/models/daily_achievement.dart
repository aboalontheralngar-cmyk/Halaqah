import 'package:uuid/uuid.dart';

class DailyAchievement {
  final String id;
  final String studentId;
  final DateTime date;
  final String source;
  final String reason;
  final double actualAmount;
  final double planAmount;
  final String unit;
  final String? rewardType;
  final String? rewardDetails;
  final int rewardPoints;
  final DateTime? awardedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  DailyAchievement({
    String? id,
    required this.studentId,
    required this.date,
    this.source = 'manual',
    required this.reason,
    this.actualAmount = 0,
    this.planAmount = 0,
    this.unit = 'ayahs',
    this.rewardType,
    this.rewardDetails,
    this.rewardPoints = 0,
    this.awardedAt,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isRewarded => rewardType != null && rewardType!.isNotEmpty;
  bool get isAutomatic => source == 'automatic';

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'date': date.toIso8601String().split('T')[0],
        'source': source,
        'reason': reason,
        'actual_amount': actualAmount,
        'plan_amount': planAmount,
        'unit': unit,
        'reward_type': rewardType,
        'reward_details': rewardDetails,
        'reward_points': rewardPoints,
        'awarded_at': awardedAt?.toIso8601String(),
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory DailyAchievement.fromMap(Map<String, dynamic> map) =>
      DailyAchievement(
        id: map['id']?.toString(),
        studentId: map['student_id'].toString(),
        date: DateTime.parse(map['date'].toString()),
        source: map['source']?.toString() ?? 'manual',
        reason: map['reason']?.toString() ?? 'تميز يومي',
        actualAmount: (map['actual_amount'] as num?)?.toDouble() ?? 0,
        planAmount: (map['plan_amount'] as num?)?.toDouble() ?? 0,
        unit: map['unit']?.toString() ?? 'ayahs',
        rewardType: map['reward_type']?.toString(),
        rewardDetails: map['reward_details']?.toString(),
        rewardPoints: (map['reward_points'] as num?)?.toInt() ?? 0,
        awardedAt: DateTime.tryParse(map['awarded_at']?.toString() ?? ''),
        notes: map['notes']?.toString(),
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  DailyAchievement copyWith({
    String? source,
    String? reason,
    double? actualAmount,
    double? planAmount,
    String? unit,
    String? rewardType,
    String? rewardDetails,
    int? rewardPoints,
    DateTime? awardedAt,
    String? notes,
  }) =>
      DailyAchievement(
        id: id,
        studentId: studentId,
        date: date,
        source: source ?? this.source,
        reason: reason ?? this.reason,
        actualAmount: actualAmount ?? this.actualAmount,
        planAmount: planAmount ?? this.planAmount,
        unit: unit ?? this.unit,
        rewardType: rewardType ?? this.rewardType,
        rewardDetails: rewardDetails ?? this.rewardDetails,
        rewardPoints: rewardPoints ?? this.rewardPoints,
        awardedAt: awardedAt ?? this.awardedAt,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
