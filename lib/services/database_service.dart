import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/student.dart';
import '../models/daily_record.dart';
import '../models/memorization.dart';
import '../models/behavior_point.dart';
import '../models/vacation.dart';
import '../models/exam.dart';
import '../models/settings.dart';
import '../models/fund_transaction.dart';
import '../models/plan.dart';
import '../models/plan_recitation_record.dart';
import '../models/notification_log.dart';
import '../models/homework_grade.dart';
import '../models/mushaf_progress.dart';
import '../models/message_template.dart';
import '../models/exam_template.dart';
import '../models/student_hold.dart';
import '../models/talaqqin_record.dart';
import '../models/student_admin_action.dart';
import '../models/student_status_change.dart';
import '../models/behavior_point_correction.dart';
import '../models/daily_achievement.dart';
import '../models/family.dart';
import '../models/family_guardian.dart';
import '../models/audit_event.dart';
import '../models/competition.dart';
import '../models/quran_course.dart';
import 'quran_service.dart';
import 'local_database_schema.dart';
import 'memorized_content_service.dart';
import 'behavior_point_policy.dart';
import 'student_status_policy.dart';
import 'daily_excellence_service.dart';
import 'recitation_points_policy.dart';
import 'cloud_tombstone_local_service.dart';
import 'local_sync_delete_outbox.dart';

class StudentBehaviorSummary {
  final double totalPoints;
  final int unresolvedViolations;

