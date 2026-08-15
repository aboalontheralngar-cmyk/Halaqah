import 'package:uuid/uuid.dart';

/// A connected tilawah/sard segment completed against a smart plan.
///
/// One teacher action may cross more than one surah. In that case every
/// database-compatible segment shares [sessionId] and uses [segmentOrder] to
/// preserve its Quran order. These rows never increase memorized content.
class PlanRecitationRecord {
  final String id;
  final String sessionId;
  final String planId;
  final String studentId;
  final int surahId;
  final int fromAyah;
  final int toAyah;
  final int segmentOrder;
  final DateTime date;
  final int qualityRating;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlanRecitationRecord({
    String? id,
    String? sessionId,
    required this.planId,
    required this.studentId,
    required this.surahId,
    required this.fromAyah,
    required this.toAyah,
    this.segmentOrder = 0,
    required this.date,
    this.qualityRating = 3,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        sessionId = sessionId ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  int get ayahCount => toAyah - fromAyah + 1;

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'plan_id': planId,
        'student_id': studentId,
        'surah_id': surahId,
        'from_ayah': fromAyah,
        'to_ayah': toAyah,
        'segment_order': segmentOrder,
        'date': date.toIso8601String().split('T')[0],
        'quality_rating': qualityRating,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory PlanRecitationRecord.fromMap(Map<String, dynamic> map) {
    final createdAt =
        DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.now();
    return PlanRecitationRecord(
      id: map['id']?.toString(),
      sessionId: map['session_id']?.toString(),
      planId: map['plan_id'].toString(),
      studentId: map['student_id'].toString(),
      surahId: (map['surah_id'] as num).toInt(),
      fromAyah: (map['from_ayah'] as num).toInt(),
      toAyah: (map['to_ayah'] as num).toInt(),
      segmentOrder: (map['segment_order'] as num?)?.toInt() ?? 0,
      date: DateTime.parse(map['date'].toString()),
      qualityRating: (map['quality_rating'] as num?)?.toInt() ?? 3,
      notes: map['notes']?.toString(),
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? createdAt,
    );
  }
}
