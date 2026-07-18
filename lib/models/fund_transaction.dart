import 'package:uuid/uuid.dart';

class FundTransaction {
  final String id;
  final String? studentId;
  final String? behaviorPointId;
  final String type; // 'subscription', 'penalty', 'expense', 'donation'
  final double amount;
  final String? note;
  final DateTime date;
  final DateTime createdAt;

  FundTransaction({
    String? id,
    this.studentId,
    this.behaviorPointId,
    required this.type,
    required this.amount,
    this.note,
    required this.date,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'behavior_point_id': behaviorPointId,
        'type': type,
        'amount': amount,
        'note': note,
        'date': date.toIso8601String().split('T')[0],
        'created_at': createdAt.toIso8601String(),
      };

  factory FundTransaction.fromMap(Map<String, dynamic> map) => FundTransaction(
        id: map['id'],
        studentId: map['student_id'],
        behaviorPointId: map['behavior_point_id'],
        type: map['type'],
        amount: (map['amount'] as num).toDouble(),
        note: map['note'],
        date: DateTime.parse(map['date']),
        createdAt: DateTime.parse(map['created_at']),
      );
}