  const StudentBehaviorSummary({
    required this.totalPoints,
    required this.unresolvedViolations,
  });
}

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  static const LocalDatabaseSchema _schema = LocalDatabaseSchema();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Applies hard-delete events that originated on another device/cloud.
  Future<Set<String>> applyCloudTombstones(
    Iterable<Map<String, dynamic>> tombstones,
  ) async =>
      CloudTombstoneLocalService.apply(await database, tombstones);

  Future<List<LocalSyncDeleteOperation>> getPendingSyncDeletes({int limit = 500}) async =>
      LocalSyncDeleteOutbox.pending(await database, limit: limit);
  Future<bool> isSyncDeleteStillPending(LocalSyncDeleteOperation operation) async =>
      LocalSyncDeleteOutbox.isStillDeleted(await database, operation);
  Future<void> acknowledgeSyncDelete(int operationId) async =>
      LocalSyncDeleteOutbox.acknowledge(await database, operationId);
  Future<int> getPendingSyncDeleteCount() async =>
      LocalSyncDeleteOutbox.count(await database);

  /// Upserts sync rows without SQLite `INSERT OR REPLACE`.
  ///
  /// `REPLACE` is implemented as delete+insert and can therefore cascade-delete
  /// child rows (for example exam scores or Quran-course enrollments). Sync must
  /// update an existing parent in place and insert only genuinely new IDs.
  Future<void> _batchUpsertMapsById(
    String table,
    Iterable<Map<String, dynamic>> rows,
  ) async {
    final byId = <String, Map<String, dynamic>>{};
    for (final source in rows) {
      final id = source['id']?.toString().trim() ?? '';
      if (id.isEmpty) {
        throw ArgumentError('سجل المزامنة في $table يفتقد المعرّف');
      }
      byId[id] = Map<String, dynamic>.from(source);
    }
    if (byId.isEmpty) return;

    final db = await database;
    final existingIds = <String>{};
    final ids = byId.keys.toList(growable: false);
    const chunkSize = 800;
    for (var start = 0; start < ids.length; start += chunkSize) {
      final end = (start + chunkSize < ids.length)
          ? start + chunkSize
          : ids.length;
      final chunk = ids.sublist(start, end);
      final placeholders = List.filled(chunk.length, '?').join(',');
      final existingRows = await db.rawQuery(
        'SELECT id FROM $table WHERE id IN ($placeholders)',
        chunk,
      );
      existingIds.addAll(existingRows.map((row) => row['id'].toString()));
    }

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final entry in byId.entries) {
        if (existingIds.contains(entry.key)) {
          batch.update(
            table,
            entry.value,
            where: 'id = ?',
            whereArgs: [entry.key],
          );
        } else {
          batch.insert(table, entry.value);
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'halaqah.db');
    return await openDatabase(
      path,
      version: LocalDatabaseSchema.version,
      onCreate: _schema.onCreate,
      onUpgrade: _schema.onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
    );
  }

  Future<List<Student>> getStudents({String? status}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = status != null
        ? await db.query(
            'students',
            where: 'status = ?',
            whereArgs: [status],
            orderBy: 'name COLLATE NOCASE ASC',
          )
        : await db.query(
            'students',
            orderBy: 'name COLLATE NOCASE ASC',
          );
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }

  Future<List<Student>> getOperationalStudents() async {
    final db = await database;
    final maps = await db.query(
      'students',
      where: 'status IN (?, ?)',
      whereArgs: ['active', 'suspended'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return maps.map(Student.fromMap).toList();
  }

  Future<List<Student>> getArchivedStudents({String? status}) async {
    if (status != null &&
        !StudentStatusPolicy.archivedStatuses.contains(status)) {
      throw ArgumentError('حالة الأرشيف غير صالحة');
    }
    final db = await database;
    final maps = await db.query(
      'students',
      where: status == null
          ? 'status IN (?, ?, ?)'
          : 'status = ?',
      whereArgs: status == null
          ? ['expelled', 'graduated', 'inactive']
          : [status],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return maps.map(Student.fromMap).toList();
  }

  Future<Student?> getStudent(String id) async {
    final db = await database;
    final maps = await db.query('students', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Student.fromMap(maps.first);
  }

  Future<Student?> getStudentByQrCode(String qrCode) async {
    final db = await database;
    final maps = await db.query('students', where: 'qr_code = ?', whereArgs: [qrCode]);
    if (maps.isEmpty) return null;
    return Student.fromMap(maps.first);
  }

  Future<void> insertStudent(Student student) async {
    final db = await database;
    await db.insert('students', student.toMap());
  }

  Future<void> updateStudent(Student student) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'students',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [student.id],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('الطالب غير موجود');
      final previousStatus = rows.first['status']?.toString() ?? 'active';
      await txn.update(
        'students',
        student.toMap(),
        where: 'id = ?',
        whereArgs: [student.id],
      );
      if (previousStatus != student.status) {
        await txn.insert(
          'student_status_history',
          StudentStatusChange(
            studentId: student.id,
            previousStatus: previousStatus,
            newStatus: student.status,
            reason: 'تحديث متزامن لحالة الطالب',
          ).toMap(),
        );
      }
    });
  }

  /// يدمج دفعة طلاب من السحابة داخل معاملة واحدة بدل فتح معاملة لكل طالب.
  /// يحافظ على سجل تغير الحالة ولا يستخدم REPLACE حتى لا يفعّل حذفًا تسلسليًا.
  Future<void> upsertStudentsFromSync(List<Student> students) async {
    if (students.isEmpty) return;
    final db = await database;
    final existingRows = await db.query('students', columns: ['id', 'status']);
    final existingStatus = <String, String>{
      for (final row in existingRows)
        row['id'].toString(): row['status']?.toString() ?? 'active',
    };

    await db.transaction((txn) async {
      for (final student in students) {
        final previousStatus = existingStatus[student.id];
        if (previousStatus == null) {
          await txn.insert('students', student.toMap());
          continue;
        }
        await txn.update(
          'students',
          student.toMap(),
          where: 'id = ?',
          whereArgs: [student.id],
        );
        if (previousStatus != student.status) {
          await txn.insert(
            'student_status_history',
            StudentStatusChange(
              studentId: student.id,
              previousStatus: previousStatus,
              newStatus: student.status,
              reason: 'تحديث متزامن لحالة الطالب',
            ).toMap(),
          );
        }
      }
    });
  }

  Future<List<Family>> getFamilies() async {
    final db = await database;
    final rows = await db.query(
      'families',
      orderBy: 'name COLLATE NOCASE ASC, reference_name COLLATE NOCASE ASC',
    );
    return rows.map(Family.fromMap).toList();
  }

  Future<Family?> getFamily(String familyId) async {
    final db = await database;
    final rows = await db.query(
      'families',
      where: 'id = ?',
      whereArgs: [familyId],
      limit: 1,
    );
    return rows.isEmpty ? null : Family.fromMap(rows.first);
  }

  Future<List<Student>> getFamilyMembers(String familyId) async {
    final db = await database;
    final rows = await db.query(
      'students',
      where: 'family_id = ?',
      whereArgs: [familyId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Student.fromMap).toList();
  }

  Future<List<FamilyGuardian>> getFamilyGuardians(String familyId) async {
    final db = await database;
    final rows = await db.query(
      'family_guardians',
      where: 'family_id = ?',
      whereArgs: [familyId],
      orderBy: 'is_primary DESC, name COLLATE NOCASE ASC',
    );
    return rows.map(FamilyGuardian.fromMap).toList();
  }

  Future<List<FamilyGuardian>> getAllFamilyGuardians() async {
    final db = await database;
    final rows = await db.query(
      'family_guardians',
      orderBy: 'family_id ASC, is_primary ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(FamilyGuardian.fromMap).toList();
  }

  Future<void> upsertFamiliesFromSync(Iterable<Family> families) async {
    final pending = families.toList(growable: false);
    if (pending.isEmpty) return;
    final db = await database;
    final ids = pending.map((family) => family.id).toList(growable: false);
    final placeholders = List.filled(ids.length, '?').join(',');
    final existingRows = await db.rawQuery(
      'SELECT id FROM families WHERE id IN ($placeholders)',
      ids,
    );
    final existingIds = existingRows.map((row) => row['id'].toString()).toSet();
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final family in pending) {
        final map = Map<String, dynamic>.from(family.toMap());
        if (existingIds.contains(family.id)) {
          batch.update(
            'families',
            map,
            where: 'id = ?',
            whereArgs: [family.id],
          );
        } else {
          batch.insert('families', map);
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertFamilyGuardiansFromSync(
    Iterable<FamilyGuardian> guardians,
  ) =>
      _batchUpsertMapsById(
        'family_guardians',
        guardians.map(
          (guardian) => Map<String, dynamic>.from(guardian.toMap()),
        ),
      );

  Future<void> saveFamily(Family family) async {
    final name = family.name.trim();
    if (name.isEmpty) throw ArgumentError('اسم العائلة مطلوب');
    family
      ..name = name
      ..updatedAt = DateTime.now();
    final db = await database;
    final exists = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM families WHERE id = ?',
            [family.id],
          ),
        ) !=
        0;
    if (exists) {
      await db.update(
        'families',
        family.toMap(),
        where: 'id = ?',
        whereArgs: [family.id],
      );
    } else {
      await db.insert('families', family.toMap());
    }
  }

  Future<void> deleteFamily(String familyId) async {
    final db = await database;
    await db.transaction((txn) async {
      final guardianRows = await txn.query(
        'family_guardians',
        columns: ['id'],
        where: 'family_id = ?',
        whereArgs: [familyId],
      );
      await txn.update(
        'students',
        {'family_id': null},
        where: 'family_id = ?',
        whereArgs: [familyId],
      );
      await txn.delete(
        'family_guardians',
        where: 'family_id = ?',
        whereArgs: [familyId],
      );
      await txn.delete('families', where: 'id = ?', whereArgs: [familyId]);
      await _appendDeletedIds(txn, 'deleted_family_ids', [familyId]);
      await _appendDeletedIds(
        txn,
        'deleted_family_guardian_ids',
        guardianRows.map((row) => row['id'].toString()).toList(),
      );
    });
  }

  Future<void> saveFamilyGuardian(FamilyGuardian guardian) async {
    if (guardian.name.trim().isEmpty) {
      throw ArgumentError('اسم ولي الأمر مطلوب');
    }
    if (guardian.phone.trim().isEmpty) {
      throw ArgumentError('رقم ولي الأمر مطلوب');
    }
    if (!FamilyGuardian.relationships.contains(guardian.relationship)) {
      throw ArgumentError('صلة ولي الأمر غير صالحة');
    }
    final db = await database;
    await db.transaction((txn) async {
      final existingCount = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM family_guardians WHERE family_id = ?',
              [guardian.familyId],
            ),
          ) ??
          0;
      if (existingCount == 0) guardian.isPrimary = true;
      if (guardian.isPrimary) {
        await txn.update(
          'family_guardians',
          {'is_primary': 0, 'updated_at': DateTime.now().toIso8601String()},
          where: 'family_id = ? AND id <> ?',
          whereArgs: [guardian.familyId, guardian.id],
        );
      }
      guardian.updatedAt = DateTime.now();
      await txn.insert(
        'family_guardians',
        guardian.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final primaryCount = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM family_guardians '
              'WHERE family_id = ? AND is_primary = 1',
              [guardian.familyId],
            ),
          ) ??
          0;
      if (primaryCount == 0) {
        guardian.isPrimary = true;
        await txn.update(
          'family_guardians',
          {'is_primary': 1, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [guardian.id],
        );
      }
      if (guardian.isPrimary) {
        await txn.update(
          'students',
          {
            'guardian_phone': guardian.phone.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'family_id = ?',
          whereArgs: [guardian.familyId],
        );
      }
    });
  }

  Future<void> deleteFamilyGuardian(String guardianId) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'family_guardians',
        where: 'id = ?',
        whereArgs: [guardianId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final removed = FamilyGuardian.fromMap(rows.first);
      await txn.delete(
        'family_guardians',
        where: 'id = ?',
        whereArgs: [guardianId],
      );
      await _appendDeletedIds(
        txn,
        'deleted_family_guardian_ids',
        [guardianId],
      );
      if (!removed.isPrimary) return;
      final remaining = await txn.query(
        'family_guardians',
        where: 'family_id = ?',
        whereArgs: [removed.familyId],
        orderBy: 'created_at ASC',
        limit: 1,
      );
      if (remaining.isEmpty) return;
      final next = FamilyGuardian.fromMap(remaining.first)..isPrimary = true;
      await txn.update(
        'family_guardians',
        {'is_primary': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [next.id],
      );
      await txn.update(
        'students',
        {
          'guardian_phone': next.phone.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'family_id = ?',
        whereArgs: [removed.familyId],
      );
    });
  }

  Future<void> assignStudentsToFamily({
    required String familyId,
    required List<String> studentIds,
  }) async {
    if (studentIds.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final family = await txn.query(
        'families',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [familyId],
        limit: 1,
      );
      if (family.isEmpty) throw StateError('العائلة غير موجودة');
      final primary = await txn.query(
        'family_guardians',
        columns: ['phone'],
        where: 'family_id = ? AND is_primary = 1',
        whereArgs: [familyId],
        limit: 1,
      );
      final primaryPhone = primary.isEmpty
          ? null
          : primary.first['phone']?.toString().trim();
      final placeholders = List.filled(studentIds.length, '?').join(',');
      await txn.rawUpdate(
        'UPDATE students SET family_id = ?, '
        'guardian_phone = CASE WHEN ? IS NULL THEN guardian_phone ELSE ? END, '
        'updated_at = ? WHERE id IN ($placeholders)',
        [
          familyId,
          primaryPhone,
          primaryPhone,
          DateTime.now().toIso8601String(),
          ...studentIds,
        ],
      );
    });
  }

  Future<void> removeStudentFromFamily(String studentId) async {
    final db = await database;
    await db.update(
      'students',
      {'family_id': null, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [studentId],
    );
  }

  Future<void> changeStudentStatus({
    required String studentId,
    required String newStatus,
    required String reason,
    String? notes,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'students',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [studentId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('الطالب غير موجود');
      final previousStatus = rows.first['status']?.toString() ?? 'active';
      final validationError = StudentStatusPolicy.validateTransition(
        previousStatus: previousStatus,
        newStatus: newStatus,
        reason: reason,
      );
      if (validationError == 'حالة الطالب لم تتغير') return;
      if (validationError != null) throw ArgumentError(validationError);
      final changedAt = DateTime.now();
      await txn.update(
        'students',
        {
          'status': newStatus,
          'updated_at': changedAt.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [studentId],
      );
      await txn.insert(
        'student_status_history',
        StudentStatusChange(
          studentId: studentId,
          previousStatus: previousStatus,
          newStatus: newStatus,
          reason: reason.trim(),
          notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
          changedAt: changedAt,
        ).toMap(),
      );
    });
  }

  Future<List<StudentStatusChange>> getStudentStatusHistory(
    String studentId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'student_status_history',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'changed_at DESC',
    );
    return rows.map(StudentStatusChange.fromMap).toList();
  }

  Future<StudentStatusChange?> getLatestStudentStatusChange(
    String studentId,
  ) async {
    final history = await getStudentStatusHistory(studentId);
    return history.isEmpty ? null : history.first;
  }

  Future<Map<String, StudentStatusChange>> getLatestStudentStatusChanges() async {
    final db = await database;
    final rows = await db.query(
      'student_status_history',
      orderBy: 'student_id ASC, changed_at DESC, created_at DESC',
    );
    final latest = <String, StudentStatusChange>{};
    for (final row in rows) {
      final change = StudentStatusChange.fromMap(row);
      latest.putIfAbsent(change.studentId, () => change);
    }
    return latest;
  }

  Future<void> deleteStudent(String id) async {
    final db = await database;
    await db.delete('students', where: 'id = ?', whereArgs: [id]);
  }

  Future<DailyRecord?> getDailyRecord(String studentId, DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    final maps = await db.query(
      'daily_records',
      where: 'student_id = ? AND date = ?',
      whereArgs: [studentId, dateStr],
    );
    if (maps.isEmpty) return null;
    return DailyRecord.fromMap(maps.first);
  }

  Future<List<DailyRecord>> getDailyRecordsForDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    final maps = await db.query(
      'daily_records',
      where: 'date = ?',
      whereArgs: [dateStr],
    );
    return List.generate(maps.length, (i) => DailyRecord.fromMap(maps[i]));
  }

  Future<List<DailyRecord>> getStudentRecords(String studentId, {int limit = 30}) async {
    final db = await database;
    final maps = await db.query(
      'daily_records',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'date DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => DailyRecord.fromMap(maps[i]));
  }

  Future<List<DailyRecord>> getStudentRecordsInRange(
    String studentId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final rows = await db.query(
      'daily_records',
      where: 'student_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [
        studentId,
        startDate.toIso8601String().split('T')[0],
        endDate.toIso8601String().split('T')[0],
      ],
      orderBy: 'date ASC',
    );
    return rows.map(DailyRecord.fromMap).toList();
  }

  Future<List<DailyRecord>> getDailyRecordsInRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final rows = await db.query(
      'daily_records',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [
        startDate.toIso8601String().split('T')[0],
        endDate.toIso8601String().split('T')[0],
      ],
      orderBy: 'date ASC, student_id ASC',
    );
    return rows.map(DailyRecord.fromMap).toList();
  }

  Future<void> saveDailyRecord(DailyRecord record) async {
    final db = await database;
    await db.insert(
      'daily_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveDailyRecords(Iterable<DailyRecord> records) async {
    final pending = records.toList(growable: false);
    if (pending.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final record in pending) {
        batch.insert(
          'daily_records',
          record.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> getConsecutiveAbsenceDays(
    String studentId, {
    DateTime? asOfDate,
  }) async {
    final settings = await getSettings();
    final suspended = (await getSuspendedDates()).toSet();
    var date = DateTime(
      (asOfDate ?? DateTime.now()).year,
      (asOfDate ?? DateTime.now()).month,
      (asOfDate ?? DateTime.now()).day,
    );
    var count = 0;
    for (var checked = 0; checked < 60; checked++) {
      final key = date.toIso8601String().split('T')[0];
      if (settings.isHolidayWeekday(date) || suspended.contains(key)) {
        date = date.subtract(const Duration(days: 1));
        continue;
      }
      final hold = await getActiveStudentHold(studentId, date: date);
      if (hold?.exemptsAttendance == true) {
        date = date.subtract(const Duration(days: 1));
        continue;
      }
      final record = await getDailyRecord(studentId, date);
      if (record?.attendance == 'absent') {
        count++;
        date = date.subtract(const Duration(days: 1));
        continue;
      }
      break;
    }
    return count;
  }

  Future<int> getConsecutiveNoRecitationDays(
    String studentId, {
    DateTime? asOfDate,
  }) async {
    final settings = await getSettings();
    final suspended = (await getSuspendedDates()).toSet();
    var date = DateTime(
      (asOfDate ?? DateTime.now()).year,
      (asOfDate ?? DateTime.now()).month,
      (asOfDate ?? DateTime.now()).day,
    );
    var count = 0;
    for (var checked = 0; checked < 60; checked++) {
      final key = date.toIso8601String().split('T')[0];
      if (settings.isHolidayWeekday(date) || suspended.contains(key)) {
        date = date.subtract(const Duration(days: 1));
        continue;
      }
      if (await getActiveStudentHold(studentId, date: date) != null) {
        break;
      }
      final record = await getDailyRecord(studentId, date);
      if (record == null || record.attendance == 'excused') break;
      if (record.recitationExempt || record.talaqqinDone) break;
      final didNotRecite = record.attendance == 'absent' ||
          ((record.attendance == 'present' || record.attendance == 'late') &&
              !record.memorizationDone &&
              !record.revisionDone);
      if (!didNotRecite) break;
      count++;
      date = date.subtract(const Duration(days: 1));
    }
    return count;
  }

  Future<void> insertMemorization(MemorizationProgress progress) async {
    final hold = await getActiveStudentHold(
      progress.studentId,
      date: progress.date,
    );
    if (hold != null) {
      throw StateError(
        'التسميع موقوف لهذا الطالب حتى ${hold.endDate.toIso8601String().split('T')[0]}: ${hold.reason}',
      );
    }
    final db = await database;
    await db.insert('memorization_progress', progress.toMap());
  }

  Future<void> saveRevisionSession({
    required List<MemorizationProgress> progress,
    required List<HomeworkGrade> grades,
    required DailyRecord dailyRecord,
  }) async {
    if (progress.isEmpty || progress.length != grades.length) {
      throw ArgumentError('بيانات جلسة المراجعة غير مكتملة');
    }
    final studentId = progress.first.studentId;
    final hold = await getActiveStudentHold(studentId, date: dailyRecord.date);
    if (hold != null) {
      throw StateError(
        'المراجعة موقوفة لهذا الطالب حتى ${_dateKey(hold.endDate)}: ${hold.reason}',
      );
    }
    for (final item in progress) {
      if (item.studentId != studentId || !item.isRevision) {
        throw ArgumentError('سجل مراجعة غير متوافق مع الجلسة');
      }
      _validateMemorizationRange(item);
    }
    final db = await database;
    await db.transaction((txn) async {
      for (var index = 0; index < progress.length; index++) {
        await txn.insert('memorization_progress', progress[index].toMap());
        await txn.insert('homework_grades', grades[index].toMap());
      }
      await txn.insert(
        'daily_records',
        dailyRecord.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Saves one direct recitation session atomically, even when it crosses
  /// more than one surah.
  ///
  /// Successful recitation rows are split per surah by the caller. An absent
  /// result may contain grade rows without progress rows so it never increases
  /// the student's memorized content or daily recitation points.
  Future<void> saveRecitationSession({
    required List<MemorizationProgress> progress,
    required List<HomeworkGrade> grades,
    required DailyRecord dailyRecord,
    int? updatedTotalMemorized,
  }) async {
    if (grades.isEmpty) {
      throw ArgumentError('بيانات تقييم جلسة التسميع غير مكتملة');
    }
    if (progress.isNotEmpty && progress.length != grades.length) {
      throw ArgumentError('مقاطع الحفظ والتقييم غير متطابقة');
    }

    final studentId = grades.first.studentId;
    final isRevision = grades.first.isRevision;
    if (dailyRecord.studentId != studentId) {
      throw ArgumentError('السجل اليومي لا يخص الطالب نفسه');
    }
    final hold = await getActiveStudentHold(studentId, date: dailyRecord.date);
    if (hold != null) {
      throw StateError(
        'التسميع موقوف لهذا الطالب حتى ${_dateKey(hold.endDate)}: ${hold.reason}',
      );
    }

    for (var index = 0; index < grades.length; index++) {
      final grade = grades[index];
      if (grade.studentId != studentId || grade.isRevision != isRevision) {
        throw ArgumentError('سجل تقييم غير متوافق مع الجلسة');
      }
      _validateHomeworkGradeRange(grade);
      if (progress.isEmpty && grade.gradeMark != 'absent') {
        throw ArgumentError('لا يمكن حفظ تقييم ناجح دون نطاق تسميع');
      }
      if (progress.isNotEmpty) {
        final item = progress[index];
        if (item.studentId != studentId ||
            item.isRevision != isRevision ||
            item.surahId != grade.surahId ||
            item.fromAyah != grade.fromAyah ||
            item.toAyah != grade.toAyah) {
          throw ArgumentError('مقطع الحفظ لا يطابق تقييمه');
        }
        _validateMemorizationRange(item);
      }
    }
    if ((isRevision || progress.isEmpty) && updatedTotalMemorized != null) {
      throw ArgumentError('لا يتغير إجمالي المحفوظ في جلسة المراجعة أو الغياب');
    }

    final db = await database;
    await db.transaction((txn) async {
      for (final item in progress) {
        await txn.insert('memorization_progress', item.toMap());
      }
      for (final grade in grades) {
        await txn.insert('homework_grades', grade.toMap());
      }
      await txn.insert(
        'daily_records',
        dailyRecord.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (!isRevision && progress.isNotEmpty) {
        // The profile total is derived from the actual unique ayahs in the
        // starting balance and daily recitation records. Never trust a stale
        // form value or add overlapping ranges twice.
        await _setExactStudentMemorizedTotal(txn, studentId);
      }
    });
  }

  Future<void> updateMemorizationProgress(
    MemorizationProgress original,
    MemorizationProgress updated,
  ) async {
    _validateMemorizationRange(updated);
    final db = await database;
    await db.transaction((txn) async {
      final previousTrackedCount = await _countTrackedMemorized(
        txn,
        original.studentId,
      );
      final companionId = await _findCompanionGradeId(txn, original);
      await txn.update(
        'memorization_progress',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [original.id],
      );
      if (companionId != null) {
        await txn.update(
          'homework_grades',
          {
            'surah_id': updated.surahId,
            'from_ayah': updated.fromAyah,
            'to_ayah': updated.toAyah,
            'date': updated.date.toIso8601String().split('T')[0],
            'grade_mark': _qualityToGradeMark(updated.qualityRating),
            'is_revision': updated.isRevision ? 1 : 0,
            'remark': updated.notes,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [companionId],
        );
      }
      await _recomputeRecitationState(txn, original.studentId, original.date);
      if (_dateKey(original.date) != _dateKey(updated.date)) {
        await _recomputeRecitationState(txn, updated.studentId, updated.date);
      }
      await _recomputeStudentMemorizedTotal(
        txn,
        updated.studentId,
        previousTrackedCount: previousTrackedCount,
      );
    });
    if (!original.isRevision) {
      await recalculateDailyRecitationPoints(
        studentId: original.studentId,
        date: original.date,
      );
    }
    if (!updated.isRevision &&
        (_dateKey(updated.date) != _dateKey(original.date) ||
            original.isRevision)) {
      await recalculateDailyRecitationPoints(
        studentId: updated.studentId,
        date: updated.date,
      );
    }
  }

  Future<void> deleteMemorizationProgress(MemorizationProgress progress) async {
    final db = await database;
    await db.transaction((txn) async {
      final previousTrackedCount = await _countTrackedMemorized(
        txn,
        progress.studentId,
      );
      final companionId = await _findCompanionGradeId(txn, progress);
      await txn.delete(
        'memorization_progress',
        where: 'id = ?',
        whereArgs: [progress.id],
      );
      if (companionId != null) {
        await txn.delete(
          'homework_grades',
          where: 'id = ?',
          whereArgs: [companionId],
        );
      }
      await _appendDeletedIds(
        txn,
        'deleted_memorization_progress_ids',
        [progress.id],
      );
      if (companionId != null) {
        await _appendDeletedIds(
          txn,
          'deleted_homework_grade_ids',
          [companionId],
        );
      }
      await _recomputeRecitationState(
        txn,
        progress.studentId,
        progress.date,
      );
      await _recomputeStudentMemorizedTotal(
        txn,
        progress.studentId,
        previousTrackedCount: previousTrackedCount,
      );
    });
    if (!progress.isRevision) {
      await recalculateDailyRecitationPoints(
        studentId: progress.studentId,
        date: progress.date,
      );
    }
  }

  void _validateMemorizationRange(MemorizationProgress progress) {
    final surah = QuranService.instance.getSurah(progress.surahId);
    if (surah == null ||
        progress.fromAyah < 1 ||
        progress.toAyah < progress.fromAyah ||
        progress.toAyah > surah.totalAyahs) {
      throw ArgumentError('نطاق الآيات غير صحيح للسورة المحددة');
    }
    if (progress.qualityRating < 1 || progress.qualityRating > 5) {
      throw ArgumentError('التقييم يجب أن يكون بين 1 و5');
    }
  }

  void _validateHomeworkGradeRange(HomeworkGrade grade) {
    final surah = QuranService.instance.getSurah(grade.surahId);
    if (surah == null ||
        grade.fromAyah < 1 ||
        grade.toAyah < grade.fromAyah ||
        grade.toAyah > surah.totalAyahs) {
      throw ArgumentError('نطاق تقييم الآيات غير صحيح للسورة المحددة');
    }
  }

  Future<String?> _findCompanionGradeId(
    DatabaseExecutor txn,
    MemorizationProgress progress,
  ) async {
    final rows = await txn.query(
      'homework_grades',
      columns: ['id', 'created_at'],
      where: 'student_id = ? AND surah_id = ? AND from_ayah = ? '
          'AND to_ayah = ? AND date = ? AND is_revision = ?',
      whereArgs: [
        progress.studentId,
        progress.surahId,
        progress.fromAyah,
        progress.toAyah,
        _dateKey(progress.date),
        progress.isRevision ? 1 : 0,
      ],
      orderBy: 'created_at ASC',
    );
    String? bestId;
    var bestDifference = const Duration(days: 365);
    for (final row in rows) {
      final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
      if (createdAt == null) continue;
      final difference = createdAt.difference(progress.createdAt).abs();
      if (difference < bestDifference) {
        bestDifference = difference;
        bestId = row['id'] as String?;
      }
    }
    return bestDifference <= const Duration(seconds: 10) ? bestId : null;
  }

  Future<void> _recomputeRecitationState(
    DatabaseExecutor txn,
    String studentId,
    DateTime date,
  ) async {
    final dateKey = _dateKey(date);
    final rows = await txn.query(
      'memorization_progress',
      where: 'student_id = ? AND date = ?',
      whereArgs: [studentId, dateKey],
      orderBy: 'created_at ASC',
    );
    final progress = rows.map(MemorizationProgress.fromMap).toList();
    final memorization = progress.where((item) => !item.isRevision).toList();
    final revision = progress.where((item) => item.isRevision).toList();

    final studentRows = await txn.query(
      'students',
      where: 'id = ?',
      whereArgs: [studentId],
      limit: 1,
    );
    if (studentRows.isEmpty) return;
    final student = Student.fromMap(studentRows.first);
    final previousRows = await txn.query(
      'memorization_progress',
      where: 'student_id = ? AND is_revision = 0 AND date < ?',
      whereArgs: [studentId, dateKey],
    );
    final previouslyMemorized = <String>{};
    for (final row in previousRows.map(MemorizationProgress.fromMap)) {
      for (var ayah = row.fromAyah; ayah <= row.toAyah; ayah++) {
        previouslyMemorized.add('${row.surahId}:$ayah');
      }
    }
    final newToday = <String>{};
    for (final row in memorization) {
      for (var ayah = row.fromAyah; ayah <= row.toAyah; ayah++) {
        final key = '${row.surahId}:$ayah';
        if (!_isPreMemorizedAyah(student, row.surahId, ayah) &&
            !previouslyMemorized.contains(key)) {
          newToday.add(key);
        }
      }
    }
    final dailyRows = await txn.query(
      'daily_records',
      columns: ['id'],
      where: 'student_id = ? AND date = ?',
      whereArgs: [studentId, dateKey],
      limit: 1,
    );
    final summary = <String, dynamic>{
      'memorization_done': memorization.isNotEmpty ? 1 : 0,
      'revision_done': revision.isNotEmpty ? 1 : 0,
      'memorization_amount': newToday.length,
      'revision_amount': revision.fold<int>(
        0,
        (sum, item) => sum + item.ayahCount,
      ),
      'memorization_note': _joinedProgressNotes(memorization),
      'revision_note': _joinedProgressNotes(revision),
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (dailyRows.isNotEmpty) {
      await txn.update(
        'daily_records',
        summary,
        where: 'student_id = ? AND date = ?',
        whereArgs: [studentId, dateKey],
      );
    } else if (progress.isNotEmpty) {
      final record = DailyRecord(
        studentId: studentId,
        date: date,
        attendance: 'present',
        memorizationDone: memorization.isNotEmpty,
        revisionDone: revision.isNotEmpty,
        memorizationAmount: newToday.length,
        revisionAmount: revision.fold<int>(
          0,
          (sum, item) => sum + item.ayahCount,
        ),
        memorizationNote: _joinedProgressNotes(memorization),
        revisionNote: _joinedProgressNotes(revision),
        notes: 'أنشئ تلقائيًا بعد تصحيح تاريخ سجل التسميع',
      );
      await txn.insert('daily_records', record.toMap());
    }
  }

  Future<void> _recomputeStudentMemorizedTotal(
    DatabaseExecutor txn,
    String studentId, {
    required int previousTrackedCount,
  }) async {
    if (previousTrackedCount < 0) {
      throw ArgumentError.value(
        previousTrackedCount,
        'previousTrackedCount',
      );
    }
    await _setExactStudentMemorizedTotal(txn, studentId);
  }

  Future<void> _setExactStudentMemorizedTotal(
    DatabaseExecutor txn,
    String studentId,
  ) async {
    final trackedCount = await _countTrackedMemorized(txn, studentId);
    await txn.update(
      'students',
      {
        'total_memorized': trackedCount.clamp(0, 6236),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [studentId],
    );
  }

  /// Reconciles the profile summary with the daily memorization evidence.
  ///
  /// This is safe to call after editing a name, phone number, or starting
  /// memorized range. Repeated and overlapping recitations count only once.
  Future<int> reconcileStudentMemorizedTotal(String studentId) async {
    final db = await database;
    return db.transaction((txn) async {
      await _setExactStudentMemorizedTotal(txn, studentId);
      final rows = await txn.query(
        'students',
        columns: ['total_memorized'],
        where: 'id = ?',
        whereArgs: [studentId],
        limit: 1,
      );
      return rows.isEmpty
          ? 0
          : (rows.first['total_memorized'] as num?)?.toInt() ?? 0;
    });
  }

  Future<int> _countTrackedMemorized(
    DatabaseExecutor txn,
    String studentId,
  ) async {
    final studentRows = await txn.query(
      'students',
      where: 'id = ?',
      whereArgs: [studentId],
      limit: 1,
    );
    if (studentRows.isEmpty) return 0;
    final student = Student.fromMap(studentRows.first);
    final progressRows = await txn.query(
      'memorization_progress',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
    final mushafRows = await txn.query(
      'mushaf_progress',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
    await QuranService.instance.initialize();
    final ranges = MemorizedContentService.buildRanges(
      student: student,
      progress: progressRows.map(MemorizationProgress.fromMap).toList(),
      mushafProgress: mushafRows.map(MushafProgress.fromMap).toList(),
      surahs: QuranService.instance.surahs,
    );
    var count = 0;
    for (final range in ranges.values) {
      count += range.toAyah - range.fromAyah + 1;
    }
    return count.clamp(0, 6236).toInt();
  }

  String? _joinedProgressNotes(List<MemorizationProgress> progress) {
    final notes = progress
        .map((item) => item.notes?.trim())
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toSet();
    return notes.isEmpty ? null : notes.join(' — ');
  }

  String _qualityToGradeMark(int quality) {
    if (quality >= 5) return 'excellent';
    if (quality == 4) return 'very_good';
    if (quality == 3) return 'good';
    return 'needs_work';
  }

  String _dateKey(DateTime date) =>
      date.toIso8601String().split('T')[0];

  Future<void> _appendDeletedIds(
    DatabaseExecutor txn,
    String settingKey,
    List<String> ids,
  ) async {
    final rows = await txn.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [settingKey],
      limit: 1,
    );
    final deleted = <String>{};
    if (rows.isNotEmpty) {
      try {
        final decoded = jsonDecode(rows.first['value']?.toString() ?? '[]');
        if (decoded is List) {
          deleted.addAll(decoded.map((id) => id.toString()));
        }
      } catch (_) {
        // Replace a malformed local tombstone with the known deletion set.
      }
    }
    deleted.addAll(ids);
    await txn.insert(
      'settings',
      {'key': settingKey, 'value': jsonEncode(deleted.toList())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MemorizationProgress>> getStudentMemorization(String studentId) async {
    final db = await database;
    final maps = await db.query(
      'memorization_progress',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => MemorizationProgress.fromMap(maps[i]));
  }

  Future<List<MemorizationProgress>> getStudentMemorizationInRange(
    String studentId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final rows = await db.query(
      'memorization_progress',
      where: 'student_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [
        studentId,
        startDate.toIso8601String().split('T')[0],
        endDate.toIso8601String().split('T')[0],
      ],
      orderBy: 'date ASC, created_at ASC',
    );
    return rows.map(MemorizationProgress.fromMap).toList();
  }

  Future<List<MemorizationProgress>> getMemorizationInRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final rows = await db.query(
      'memorization_progress',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [_dateKey(startDate), _dateKey(endDate)],
      orderBy: 'date ASC, created_at ASC',
    );
    return rows.map(MemorizationProgress.fromMap).toList();
  }

  Future<int> countNewMemorizedAyahs({
    required Student student,
    required int surahId,
    required int fromAyah,
    required int toAyah,
  }) async {
    final progress = await getStudentMemorization(student.id);
    final alreadyRegistered = <int>{};

    for (final row in progress) {
      if (row.isRevision || row.surahId != surahId) continue;
      for (var ayah = row.fromAyah; ayah <= row.toAyah; ayah++) {
        alreadyRegistered.add(ayah);
      }
    }

    var newCount = 0;
    for (var ayah = fromAyah; ayah <= toAyah; ayah++) {
      final isPreMemorized = _isPreMemorizedAyah(student, surahId, ayah);
      if (!isPreMemorized && !alreadyRegistered.contains(ayah)) {
        newCount++;
      }
    }
    return newCount;
  }

  Future<bool> isSurahFullyMemorized({
    required Student student,
    required int surahId,
    required int totalAyahs,
  }) async {
    final progress = await getStudentMemorization(student.id);
    final registered = <int>{};
    for (final row in progress) {
      if (row.isRevision || row.surahId != surahId) continue;
      for (var ayah = row.fromAyah; ayah <= row.toAyah; ayah++) {
        if (ayah >= 1 && ayah <= totalAyahs) registered.add(ayah);
      }
    }
    for (var ayah = 1; ayah <= totalAyahs; ayah++) {
      if (!_isPreMemorizedAyah(student, surahId, ayah) &&
          !registered.contains(ayah)) {
        return false;
      }
    }
    return true;
  }

  bool _isPreMemorizedAyah(Student student, int surahId, int ayah) {
    final startSurah = student.preMemorizedStartSurah;
    final endSurah = student.preMemorizedEndSurah;
    if (startSurah == null || endSurah == null) return false;

    final startAyah = student.preMemorizedStartAyah ?? 1;
    final endAyah = student.preMemorizedEndAyah ?? 1;
    if (startSurah == endSurah) {
      if (surahId != startSurah) return false;
      final first = startAyah < endAyah ? startAyah : endAyah;
      final last = startAyah > endAyah ? startAyah : endAyah;
      return ayah >= first && ayah <= last;
    }

    final firstSurah = startSurah < endSurah ? startSurah : endSurah;
    final lastSurah = startSurah > endSurah ? startSurah : endSurah;
    if (surahId < firstSurah || surahId > lastSurah) return false;
    if (surahId == startSurah) return ayah >= startAyah;
    if (surahId == endSurah) return ayah <= endAyah;
    return true;
  }

  Future<Map<int, MemorizedAyahRange>> getStudentMemorizedRanges(
    String studentId,
  ) async {
    final student = await getStudent(studentId);
    if (student == null) return {};
    final progress = await getStudentMemorization(studentId);
    final mushafProgress = await getStudentMushafProgress(studentId);
    await QuranService.instance.initialize();
    return MemorizedContentService.buildRanges(
      student: student,
      progress: progress,
      mushafProgress: mushafProgress,
      surahs: QuranService.instance.surahs,
    );
  }

  Future<List<int>> getMemorizedSurahs(String studentId) async {
    final ranges = await getStudentMemorizedRanges(studentId);
    return ranges.keys.toList()..sort();
  }

  Future<void> insertBehaviorPoint(BehaviorPoint point) async {
    final db = await database;
    final studentRows = await db.query(
      'students',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [point.studentId],
      limit: 1,
    );
    if (studentRows.isEmpty) throw StateError('الطالب المحدد غير موجود');
    final validationError = BehaviorPointPolicy.validate(
      type: point.type,
      points: point.points,
      reason: point.reason,
      studentStatus: studentRows.first['status']?.toString() ?? 'inactive',
    );
    if (validationError != null) throw ArgumentError(validationError);
    await db.insert('behavior_points', point.toMap());
  }

  Future<void> insertBehaviorPoints(List<BehaviorPoint> points) async {
    if (points.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final point in points) {
        final studentRows = await txn.query(
          'students',
          columns: ['status'],
          where: 'id = ?',
          whereArgs: [point.studentId],
          limit: 1,
        );
        if (studentRows.isEmpty) {
          throw StateError('أحد الطلاب المحددين غير موجود');
        }
        final validationError = BehaviorPointPolicy.validate(
          type: point.type,
          points: point.points,
          reason: point.reason,
          studentStatus:
              studentRows.first['status']?.toString() ?? 'inactive',
        );
        if (validationError != null) throw ArgumentError(validationError);
      }
      for (final point in points) {
        await txn.insert('behavior_points', point.toMap());
      }
    });
  }

  Future<void> deleteBehaviorPoint(
    String id, {
    String? expectedStudentId,
    String correctionReason = 'حذف سجل أُدخل بالخطأ',
  }) async {
    if (correctionReason.trim().isEmpty) {
      throw ArgumentError('سبب التصحيح مطلوب');
    }
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'behavior_points',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final point = BehaviorPoint.fromMap(rows.first);
      if (expectedStudentId != null && point.studentId != expectedStudentId) {
        throw StateError('تغير إسناد السجل؛ أعد تحميل الصفحة قبل الحذف');
      }
      await txn.insert(
        'behavior_point_corrections',
        BehaviorPointCorrection(
          pointId: point.id,
          originalStudentId: point.studentId,
          action: 'delete',
          reason: correctionReason.trim(),
          pointReasonSnapshot: point.reason,
          pointsSnapshot: point.points,
        ).toMap(),
      );
      await txn.delete(
        'behavior_points',
        where: 'id = ?',
        whereArgs: [id],
      );
      await _appendDeletedIds(txn, 'deleted_behavior_point_ids', [id]);
    });
  }

  Future<void> reassignBehaviorPoint({
    required String pointId,
    required String expectedStudentId,
    required String correctedStudentId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) throw ArgumentError('سبب التصحيح مطلوب');
    if (expectedStudentId == correctedStudentId) {
      throw ArgumentError('اختر طالبًا مختلفًا');
    }
    final db = await database;
    await db.transaction((txn) async {
      final pointRows = await txn.query(
        'behavior_points',
        where: 'id = ?',
        whereArgs: [pointId],
        limit: 1,
      );
      if (pointRows.isEmpty) throw StateError('سجل النقاط غير موجود');
      final point = BehaviorPoint.fromMap(pointRows.first);
      if (point.studentId != expectedStudentId) {
        throw StateError('تغير إسناد السجل؛ أعد تحميل الصفحة');
      }
      final studentRows = await txn.query(
        'students',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [correctedStudentId],
        limit: 1,
      );
      if (studentRows.isEmpty ||
          !BehaviorPointPolicy.activeStudentStatuses.contains(
            studentRows.first['status']?.toString(),
          )) {
        throw StateError('الطالب المصحح غير نشط أو غير موجود');
      }
      await txn.update(
        'behavior_points',
        {'student_id': correctedStudentId},
        where: 'id = ?',
        whereArgs: [pointId],
      );
      await txn.insert(
        'behavior_point_corrections',
        BehaviorPointCorrection(
          pointId: point.id,
          originalStudentId: expectedStudentId,
          correctedStudentId: correctedStudentId,
          action: 'reassign',
          reason: reason.trim(),
          pointReasonSnapshot: point.reason,
          pointsSnapshot: point.points,
        ).toMap(),
      );
    });
  }

  Future<void> upsertBehaviorPointsFromSync(
    Iterable<BehaviorPoint> points,
  ) =>
      _batchUpsertMapsById(
        'behavior_points',
        points.map((point) => Map<String, dynamic>.from(point.toMap())),
      );

  Future<void> upsertBehaviorPointFromSync(BehaviorPoint point) =>
      upsertBehaviorPointsFromSync([point]);

  Future<List<BehaviorPoint>> getStudentBehaviorPoints(String studentId) async {
    final db = await database;
    final maps = await db.query(
      'behavior_points',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => BehaviorPoint.fromMap(maps[i]));
  }

  Future<List<BehaviorPoint>> getStudentBehaviorPointsInRange(
    String studentId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final rows = await db.query(
      'behavior_points',
      where: 'student_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [
        studentId,
        startDate.toIso8601String().split('T')[0],
        endDate.toIso8601String().split('T')[0],
      ],
      orderBy: 'date ASC, created_at ASC',
    );
    return rows.map(BehaviorPoint.fromMap).toList();
  }

  Future<List<BehaviorPoint>> getBehaviorPointsInRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final rows = await db.query(
      'behavior_points',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [_dateKey(startDate), _dateKey(endDate)],
      orderBy: 'student_id ASC, date ASC, created_at ASC',
    );
    return rows.map(BehaviorPoint.fromMap).toList();
  }

  Future<double> getStudentTotalPoints(String studentId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(points), 0) as total 
      FROM behavior_points 
      WHERE student_id = ?
    ''', [studentId]);
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<Map<String, StudentBehaviorSummary>> getBehaviorSummaries() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        student_id,
        COALESCE(SUM(points), 0) AS total_points,
        SUM(CASE WHEN type = 'negative' AND resolved = 0 THEN 1 ELSE 0 END)
          AS unresolved_count
      FROM behavior_points
      GROUP BY student_id
    ''');
    return {
      for (final row in rows)
        row['student_id'].toString(): StudentBehaviorSummary(
          totalPoints: (row['total_points'] as num?)?.toDouble() ?? 0,
          unresolvedViolations:
              (row['unresolved_count'] as num?)?.toInt() ?? 0,
        ),
    };
  }

  Future<List<BehaviorPoint>> getAllUnresolvedViolations() async {
    final db = await database;
    final rows = await db.query(
      'behavior_points',
      where: 'type = ? AND resolved = 0',
      whereArgs: ['negative'],
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map(BehaviorPoint.fromMap).toList();
  }

  Future<bool> hasBehaviorPointForDate(
    String studentId,
    String reason,
    DateTime date,
  ) async {
    final db = await database;
    final dateKey = date.toIso8601String().split('T')[0];
    final rows = await db.query(
      'behavior_points',
      columns: ['id'],
      where: 'student_id = ? AND reason = ? AND date = ?',
      whereArgs: [studentId, reason, dateKey],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// يعيد احتساب نقاط إنجاز الحفظ لليوم كله، بصرف النظر عن عدد التسجيلات.
  ///
  /// عند إنشاء مكافأة تلقائية لأول مرة تُثبت معها نسخة قاعدة النقاط والهدف
  /// اليومي في الملاحظات. أي إعادة احتساب لاحقة لذلك اليوم تستخدم النسخة
  /// المثبتة بدل إعدادات جديدة، حتى لا تتغير النتائج التاريخية عند تعديل
  /// قواعد النقاط أو مقرر الطالب لاحقًا.
  Future<RecitationPointsResult> recalculateDailyRecitationPoints({
    required String studentId,
    required DateTime date,
  }) async {
    await QuranService.instance.initialize();
    final student = await getStudent(studentId);
    if (student == null) throw StateError('الطالب المحدد غير موجود');
    final day = DateTime(date.year, date.month, date.day);
    final progress = await getStudentMemorizationInRange(
      studentId,
      day,
      day,
    );
    final surahs = {
      for (final surah in QuranService.instance.surahs) surah.number: surah,
    };
    final settings = await getSettings();
    final activeCourse = await getActiveQuranCourseForStudent(
      studentId,
      date: day,
      requireMemorization: true,
    );
    final configuredUnit = activeCourse?.memorizationUnit ?? student.planType;
    final configuredPlanAmount =
        (activeCourse?.memorizationAmount ?? student.planAmount).toDouble();
    final configuredCompletionReward =
        settings.pointsConfig['daily_memorization'] ?? 5;
    final configuredExtraReward =
        settings.pointsConfig['extra_memorization'] ?? 2;

    const automaticReason = 'إنجاز المقرر اليومي (تلقائي)';
    const legacyReason = 'زيادة عن المقرر اليومي';
    final db = await database;
    final dateKey = day.toIso8601String().split('T')[0];
    final existingRows = await db.query(
      'behavior_points',
      where: 'student_id = ? AND date = ? AND reason IN (?, ?)',
      whereArgs: [studentId, dateKey, automaticReason, legacyReason],
      orderBy: 'created_at ASC',
    );

    String effectiveUnit = configuredUnit;
    double effectivePlanAmount = configuredPlanAmount;
    int completionReward = configuredCompletionReward;
    int extraReward = configuredExtraReward;
    String roundingMode = settings.recitationPointsRounding;

    if (existingRows.isNotEmpty) {
      final note = existingRows.first['notes']?.toString() ?? '';
      final snapshotMatch = RegExp(
        r'\[rule completion=(\d+);extra=(\d+);target=([0-9.]+);unit=([a-z_]+)(?:;rounding=([a-z_]+))?\]',
      ).firstMatch(note);
      if (snapshotMatch != null) {
        completionReward = int.tryParse(snapshotMatch.group(1) ?? '') ??
            configuredCompletionReward;
        extraReward = int.tryParse(snapshotMatch.group(2) ?? '') ??
            configuredExtraReward;
        effectivePlanAmount = double.tryParse(snapshotMatch.group(3) ?? '') ??
            configuredPlanAmount;
        final storedUnit = snapshotMatch.group(4);
        if (storedUnit == 'ayahs' ||
            storedUnit == 'pages' ||
            storedUnit == 'lines' ||
            storedUnit == 'hizbs') {
          effectiveUnit = storedUnit!;
        }
        final storedRounding = snapshotMatch.group(5);
        if (storedRounding == 'exact' ||
            storedRounding == 'nearest' ||
            storedRounding == 'floor' ||
            storedRounding == 'ceil') {
          roundingMode = storedRounding!;
        }
      }
    }

    final actualAmount = DailyExcellenceService.calculateActualAmount(
      progress: progress,
      surahs: surahs,
      unit: effectiveUnit,
    );
    final result = RecitationPointsPolicy.calculate(
      actualAmount: actualAmount,
      planAmount: effectivePlanAmount,
      unit: effectiveUnit,
      completionReward: completionReward,
      extraReward: extraReward,
      roundingMode: roundingMode,
    );

    final courseLabel = activeCourse == null ? '' : ' ضمن دورة ${activeCourse.title}';
    final ruleSnapshot =
        '[rule completion=$completionReward;extra=$extraReward;'
        'target=${result.planAmount};unit=$effectiveUnit;rounding=$roundingMode]';
    final details =
        'المسمّع ${result.actualAmount.toStringAsFixed(2)} من '
        '${result.planAmount.toStringAsFixed(2)} $effectiveUnit$courseLabel؛ '
        '${result.completionPoints.toStringAsFixed(result.completionPoints % 1 == 0 ? 0 : 2)} نقطة بحسب إنجاز ${result.completionPercent}% من المقرر (سياسة $roundingMode) و${result.bonusPoints.toStringAsFixed(result.bonusPoints % 1 == 0 ? 0 : 2)} للزيادة الفعلية '
        '$ruleSnapshot';

    await db.transaction((txn) async {
      if (result.totalPoints <= 0) {
        for (final row in existingRows) {
          await txn.delete(
            'behavior_points',
            where: 'id = ?',
            whereArgs: [row['id']],
          );
          await _appendDeletedIds(
            txn,
            'deleted_behavior_point_ids',
            [row['id'].toString()],
          );
        }
        return;
      }

      if (existingRows.isEmpty) {
        await txn.insert(
          'behavior_points',
          BehaviorPoint(
            studentId: studentId,
            type: 'positive',
            reason: automaticReason,
            points: result.totalPoints,
            date: day,
            resolved: true,
            notes: details,
          ).toMap(),
        );
        return;
      }

      final retainedId = existingRows.first['id'].toString();
      await txn.update(
        'behavior_points',
        {
          'type': 'positive',
          'reason': automaticReason,
          'points': result.totalPoints,
          'resolved': 1,
          'notes': details,
        },
        where: 'id = ?',
        whereArgs: [retainedId],
      );
      for (final duplicate in existingRows.skip(1)) {
        await txn.delete(
          'behavior_points',
          where: 'id = ?',
          whereArgs: [duplicate['id']],
        );
        await _appendDeletedIds(
          txn,
          'deleted_behavior_point_ids',
          [duplicate['id'].toString()],
        );
      }
    });
    return result;
  }

  Future<List<BehaviorPoint>> getUnresolvedViolations(String studentId) async {
    final db = await database;
    final maps = await db.query(
      'behavior_points',
      where: 'student_id = ? AND type = ? AND resolved = 0',
      whereArgs: [studentId, 'negative'],
    );
    return List.generate(maps.length, (i) => BehaviorPoint.fromMap(maps[i]));
  }

  Future<void> resolveBehaviorPoint(String id) async {
    final db = await database;
    await db.update(
      'behavior_points',
      {'resolved': 1, 'resolved_date': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<DailyAchievement>> getDailyAchievements(DateTime date) async {
    final db = await database;
    final rows = await db.query(
      'daily_achievements',
      where: 'date = ?',
      whereArgs: [_dateKey(date)],
      orderBy: 'actual_amount DESC, created_at ASC',
    );
    return rows.map(DailyAchievement.fromMap).toList();
  }

  Future<DailyAchievement?> getStudentDailyAchievement(
    String studentId,
    DateTime date,
  ) async {
    final db = await database;
    final rows = await db.query(
      'daily_achievements',
      where: 'student_id = ? AND date = ?',
      whereArgs: [studentId, _dateKey(date)],
      limit: 1,
    );
    return rows.isEmpty ? null : DailyAchievement.fromMap(rows.first);
  }

  Future<DailyAchievement> saveDailyAchievement(
    DailyAchievement achievement,
  ) async {
    _validateDailyAchievement(achievement);
    final db = await database;
    return db.transaction((txn) async {
      final studentRows = await txn.query(
        'students',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [achievement.studentId],
        limit: 1,
      );
      if (studentRows.isEmpty ||
          !BehaviorPointPolicy.activeStudentStatuses.contains(
            studentRows.first['status']?.toString(),
          )) {
        throw StateError('لا يمكن تكريم طالب غير نشط');
      }
      final existingRows = await txn.query(
        'daily_achievements',
        where: 'student_id = ? AND date = ?',
        whereArgs: [achievement.studentId, _dateKey(achievement.date)],
        limit: 1,
      );
      final saved = existingRows.isEmpty
          ? achievement
          : _mergeDailyAchievement(
              DailyAchievement.fromMap(existingRows.first),
              achievement,
            );
      await txn.insert(
        'daily_achievements',
        saved.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return saved;
    });
  }

  Future<DailyAchievement> awardDailyAchievement({
    required DailyAchievement achievement,
    required String rewardType,
    String? rewardDetails,
    int rewardPoints = 0,
  }) async {
    const validRewards = {'points', 'certificate', 'gift', 'meal', 'other'};
    if (!validRewards.contains(rewardType)) {
      throw ArgumentError('نوع المكافأة غير صالح');
    }
    if (rewardType == 'points' && rewardPoints < 1) {
      throw ArgumentError('عدد نقاط المكافأة يجب أن يكون أكبر من صفر');
    }
    _validateDailyAchievement(achievement);
    final db = await database;
    return db.transaction((txn) async {
      final studentRows = await txn.query(
        'students',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [achievement.studentId],
        limit: 1,
      );
      final studentStatus = studentRows.isEmpty
          ? 'inactive'
          : studentRows.first['status']?.toString() ?? 'inactive';
      if (!BehaviorPointPolicy.activeStudentStatuses.contains(studentStatus)) {
        throw StateError('لا يمكن مكافأة طالب غير نشط');
      }

      final existingRows = await txn.query(
        'daily_achievements',
        where: 'student_id = ? AND date = ?',
        whereArgs: [achievement.studentId, _dateKey(achievement.date)],
        limit: 1,
      );
      final base = existingRows.isEmpty
          ? achievement
          : _mergeDailyAchievement(
              DailyAchievement.fromMap(existingRows.first),
              achievement,
            );
      final now = DateTime.now();
      final pointReason = 'تكريم متميز اليوم ${_dateKey(achievement.date)}';
      final previousRewardPoints = await txn.query(
        'behavior_points',
        where: 'student_id = ? AND reason = ? AND date = ?',
        whereArgs: [
          achievement.studentId,
          pointReason,
          _dateKey(achievement.date),
        ],
      );
      if (previousRewardPoints.isNotEmpty &&
          (rewardType != 'points' ||
              previousRewardPoints.first['points'] != rewardPoints)) {
        final deletedIds = previousRewardPoints
            .map((row) => row['id']?.toString())
            .whereType<String>()
            .toList();
        await txn.delete(
          'behavior_points',
          where: 'student_id = ? AND reason = ? AND date = ?',
          whereArgs: [
            achievement.studentId,
            pointReason,
            _dateKey(achievement.date),
          ],
        );
        await _appendDeletedIds(
          txn,
          'deleted_behavior_point_ids',
          deletedIds,
        );
      }
      final saved = base.copyWith(
        rewardType: rewardType,
        rewardDetails: rewardDetails?.trim(),
        rewardPoints: rewardType == 'points' ? rewardPoints : 0,
        awardedAt: now,
      );
      await txn.insert(
        'daily_achievements',
        saved.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (rewardType == 'points') {
        final duplicate = await txn.query(
          'behavior_points',
          columns: ['id'],
          where: 'student_id = ? AND reason = ? AND date = ?',
          whereArgs: [
            achievement.studentId,
            pointReason,
            _dateKey(achievement.date),
          ],
          limit: 1,
        );
        if (duplicate.isEmpty) {
          await txn.insert(
            'behavior_points',
            BehaviorPoint(
              studentId: achievement.studentId,
              type: 'positive',
              reason: pointReason,
              points: rewardPoints,
              date: achievement.date,
              resolved: true,
              notes: rewardDetails?.trim().isEmpty == false
                  ? rewardDetails!.trim()
                  : achievement.reason,
            ).toMap(),
          );
        }
      }
      return saved;
    });
  }

  DailyAchievement _mergeDailyAchievement(
    DailyAchievement existing,
    DailyAchievement incoming,
  ) =>
      DailyAchievement(
        id: existing.id,
        studentId: existing.studentId,
        date: existing.date,
        source: incoming.isAutomatic ? incoming.source : existing.source,
        reason: incoming.reason,
        actualAmount: incoming.actualAmount,
        planAmount: incoming.planAmount,
        unit: incoming.unit,
        rewardType: existing.rewardType,
        rewardDetails: existing.rewardDetails,
        rewardPoints: existing.rewardPoints,
        awardedAt: existing.awardedAt,
        notes: incoming.notes ?? existing.notes,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );

  void _validateDailyAchievement(DailyAchievement achievement) {
    if (!const {'automatic', 'manual'}.contains(achievement.source) ||
        !const {'ayahs', 'pages', 'lines', 'hizbs'}.contains(achievement.unit) ||
        achievement.reason.trim().isEmpty ||
        achievement.actualAmount < 0 ||
        achievement.planAmount < 0) {
      throw ArgumentError('بيانات تميز اليوم غير صالحة');
    }
  }

  Future<void> insertVacation(Vacation vacation) async {
    final db = await database;
    await db.insert('vacations', vacation.toMap());

    // Auto-update attendance records
    if (vacation.approved) {
      final startStr = vacation.startDate.toIso8601String().split('T')[0];
      final endStr = vacation.endDate.toIso8601String().split('T')[0];
      await db.update(
        'daily_records',
        {
          'attendance': 'excused',
          'notes': 'تحولت لإجازة تلقائيًا: ${VacationReason.getLabel(vacation.reason)}',
        },
        where: 'student_id = ? AND date BETWEEN ? AND ? AND attendance = ?',
        whereArgs: [vacation.studentId, startStr, endStr, 'absent'],
      );
    }
  }

  Future<void> upsertVacationsFromSync(Iterable<Vacation> vacations) =>
      _batchUpsertMapsById(
        'vacations',
        vacations.map(
          (vacation) => Map<String, dynamic>.from(vacation.toMap()),
        ),
      );

  Future<void> upsertVacationFromSync(Vacation vacation) =>
      upsertVacationsFromSync([vacation]);

  Future<void> insertVacations(List<Vacation> vacations) async {
    if (vacations.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final vacation in vacations) {
        await txn.insert('vacations', vacation.toMap());
        if (!vacation.approved) continue;
        final startStr = vacation.startDate.toIso8601String().split('T')[0];
        final endStr = vacation.endDate.toIso8601String().split('T')[0];
        await txn.update(
          'daily_records',
          {
            'attendance': 'excused',
            'notes':
                'تحولت لإجازة تلقائيًا: ${VacationReason.getLabel(vacation.reason)}',
          },
          where: 'student_id = ? AND date BETWEEN ? AND ? AND attendance = ?',
          whereArgs: [vacation.studentId, startStr, endStr, 'absent'],
        );
      }
    });
  }

  Future<void> updateVacation(Vacation vacation) async {
    final db = await database;
    await db.update(
      'vacations',
      vacation.toMap(),
      where: 'id = ?',
      whereArgs: [vacation.id],
    );

    // Update daily records
    final startStr = vacation.startDate.toIso8601String().split('T')[0];
    final endStr = vacation.endDate.toIso8601String().split('T')[0];
    if (vacation.approved) {
      await db.update(
        'daily_records',
        {
          'attendance': 'excused',
          'notes': 'تحولت لإجازة تلقائيًا: ${VacationReason.getLabel(vacation.reason)}',
        },
        where: 'student_id = ? AND date BETWEEN ? AND ? AND attendance = ?',
        whereArgs: [vacation.studentId, startStr, endStr, 'absent'],
      );
    } else {
      await db.update(
        'daily_records',
        {
          'attendance': 'absent',
        },
        where: "student_id = ? AND date BETWEEN ? AND ? AND attendance = 'excused' AND (notes LIKE '%إجازة%' OR notes LIKE '%vacation%')",
        whereArgs: [vacation.studentId, startStr, endStr],
      );
    }
  }

  Future<List<Vacation>> getStudentVacations(String studentId) async {
    final db = await database;
    final maps = await db.query(
      'vacations',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'start_date DESC',
    );
    return List.generate(maps.length, (i) => Vacation.fromMap(maps[i]));
  }

  Future<List<Vacation>> getStudentVacationsInRange(
    String studentId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final rows = await db.query(
      'vacations',
      where: 'student_id = ? AND start_date <= ? AND end_date >= ?',
      whereArgs: [
        studentId,
        endDate.toIso8601String().split('T')[0],
        startDate.toIso8601String().split('T')[0],
      ],
      orderBy: 'start_date ASC',
    );
    return rows.map(Vacation.fromMap).toList();
  }

  Future<List<Vacation>> getVacationsInRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final rows = await db.query(
      'vacations',
      where: 'start_date <= ? AND end_date >= ?',
      whereArgs: [_dateKey(endDate), _dateKey(startDate)],
      orderBy: 'student_id ASC, start_date ASC',
    );
    return rows.map(Vacation.fromMap).toList();
  }

  Future<bool> isStudentOnVacation(String studentId, DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    final maps = await db.rawQuery('''
      SELECT * FROM vacations 
      WHERE student_id = ? AND approved = 1 
      AND start_date <= ? AND end_date >= ?
    ''', [studentId, dateStr, dateStr]);
    return maps.isNotEmpty;
  }

  Future<void> deleteVacation(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      final maps = await txn.query(
        'vacations',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (maps.isEmpty) return;
      final vacation = Vacation.fromMap(maps.first);
      await txn.delete('vacations', where: 'id = ?', whereArgs: [id]);
      await _appendDeletedIds(txn, 'deleted_vacation_ids', [id]);

      // Revert only attendance rows that had been turned into an excused row
      // because of this vacation. Manual unrelated attendance is preserved.
      final startStr = vacation.startDate.toIso8601String().split('T')[0];
      final endStr = vacation.endDate.toIso8601String().split('T')[0];
      await txn.update(
        'daily_records',
        {'attendance': 'absent'},
        where: "student_id = ? AND date BETWEEN ? AND ? AND attendance = 'excused' AND (notes LIKE '%إجازة%' OR notes LIKE '%vacation%')",
        whereArgs: [vacation.studentId, startStr, endStr],
      );
    });
  }

  Future<List<Vacation>> getAllVacations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('vacations', orderBy: 'start_date DESC');
    return List.generate(maps.length, (i) => Vacation.fromMap(maps[i]));
  }

  Future<void> updateVacationApproval(String id, bool approved) async {
    final db = await database;
    await db.update(
      'vacations',
      {'approved': approved ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );

    // Update daily records
    final maps = await db.query('vacations', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      final vacation = Vacation.fromMap(maps.first);
      final startStr = vacation.startDate.toIso8601String().split('T')[0];
      final endStr = vacation.endDate.toIso8601String().split('T')[0];
      if (approved) {
        await db.update(
          'daily_records',
          {
            'attendance': 'excused',
            'notes': 'تحولت لإجازة تلقائيًا: ${VacationReason.getLabel(vacation.reason)}',
          },
          where: 'student_id = ? AND date BETWEEN ? AND ? AND attendance = ?',
          whereArgs: [vacation.studentId, startStr, endStr, 'absent'],
        );
      } else {
        await db.update(
          'daily_records',
          {
            'attendance': 'absent',
          },
          where: "student_id = ? AND date BETWEEN ? AND ? AND attendance = 'excused' AND (notes LIKE '%إجازة%' OR notes LIKE '%vacation%')",
          whereArgs: [vacation.studentId, startStr, endStr],
        );
      }
    }
  }

  Future<void> insertExam(Exam exam) async {
    final db = await database;
    await db.insert('exams', exam.toMap());
  }

  Future<void> upsertExamsFromSync(Iterable<Exam> exams) =>
      _batchUpsertMapsById(
        'exams',
        exams.map((exam) => Map<String, dynamic>.from(exam.toMap())),
      );

  Future<void> upsertExamFromSync(Exam exam) => upsertExamsFromSync([exam]);

  Future<List<Exam>> getStudentExams(String studentId) async {
    final db = await database;
    final maps = await db.query(
      'exams',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Exam.fromMap(maps[i]));
  }

  Future<void> updateExam(Exam exam) async {
    final db = await database;
    await db.update(
      'exams',
      exam.toMap(),
      where: 'id = ?',
      whereArgs: [exam.id],
    );
  }

  Future<List<Exam>> getStudentExamsInRange(
    String studentId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final rows = await db.query(
      'exams',
      where: 'student_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [studentId, _dateKey(startDate), _dateKey(endDate)],
      orderBy: 'date ASC, created_at ASC',
    );
    return rows.map(Exam.fromMap).toList();
  }

  Future<List<Exam>> getExamsInRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final rows = await db.query(
      'exams',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [_dateKey(startDate), _dateKey(endDate)],
      orderBy: 'student_id ASC, date ASC, created_at ASC',
    );
    return rows.map(Exam.fromMap).toList();
  }

  Future<void> deleteExam(String examId) async {
    final db = await database;
    final current = await getSetting('deleted_exam_ids');
    List<dynamic> decoded = [];
    if (current != null && current.isNotEmpty) {
      try {
        final value = jsonDecode(current);
        if (value is List) decoded = value;
      } catch (_) {
        decoded = [];
      }
    }
    final deletedIds = decoded.map((id) => id.toString()).toSet()..add(examId);

    await db.transaction((txn) async {
      // If the exam was used as a smart-plan gate, deleting it reopens that gate
      // instead of leaving a dangling completion_exam_id.
      await txn.update(
        'plans',
        {
          'completion_exam_id': null,
          'test_status': 'pending',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'completion_exam_id = ?',
        whereArgs: [examId],
      );
      await txn.delete('exams', where: 'id = ?', whereArgs: [examId]);
      await txn.insert(
        'settings',
        {
          'key': 'deleted_exam_ids',
          'value': jsonEncode(deletedIds.toList()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> saveExamTemplate(
    ExamTemplate template,
    List<ExamTemplateQuestion> questions,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'exam_templates',
        template.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await txn.update(
        'exam_templates',
        template.toMap(),
        where: 'id = ?',
        whereArgs: [template.id],
      );
      await txn.delete(
        'exam_template_questions',
        where: 'template_id = ?',
        whereArgs: [template.id],
      );
      for (final question in questions) {
        await txn.insert('exam_template_questions', question.toMap());
      }
    });
  }

  Future<List<ExamTemplate>> getExamTemplates({String? studentId}) async {
    final db = await database;
    final rows = await db.query(
      'exam_templates',
      where: studentId == null ? null : 'student_id = ?',
      whereArgs: studentId == null ? null : [studentId],
      orderBy: 'updated_at DESC',
    );
    return rows.map(ExamTemplate.fromMap).toList();
  }

  Future<List<ExamTemplateQuestion>> getExamTemplateQuestions(
    String templateId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'exam_template_questions',
      where: 'template_id = ?',
      whereArgs: [templateId],
      orderBy: 'question_order ASC',
    );
    return rows.map(ExamTemplateQuestion.fromMap).toList();
  }

  Future<void> deleteExamTemplate(String templateId) async {
    final db = await database;
    final current = await getSetting('deleted_exam_template_ids');
    List<dynamic> decoded = [];
    if (current != null && current.isNotEmpty) {
      try {
        final value = jsonDecode(current);
        if (value is List) decoded = value;
      } catch (_) {
        decoded = [];
      }
    }
    final deletedIds = decoded.map((id) => id.toString()).toSet()
      ..add(templateId);
    await db.transaction((txn) async {
      // Older SQLite schemas intentionally allowed exams to retain template_id
      // after a template was removed. Clear those references first so the next
      // cloud upload cannot violate exams_template_id_fkey.
      await txn.update(
        'exams',
        {'template_id': null},
        where: 'template_id = ?',
        whereArgs: [templateId],
      );
      await txn.delete(
        'exam_templates',
        where: 'id = ?',
        whereArgs: [templateId],
      );
      await txn.insert(
        'settings',
        {
          'key': 'deleted_exam_template_ids',
          'value': jsonEncode(deletedIds.toList()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> saveCompetitionEvent(CompetitionEvent event) async {
    final db = await database;
    await db.insert(
      'competition_events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CompetitionEvent>> getCompetitionEvents() async {
    final db = await database;
    final rows = await db.query(
      'competition_events',
      orderBy: "CASE status WHEN 'active' THEN 0 ELSE 1 END, created_at DESC",
    );
    return rows.map(CompetitionEvent.fromMap).toList();
  }

  Future<Map<String, int>> getCompetitionResultCounts() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT event_id, COUNT(*) AS count FROM competition_results GROUP BY event_id',
    );
    return <String, int>{
      for (final row in rows)
        row['event_id'].toString(): (row['count'] as num?)?.toInt() ?? 0,
    };
  }

  Future<void> saveCompetitionResult(CompetitionResult result) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'competition_results',
        where: 'event_id = ? AND student_id = ? AND id != ?',
        whereArgs: [result.eventId, result.studentId, result.id],
      );
      await txn.insert(
        'competition_results',
        result.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<List<CompetitionResult>> getCompetitionResults(
    String eventId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'competition_results',
      where: 'event_id = ?',
      whereArgs: [eventId],
      orderBy: 'score DESC, assessed_at ASC',
    );
    return rows.map(CompetitionResult.fromMap).toList();
  }

  Future<void> deleteCompetitionEvent(String eventId) async {
    final db = await database;
    await db.transaction((txn) async {
      // Explicit child deletion keeps the operation deterministic even on a
      // device where SQLite foreign-key enforcement was temporarily disabled.
      await txn.delete(
        'competition_results',
        where: 'event_id = ?',
        whereArgs: [eventId],
      );
      await txn.delete(
        'competition_events',
        where: 'id = ?',
        whereArgs: [eventId],
      );
    });
  }

  Future<void> saveTalaqqinSession({
    required List<TalaqqinRecord> records,
    required DailyRecord dailyRecord,
  }) async {
    if (records.isEmpty) throw ArgumentError('جلسة التلقين فارغة');
    if (records.any((row) => row.studentId != dailyRecord.studentId)) {
      throw ArgumentError('جلسة التلقين لا تطابق الطالب');
    }
    final activeHold = await getActiveStudentHold(
      dailyRecord.studentId,
      date: dailyRecord.date,
    );
    if (activeHold != null) {
      throw StateError('الطالب موقوف مؤقتًا ولا يمكن تسجيل التلقين الآن');
    }
    final db = await database;
    await db.transaction((txn) async {
      for (final row in records) {
        await txn.insert(
          'talaqqin_records',
          row.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.insert(
        'daily_records',
        dailyRecord.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<List<TalaqqinRecord>> getStudentTalaqqinRecords(
    String studentId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    var where = 'student_id = ?';
    final args = <Object?>[studentId];
    if (startDate != null && endDate != null) {
      where += ' AND date BETWEEN ? AND ?';
      args.add(startDate.toIso8601String().split('T').first);
      args.add(endDate.toIso8601String().split('T').first);
    }
    final rows = await db.query(
      'talaqqin_records',
      where: where,
      whereArgs: args,
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map(TalaqqinRecord.fromMap).toList();
  }

  Future<void> upsertTalaqqinRecordsFromSync(
    Iterable<TalaqqinRecord> records,
  ) =>
      _batchUpsertMapsById(
        'talaqqin_records',
        records.map((record) => Map<String, dynamic>.from(record.toMap())),
      );

  Future<void> upsertTalaqqinRecord(TalaqqinRecord record) =>
      upsertTalaqqinRecordsFromSync([record]);

  Future<List<TalaqqinRecord>> getAllTalaqqinRecords() async {
    final db = await database;
    final rows = await db.query(
      'talaqqin_records',
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map(TalaqqinRecord.fromMap).toList();
  }

  Future<void> upsertStudentAdminActionsFromSync(
    Iterable<StudentAdminAction> actions,
  ) =>
      _batchUpsertMapsById(
        'student_admin_actions',
        actions.map((action) => Map<String, dynamic>.from(action.toMap())),
      );

  Future<void> saveStudentAdminAction(StudentAdminAction action) =>
      upsertStudentAdminActionsFromSync([action]);

  Future<List<StudentAdminAction>> getStudentAdminActions(
    String studentId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'student_admin_actions',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map(StudentAdminAction.fromMap).toList();
  }

  Future<List<StudentAdminAction>> getAllStudentAdminActions() async {
    final db = await database;
    final rows = await db.query(
      'student_admin_actions',
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map(StudentAdminAction.fromMap).toList();
  }

  Future<void> setStudentAdminActionResolved(String id, bool resolved) async {
    final db = await database;
    await db.update(
      'student_admin_actions',
      {
        'resolved': resolved ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> saveStudentHold(StudentHold hold) async {
    final db = await database;
    final overlap = await db.query(
      'student_holds',
      columns: ['id'],
      where: 'student_id = ? AND id != ? AND ended_at IS NULL '
          'AND start_date <= ? AND end_date >= ?',
      whereArgs: [
        hold.studentId,
        hold.id,
        hold.endDate.toIso8601String().split('T')[0],
        hold.startDate.toIso8601String().split('T')[0],
      ],
      limit: 1,
    );
    if (overlap.isNotEmpty) {
      throw StateError('يوجد إيقاف آخر متداخل مع هذه الفترة');
    }
    await db.insert(
      'student_holds',
      hold.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<StudentHold>> getStudentHolds(String studentId) async {
    final db = await database;
    final rows = await db.query(
      'student_holds',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'created_at DESC',
    );
    return rows.map(StudentHold.fromMap).toList();
  }

  Future<List<StudentHold>> getAllStudentHolds() async {
    final db = await database;
    final rows = await db.query('student_holds', orderBy: 'created_at DESC');
    return rows.map(StudentHold.fromMap).toList();
  }

  Future<List<StudentHold>> getAllStudentHoldsInRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final rows = await db.query(
      'student_holds',
      where: 'start_date <= ? AND end_date >= ?',
      whereArgs: [
        endDate.toIso8601String().split('T')[0],
        startDate.toIso8601String().split('T')[0],
      ],
      orderBy: 'student_id ASC, start_date ASC',
    );
    return rows.map(StudentHold.fromMap).toList();
  }

  Future<List<StudentHold>> getStudentHoldsInRange(
    String studentId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final rows = await db.query(
      'student_holds',
      where: 'student_id = ? AND start_date <= ? AND end_date >= ?',
      whereArgs: [
        studentId,
        endDate.toIso8601String().split('T')[0],
        startDate.toIso8601String().split('T')[0],
      ],
      orderBy: 'start_date ASC',
    );
    return rows.map(StudentHold.fromMap).toList();
  }

  Future<StudentHold?> getActiveStudentHold(
    String studentId, {
    DateTime? date,
  }) async {
    final db = await database;
    final target = (date ?? DateTime.now()).toIso8601String().split('T')[0];
    final rows = await db.query(
      'student_holds',
      where: 'student_id = ? AND start_date <= ? AND end_date >= ? '
          "AND (ended_at IS NULL OR substr(ended_at, 1, 10) >= ?)",
      whereArgs: [studentId, target, target, target],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : StudentHold.fromMap(rows.first);
  }

  Future<List<StudentHold>> getActiveStudentHolds({DateTime? date}) async {
    final db = await database;
    final target = (date ?? DateTime.now()).toIso8601String().split('T')[0];
    final rows = await db.query(
      'student_holds',
      where: 'start_date <= ? AND end_date >= ? '
          "AND (ended_at IS NULL OR substr(ended_at, 1, 10) >= ?)",
      whereArgs: [target, target, target],
      orderBy: 'created_at DESC',
    );
    return rows.map(StudentHold.fromMap).toList();
  }

  Future<void> endStudentHold(String holdId) async {
    final db = await database;
    await db.update(
      'student_holds',
      {'ended_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND ended_at IS NULL',
      whereArgs: [holdId],
    );
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  Future<HalaqahSettings> getSettings() async {
    final db = await database;
    final maps = await db.query('settings');
    if (maps.isEmpty) return HalaqahSettings();
    
    final settingsMap = <String, dynamic>{};
    for (final map in maps) {
      settingsMap[map['key'] as String] = map['value'];
    }
    return HalaqahSettings.fromMap(settingsMap);
  }

  Future<void> saveSettings(HalaqahSettings settings) async {
    final db = await database;
    final map = settings.toMap();
    final currentPointsRows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['points_config'],
      limit: 1,
    );
    final previousPointsSnapshot = currentPointsRows.isEmpty
        ? null
        : currentPointsRows.first['value']?.toString();
    final nextPointsSnapshot = map['points_config']?.toString() ?? '';
    final now = DateTime.now();

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final entry in map.entries) {
        batch.insert(
          'settings',
          {'key': entry.key, 'value': entry.value.toString()},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);

      if (previousPointsSnapshot != nextPointsSnapshot) {
        await txn.insert(
          'rules_config_history',
          {
            'id': 'points_${now.microsecondsSinceEpoch}',
            'config_key': 'points_config',
            'previous_snapshot': previousPointsSnapshot,
            'snapshot': nextPointsSnapshot,
            'created_at': now.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getPointsConfigHistory({
    int limit = 30,
  }) async {
    final db = await database;
    final rows = await db.query(
      'rules_config_history',
      where: 'config_key = ?',
      whereArgs: ['points_config'],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  static const List<String> backupTables = [
    'families',
    'family_guardians',
    'students',
    'student_status_history',
    'daily_records',
    'memorization_progress',
    'behavior_points',
    'behavior_point_corrections',
    'daily_achievements',
    'vacations',
    'student_holds',
    'talaqqin_records',
    'student_admin_actions',
    'exams',
    'exam_templates',
    'exam_template_questions',
    'competition_events',
    'competition_results',
    'fund_transactions',
    'plans',
    'plan_recitation_records',
    'quran_courses',
    'quran_course_enrollments',
    'notifications',
    'homework_grades',
    'mushaf_progress',
    'message_templates',
    'audit_events',
    'rules_config_history',
    'sync_delete_outbox',
    'settings',
  ];

  Future<Map<String, List<Map<String, dynamic>>>> exportBackupTables() async {
    final db = await database;
    final result = <String, List<Map<String, dynamic>>>{};
    for (final table in backupTables) {
      result[table] = (await db.query(table))
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    return result;
  }

  Future<Map<String, List<Map<String, dynamic>>>>
      exportDeviceExchangeTables() async {
    final db = await database;
    final result = <String, List<Map<String, dynamic>>>{};
    for (final table in backupTables) {
      if (table == 'settings' ||
          table == 'audit_events' ||
          table == 'message_templates' ||
          table == 'sync_delete_outbox') {
        continue;
      }
      result[table] = (await db.query(table))
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    return result;
  }

  Future<void> restoreFromBackup(Map<String, dynamic> backup) async {
    final db = await database;

    final rawTables = backup['tables'];
    if (rawTables is! Map) {
      // Version 1 backups did not contain every table. Merge their rows without
      // clearing the database, otherwise restoring one would silently delete
      // plans, fund transactions, grades, Mushaf progress, and templates.
      final legacyTables = <String, dynamic>{
        'students': backup['students'],
        'daily_records': backup['records'],
        'memorization_progress': backup['memorizations'],
        'behavior_points': backup['behavior_points'],
        'vacations': backup['vacations'],
        'exams': backup['exams'],
      };

      await db.transaction((txn) async {
        for (final table in backupTables) {
          final rows = legacyTables[table];
          if (rows is! List) continue;
          for (final item in rows) {
            if (item is! Map) continue;
            final row = Map<String, dynamic>.from(item);
            if ((table == 'memorization_progress' ||
                    table == 'homework_grades') &&
                row['updated_at'] == null) {
              row['updated_at'] = row['created_at'] ??
                  DateTime.now().toIso8601String();
            }
            final primaryKey = table == 'message_templates' ? 'type' : 'id';
            final insertedId = await txn.insert(
              table,
              row,
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
            final keyValue = row[primaryKey];
            if (insertedId == 0 && keyValue != null) {
              await txn.update(
                table,
                row,
                where: '$primaryKey = ?',
                whereArgs: [keyValue],
              );
            }
          }
        }

        final settings = backup['settings'];
        if (settings is Map) {
          for (final entry in settings.entries) {
            if (entry.value == null) continue;
            await txn.insert(
              'settings',
              {'key': entry.key.toString(), 'value': entry.value.toString()},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      });
      return;
    }

    final tables = <String, List<dynamic>>{};
    const optionalV2Tables = {
      'exam_templates',
      'exam_template_questions',
      'student_holds',
      'student_status_history',
      'behavior_point_corrections',
      'daily_achievements',
      'families',
      'family_guardians',
      'audit_events',
      'plan_recitation_records',
      'competition_events',
      'competition_results',
      'talaqqin_records',
      'student_admin_actions',
      'quran_courses',
      'quran_course_enrollments',
      'sync_delete_outbox',
    };
    for (final table in backupTables) {
      final rows = rawTables[table];
      if (rows is! List) {
        if (optionalV2Tables.contains(table)) {
          tables[table] = const [];
          continue;
        }
        throw FormatException('النسخة الاحتياطية لا تحتوي على جدول $table');
      }
      tables[table] = rows;
    }

    await db.transaction((txn) async {
      // Restoring a snapshot is not a user delete operation. Suppress the
      // SQLite v25 delete-outbox triggers while replacing the local snapshot.
      await txn.insert(
        'settings',
        {'key': 'sync_remote_delete_replay', 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('sync_delete_outbox');
      // Clear existing data (children first, then parents)
      await txn.delete('behavior_point_corrections');
      await txn.delete('daily_achievements');
      await txn.delete('family_guardians');
      await txn.delete('student_status_history');
      await txn.delete('daily_records');
      await txn.delete('memorization_progress');
      await txn.delete('behavior_points');
      await txn.delete('vacations');
      await txn.delete('student_admin_actions');
      await txn.delete('talaqqin_records');
      await txn.delete('student_holds');
      await txn.delete('exams');
      await txn.delete('competition_results');
      await txn.delete('exam_template_questions');
      await txn.delete('exam_templates');
      await txn.delete('competition_events');
      await txn.delete('fund_transactions');
      await txn.delete('quran_course_enrollments');
      await txn.delete('quran_courses');
      await txn.delete('plan_recitation_records');
      await txn.delete('plans');
      await txn.delete('notifications');
      await txn.delete('homework_grades');
      await txn.delete('mushaf_progress');
      await txn.delete('message_templates');
      await txn.delete('audit_events');
      await txn.delete('students');
      await txn.delete('families');
      await txn.delete('settings');

      Future<void> insertAll(String table, List<dynamic> rows) async {
        for (final item in rows) {
          if (item is Map) {
            final row = Map<String, dynamic>.from(item);
            if ((table == 'memorization_progress' ||
                    table == 'homework_grades') &&
                row['updated_at'] == null) {
              row['updated_at'] = row['created_at'] ??
                  DateTime.now().toIso8601String();
            }
            await txn.insert(
              table,
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }

      // Families are parents of both students and guardians.
      await insertAll('families', tables['families']!);
      await insertAll('students', tables['students']!);
      await insertAll('family_guardians', tables['family_guardians']!);
      for (final table in backupTables) {
        if (table == 'families' ||
            table == 'family_guardians' ||
            table == 'students' ||
            table == 'settings') {
          continue;
        }
        await insertAll(table, tables[table]!);
      }
      await insertAll('settings', tables['settings']!);
      await txn.insert(
        'settings',
        {'key': 'sync_remote_delete_replay', 'value': '0'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Merges an encrypted device-exchange package without replacing the
  /// receiving device settings. Rows with the same identity use their latest
  /// update timestamp; new rows are inserted in dependency order.
  Future<Map<String, int>> mergeFromBackup(Map<String, dynamic> backup) async {
    final rawTables = backup['tables'];
    if (rawTables is! Map) {
      throw const FormatException(
        'دمج الأجهزة يحتاج نسخة حديثة مشفرة من حلقتي',
      );
    }
    final db = await database;
    var inserted = 0;
    var updated = 0;
    var skipped = 0;

    DateTime rowTime(Map<String, dynamic> row) {
      for (final key in const [
        'updated_at',
        'assessed_at',
        'created_at',
        'changed_at',
        'date',
      ]) {
        final parsed = DateTime.tryParse(row[key]?.toString() ?? '');
        if (parsed != null) return parsed;
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    await db.transaction((txn) async {
      for (final table in backupTables) {
        if (table == 'settings' ||
            table == 'audit_events' ||
            table == 'message_templates' ||
            table == 'sync_delete_outbox') {
          continue;
        }
        final rows = rawTables[table];
        if (rows is! List) continue;
        for (final item in rows) {
          if (item is! Map) {
            skipped++;
            continue;
          }
          final incoming = Map<String, dynamic>.from(item);
          final id = incoming['id'];
          if (id == null) {
            skipped++;
            continue;
          }
          final existingRows = await txn.query(
            table,
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );
          if (existingRows.isEmpty) {
            try {
              final rowId = await txn.insert(
                table,
                incoming,
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
              if (rowId == 0) {
                skipped++;
              } else {
                inserted++;
              }
            } catch (_) {
              skipped++;
            }
            continue;
          }
          final existing = Map<String, dynamic>.from(existingRows.first);
          if (rowTime(incoming).isAfter(rowTime(existing))) {
            await txn.update(
              table,
              incoming,
              where: 'id = ?',
              whereArgs: [id],
            );
            updated++;
          } else {
            skipped++;
          }
        }
      }
    });

    final students = await getStudents();
    for (final student in students) {
      await reconcileStudentMemorizedTotal(student.id);
    }
    return {
      'inserted': inserted,
      'updated': updated,
      'skipped': skipped,
    };
  }

  Future<void> saveAuditEvent(AuditEvent event) async {
    final db = await database;
    await db.insert(
      'audit_events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<AuditEvent>> getAuditEvents({int limit = 200}) async {
    final db = await database;
    final rows = await db.query(
      'audit_events',
      orderBy: 'created_at DESC',
      limit: limit.clamp(1, 1000).toInt(),
    );
    return rows
        .map((row) => AuditEvent.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<int> deleteAuditEventsBefore(DateTime cutoff) async {
    final db = await database;
    return db.delete(
      'audit_events',
      where: 'created_at < ?',
      whereArgs: <Object?>[cutoff.toUtc().toIso8601String()],
    );
  }

  Future<Map<String, dynamic>> getStudentStatistics(String studentId) async {
    final db = await database;
    
    final attendanceResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN attendance = 'present' THEN 1 ELSE 0 END) as present,
        SUM(CASE WHEN attendance = 'late' THEN 1 ELSE 0 END) as late,
        SUM(CASE WHEN attendance = 'absent' THEN 1 ELSE 0 END) as absent
      FROM daily_records WHERE student_id = ?
    ''', [studentId]);

    final memorizationResult = await db.rawQuery('''
      SELECT COALESCE(SUM(to_ayah - from_ayah + 1), 0) as total
      FROM memorization_progress 
      WHERE student_id = ? AND is_revision = 0
    ''', [studentId]);

    final pointsResult = await db.rawQuery('''
      SELECT COALESCE(SUM(points), 0) as total
      FROM behavior_points WHERE student_id = ?
    ''', [studentId]);

    final examResult = await db.rawQuery('''
      SELECT COUNT(*) as total, COALESCE(AVG(score), 0) as avg
      FROM exams WHERE student_id = ?
    ''', [studentId]);

    return {
      'attendance': attendanceResult.first,
      'memorization': memorizationResult.first['total'] ?? 0,
      'points': pointsResult.first['total'] ?? 0,
      'exams': examResult.first,
    };
  }

  // Fund Transactions CRUD
  Future<void> insertFundTransaction(FundTransaction transaction) async {
    if (transaction.settledNegativePoints < 0) {
      throw ArgumentError('لا يمكن أن تكون نقاط التسوية سالبة');
    }
    if (transaction.settledNegativePoints > 0 &&
        (transaction.type != 'penalty' || transaction.studentId == null)) {
      throw ArgumentError('تسوية النقاط متاحة فقط لغرامة مرتبطة بطالب');
    }
    final db = await database;
    await db.transaction((txn) async {
      if (transaction.settledNegativePoints > 0) {
        final result = await txn.rawQuery(
          '''
          SELECT COALESCE(SUM(ABS(points)), 0) AS total
          FROM behavior_points
          WHERE student_id = ? AND points < 0
          ''',
          [transaction.studentId],
        );
        final paid = await txn.rawQuery(
          '''
          SELECT COALESCE(SUM(settled_negative_points), 0) AS total
          FROM fund_transactions
          WHERE student_id = ? AND type = 'penalty'
          ''',
          [transaction.studentId],
        );
        final gross = (result.first['total'] as num?)?.toInt() ?? 0;
        final alreadySettled = (paid.first['total'] as num?)?.toInt() ?? 0;
        final outstanding = (gross - alreadySettled).clamp(0, gross).toInt();
        if (transaction.settledNegativePoints > outstanding) {
          throw StateError(
            'النقاط المطلوب تسويتها أكبر من الرصيد السلبي المتبقي ($outstanding)',
          );
        }
      }
      await txn.insert('fund_transactions', transaction.toMap());
    });
  }

  Future<void> upsertFundTransactionsFromSync(
    Iterable<FundTransaction> transactions,
  ) =>
      _batchUpsertMapsById(
        'fund_transactions',
        transactions.map(
          (transaction) => Map<String, dynamic>.from(transaction.toMap()),
        ),
      );

  Future<void> upsertFundTransactionFromSync(
    FundTransaction transaction,
  ) =>
      upsertFundTransactionsFromSync([transaction]);

  Future<List<FundTransaction>> getFundTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('fund_transactions', orderBy: 'date DESC');
    return List.generate(maps.length, (i) => FundTransaction.fromMap(maps[i]));
  }

  Future<List<FundTransaction>> getStudentFundTransactions(String studentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'fund_transactions',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => FundTransaction.fromMap(maps[i]));
  }

  Future<List<FundTransaction>> getStudentFundTransactionsInRange(
    String studentId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final rows = await db.query(
      'fund_transactions',
      where: 'student_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [studentId, _dateKey(startDate), _dateKey(endDate)],
      orderBy: 'date ASC, created_at ASC',
    );
    return rows.map(FundTransaction.fromMap).toList();
  }

  Future<List<FundTransaction>> getFundTransactionsInRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final rows = await db.query(
      'fund_transactions',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [_dateKey(startDate), _dateKey(endDate)],
      orderBy: 'student_id ASC, date ASC, created_at ASC',
    );
    return rows.map(FundTransaction.fromMap).toList();
  }

  Future<int> getOutstandingNegativePoints(String studentId) async {
    final db = await database;
    final negativeRows = await db.rawQuery(
      'SELECT COALESCE(SUM(ABS(points)), 0) AS total '
      'FROM behavior_points WHERE student_id = ? AND points < 0',
      [studentId],
    );
    final settlementRows = await db.rawQuery(
      'SELECT COALESCE(SUM(settled_negative_points), 0) AS total '
      "FROM fund_transactions WHERE student_id = ? AND type = 'penalty'",
      [studentId],
    );
    final negative = (negativeRows.first['total'] as num?)?.toInt() ?? 0;
    final settled = (settlementRows.first['total'] as num?)?.toInt() ?? 0;
    return (negative - settled).clamp(0, negative).toInt();
  }

  Future<double> getFundBalance() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN type IN ('subscription', 'penalty', 'donation') THEN amount ELSE -amount END) as balance
      FROM fund_transactions
    ''');
    return (result.first['balance'] as num?)?.toDouble() ?? 0.0;
  }

  // Plans CRUD
  Future<void> insertSmartPlan(SmartPlan plan) async {
    _validateSmartPlan(plan);
    final db = await database;
    await db.transaction((txn) async {
      final reason = await _smartPlanGateReason(txn, plan.studentId);
      if (reason != null) throw StateError(reason);
      await txn.insert('plans', plan.toMap());
      await _applyPlanAsStudentDefault(txn, plan);
    });
  }

  Future<void> updateSmartPlan(SmartPlan plan) async {
    _validateSmartPlan(plan);
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'plans',
        plan.copyWith(updatedAt: DateTime.now()).toMap(),
        where: 'id = ?',
        whereArgs: [plan.id],
      );
      if (plan.isActive) await _applyPlanAsStudentDefault(txn, plan);
    });
  }

  Future<void> completeSmartPlan(SmartPlan plan) async {
    if (!plan.isActive) return;
    final completed = plan.copyWith(
      status: 'completed',
      testStatus: 'pending',
      completedAt: DateTime.now(),
      clearCompletionExam: true,
    );
    await updateSmartPlan(completed);
  }

  Future<void> approveSmartPlanExam(SmartPlan plan, Exam exam) async {
    if (exam.studentId != plan.studentId || !exam.isPassed) {
      throw StateError('الاختبار المختار ليس اختبارًا ناجحًا لهذا الطالب');
    }
    final earliest = DateTime(
      (plan.completedAt ?? plan.endDate).year,
      (plan.completedAt ?? plan.endDate).month,
      (plan.completedAt ?? plan.endDate).day,
    );
    final examDate = DateTime(exam.date.year, exam.date.month, exam.date.day);
    if (examDate.isBefore(earliest)) {
      throw StateError('يجب أن يكون اختبار التجاوز بعد إكمال الخطة السابقة');
    }
    await updateSmartPlan(
      plan.copyWith(
        status: 'completed',
        testStatus: 'passed',
        completionExamId: exam.id,
      ),
    );
  }

  Future<String?> getSmartPlanGateReason(String studentId) async {
    final db = await database;
    return _smartPlanGateReason(db, studentId);
  }

  Future<Map<String, String?>> getSmartPlanGateReasons(
    Iterable<String> studentIds,
  ) async {
    final ids = studentIds.toSet().toList();
    if (ids.isEmpty) return const <String, String?>{};
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery(
      '''
      SELECT *
      FROM plans
      WHERE student_id IN ($placeholders)
        AND status != 'cancelled'
      ORDER BY student_id ASC, created_at DESC
      ''',
      ids,
    );
    final latestByStudent = <String, SmartPlan>{};
    for (final row in rows) {
      final studentId = row['student_id']?.toString();
      if (studentId == null || latestByStudent.containsKey(studentId)) continue;
      latestByStudent[studentId] = SmartPlan.fromMap(row);
    }
    return {
      for (final id in ids) id: _smartPlanGateReasonForPlan(latestByStudent[id]),
    };
  }

  String? _smartPlanGateReasonForPlan(SmartPlan? latest) {
    if (latest == null) return null;
    if (latest.isActive) {
      return 'للطالب خطة نشطة. أكمل بنودها، اعتمد إكمالها، ثم سجّل اختبار التجاوز قبل إصدار الخطة التالية';
    }
    if (latest.testStatus == 'failed') {
      return 'لم يجتز الطالب اختبار الخطة السابقة. أعد الاختبار وسجّل نتيجة ناجحة قبل إصدار خطة جديدة';
    }
    if (latest.testStatus == 'pending') {
      return 'الخطة السابقة مكتملة وتنتظر اختبار التجاوز. لا تصدر الخطة التالية قبل اعتماد اختبار ناجح';
    }
    return null;
  }

  Future<String?> _smartPlanGateReason(
    DatabaseExecutor executor,
    String studentId,
  ) async {
    final rows = await executor.query(
      'plans',
      where: "student_id = ? AND status != 'cancelled'",
      whereArgs: [studentId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _smartPlanGateReasonForPlan(SmartPlan.fromMap(rows.first));
  }

  Future<void> deleteSmartPlan(SmartPlan plan) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('plans', where: 'id = ?', whereArgs: [plan.id]);
      await _appendDeletedIds(txn, 'deleted_plan_ids', [plan.id]);
    });
  }

  void _validateSmartPlan(SmartPlan plan) {
    if (!const ['weekly', 'monthly'].contains(plan.period) ||
        !const ['ayahs', 'pages', 'lines', 'hizbs'].contains(plan.unit) ||
        !const ['ayahs', 'pages', 'lines', 'hizbs'].contains(plan.reviewUnit) ||
        plan.newAmount < 1 ||
        plan.reviewAmount < 1 ||
        plan.recitationAmount < 1 ||
        plan.endDate.isBefore(plan.startDate)) {
      throw ArgumentError('بيانات الخطة أو مدتها غير صحيحة');
    }
  }

  Future<void> _applyPlanAsStudentDefault(
    DatabaseExecutor executor,
    SmartPlan plan,
  ) async {
    await executor.update(
      'students',
      {
        'plan_type': plan.unit,
        'plan_amount': plan.newAmount,
        'review_plan_amount': plan.reviewAmount,
        'review_plan_type': plan.reviewUnit,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [plan.studentId],
    );
  }

  Future<List<SmartPlan>> getSmartPlans() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('plans', orderBy: 'created_at DESC');
    return List.generate(maps.length, (i) => SmartPlan.fromMap(maps[i]));
  }

  Future<void> upsertSmartPlanFromSync(SmartPlan plan) async {
    final db = await database;
    await db.insert(
      'plans',
      plan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSmartPlanFromSync(String id) async {
    final db = await database;
    await db.delete('plans', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SmartPlan>> getStudentSmartPlans(String studentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'plans',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => SmartPlan.fromMap(maps[i]));
  }

  Future<SmartPlan?> getActiveStudentPlan(String studentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'plans',
      where: 'student_id = ? AND status = ?',
      whereArgs: [studentId, 'active'],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return SmartPlan.fromMap(maps.first);
  }

  // Quran courses CRUD
  Future<List<QuranCourse>> getQuranCourses() async {
    final db = await database;
    final rows = await db.query(
      'quran_courses',
      orderBy: "CASE status WHEN 'active' THEN 0 WHEN 'planned' THEN 1 ELSE 2 END, start_date DESC",
    );
    return rows.map(QuranCourse.fromMap).toList();
  }

  Future<QuranCourse?> getQuranCourse(String id) async {
    final db = await database;
    final rows = await db.query(
      'quran_courses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : QuranCourse.fromMap(rows.first);
  }

  /// يعيد الدورة الفعالة للطالب في يوم دراسي محدد. عند تعدد الدورات
  /// نأخذ الأحدث بدءًا، مع إبقاء نوع المسار شرطًا اختياريًا.
  Future<QuranCourse?> getActiveQuranCourseForStudent(
    String studentId, {
    DateTime? date,
    bool requireMemorization = false,
    bool requireRevision = false,
  }) async {
    final target = date ?? DateTime.now();
    final dateKey = _dateKey(target);
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT c.*
      FROM quran_courses c
      INNER JOIN quran_course_enrollments e ON e.course_id = c.id
      WHERE e.student_id = ?
        AND e.status = 'active'
        AND c.status = 'active'
        AND c.start_date <= ?
        AND c.end_date >= ?
      ORDER BY c.start_date DESC, c.updated_at DESC
      ''',
      [studentId, dateKey, dateKey],
    );
    for (final row in rows) {
      final course = QuranCourse.fromMap(row);
      if (!course.studyWeekdays.contains(target.weekday)) continue;
      if (requireMemorization && !course.includesMemorization) continue;
      if (requireRevision && !course.includesRevision) continue;
      return course;
    }
    return null;
  }

  Future<void> saveQuranCourse(
    QuranCourse course, {
    List<String>? studentIds,
  }) async {
    _validateQuranCourse(course);
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'quran_courses',
        course.copyWith().toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (studentIds != null) {
        final uniqueIds = studentIds.toSet();
        final previousEnrollments = await txn.query(
          'quran_course_enrollments',
          columns: ['id'],
          where: 'course_id = ?',
          whereArgs: [course.id],
        );
        await _appendDeletedIds(
          txn,
          'deleted_quran_course_enrollment_ids',
          previousEnrollments.map((row) => row['id'].toString()).toList(),
        );
        await txn.delete(
          'quran_course_enrollments',
          where: 'course_id = ?',
          whereArgs: [course.id],
        );
        if (uniqueIds.isNotEmpty) {
          final placeholders = List.filled(uniqueIds.length, '?').join(',');
          final activeRows = await txn.rawQuery(
            'SELECT id FROM students WHERE status = ? AND id IN ($placeholders)',
            ['active', ...uniqueIds],
          );
          final activeIds = activeRows.map((row) => row['id'].toString()).toSet();
          if (activeIds.length != uniqueIds.length ||
              !activeIds.containsAll(uniqueIds)) {
            throw StateError('أحد طلاب الدورة غير نشط أو غير موجود');
          }
          final batch = txn.batch();
          for (final studentId in uniqueIds) {
            batch.insert(
              'quran_course_enrollments',
              QuranCourseEnrollment(
                courseId: course.id,
                studentId: studentId,
              ).toMap(),
            );
          }
          await batch.commit(noResult: true);
        }
      }
    });
  }

  Future<void> deleteQuranCourse(String courseId) async {
    final db = await database;
    await db.transaction((txn) async {
      final enrollmentRows = await txn.query(
        'quran_course_enrollments',
        columns: ['id'],
        where: 'course_id = ?',
        whereArgs: [courseId],
      );
      await _appendDeletedIds(
        txn,
        'deleted_quran_course_enrollment_ids',
        enrollmentRows.map((row) => row['id'].toString()).toList(),
      );
      await _appendDeletedIds(
        txn,
        'deleted_quran_course_ids',
        [courseId],
      );
      await txn.delete('quran_courses', where: 'id = ?', whereArgs: [courseId]);
    });
  }

  Future<void> deleteQuranCourseFromSync(String courseId) async {
    final db = await database;
    await db.delete('quran_courses', where: 'id = ?', whereArgs: [courseId]);
  }

  Future<List<QuranCourseEnrollment>> getQuranCourseEnrollments(
    String courseId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'quran_course_enrollments',
      where: 'course_id = ?',
      whereArgs: [courseId],
      orderBy: 'enrolled_at ASC',
    );
    return rows.map(QuranCourseEnrollment.fromMap).toList();
  }

  Future<List<QuranCourseEnrollment>> getAllQuranCourseEnrollments() async {
    final db = await database;
    final rows = await db.query('quran_course_enrollments');
    return rows.map(QuranCourseEnrollment.fromMap).toList();
  }

  Future<void> upsertQuranCoursesFromSync(List<QuranCourse> courses) =>
      _batchUpsertMapsById(
        'quran_courses',
        courses.map((course) => Map<String, dynamic>.from(course.toMap())),
      );

  Future<void> upsertQuranCourseEnrollmentsFromSync(
    List<QuranCourseEnrollment> enrollments,
  ) =>
      _batchUpsertMapsById(
        'quran_course_enrollments',
        enrollments.map(
          (enrollment) => Map<String, dynamic>.from(enrollment.toMap()),
        ),
      );

  Future<void> upsertQuranCourseFromSync(QuranCourse course) =>
      upsertQuranCoursesFromSync([course]);

  Future<void> upsertQuranCourseEnrollmentFromSync(
    QuranCourseEnrollment enrollment,
  ) =>
      upsertQuranCourseEnrollmentsFromSync([enrollment]);

  void _validateQuranCourse(QuranCourse course) {
    const courseTypes = {'memorization', 'revision', 'mixed'};
    const units = {'ayahs', 'lines', 'pages', 'hizbs'};
    const statuses = {'planned', 'active', 'completed', 'cancelled'};
    if (course.title.trim().isEmpty ||
        !courseTypes.contains(course.type) ||
        !units.contains(course.memorizationUnit) ||
        !units.contains(course.revisionUnit) ||
        !statuses.contains(course.status) ||
        (course.includesMemorization && course.memorizationAmount < 1) ||
        (course.includesRevision && course.revisionAmount < 1) ||
        course.endDate.isBefore(course.startDate) ||
        course.studyWeekdays.isEmpty ||
        course.studyWeekdays.any((day) => day < 1 || day > 7)) {
      throw ArgumentError('بيانات دورة الحفظ أو المراجعة غير صحيحة');
    }
  }

  Future<void> savePlanRecitationSession(
    List<PlanRecitationRecord> records,
  ) async {
    if (records.isEmpty) {
      throw ArgumentError('جلسة السرد لا تحتوي على نطاق قرآني');
    }
    final first = records.first;
    final db = await database;
    await db.transaction((txn) async {
      final planRows = await txn.query(
        'plans',
        where: 'id = ?',
        whereArgs: [first.planId],
        limit: 1,
      );
      if (planRows.isEmpty) throw StateError('الخطة المرتبطة غير موجودة');
      final plan = SmartPlan.fromMap(planRows.first);
      if (plan.studentId != first.studentId) {
        throw StateError('الخطة لا تخص الطالب المحدد');
      }
      final sessionDate = _dateKey(first.date);
      if (sessionDate.compareTo(_dateKey(plan.startDate)) < 0 ||
          sessionDate.compareTo(_dateKey(plan.endDate)) > 0) {
        throw StateError('تاريخ السرد يجب أن يكون داخل مدة الخطة');
      }
      final segmentOrders = <int>{};
      for (final record in records) {
        if (record.sessionId != first.sessionId ||
            record.planId != first.planId ||
            record.studentId != first.studentId ||
            _dateKey(record.date) != sessionDate) {
          throw ArgumentError('مقاطع جلسة السرد غير متوافقة');
        }
        if (!segmentOrders.add(record.segmentOrder)) {
          throw ArgumentError('ترتيب مقاطع السرد مكرر');
        }
        _validatePlanRecitationRecord(record);
        await txn.insert('plan_recitation_records', record.toMap());
      }
    });
  }

  Future<List<PlanRecitationRecord>> getPlanRecitationRecords(
    String planId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'plan_recitation_records',
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'date DESC, created_at DESC, segment_order ASC',
    );
    return rows.map(PlanRecitationRecord.fromMap).toList();
  }

  /// سجل السرد المتصل للطالب عبر جميع الخطط؛ تستخدمه الخطة التالية لتبدأ
  /// من موضع التوقف الحقيقي بدل الرجوع إلى أول المصحف.
  Future<List<PlanRecitationRecord>> getStudentPlanRecitationRecords(
    String studentId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'plan_recitation_records',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'date DESC, created_at DESC, segment_order ASC',
    );
    return rows.map(PlanRecitationRecord.fromMap).toList();
  }

  Future<List<PlanRecitationRecord>> getPlanRecitationRecordsInRange({
    required String studentId,
    required String planId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;
    final rows = await db.query(
      'plan_recitation_records',
      where: 'student_id = ? AND plan_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [
        studentId,
        planId,
        _dateKey(startDate),
        _dateKey(endDate),
      ],
      orderBy: 'date ASC, created_at ASC, segment_order ASC',
    );
    return rows.map(PlanRecitationRecord.fromMap).toList();
  }

  Future<List<PlanRecitationRecord>> getAllPlanRecitationRecords() async {
    final db = await database;
    final rows = await db.query('plan_recitation_records');
    return rows.map(PlanRecitationRecord.fromMap).toList();
  }

  Future<void> deletePlanRecitationSession(String sessionId) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'plan_recitation_records',
        columns: ['id'],
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      if (rows.isEmpty) return;
      await txn.delete(
        'plan_recitation_records',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      await _appendDeletedIds(
        txn,
        'deleted_plan_recitation_record_ids',
        rows.map((row) => row['id'].toString()).toList(),
      );
    });
  }

  Future<void> upsertPlanRecitationRecordFromSync(
    PlanRecitationRecord record,
  ) async {
    _validatePlanRecitationRecord(record);
    final db = await database;
    await db.insert(
      'plan_recitation_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deletePlanRecitationRecordFromSync(String id) async {
    final db = await database;
    await db.delete(
      'plan_recitation_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  void _validatePlanRecitationRecord(PlanRecitationRecord record) {
    final surah = QuranService.instance.getSurah(record.surahId);
    if (surah == null ||
        record.fromAyah < 1 ||
        record.toAyah < record.fromAyah ||
        record.toAyah > surah.totalAyahs ||
        record.segmentOrder < 0 ||
        record.qualityRating < 1 ||
        record.qualityRating > 5) {
      throw ArgumentError('بيانات نطاق السرد أو تقييمه غير صحيحة');
    }
  }

  // Notifications CRUD
  Future<void> insertNotification(NotificationLog notification) async {
    final db = await database;
    await db.insert('notifications', notification.toMap());
  }

  Future<void> upsertNotificationsFromSync(
    Iterable<NotificationLog> notifications,
  ) =>
      _batchUpsertMapsById(
        'notifications',
        notifications.map(
          (notification) => Map<String, dynamic>.from(notification.toMap()),
        ),
      );

  Future<void> upsertNotificationFromSync(NotificationLog notification) =>
      upsertNotificationsFromSync([notification]);

  /// Adds one durable notification when a surah first becomes complete.
  /// The unique student/surah title check keeps direct entry and a recitation
  /// session from producing duplicate notices for the same achievement.
  Future<bool> ensureSurahCompletionNotification({
    required Student student,
    required String surahName,
  }) async {
    final db = await database;
    final title = 'اكتملت سورة $surahName';
    final existing = await db.query(
      'notifications',
      columns: ['id'],
      where: 'student_id = ? AND type = ? AND title = ?',
      whereArgs: [student.id, 'surah_completed', title],
      limit: 1,
    );
    if (existing.isNotEmpty) return false;
    await db.insert(
      'notifications',
      NotificationLog(
        studentId: student.id,
        type: 'surah_completed',
        title: title,
        body: 'أتم ${student.name} حفظ سورة $surahName، '
            'وأُدرجت السورة تلقائيًا ضمن المراجعة المستحقة.',
      ).toMap(),
    );
    return true;
  }

  Future<void> generateNotifications() async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = _dateKey(today);
    final settings = await getSettings();
    if (!_isPastClassEndTime(settings, now)) return;

    final suspended = (await getSuspendedDates()).toSet();
    if (suspended.contains(todayStr)) return;

    // هذه العملية قد تعمل عند فتح التطبيق. نقرأ نافذة 60 يومًا مرة واحدة
    // بدل تنفيذ استعلامات متكررة لكل طالب ولكل يوم.
    final rangeStart = today.subtract(const Duration(days: 59));
    final threeDaysAgo = today.subtract(const Duration(days: 3));
    final values = await Future.wait<dynamic>([
      getStudents(status: 'active'),
      getDailyRecordsInRange(rangeStart, today),
      getAllStudentHoldsInRange(rangeStart, today),
      db.query(
        'notifications',
        columns: ['student_id', 'type', 'created_at'],
        where: 'created_at >= ? OR type = ?',
        whereArgs: [threeDaysAgo.toIso8601String(), 'student_expelled'],
      ),
    ]);
    final students = values[0] as List<Student>;
    final records = values[1] as List<DailyRecord>;
    final holds = values[2] as List<StudentHold>;
    final notificationRows = List<Map<String, dynamic>>.from(values[3] as List);

    final recordsByStudentDate = <String, DailyRecord>{};
    for (final record in records) {
      recordsByStudentDate['${record.studentId}|${_dateKey(record.date)}'] = record;
    }
    final holdsByStudent = <String, List<StudentHold>>{};
    for (final hold in holds) {
      holdsByStudent.putIfAbsent(hold.studentId, () => <StudentHold>[]).add(hold);
    }

    bool hasNotification(String studentId, String type, {int withinDays = 0}) {
      return notificationRows.any((row) {
        if (row['student_id']?.toString() != studentId || row['type'] != type) {
          return false;
        }
        if (type == 'student_expelled') return true;
        final created = DateTime.tryParse(row['created_at']?.toString() ?? '');
        if (created == null) return false;
        final threshold = withinDays <= 0 ? today : today.subtract(Duration(days: withinDays));
        return !DateTime(created.year, created.month, created.day).isBefore(threshold);
      });
    }

    StudentHold? holdAt(String studentId, DateTime date) {
      for (final hold in holdsByStudent[studentId] ?? const <StudentHold>[]) {
        if (hold.isActiveAt(date)) return hold;
      }
      return null;
    }

    int consecutiveAbsences(String studentId) {
      var date = today;
      var count = 0;
      for (var checked = 0; checked < 60; checked++) {
        final key = _dateKey(date);
        if (settings.isHolidayWeekday(date) || suspended.contains(key)) {
          date = date.subtract(const Duration(days: 1));
          continue;
        }
        final hold = holdAt(studentId, date);
        if (hold?.exemptsAttendance == true) {
          date = date.subtract(const Duration(days: 1));
          continue;
        }
        final record = recordsByStudentDate['$studentId|$key'];
        if (record?.attendance == 'absent') {
          count++;
          date = date.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
      return count;
    }

    int consecutiveNoRecitation(String studentId) {
      var date = today;
      var count = 0;
      for (var checked = 0; checked < 60; checked++) {
        final key = _dateKey(date);
        if (settings.isHolidayWeekday(date) || suspended.contains(key)) {
          date = date.subtract(const Duration(days: 1));
          continue;
        }
        if (holdAt(studentId, date) != null) break;
        final record = recordsByStudentDate['$studentId|$key'];
        if (record == null || record.attendance == 'excused') break;
        if (record.recitationExempt || record.talaqqinDone) break;
        final didNotRecite = record.attendance == 'absent' ||
            ((record.attendance == 'present' || record.attendance == 'late') &&
                !record.memorizationDone &&
                !record.revisionDone);
        if (!didNotRecite) break;
        count++;
        date = date.subtract(const Duration(days: 1));
      }
      return count;
    }

    for (final student in students) {
      final todayRecord = recordsByStudentDate['${student.id}|$todayStr'];
      if (todayRecord != null) {
        if (todayRecord.attendance == 'absent' &&
            !hasNotification(student.id, 'repeated_absence')) {
          await insertNotification(NotificationLog(
            studentId: student.id,
            type: 'repeated_absence',
            title: 'غياب اليوم ⚠️',
            body: 'الطالب ${student.name} غائب اليوم عن الحلقة.',
          ));
        } else if (holdAt(student.id, today) == null &&
            (todayRecord.attendance == 'present' ||
                todayRecord.attendance == 'late') &&
            !todayRecord.memorizationDone &&
            !todayRecord.revisionDone &&
            !todayRecord.talaqqinDone &&
            !todayRecord.recitationExempt &&
            !hasNotification(student.id, 'low_performance')) {
          await insertNotification(NotificationLog(
            studentId: student.id,
            type: 'low_performance',
            title: 'لم يسمّع اليوم ⚠️',
            body: 'حضر الطالب ${student.name} اليوم ولكنه لم يكمل أي تسميع للحفظ أو المراجعة.',
          ));
        }
      }

      final noRecitationDays = consecutiveNoRecitation(student.id);
      if (noRecitationDays >= 2 &&
          !hasNotification(student.id, 'consecutive_no_recitation')) {
        await insertNotification(NotificationLog(
          studentId: student.id,
          type: 'consecutive_no_recitation',
          title: 'تذكير تسميع متتالٍ ⚠️',
          body: 'الطالب ${student.name} لم يسمّع في '
              '$noRecitationDays أيام دراسية متتالية.',
        ));
      }

      final consecutiveAbsenceDays = consecutiveAbsences(student.id);
      if (consecutiveAbsenceDays >= settings.absenceDaysBeforeWarning &&
          !hasNotification(student.id, 'dismissal_warning', withinDays: 3)) {
        await insertNotification(NotificationLog(
          studentId: student.id,
          type: 'dismissal_warning',
          title: 'تحذير غياب متكرر ⚠️',
          body: 'الطالب ${student.name} غائب لـ '
              '$consecutiveAbsenceDays أيام متتالية.',
        ));
      }

      if (settings.autoExpulsionEnabled &&
          consecutiveAbsenceDays >= settings.absenceDaysBeforeExpulsion) {
        final updated = await db.update(
          'students',
          {'status': 'expelled', 'updated_at': now.toIso8601String()},
          where: 'id = ? AND status = ?',
          whereArgs: [student.id, 'active'],
        );
        if (updated > 0) {
          await db.insert(
            'student_status_history',
            StudentStatusChange(
              studentId: student.id,
              previousStatus: 'active',
              newStatus: 'expelled',
              reason: 'فصل تلقائي بعد تجاوز حد الغياب',
              notes: '$consecutiveAbsenceDays أيام دراسية متتالية',
              changedAt: now,
            ).toMap(),
          );
        }
        if (!hasNotification(student.id, 'student_expelled')) {
          await insertNotification(NotificationLog(
            studentId: student.id,
            type: 'student_expelled',
            title: 'تم فصل الطالب مؤقتًا',
            body: 'بلغ غياب ${student.name} $consecutiveAbsenceDays أيام دراسية '
                'متتالية، فتم نقله إلى قائمة المفصولين حسب الإعدادات.',
          ));
        }
      }
    }
  }

  bool _isPastClassEndTime(HalaqahSettings settings, DateTime now) {
    final value = settings.currentEndTime.split(':');
    if (value.length < 2) return true;
    final hour = int.tryParse(value[0]) ?? 0;
    final minute = int.tryParse(value[1]) ?? 0;
    final end = DateTime(now.year, now.month, now.day, hour, minute);
    return !now.isBefore(end);
  }

  Future<List<NotificationLog>> getNotifications() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('notifications', orderBy: 'created_at DESC');
    return List.generate(maps.length, (i) => NotificationLog.fromMap(maps[i]));
  }

  Future<List<NotificationLog>> getStudentNotifications(String studentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notifications',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => NotificationLog.fromMap(maps[i]));
  }

  Future<void> markNotificationAsRead(String id) async {
    final db = await database;
    await db.update(
      'notifications',
      {'read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllNotificationsAsRead() async {
    final db = await database;
    await db.update(
      'notifications',
      {'read': 1},
      where: 'read = ?',
      whereArgs: [0],
    );
  }

  Future<int> getUnreadNotificationsCount() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM notifications WHERE read = 0
    ''');
    return (result.first['count'] as int?) ?? 0;
  }

  // HomeworkGrade CRUD methods
  Future<void> insertHomeworkGrade(HomeworkGrade grade) async {
    final db = await database;
    await db.insert('homework_grades', grade.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<HomeworkGrade>> getStudentHomeworkGrades(String studentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'homework_grades',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'date DESC, created_at DESC',
    );
    return List.generate(maps.length, (i) => HomeworkGrade.fromMap(maps[i]));
  }

  Future<void> deleteHomeworkGrade(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('homework_grades', where: 'id = ?', whereArgs: [id]);
      await _appendDeletedIds(txn, 'deleted_homework_grade_ids', [id]);
    });
  }

  Future<String?> deleteMemorizationProgressFromSync(String id) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'memorization_progress',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final original = MemorizationProgress.fromMap(rows.first);
      final previousTrackedCount = await _countTrackedMemorized(
        txn,
        original.studentId,
      );
      await txn.delete(
        'memorization_progress',
        where: 'id = ?',
        whereArgs: [id],
      );
      await _recomputeRecitationState(txn, original.studentId, original.date);
      await _recomputeStudentMemorizedTotal(
        txn,
        original.studentId,
        previousTrackedCount: previousTrackedCount,
      );
      return original.studentId;
    });
  }

  Future<void> upsertMemorizationProgressFromSync(
    MemorizationProgress progress,
  ) async {
    _validateMemorizationRange(progress);
    final db = await database;
    await db.transaction((txn) async {
      final existingRows = await txn.query(
        'memorization_progress',
        where: 'id = ?',
        whereArgs: [progress.id],
        limit: 1,
      );
      final existing = existingRows.isEmpty
          ? null
          : MemorizationProgress.fromMap(existingRows.first);
      final previousTrackedCount = await _countTrackedMemorized(
        txn,
        progress.studentId,
      );
      await txn.insert(
        'memorization_progress',
        progress.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (existing != null && _dateKey(existing.date) != _dateKey(progress.date)) {
        await _recomputeRecitationState(
          txn,
          existing.studentId,
          existing.date,
        );
      }
      await _recomputeRecitationState(txn, progress.studentId, progress.date);
      await _recomputeStudentMemorizedTotal(
        txn,
        progress.studentId,
        previousTrackedCount: previousTrackedCount,
      );
    });
  }

  // MushafProgress CRUD methods
  Future<void> insertOrUpdateMushafProgress(MushafProgress progress) async {
    final db = await database;
    await db.insert(
      'mushaf_progress',
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MushafProgress>> getStudentMushafProgress(String studentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'mushaf_progress',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
    return List.generate(maps.length, (i) => MushafProgress.fromMap(maps[i]));
  }

  Future<void> clearStudentMushafProgress(String studentId) async {
    final db = await database;
    await db.delete('mushaf_progress', where: 'student_id = ?', whereArgs: [studentId]);
  }

  Future<void> clearStudentGradedMushafProgress(String studentId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'mushaf_progress',
        where: 'student_id = ? AND is_pre_memorized = 0',
        whereArgs: [studentId],
      );
      await txn.update(
        'mushaf_progress',
        {'average_grade': 0.0, 'last_graded_date': null},
        where: 'student_id = ? AND is_pre_memorized = 1',
        whereArgs: [studentId],
      );
    });
  }

  Future<void> clearPreMemorizedProgress(String studentId) async {
    final db = await database;
    await db.delete(
      'mushaf_progress',
      where: 'student_id = ? AND is_pre_memorized = 1',
      whereArgs: [studentId],
    );
  }

  // MessageTemplate CRUD methods
  Future<MessageTemplate?> getMessageTemplate(String type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'message_templates',
      where: 'type = ?',
      whereArgs: [type],
    );
    if (maps.isEmpty) return null;
    return MessageTemplate.fromMap(maps.first);
  }

  Future<void> saveMessageTemplate(MessageTemplate template) async {
    final db = await database;
    await db.insert(
      'message_templates',
      template.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<HomeworkGrade>> getAllHomeworkGrades() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('homework_grades');
    return List.generate(maps.length, (i) => HomeworkGrade.fromMap(maps[i]));
  }

  Future<List<DailyRecord>> getAllDailyRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('daily_records');
    return List.generate(maps.length, (i) => DailyRecord.fromMap(maps[i]));
  }

  Future<List<MushafProgress>> getAllMushafProgress() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('mushaf_progress');
    return List.generate(maps.length, (i) => MushafProgress.fromMap(maps[i]));
  }

  Future<List<MemorizationProgress>> getAllMemorizationProgress() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('memorization_progress');
    return List.generate(maps.length, (i) => MemorizationProgress.fromMap(maps[i]));
  }

  Future<List<BehaviorPoint>> getAllBehaviorPoints() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('behavior_points');
    return List.generate(maps.length, (i) => BehaviorPoint.fromMap(maps[i]));
  }

  Future<List<BehaviorPointCorrection>> getAllBehaviorPointCorrections() async {
    final db = await database;
    final maps = await db.query('behavior_point_corrections');
    return maps.map(BehaviorPointCorrection.fromMap).toList();
  }

  Future<List<DailyAchievement>> getAllDailyAchievements() async {
    final db = await database;
    final maps = await db.query('daily_achievements');
    return maps.map(DailyAchievement.fromMap).toList();
  }

  Future<void> upsertDailyAchievementsFromSync(
    Iterable<DailyAchievement> achievements,
  ) async {
    final pending = achievements.toList(growable: false);
    if (pending.isEmpty) return;
    for (final achievement in pending) {
      _validateDailyAchievement(achievement);
    }

    final db = await database;
    await db.transaction((txn) async {
      final existingRows = await txn.query('daily_achievements');
      final existingByKey = <String, DailyAchievement>{
        for (final row in existingRows)
          '${row['student_id']}|${row['date']}':
              DailyAchievement.fromMap(row),
      };
      final batch = txn.batch();
      for (final achievement in pending) {
        final key =
            '${achievement.studentId}|${_dateKey(achievement.date)}';
        final existing = existingByKey[key];
        if (existing != null &&
            !achievement.updatedAt.isAfter(existing.updatedAt)) {
          continue;
        }
        final merged = existing == null
            ? achievement
            : DailyAchievement(
                id: existing.id,
                studentId: achievement.studentId,
                date: achievement.date,
                source: achievement.source,
                reason: achievement.reason,
                actualAmount: achievement.actualAmount,
                planAmount: achievement.planAmount,
                unit: achievement.unit,
                rewardType: achievement.rewardType,
                rewardDetails: achievement.rewardDetails,
                rewardPoints: achievement.rewardPoints,
                awardedAt: achievement.awardedAt,
                notes: achievement.notes,
                createdAt: existing.createdAt,
                updatedAt: achievement.updatedAt,
              );
        if (existing == null) {
          batch.insert('daily_achievements', merged.toMap());
        } else {
          batch.update(
            'daily_achievements',
            merged.toMap(),
            where: 'id = ?',
            whereArgs: [existing.id],
          );
        }
        existingByKey[key] = merged;
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertDailyAchievementFromSync(
    DailyAchievement achievement,
  ) =>
      upsertDailyAchievementsFromSync([achievement]);

  Future<List<Exam>> getAllExams() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('exams');
    return List.generate(maps.length, (i) => Exam.fromMap(maps[i]));
  }

  Future<void> initializeMushafProgress(String studentId, int initialJuzCount, String direction) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      
      // Determine which Hizbs are pre-memorized
      Set<int> preMemorizedHizbs = {};
      if (direction == 'desc') {
        for (int i = 0; i < initialJuzCount; i++) {
          final juz = 30 - i;
          preMemorizedHizbs.add((juz - 1) * 2 + 1);
          preMemorizedHizbs.add((juz - 1) * 2 + 2);
        }
      } else {
        for (int i = 0; i < initialJuzCount; i++) {
          final juz = i + 1;
          preMemorizedHizbs.add((juz - 1) * 2 + 1);
          preMemorizedHizbs.add((juz - 1) * 2 + 2);
        }
      }
      
      // We also import uuid packages if needed. Let's generate a UUID.
      // Since Uuid() is imported or package is available, we can construct Uuid().v4()
      for (final hizb in preMemorizedHizbs) {
        for (int thumun = 1; thumun <= 8; thumun++) {
          batch.insert(
            'mushaf_progress',
            {
              'id': '${studentId}_${hizb}_${thumun}', // Deterministic ID is even better for UNIQUE constraint
              'student_id': studentId,
              'hizb_number': hizb,
              'thumun_number': thumun,
              'average_grade': 0.0,
              'last_graded_date': null,
              'is_pre_memorized': 1,
            },
            // Do not replace a graded thumun with an empty pre-memorized row.
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
      
      await batch.commit(noResult: true);
    });
  }

  Future<void> initializeMushafProgressForRange(
    String studentId,
    int startSurahId,
    int startAyah,
    int endSurahId,
    int endAyah,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      
      final uniqueThumuns = <String>{}; // Format: "hizb_thumun"
      
      final start = startSurahId;
      final end = endSurahId;
      
      if (start == end) {
        final surah = QuranService.instance.getSurah(start);
        if (surah != null && endAyah >= startAyah) {
          final ayahs = surah.getAyahRange(startAyah, endAyah);
          for (final ayah in ayahs) {
            final hizb = ayah.hizb;
            final quarter = ayah.quarter;
            if (hizb >= 1 && hizb <= 60 && quarter >= 1 && quarter <= 240) {
              final quarterInHizb = ((quarter - 1) % 4) + 1;
              final thumun1 = (quarterInHizb - 1) * 2 + 1;
              final thumun2 = (quarterInHizb - 1) * 2 + 2;
              uniqueThumuns.add('${hizb}_$thumun1');
              uniqueThumuns.add('${hizb}_$thumun2');
            }
          }
        }
      } else if (start > end) {
        // Descending (e.g. 114 down to 112)
        // Start Surah (from startAyah to totalAyahs)
        final startSurahObj = QuranService.instance.getSurah(start);
        if (startSurahObj != null) {
          final total = startSurahObj.totalAyahs;
          if (total >= startAyah) {
            final ayahs = startSurahObj.getAyahRange(startAyah, total);
            for (final ayah in ayahs) {
              final hizb = ayah.hizb;
              final quarter = ayah.quarter;
              if (hizb >= 1 && hizb <= 60 && quarter >= 1 && quarter <= 240) {
                final quarterInHizb = ((quarter - 1) % 4) + 1;
                final thumun1 = (quarterInHizb - 1) * 2 + 1;
                final thumun2 = (quarterInHizb - 1) * 2 + 2;
                uniqueThumuns.add('${hizb}_$thumun1');
                uniqueThumuns.add('${hizb}_$thumun2');
              }
            }
          }
        }
        
        // Full Surahs in between (end + 1 to start - 1)
        for (int i = end + 1; i <= start - 1; i++) {
          final surah = QuranService.instance.getSurah(i);
          if (surah == null) continue;
          for (final ayah in surah.ayahs) {
            final hizb = ayah.hizb;
            final quarter = ayah.quarter;
            if (hizb >= 1 && hizb <= 60 && quarter >= 1 && quarter <= 240) {
              final quarterInHizb = ((quarter - 1) % 4) + 1;
              final thumun1 = (quarterInHizb - 1) * 2 + 1;
              final thumun2 = (quarterInHizb - 1) * 2 + 2;
              uniqueThumuns.add('${hizb}_$thumun1');
              uniqueThumuns.add('${hizb}_$thumun2');
            }
          }
        }
        
        // End Surah (from 1 to endAyah)
        final endSurahObj = QuranService.instance.getSurah(end);
        if (endSurahObj != null) {
          final ayahs = endSurahObj.getAyahRange(1, endAyah);
          for (final ayah in ayahs) {
            final hizb = ayah.hizb;
            final quarter = ayah.quarter;
            if (hizb >= 1 && hizb <= 60 && quarter >= 1 && quarter <= 240) {
              final quarterInHizb = ((quarter - 1) % 4) + 1;
              final thumun1 = (quarterInHizb - 1) * 2 + 1;
              final thumun2 = (quarterInHizb - 1) * 2 + 2;
              uniqueThumuns.add('${hizb}_$thumun1');
              uniqueThumuns.add('${hizb}_$thumun2');
            }
          }
        }
      } else {
        // Ascending (e.g. 2 up to 5)
        // Start Surah (from startAyah to totalAyahs)
        final startSurahObj = QuranService.instance.getSurah(start);
        if (startSurahObj != null) {
          final total = startSurahObj.totalAyahs;
          if (total >= startAyah) {
            final ayahs = startSurahObj.getAyahRange(startAyah, total);
            for (final ayah in ayahs) {
              final hizb = ayah.hizb;
              final quarter = ayah.quarter;
              if (hizb >= 1 && hizb <= 60 && quarter >= 1 && quarter <= 240) {
                final quarterInHizb = ((quarter - 1) % 4) + 1;
                final thumun1 = (quarterInHizb - 1) * 2 + 1;
                final thumun2 = (quarterInHizb - 1) * 2 + 2;
                uniqueThumuns.add('${hizb}_$thumun1');
                uniqueThumuns.add('${hizb}_$thumun2');
              }
            }
          }
        }
        
        // Full Surahs in between (start + 1 to end - 1)
        for (int i = start + 1; i <= end - 1; i++) {
          final surah = QuranService.instance.getSurah(i);
          if (surah == null) continue;
          for (final ayah in surah.ayahs) {
            final hizb = ayah.hizb;
            final quarter = ayah.quarter;
            if (hizb >= 1 && hizb <= 60 && quarter >= 1 && quarter <= 240) {
              final quarterInHizb = ((quarter - 1) % 4) + 1;
              final thumun1 = (quarterInHizb - 1) * 2 + 1;
              final thumun2 = (quarterInHizb - 1) * 2 + 2;
              uniqueThumuns.add('${hizb}_$thumun1');
              uniqueThumuns.add('${hizb}_$thumun2');
            }
          }
        }
        
        // End Surah (from 1 to endAyah)
        final endSurahObj = QuranService.instance.getSurah(end);
        if (endSurahObj != null) {
          final ayahs = endSurahObj.getAyahRange(1, endAyah);
          for (final ayah in ayahs) {
            final hizb = ayah.hizb;
            final quarter = ayah.quarter;
            if (hizb >= 1 && hizb <= 60 && quarter >= 1 && quarter <= 240) {
              final quarterInHizb = ((quarter - 1) % 4) + 1;
              final thumun1 = (quarterInHizb - 1) * 2 + 1;
              final thumun2 = (quarterInHizb - 1) * 2 + 2;
              uniqueThumuns.add('${hizb}_$thumun1');
              uniqueThumuns.add('${hizb}_$thumun2');
            }
          }
        }
      }
      
      for (final key in uniqueThumuns) {
        final parts = key.split('_');
        final hizb = int.parse(parts[0]);
        final thumun = int.parse(parts[1]);
        
        batch.insert(
          'mushaf_progress',
          {
            'id': '${studentId}_${hizb}_${thumun}',
            'student_id': studentId,
            'hizb_number': hizb,
            'thumun_number': thumun,
            'average_grade': 0.0,
            'last_graded_date': null,
            'is_pre_memorized': 1,
          },
          // Preserve an existing graded entry while filling missing map cells.
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      
      await batch.commit(noResult: true);
    });
  }

  Future<List<String>> getSuspendedDates() async {
    final val = await getSetting('suspended_dates');
    if (val == null || val.trim().isEmpty) return [];
    return val.split(',');
  }

  Future<void> saveSuspendedDates(List<String> dates) async {
    await saveSetting('suspended_dates', dates.join(','));
  }

  Future<void> replaceStudySuspensions(Map<String, String> reasonsByDate) async {
    final dates = reasonsByDate.keys.toList()..sort();
    await saveSetting('suspended_dates', dates.join(','));
    final encoded = dates
        .map((date) => '$date=${reasonsByDate[date] ?? ''}')
        .join(';');
    await saveSetting('suspension_reasons', encoded);
  }

  Future<bool> isDateSuspended(DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final dates = await getSuspendedDates();
    if (dates.contains(dateStr)) return true;
    // أيام العطلة الأسبوعية (مثل الجمعة) تُعتبر معطّلة تلقائياً
    final settings = await getSettings();
    return settings.isHolidayWeekday(date);
  }

  // أسباب/ملاحظات تعليق الدراسة: تُخزَّن كأزواج "تاريخ=السبب" مفصولة بفاصلة منقوطة
  Future<Map<String, String>> getSuspensionReasons() async {
    final val = await getSetting('suspension_reasons');
    if (val == null || val.trim().isEmpty) return {};
    final map = <String, String>{};
    for (final entry in val.split(';')) {
      final idx = entry.indexOf('=');
      if (idx > 0) {
        map[entry.substring(0, idx)] = entry.substring(idx + 1);
      }
    }
    return map;
  }

  Future<void> setSuspensionReason(String dateStr, String? reason) async {
    final map = await getSuspensionReasons();
    if (reason == null || reason.trim().isEmpty) {
      map.remove(dateStr);
    } else {
      map[dateStr] = reason.trim().replaceAll(';', ' ').replaceAll('=', ' ');
    }
    final encoded = map.entries.map((e) => '${e.key}=${e.value}').join(';');
    await saveSetting('suspension_reasons', encoded);
  }

  /// Applies or removes an exceptional study suspension atomically.
  ///
  /// When a teacher marks a past day as suspended after daily closing has
  /// already created absences/penalties, only records that are provably
  /// system-generated are rolled back. Manual attendance and manual points are
  /// never deleted. Tombstones are queued so the same rollback reaches cloud.
  Future<Map<String, int>> setStudySuspension({
    required DateTime date,
    required bool suspended,
    String? reason,
  }) async {
    final db = await database;
    final dateStr = _dateKey(date);
    var deletedAttendance = 0;
    var deletedPoints = 0;

    await db.transaction((txn) async {
      Future<String?> readSetting(String key) async {
        final rows = await txn.query(
          'settings',
          columns: ['value'],
          where: 'key = ?',
          whereArgs: [key],
          limit: 1,
        );
        return rows.isEmpty ? null : rows.first['value']?.toString();
      }

      Future<void> writeSetting(String key, String value) => txn.insert(
            'settings',
            {'key': key, 'value': value},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

      final suspendedDates = (await readSetting('suspended_dates') ?? '')
          .split(',')
          .where((item) => item.trim().isNotEmpty)
          .toSet();
      final reasons = <String, String>{};
      for (final entry in (await readSetting('suspension_reasons') ?? '').split(';')) {
        final index = entry.indexOf('=');
        if (index > 0) reasons[entry.substring(0, index)] = entry.substring(index + 1);
      }

      if (suspended) {
        suspendedDates.add(dateStr);
        final safeReason = (reason ?? '').trim().replaceAll(';', ' ').replaceAll('=', ' ');
        if (safeReason.isNotEmpty) reasons[dateStr] = safeReason;

        final autoAttendanceRows = await txn.query(
          'daily_records',
          columns: ['student_id'],
          where: '''date = ? AND attendance = 'absent' AND (
            notes IN (?, ?) OR absence_note IN (?, ?)
          )''',
          whereArgs: [
            dateStr,
            'أُنشئ عند الإغلاق التلقائي لليوم السابق',
            'أُنشئ تلقائيًا عند إغلاق اليوم',
            'سجل تلقائي بعد انتهاء اليوم دون إغلاق يدوي',
            'سجل تلقائي بعد مراجعة المعلم وإغلاق اليوم',
          ],
        );
        final attendanceKeys = autoAttendanceRows
            .map((row) => '${row['student_id']}|$dateStr')
            .toList(growable: false);
        deletedAttendance = await txn.delete(
          'daily_records',
          where: '''date = ? AND attendance = 'absent' AND (
            notes IN (?, ?) OR absence_note IN (?, ?)
          )''',
          whereArgs: [
            dateStr,
            'أُنشئ عند الإغلاق التلقائي لليوم السابق',
            'أُنشئ تلقائيًا عند إغلاق اليوم',
            'سجل تلقائي بعد انتهاء اليوم دون إغلاق يدوي',
            'سجل تلقائي بعد مراجعة المعلم وإغلاق اليوم',
          ],
        );
        if (attendanceKeys.isNotEmpty) {
          await _appendDeletedIds(txn, 'deleted_attendance_keys', attendanceKeys);
        }

        final autoPointRows = await txn.query(
          'behavior_points',
          columns: ['id'],
          where: '''date = ? AND reason IN (?, ?) AND (
            notes LIKE '%تلقائي%' OR notes LIKE '%إغلاق%'
          )''',
          whereArgs: [
            dateStr,
            'غياب بدون عذر (تلقائي)',
            'عدم التسميع (تلقائي)',
          ],
        );
        final pointIds = autoPointRows
            .map((row) => row['id']?.toString())
            .whereType<String>()
            .toList(growable: false);
        deletedPoints = await txn.delete(
          'behavior_points',
          where: '''date = ? AND reason IN (?, ?) AND (
            notes LIKE '%تلقائي%' OR notes LIKE '%إغلاق%'
          )''',
          whereArgs: [
            dateStr,
            'غياب بدون عذر (تلقائي)',
            'عدم التسميع (تلقائي)',
          ],
        );
        if (pointIds.isNotEmpty) {
          await _appendDeletedIds(txn, 'deleted_behavior_point_ids', pointIds);
        }

        await txn.delete(
          'settings',
          where: 'key IN (?, ?)',
          whereArgs: [
            'daily_operations_closed_$dateStr',
            'daily_operations_close_mode_$dateStr',
          ],
        );
      } else {
        suspendedDates.remove(dateStr);
        reasons.remove(dateStr);
        await _appendDeletedIds(txn, 'deleted_suspension_dates', [dateStr]);
      }

      final orderedSuspendedDates = suspendedDates.toList()..sort();
      await writeSetting('suspended_dates', orderedSuspendedDates.join(','));
      final encodedReasons = reasons.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join(';');
      await writeSetting('suspension_reasons', encodedReasons);
    });

    return {
      'deleted_attendance': deletedAttendance,
      'deleted_points': deletedPoints,
    };
  }

  /// احتساب النقاط السلبية التلقائية لتاريخ معيّن (افتراضياً اليوم) دون تدخل المعلم.
  /// - الغياب بدون عذر: عقوبة الغياب.
  /// - الحضور دون تسميع ولا مراجعة: عقوبة عدم إتمام المقرر.
  /// الدالة idempotent: لا تكرر إضافة نقاط لنفس السبب ونفس التاريخ.
  /// لا تُحتسب نقاط في الأيام المعطّلة (عطلة). يمرر [isHoliday] من طبقة الأعلى.
  Future<int> applyAutomaticNegativePoints({
    DateTime? date,
    bool isHoliday = false,
  }) async {
    if (isHoliday) return 0;
    final db = await database;
    final targetDate = date ?? DateTime.now();
    final dateStr = _dateKey(targetDate);
    final settings = await getSettings();
    final absencePenalty = settings.pointsConfig['unexcused_absence'] ?? -5;
    final incompletePenalty = settings.pointsConfig['incomplete_penalty'] ?? -3;

    const absenceReason = 'غياب بدون عذر (تلقائي)';
    const incompleteReason = 'عدم التسميع (تلقائي)';
    final results = await Future.wait<dynamic>([
      getDailyRecordsForDate(targetDate),
      getActiveStudentHolds(date: targetDate),
    ]);
    final records = results[0] as List<DailyRecord>;
    final holds = results[1] as List<StudentHold>;
    final holdByStudent = {for (final hold in holds) hold.studentId: hold};
    var changes = 0;

    await db.transaction((txn) async {
      for (final record in records) {
        final hold = holdByStudent[record.studentId];
        final shouldHaveAbsencePenalty =
            record.attendance == 'absent' && hold?.exemptsAttendance != true;
        final shouldHaveIncompletePenalty =
            (record.attendance == 'present' || record.attendance == 'late') &&
            !record.memorizationDone &&
            !record.revisionDone &&
            !record.talaqqinDone &&
            !record.recitationExempt &&
            hold == null;

        Future<void> reconcilePenalty({
          required String reason,
          required int points,
          required bool requiredNow,
        }) async {
          final rows = await txn.query(
            'behavior_points',
            where: 'student_id = ? AND date = ? AND reason = ?',
            whereArgs: [record.studentId, dateStr, reason],
            orderBy: 'created_at ASC',
          );
          if (!requiredNow) {
            if (rows.isEmpty) return;
            final ids = rows
                .map((row) => row['id']?.toString())
                .whereType<String>()
                .toList();
            await txn.delete(
              'behavior_points',
              where: 'student_id = ? AND date = ? AND reason = ?',
              whereArgs: [record.studentId, dateStr, reason],
            );
            await _appendDeletedIds(txn, 'deleted_behavior_point_ids', ids);
            changes += rows.length;
            return;
          }

          if (rows.isEmpty) {
            await txn.insert(
              'behavior_points',
              BehaviorPoint(
                studentId: record.studentId,
                type: 'negative',
                reason: reason,
                points: points,
                date: targetDate,
                resolved: true,
                notes: 'احتساب تلقائي عند إغلاق اليوم',
              ).toMap(),
            );
            changes++;
            return;
          }

          // Historical automatic penalties are frozen at the value that was
          // active when the day was closed. Changing point rules later must not
          // rewrite old results; only stale/duplicate automatic rows are removed.
          for (final duplicate in rows.skip(1)) {
            final duplicateId = duplicate['id']?.toString();
            await txn.delete(
              'behavior_points',
              where: 'id = ?',
              whereArgs: [duplicateId],
            );
            if (duplicateId != null) {
              await _appendDeletedIds(
                txn,
                'deleted_behavior_point_ids',
                [duplicateId],
              );
            }
            changes++;
          }
        }

        await reconcilePenalty(
          reason: absenceReason,
          points: absencePenalty,
          requiredNow: shouldHaveAbsencePenalty,
        );
        await reconcilePenalty(
          reason: incompleteReason,
          points: incompletePenalty,
          requiredNow: shouldHaveIncompletePenalty,
        );
      }
    });
    return changes;
  }

  Future<List<String>> getStudentsWhoDidNotReciteLastClass() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT student_id FROM daily_records dr
      WHERE (attendance = 'present' OR attendance = 'late')
      AND date = (
        SELECT MAX(date) FROM daily_records 
        WHERE student_id = dr.student_id 
        AND (attendance = 'present' OR attendance = 'late')
      )
      AND memorization_done = 0 
      AND revision_done = 0
      AND talaqqin_done = 0
      AND recitation_exempt = 0
      AND NOT EXISTS (
        SELECT 1 FROM student_holds sh
        WHERE sh.student_id = dr.student_id
          AND sh.ended_at IS NULL
          AND dr.date BETWEEN sh.start_date AND sh.end_date
      )
    ''');
    return results.map((r) => r['student_id'] as String).toList();
  }
}
