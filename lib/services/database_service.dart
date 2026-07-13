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
import '../models/notification_log.dart';
import '../models/homework_grade.dart';
import '../models/mushaf_progress.dart';
import '../models/message_template.dart';
import '../models/exam_template.dart';
import '../models/student_hold.dart';
import '../models/student_status_change.dart';
import '../models/behavior_point_correction.dart';
import '../models/daily_achievement.dart';
import '../models/family.dart';
import '../models/family_guardian.dart';
import '../models/audit_event.dart';
import 'quran_service.dart';
import 'memorized_content_service.dart';
import 'recitation_record_math.dart';
import 'behavior_point_policy.dart';
import 'student_status_policy.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'halaqah.db');
    return await openDatabase(
      path,
      version: 14,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        guardian_phone TEXT,
        qr_code TEXT UNIQUE,
        plan_type TEXT DEFAULT 'ayahs',
        plan_amount INTEGER DEFAULT 5,
        total_memorized INTEGER DEFAULT 0,
        join_date TEXT NOT NULL,
        status TEXT DEFAULT 'active',
        photo_path TEXT,
        notes TEXT,
        memorization_direction TEXT DEFAULT 'desc',
        pre_memorized_start_surah INTEGER,
        pre_memorized_start_ayah INTEGER,
        pre_memorized_end_surah INTEGER,
        pre_memorized_end_ayah INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_records (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        date TEXT NOT NULL,
        attendance TEXT DEFAULT 'absent',
        arrival_time TEXT,
        absence_reason TEXT,
        absence_note TEXT,
        memorization_done INTEGER DEFAULT 0,
        revision_done INTEGER DEFAULT 0,
        memorization_amount INTEGER DEFAULT 0,
        revision_amount INTEGER DEFAULT 0,
        memorization_note TEXT,
        revision_note TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        UNIQUE(student_id, date)
      )
    ''');

    await db.execute('''
      CREATE TABLE memorization_progress (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        surah_id INTEGER NOT NULL,
        from_ayah INTEGER NOT NULL,
        to_ayah INTEGER NOT NULL,
        date TEXT NOT NULL,
        quality_rating INTEGER DEFAULT 3,
        is_revision INTEGER DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE behavior_points (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        type TEXT NOT NULL,
        reason TEXT NOT NULL,
        points INTEGER NOT NULL,
        date TEXT NOT NULL,
        resolved INTEGER DEFAULT 0,
        resolved_date TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE vacations (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        reason TEXT NOT NULL,
        approved INTEGER DEFAULT 1,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE exams (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        date TEXT NOT NULL,
        type TEXT DEFAULT 'oral',
        from_surah INTEGER NOT NULL,
        to_surah INTEGER NOT NULL,
        from_ayah INTEGER,
        to_ayah INTEGER,
        score INTEGER DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('CREATE INDEX idx_daily_records_date ON daily_records(date)');
    await db.execute('CREATE INDEX idx_daily_records_student ON daily_records(student_id)');
    await db.execute('CREATE INDEX idx_memorization_student ON memorization_progress(student_id)');
    await db.execute('CREATE INDEX idx_behavior_student ON behavior_points(student_id)');
    await _createVersion2Tables(db);
    await _createVersion3Tables(db);
    await _createVersion6Tables(db);
    await _createVersion7Tables(db);
    await _upgradeToVersion8(db);
    await _createVersion9Tables(db);
    await _createVersion10Tables(db);
    await _createVersion11Tables(db);
    await _upgradeToVersion12(db);
    await _upgradeToVersion13(db);
    await _upgradeToVersion14(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createVersion2Tables(db);
    }
    if (oldVersion < 3) {
      await _createVersion3Tables(db);
    }
    if (oldVersion < 4) {
      await _upgradeToVersion4(db);
    }
    if (oldVersion < 5) {
      await _upgradeToVersion5(db);
    }
    if (oldVersion < 6) {
      await _createVersion6Tables(db);
    }
    if (oldVersion < 7) {
      await _createVersion7Tables(db);
    }
    if (oldVersion < 8) {
      await _upgradeToVersion8(db);
    }
    if (oldVersion < 9) {
      await _createVersion9Tables(db);
    }
    if (oldVersion < 10) {
      await _createVersion10Tables(db);
    }
    if (oldVersion < 11) {
      await _createVersion11Tables(db);
    }
    if (oldVersion < 12) {
      await _upgradeToVersion12(db);
    }
    if (oldVersion < 13) {
      await _upgradeToVersion13(db);
    }
    if (oldVersion < 14) {
      await _upgradeToVersion14(db);
    }
  }

  Future<void> _upgradeToVersion14(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_events (
        id TEXT PRIMARY KEY,
        event_type TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT,
        outcome TEXT NOT NULL DEFAULT 'success',
        details_json TEXT NOT NULL DEFAULT '{}',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_events_created '
      'ON audit_events(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_events_entity '
      'ON audit_events(entity_type, entity_id, created_at DESC)',
    );
    await _createAuditTriggers(db);
  }

  Future<void> _createAuditTriggers(Database db) async {
    const sensitiveTables = <String>[
      'students',
      'daily_records',
      'memorization_progress',
      'behavior_points',
      'vacations',
      'student_holds',
      'exams',
      'plans',
      'families',
      'family_guardians',
      'daily_achievements',
    ];
    for (final table in sensitiveTables) {
      for (final operation in const <String>['INSERT', 'UPDATE', 'DELETE']) {
        final operationName = operation.toLowerCase();
        final triggerName = 'audit_${table}_$operationName';
        final rowAlias = operation == 'DELETE' ? 'OLD' : 'NEW';
        await db.execute('DROP TRIGGER IF EXISTS $triggerName');
        await db.execute('''
          CREATE TRIGGER $triggerName
          AFTER $operation ON $table
          BEGIN
            INSERT INTO audit_events (
              id, event_type, entity_type, entity_id,
              outcome, details_json, created_at
            ) VALUES (
              lower(hex(randomblob(16))),
              '$table.$operationName',
              '$table',
              $rowAlias.id,
              'success',
              '{"source":"sqlite_trigger"}',
              strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
            );
          END
        ''');
      }
    }
  }

  Future<void> _upgradeToVersion13(Database db) async {
    final columns = await db.rawQuery(
      'PRAGMA table_info(exam_template_questions)',
    );
    final names = columns.map((row) => row['name']?.toString()).toSet();
    const additions = <String, String>{
      'to_surah_id': 'INTEGER',
      'is_assessed': 'INTEGER NOT NULL DEFAULT 0',
      'memorization_errors': 'INTEGER NOT NULL DEFAULT 0',
      'tashkeel_errors': 'INTEGER NOT NULL DEFAULT 0',
      'recitation_errors': 'INTEGER NOT NULL DEFAULT 0',
      'prompt_count': 'INTEGER NOT NULL DEFAULT 0',
      'question_score': 'REAL NOT NULL DEFAULT 0',
    };
    for (final entry in additions.entries) {
      if (!names.contains(entry.key)) {
        await db.execute(
          'ALTER TABLE exam_template_questions '
          'ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
    }
    await db.execute(
      'UPDATE exam_template_questions '
      'SET to_surah_id = COALESCE(to_surah_id, surah_id)',
    );
  }

  Future<void> _upgradeToVersion12(Database db) async {
    for (final table in ['homework_grades', 'memorization_progress']) {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      final names = columns.map((row) => row['name']?.toString()).toSet();
      if (!names.contains('updated_at')) {
        await db.execute('ALTER TABLE $table ADD COLUMN updated_at TEXT');
      }
      await db.execute(
        'UPDATE $table SET updated_at = COALESCE(updated_at, created_at)',
      );
    }
  }

  Future<void> _createVersion11Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS families (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        reference_name TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS family_guardians (
        id TEXT PRIMARY KEY,
        family_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT,
        relationship TEXT NOT NULL DEFAULT 'guardian',
        is_primary INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (family_id) REFERENCES families (id) ON DELETE CASCADE
      )
    ''');
    final studentColumns = await db.rawQuery('PRAGMA table_info(students)');
    final studentColumnNames =
        studentColumns.map((row) => row['name']?.toString()).toSet();
    if (!studentColumnNames.contains('family_id')) {
      await db.execute('ALTER TABLE students ADD COLUMN family_id TEXT');
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_students_family ON students(family_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_family_guardians_family '
      'ON family_guardians(family_id, is_primary DESC, name)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_family_one_primary_guardian '
      'ON family_guardians(family_id) WHERE is_primary = 1',
    );
  }

  Future<void> _createVersion10Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_achievements (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        date TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'manual',
        reason TEXT NOT NULL,
        actual_amount REAL NOT NULL DEFAULT 0,
        plan_amount REAL NOT NULL DEFAULT 0,
        unit TEXT NOT NULL DEFAULT 'ayahs',
        reward_type TEXT,
        reward_details TEXT,
        reward_points INTEGER NOT NULL DEFAULT 0,
        awarded_at TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        UNIQUE(student_id, date)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_daily_achievements_date '
      'ON daily_achievements(date DESC, student_id)',
    );
  }

  Future<void> _createVersion9Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS student_status_history (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        previous_status TEXT NOT NULL,
        new_status TEXT NOT NULL,
        reason TEXT NOT NULL,
        notes TEXT,
        changed_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS behavior_point_corrections (
        id TEXT PRIMARY KEY,
        point_id TEXT,
        original_student_id TEXT NOT NULL,
        corrected_student_id TEXT,
        action TEXT NOT NULL,
        reason TEXT NOT NULL,
        point_reason_snapshot TEXT NOT NULL,
        points_snapshot INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (point_id) REFERENCES behavior_points (id) ON DELETE SET NULL,
        FOREIGN KEY (original_student_id) REFERENCES students (id) ON DELETE CASCADE,
        FOREIGN KEY (corrected_student_id) REFERENCES students (id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_student_status_history_student '
      'ON student_status_history(student_id, changed_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_behavior_corrections_point '
      'ON behavior_point_corrections(point_id, created_at DESC)',
    );
  }

  Future<void> _upgradeToVersion8(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(plans)');
    final names = columns.map((row) => row['name']?.toString()).toSet();
    if (!names.contains('test_status')) {
      await db.execute(
        "ALTER TABLE plans ADD COLUMN test_status TEXT NOT NULL DEFAULT 'not_required'",
      );
    }
    if (!names.contains('completion_exam_id')) {
      await db.execute('ALTER TABLE plans ADD COLUMN completion_exam_id TEXT');
    }
    if (!names.contains('completed_at')) {
      await db.execute('ALTER TABLE plans ADD COLUMN completed_at TEXT');
    }
    if (!names.contains('updated_at')) {
      await db.execute('ALTER TABLE plans ADD COLUMN updated_at TEXT');
    }
    await db.execute(
      'UPDATE plans SET updated_at = COALESCE(updated_at, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_plans_student_status_test '
      'ON plans(student_id, status, test_status)',
    );
  }

  Future<void> _createVersion7Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS student_holds (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        reason TEXT NOT NULL,
        notes TEXT,
        ended_at TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_student_holds_active '
      'ON student_holds(student_id, start_date, end_date, ended_at)',
    );
  }

  Future<void> _createVersion6Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exam_templates (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        criteria_json TEXT NOT NULL DEFAULT '{}',
        questions_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exam_template_questions (
        id TEXT PRIMARY KEY,
        template_id TEXT NOT NULL,
        question_order INTEGER NOT NULL,
        surah_id INTEGER NOT NULL,
        to_surah_id INTEGER,
        from_ayah INTEGER NOT NULL,
        to_ayah INTEGER NOT NULL,
        question_type TEXT NOT NULL DEFAULT 'recite_from',
        prompt_text TEXT NOT NULL,
        answer_text TEXT NOT NULL,
        page INTEGER NOT NULL DEFAULT 0,
        juz INTEGER NOT NULL DEFAULT 0,
        hizb INTEGER NOT NULL DEFAULT 0,
        difficulty INTEGER NOT NULL DEFAULT 0,
        lines REAL NOT NULL DEFAULT 0,
        is_assessed INTEGER NOT NULL DEFAULT 0,
        memorization_errors INTEGER NOT NULL DEFAULT 0,
        tashkeel_errors INTEGER NOT NULL DEFAULT 0,
        recitation_errors INTEGER NOT NULL DEFAULT 0,
        prompt_count INTEGER NOT NULL DEFAULT 0,
        question_score REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (template_id) REFERENCES exam_templates (id) ON DELETE CASCADE,
        UNIQUE(template_id, question_order)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_exam_templates_student ON exam_templates(student_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_exam_questions_template ON exam_template_questions(template_id)',
    );
  }

  Future<void> _createVersion2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fund_transactions (
        id TEXT PRIMARY KEY,
        student_id TEXT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS plans (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        period TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        unit TEXT NOT NULL DEFAULT 'ayahs',
        new_amount INTEGER NOT NULL DEFAULT 5,
        review_amount INTEGER NOT NULL DEFAULT 10,
        status TEXT NOT NULL DEFAULT 'active',
        test_status TEXT NOT NULL DEFAULT 'not_required',
        completion_exam_id TEXT,
        completed_at TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_fund_transactions_student ON fund_transactions(student_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_plans_student ON plans(student_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notifications_student ON notifications(student_id)');
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

  Future<void> saveDailyRecord(DailyRecord record) async {
    final db = await database;
    await db.insert(
      'daily_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
    final studentRows = await txn.query(
      'students',
      where: 'id = ?',
      whereArgs: [studentId],
      limit: 1,
    );
    if (studentRows.isEmpty) return;
    final student = Student.fromMap(studentRows.first);
    final trackedCount = await _countTrackedMemorized(txn, studentId);
    final adjustedTotal = RecitationRecordMath.adjustMemorizedTotal(
      currentTotal: student.totalMemorized,
      previousTrackedCount: previousTrackedCount,
      currentTrackedCount: trackedCount,
    );
    await txn.update(
      'students',
      {
        'total_memorized': adjustedTotal,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [studentId],
    );
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
    final keys = <String>{};
    for (var surahId = 1; surahId <= 114; surahId++) {
      final total = QuranService.instance.getSurahAyahCount(surahId);
      for (var ayah = 1; ayah <= total; ayah++) {
        if (_isPreMemorizedAyah(student, surahId, ayah)) {
          keys.add('$surahId:$ayah');
        }
      }
    }
    final rows = await txn.query(
      'memorization_progress',
      where: 'student_id = ? AND is_revision = 0',
      whereArgs: [studentId],
    );
    for (final progress in rows.map(MemorizationProgress.fromMap)) {
      final total = QuranService.instance.getSurahAyahCount(progress.surahId);
      for (var ayah = progress.fromAyah; ayah <= progress.toAyah; ayah++) {
        if (ayah >= 1 && ayah <= total) keys.add('${progress.surahId}:$ayah');
      }
    }
    return keys.length;
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

  Future<int> getStudentTotalPoints(String studentId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(points), 0) as total 
      FROM behavior_points 
      WHERE student_id = ?
    ''', [studentId]);
    return (result.first['total'] as int?) ?? 0;
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
        !const {'ayahs', 'pages', 'lines'}.contains(achievement.unit) ||
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
    // Get the vacation details first
    final maps = await db.query('vacations', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      final vacation = Vacation.fromMap(maps.first);
      // Delete vacation
      await db.delete('vacations', where: 'id = ?', whereArgs: [id]);
      // Revert attendance
      final startStr = vacation.startDate.toIso8601String().split('T')[0];
      final endStr = vacation.endDate.toIso8601String().split('T')[0];
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
      where: 'student_id = ? AND ended_at IS NULL '
          'AND start_date <= ? AND end_date >= ?',
      whereArgs: [studentId, target, target],
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
      where: 'ended_at IS NULL AND start_date <= ? AND end_date >= ?',
      whereArgs: [target, target],
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
    final map = settings.toMap();
    for (final entry in map.entries) {
      await saveSetting(entry.key, entry.value.toString());
    }
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
    'exams',
    'exam_templates',
    'exam_template_questions',
    'fund_transactions',
    'plans',
    'notifications',
    'homework_grades',
    'mushaf_progress',
    'message_templates',
    'audit_events',
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
      // Clear existing data (children first, then parents)
      await txn.delete('behavior_point_corrections');
      await txn.delete('daily_achievements');
      await txn.delete('family_guardians');
      await txn.delete('student_status_history');
      await txn.delete('daily_records');
      await txn.delete('memorization_progress');
      await txn.delete('behavior_points');
      await txn.delete('vacations');
      await txn.delete('student_holds');
      await txn.delete('exams');
      await txn.delete('exam_template_questions');
      await txn.delete('exam_templates');
      await txn.delete('fund_transactions');
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
    });
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
    final db = await database;
    await db.insert('fund_transactions', transaction.toMap());
  }

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
    final latest = SmartPlan.fromMap(rows.first);
    if (latest.isActive) {
      return 'للطالب خطة نشطة؛ أكملها أولًا ثم سجّل اختبار التجاوز';
    }
    if (latest.isWaitingForExam) {
      return 'لا يمكن إنشاء خطة جديدة قبل اجتياز اختبار الخطة السابقة';
    }
    return null;
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
        !const ['ayahs', 'pages', 'lines'].contains(plan.unit) ||
        plan.newAmount < 1 ||
        plan.reviewAmount < 1 ||
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

  // Notifications CRUD
  Future<void> insertNotification(NotificationLog notification) async {
    final db = await database;
    await db.insert('notifications', notification.toMap());
  }

  Future<void> generateNotifications() async {
    final db = await database;
    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T')[0];
    final settings = await getSettings();
    if (!_isPastClassEndTime(settings, now) || await isDateSuspended(now)) {
      return;
    }
    
    // Fetch all active students
    final students = await getStudents(status: 'active');
    
    for (final student in students) {
      // 1. Check if student is absent today
      final todayRecord = await getDailyRecord(student.id, now);
      if (todayRecord != null) {
        if (todayRecord.attendance == 'absent') {
          // Check if notification already exists for today
          final exist = await db.rawQuery('''
            SELECT * FROM notifications 
            WHERE student_id = ? AND type = 'repeated_absence' 
            AND date(created_at) = date(?)
          ''', [student.id, todayStr]);
          
          if (exist.isEmpty) {
            await insertNotification(NotificationLog(
              studentId: student.id,
              type: 'repeated_absence',
              title: 'غياب اليوم ⚠️',
              body: 'الطالب ${student.name} غائب اليوم عن الحلقة.',
            ));
          }
        } else if (await getActiveStudentHold(student.id, date: now) == null &&
                   (todayRecord.attendance == 'present' || todayRecord.attendance == 'late') &&
                   !todayRecord.memorizationDone && !todayRecord.revisionDone) {
          // 2. Check if student didn't recite today
          // Check if notification already exists for today
          final exist = await db.rawQuery('''
            SELECT * FROM notifications 
            WHERE student_id = ? AND type = 'low_performance' 
            AND date(created_at) = date(?)
          ''', [student.id, todayStr]);
          
          if (exist.isEmpty) {
            await insertNotification(NotificationLog(
              studentId: student.id,
              type: 'low_performance',
              title: 'لم يسمّع اليوم ⚠️',
              body: 'حضر الطالب ${student.name} اليوم ولكنه لم يكمل أي تسميع للحفظ أو المراجعة.',
            ));
          }
        }
      }

      final noRecitationDays = await getConsecutiveNoRecitationDays(
        student.id,
        asOfDate: now,
      );
      if (noRecitationDays >= 2) {
        final exist = await db.query(
          'notifications',
          columns: ['id'],
          where: "student_id = ? AND type = 'consecutive_no_recitation' "
              'AND date(created_at) = date(?)',
          whereArgs: [student.id, todayStr],
          limit: 1,
        );
        if (exist.isEmpty) {
          await insertNotification(NotificationLog(
            studentId: student.id,
            type: 'consecutive_no_recitation',
            title: 'تذكير تسميع متتالٍ ⚠️',
            body: 'الطالب ${student.name} لم يسمّع في '
                '$noRecitationDays أيام دراسية متتالية.',
          ));
        }
      }
      
      // 3. Check for consecutive absences
      final consecutiveAbsences = await getConsecutiveAbsenceDays(student.id);
      if (consecutiveAbsences >= settings.absenceDaysBeforeWarning) {
        // Check if warning was already generated in the last 3 days to avoid spamming
        final threeDaysAgo = now.subtract(const Duration(days: 3)).toIso8601String().split('T')[0];
        final exist = await db.rawQuery('''
          SELECT * FROM notifications 
          WHERE student_id = ? AND type = 'dismissal_warning' 
          AND date(created_at) >= date(?)
        ''', [student.id, threeDaysAgo]);
        
        if (exist.isEmpty) {
          await insertNotification(NotificationLog(
            studentId: student.id,
            type: 'dismissal_warning',
            title: 'تحذير غياب متكرر ⚠️',
            body: 'الطالب ${student.name} غائب لـ $consecutiveAbsences أيام متتالية.',
          ));
        }
      }

      if (settings.autoExpulsionEnabled &&
          consecutiveAbsences >= settings.absenceDaysBeforeExpulsion) {
        final updated = await db.update(
          'students',
          {
            'status': 'expelled',
            'updated_at': now.toIso8601String(),
          },
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
              notes: '$consecutiveAbsences أيام دراسية متتالية',
              changedAt: now,
            ).toMap(),
          );
        }
        final exists = await db.query(
          'notifications',
          columns: ['id'],
          where: "student_id = ? AND type = 'student_expelled'",
          whereArgs: [student.id],
          limit: 1,
        );
        if (exists.isEmpty) {
          await insertNotification(NotificationLog(
            studentId: student.id,
            type: 'student_expelled',
            title: 'تم فصل الطالب مؤقتًا',
            body: 'بلغ غياب ${student.name} $consecutiveAbsences أيام دراسية '
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

  Future<void> _createVersion3Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS homework_grades (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        surah_id INTEGER NOT NULL,
        from_ayah INTEGER NOT NULL,
        to_ayah INTEGER NOT NULL,
        date TEXT NOT NULL,
        grade_mark TEXT NOT NULL,
        mistakes_count INTEGER DEFAULT 0,
        is_revision INTEGER DEFAULT 0,
        remark TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS mushaf_progress (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        hizb_number INTEGER NOT NULL,
        thumun_number INTEGER NOT NULL,
        average_grade REAL DEFAULT 0.0,
        last_graded_date TEXT,
        is_pre_memorized INTEGER DEFAULT 0,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        UNIQUE(student_id, hizb_number, thumun_number)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS message_templates (
        type TEXT PRIMARY KEY,
        content TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_homework_grades_student ON homework_grades(student_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mushaf_progress_student ON mushaf_progress(student_id)');

    // Insert default message templates if they don't exist
    await db.insert('message_templates', {
      'type': 'assignment',
      'content': 'السلام عليكم ورحمة الله وبركاته، تم تكليف الطالب {اسم_الطالب} بواجب حفظ جديد: من سورة {السورة} آية {من} إلى آية {إلى}. نسأل الله له التوفيق.'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('message_templates', {
      'type': 'grading',
      'content': 'السلام عليكم ورحمة الله وبركاته، تسميع الطالب {اسم_الطالب} اليوم في سورة {السورة} من آية {من} إلى آية {إلى}:\n- التقييم: {التقييم}\n- الأخطاء: {الأخطاء}\n- ملاحظة: {الملاحظة}'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _upgradeToVersion4(Database db) async {
    try {
      await db.execute("ALTER TABLE students ADD COLUMN memorization_direction TEXT DEFAULT 'desc'");
    } catch (e) {
      print("Error upgrading database to version 4: $e");
    }
  }

  Future<void> _upgradeToVersion5(Database db) async {
    try {
      await db.execute("ALTER TABLE students ADD COLUMN pre_memorized_start_surah INTEGER");
      await db.execute("ALTER TABLE students ADD COLUMN pre_memorized_start_ayah INTEGER");
      await db.execute("ALTER TABLE students ADD COLUMN pre_memorized_end_surah INTEGER");
      await db.execute("ALTER TABLE students ADD COLUMN pre_memorized_end_ayah INTEGER");
    } catch (e) {
      print("Error upgrading database to version 5: $e");
    }
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
    await db.delete('homework_grades', where: 'id = ?', whereArgs: [id]);
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

  Future<void> upsertDailyAchievementFromSync(
    DailyAchievement achievement,
  ) async {
    _validateDailyAchievement(achievement);
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'daily_achievements',
        where: 'student_id = ? AND date = ?',
        whereArgs: [achievement.studentId, _dateKey(achievement.date)],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final existing = DailyAchievement.fromMap(rows.first);
        if (!achievement.updatedAt.isAfter(existing.updatedAt)) return;
        final merged = DailyAchievement(
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
        await txn.insert(
          'daily_achievements',
          merged.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return;
      }
      await txn.insert('daily_achievements', achievement.toMap());
    });
  }

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
    final dateStr = targetDate.toIso8601String().split('T')[0];

    final settings = await getSettings();
    final absencePenalty = settings.pointsConfig['unexcused_absence'] ?? -5;
    final incompletePenalty = settings.pointsConfig['incomplete_penalty'] ?? -3;

    const absenceReason = 'غياب بدون عذر (تلقائي)';
    const incompleteReason = 'عدم التسميع (تلقائي)';

    final records = await getDailyRecordsForDate(targetDate);
    int added = 0;

    for (final record in records) {
      // غياب بدون عذر
      if (record.attendance == 'absent') {
        final exists = await db.query(
          'behavior_points',
          where: 'student_id = ? AND date = ? AND reason = ?',
          whereArgs: [record.studentId, dateStr, absenceReason],
          limit: 1,
        );
        if (exists.isEmpty) {
          await insertBehaviorPoint(BehaviorPoint(
            studentId: record.studentId,
            type: 'negative',
            reason: absenceReason,
            points: absencePenalty,
            date: targetDate,
            resolved: true,
            notes: 'احتساب تلقائي عند إغلاق اليوم',
          ));
          added++;
        }
      }
      // حاضر لكن لم يسمّع ولم يراجع
      else if ((record.attendance == 'present' || record.attendance == 'late') &&
          !record.memorizationDone &&
          !record.revisionDone) {
        if (await getActiveStudentHold(record.studentId, date: targetDate) !=
            null) {
          continue;
        }
        final exists = await db.query(
          'behavior_points',
          where: 'student_id = ? AND date = ? AND reason = ?',
          whereArgs: [record.studentId, dateStr, incompleteReason],
          limit: 1,
        );
        if (exists.isEmpty) {
          await insertBehaviorPoint(BehaviorPoint(
            studentId: record.studentId,
            type: 'negative',
            reason: incompleteReason,
            points: incompletePenalty,
            date: targetDate,
            resolved: true,
            notes: 'احتساب تلقائي عند إغلاق اليوم',
          ));
          added++;
        }
      }
    }
    return added;
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
