import 'package:uuid/uuid.dart';

class BehaviorPointCorrection {
  final String id;
  final String? pointId;
  final String originalStudentId;
  final String? correctedStudentId;
  final String action;
  final String reason;
  final String pointReasonSnapshot;
  final int pointsSnapshot;
  final DateTime createdAt;

  BehaviorPointCorrection({
    String? id,
    this.pointId,
    required this.originalStudentId,
    this.correctedStudentId,
    required this.action,
    required this.reason,
    required this.pointReasonSnapshot,
    required this.pointsSnapshot,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'point_id': pointId,
        'original_student_id': originalStudentId,
        'corrected_student_id': correctedStudentId,
        'action': action,
        'reason': reason,
        'point_reason_snapshot': pointReasonSnapshot,
        'points_snapshot': pointsSnapshot,
        'created_at': createdAt.toIso8601String(),
      };

  factory BehaviorPointCorrection.fromMap(Map<String, dynamic> map) =>
      BehaviorPointCorrection(
        id: map['id']?.toString(),
        pointId: map['point_id']?.toString(),
        originalStudentId: map['original_student_id'].toString(),
        correctedStudentId: map['corrected_student_id']?.toString(),
        action: map['action']?.toString() ?? 'delete',
        reason: map['reason']?.toString() ?? '',
        pointReasonSnapshot: map['point_reason_snapshot']?.toString() ?? '',
        pointsSnapshot: (map['points_snapshot'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}
