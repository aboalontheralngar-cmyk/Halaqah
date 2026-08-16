import '../models/plan_recitation_record.dart';
import 'database_service.dart';

/// Read-only range queries used by reporting.
///
/// Kept outside [DatabaseService] so report growth does not turn the central
/// CRUD service back into a monolith. This class deliberately contains no
/// business logic and performs only bounded, indexed reads.
class ReportRangeDataService {
  ReportRangeDataService({DatabaseService? database})
      : _database = database ?? DatabaseService();

  final DatabaseService _database;

  Future<List<PlanRecitationRecord>> studentRecitationRecords({
    required String studentId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'plan_recitation_records',
      where: 'student_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [studentId, _key(startDate), _key(endDate)],
      orderBy: 'date ASC, created_at ASC, segment_order ASC',
    );
    return rows.map(PlanRecitationRecord.fromMap).toList();
  }

  Future<List<PlanRecitationRecord>> allRecitationRecords({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'plan_recitation_records',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [_key(startDate), _key(endDate)],
      orderBy: 'student_id ASC, date ASC, created_at ASC, segment_order ASC',
    );
    return rows.map(PlanRecitationRecord.fromMap).toList();
  }

  String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
