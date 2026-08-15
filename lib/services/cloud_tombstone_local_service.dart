import 'package:sqflite/sqflite.dart';

/// Replays hard-delete events received from Supabase without producing a new
/// outbound delete queue. This is intentionally separate from DatabaseService
/// so the core repository does not grow again as sync coverage expands.
class CloudTombstoneLocalService {
  const CloudTombstoneLocalService._();

  static Future<Set<String>> apply(
    Database database,
    Iterable<Map<String, dynamic>> tombstones,
  ) async {
    final affectedMemorizationStudents = <String>{};
    await database.transaction((txn) async {
      // SQLite v25 has AFTER DELETE triggers that enqueue local->cloud deletes.
      // Remote tombstones are replays, not new local intent, so suppress those
      // triggers for the duration of this transaction to prevent echo loops.
      await txn.insert(
        'settings',
        {'key': 'sync_remote_delete_replay', 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final tombstone in tombstones) {
        final remoteTable = tombstone['table_name']?.toString() ?? '';
        final rowDataRaw = tombstone['row_data'];
        final rowData = rowDataRaw is Map
            ? Map<String, dynamic>.from(rowDataRaw)
            : <String, dynamic>{};
        final recordId = (tombstone['record_id'] ?? rowData['id'])?.toString();

        Future<void> deleteById(String localTable) async {
          final id = recordId;
          if (id == null || id.isEmpty) return;
          await txn.delete(localTable, where: 'id = ?', whereArgs: [id]);
        }

        switch (remoteTable) {
          case 'students':
            await deleteById('students');
            break;
          case 'families':
            final id = recordId;
            if (id == null || id.isEmpty) break;
            await txn.update(
              'students',
              {'family_id': null},
              where: 'family_id = ?',
              whereArgs: [id],
            );
            await txn.delete(
              'family_guardians',
              where: 'family_id = ?',
              whereArgs: [id],
            );
            await deleteById('families');
            break;
          case 'family_guardians':
            await deleteById('family_guardians');
            break;
          case 'attendance':
            final studentId = rowData['student_id']?.toString();
            final date = rowData['date']?.toString();
            if (studentId != null && date != null) {
              await txn.delete(
                'daily_records',
                where: 'student_id = ? AND date = ?',
                whereArgs: [studentId, date],
              );
            }
            break;
          case 'homework_grades':
            await deleteById('homework_grades');
            break;
          case 'memorization':
            final studentId = rowData['student_id']?.toString();
            if (studentId != null && studentId.isNotEmpty) {
              affectedMemorizationStudents.add(studentId);
            }
            await deleteById('memorization_progress');
            break;
          case 'points':
            await deleteById('behavior_points');
            break;
          case 'daily_achievements':
            await deleteById('daily_achievements');
            break;
          case 'vacations':
            await deleteById('vacations');
            break;
          case 'exams':
          case 'exam_scores':
            await deleteById('exams');
            break;
          case 'exam_templates':
            await deleteById('exam_templates');
            break;
          case 'fund_transactions':
            await deleteById('fund_transactions');
            break;
          case 'notifications':
            await deleteById('notifications');
            break;
          case 'student_holds':
            await deleteById('student_holds');
            break;
          case 'talaqqin_records':
            await deleteById('talaqqin_records');
            break;
          case 'student_admin_actions':
            await deleteById('student_admin_actions');
            break;
          case 'plans':
            await deleteById('plans');
            break;
          case 'quran_courses':
            await deleteById('quran_courses');
            break;
          case 'quran_course_enrollments':
            await deleteById('quran_course_enrollments');
            break;
          case 'plan_recitation_records':
            await deleteById('plan_recitation_records');
            break;
          case 'mushaf_progress':
            final studentId = rowData['student_id']?.toString();
            final hizb = rowData['hizb_number']?.toString();
            final thumun = rowData['thumun_number']?.toString();
            if (studentId != null && hizb != null && thumun != null) {
              await txn.delete(
                'mushaf_progress',
                where: 'student_id = ? AND hizb_number = ? AND thumun_number = ?',
                whereArgs: [studentId, hizb, thumun],
              );
              affectedMemorizationStudents.add(studentId);
            }
            break;
          default:
            break;
        }
      }
      await txn.insert(
        'settings',
        {'key': 'sync_remote_delete_replay', 'value': '0'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    return affectedMemorizationStudents;
  }
}
