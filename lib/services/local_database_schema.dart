import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Owns the SQLite schema lifecycle separately from application CRUD logic.
///
/// Keeping create/upgrade code here makes database_service.dart materially
/// smaller and gives schema changes one auditable boundary without scattering
/// database-version transitions or migration order across CRUD code.
class LocalDatabaseSchema {
  const LocalDatabaseSchema();

  // Build 84 prevents cloud replay writes from re-dirtying upload stages.
  // Previous release database version: 27.
  static const int version = 28;

  Future<void> onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        guardian_phone TEXT,
        qr_code TEXT UNIQUE,
        student_code TEXT NOT NULL UNIQUE,
        plan_type TEXT DEFAULT 'ayahs',
        plan_amount INTEGER DEFAULT 5,
        review_plan_amount INTEGER DEFAULT 10,
        review_plan_type TEXT NOT NULL DEFAULT 'ayahs',
        review_system TEXT NOT NULL DEFAULT 'adaptive_spaced',
        talaqqin_enabled INTEGER NOT NULL DEFAULT 0,
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
        points REAL NOT NULL,
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
        template_id TEXT,
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
    await _upgradeToVersion15(db);
    await _upgradeToVersion16(db);
    await _upgradeToVersion17(db);
    await _upgradeToVersion18(db);
    await _upgradeToVersion19(db);
    await _upgradeToVersion20(db);
    await _upgradeToVersion21(db);
    await _upgradeToVersion22(db);
    await _upgradeToVersion23(db);
    await _upgradeToVersion24(db);
    await _upgradeToVersion25(db);
    await _upgradeToVersion26(db);
    await _upgradeToVersion27(db);
    await _upgradeToVersion28(db);
  }

  Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
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
    if (oldVersion < 15) {
      await _upgradeToVersion15(db);
    }
    if (oldVersion < 16) {
      await _upgradeToVersion16(db);
    }
    if (oldVersion < 17) {
      await _upgradeToVersion17(db);
    }
    if (oldVersion < 18) {
      await _upgradeToVersion18(db);
    }
    if (oldVersion < 19) {
      await _upgradeToVersion19(db);
    }
    if (oldVersion < 20) {
      await _upgradeToVersion20(db);
    }
    if (oldVersion < 21) {
      await _upgradeToVersion21(db);
    }
    if (oldVersion < 22) {
      await _upgradeToVersion22(db);
    }
    if (oldVersion < 23) {
      await _upgradeToVersion23(db);
    }
    if (oldVersion < 24) {
      await _upgradeToVersion24(db);
    }
    if (oldVersion < 25) {
      await _upgradeToVersion25(db);
    }
    if (oldVersion < 26) {
      await _upgradeToVersion26(db);
    }
    if (oldVersion < 27) {
      await _upgradeToVersion27(db);
    }
    if (oldVersion < 28) {
      await _upgradeToVersion28(db);
    }
  }


  static const Map<String, String> _syncDirtyStageByTable = {
    'families': 'families',
    'family_guardians': 'families',
    'students': 'students',
    'homework_grades': 'homework',
    'daily_records': 'attendance',
    'memorization_progress': 'memorization',
    'mushaf_progress': 'mushaf',
    'behavior_points': 'points',
    'behavior_point_corrections': 'point_corrections',
    'daily_achievements': 'achievements',
    'vacations': 'vacations',
    'exam_templates': 'exam_templates',
    'exam_template_questions': 'exam_templates',
    'exams': 'exams',
    'notifications': 'notifications',
    'fund_transactions': 'fund',
    'student_holds': 'student_holds',
    'talaqqin_records': 'talaqqin',
    'student_admin_actions': 'admin_actions',
    'plans': 'plans',
    'quran_courses': 'courses',
    'quran_course_enrollments': 'courses',
    'plan_recitation_records': 'plan_recitation',
  };

  static const List<String> _initialSyncDirtyStages = [
    'families',
    'students',
    'homework',
    'attendance',
    'study_suspensions',
    'memorization',
    'mushaf',
    'points',
    'point_corrections',
    'achievements',
    'vacations',
    'exam_templates',
    'exams',
    'notifications',
    'fund',
    'student_holds',
    'talaqqin',
    'admin_actions',
    'plans',
    'courses',
    'plan_recitation',
  ];

  Future<void> _upgradeToVersion28(Database db) async {
    // Recreate dirty-stage triggers with a cloud-replay guard. Without this,
    // a bidirectional pull marks the same stage dirty again and the next sync
    // needlessly uploads the rows it just downloaded.
    for (final entry in _syncDirtyStageByTable.entries) {
      await _createSyncDirtyStageTriggers(
        db,
        localTable: entry.key,
        stageId: entry.value,
      );
    }
  }

  Future<void> _upgradeToVersion27(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_dirty_stages (
        stage_id TEXT PRIMARY KEY,
        generation INTEGER NOT NULL DEFAULT 1,
        changed_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Force exactly one full device -> cloud upload after upgrading. Once it
    // succeeds, later upload-only syncs can skip untouched domains entirely.
    for (final stageId in _initialSyncDirtyStages) {
      await db.insert(
        'sync_dirty_stages',
        {
          'stage_id': stageId,
          'generation': 1,
          'changed_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    for (final entry in _syncDirtyStageByTable.entries) {
      await _createSyncDirtyStageTriggers(
        db,
        localTable: entry.key,
        stageId: entry.value,
      );
    }
  }

  Future<void> _createSyncDirtyStageTriggers(
    Database db, {
    required String localTable,
    required String stageId,
  }) async {
    final tableRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [localTable],
    );
    if (tableRows.isEmpty) return;

    final safeTable = localTable.replaceAll("'", "''");
    final safeStage = stageId.replaceAll("'", "''");
    for (final event in const ['INSERT', 'UPDATE']) {
      final suffix = event.toLowerCase();
      final trigger = 'sync_dirty_${localTable}_$suffix';
      await db.execute('DROP TRIGGER IF EXISTS $trigger');
      await db.execute('''
        CREATE TRIGGER $trigger
        AFTER $event ON $safeTable
        WHEN COALESCE(
          (SELECT value FROM settings WHERE key = 'sync_remote_write_replay'),
          '0'
        ) != '1'
        BEGIN
          INSERT OR IGNORE INTO sync_dirty_stages (
            stage_id, generation, changed_at
          ) VALUES ('$safeStage', 0, CURRENT_TIMESTAMP);
          UPDATE sync_dirty_stages
          SET generation = generation + 1,
              changed_at = CURRENT_TIMESTAMP
          WHERE stage_id = '$safeStage';
        END
      ''');
    }
  }


  Future<void> _upgradeToVersion26(Database db) async {
    final planColumns = await db.rawQuery('PRAGMA table_info(plans)');
    if (!planColumns.any((column) => column['name'] == 'friday_mode')) {
      await db.execute(
        "ALTER TABLE plans ADD COLUMN friday_mode TEXT NOT NULL DEFAULT 'catchup_recitation'",
      );
    }
    await db.execute(
      "UPDATE plans SET friday_mode = 'catchup_recitation' "
      "WHERE friday_mode IS NULL OR friday_mode NOT IN ('catchup_recitation','full_plan','holiday')",
    );
    // Build 78 introduces true fractional recitation rewards. Existing installs
    // used nearest as the old default; migrate that default to exact while
    // preserving explicit floor/ceil choices.
    await db.execute(
      "UPDATE settings SET value = 'exact' "
      "WHERE key = 'recitation_points_rounding' AND value = 'nearest'",
    );
  }


  Future<void> _upgradeToVersion25(Database db) async {
    final examColumns = await db.rawQuery('PRAGMA table_info(exams)');
    if (!examColumns.any((column) => column['name'] == 'template_id')) {
      await db.execute('ALTER TABLE exams ADD COLUMN template_id TEXT');
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_delete_outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_table TEXT NOT NULL,
        local_id TEXT NOT NULL,
        remote_table TEXT NOT NULL,
        remote_id TEXT,
        remote_key1 TEXT,
        remote_value1 TEXT,
        remote_key2 TEXT,
        remote_value2 TEXT,
        remote_key3 TEXT,
        remote_value3 TEXT,
        priority INTEGER NOT NULL DEFAULT 100,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(local_table, local_id, remote_table) ON CONFLICT IGNORE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_delete_outbox_priority '
      'ON sync_delete_outbox(priority, id)',
    );

    const directTables = <(String, String, int)>[
      ('family_guardians', 'family_guardians', 10),
      ('homework_grades', 'homework_grades', 10),
      ('memorization_progress', 'memorization', 10),
      ('behavior_points', 'points', 10),
      ('daily_achievements', 'daily_achievements', 10),
      ('vacations', 'vacations', 10),
      ('fund_transactions', 'fund_transactions', 10),
      ('notifications', 'notifications', 10),
      ('student_holds', 'student_holds', 10),
      ('talaqqin_records', 'talaqqin_records', 10),
      ('student_admin_actions', 'student_admin_actions', 10),
      ('quran_course_enrollments', 'quran_course_enrollments', 10),
      ('plan_recitation_records', 'plan_recitation_records', 10),
      ('exams', 'exams', 40),
      ('exam_templates', 'exam_templates', 40),
      ('plans', 'plans', 50),
      ('quran_courses', 'quran_courses', 60),
      ('families', 'families', 70),
      ('students', 'students', 100),
    ];
    for (final entry in directTables) {
      await _createDeleteOutboxTrigger(
        db,
        localTable: entry.$1,
        remoteTable: entry.$2,
        priority: entry.$3,
      );
    }

    await _createDeleteOutboxTrigger(
      db,
      localTable: 'daily_records',
      remoteTable: 'attendance',
      priority: 10,
      remoteKey1: 'student_id',
      remoteValue1: 'OLD.student_id',
      remoteKey2: 'date',
      remoteValue2: 'OLD.date',
      useRemoteId: false,
    );
    await _createDeleteOutboxTrigger(
      db,
      localTable: 'mushaf_progress',
      remoteTable: 'mushaf_progress',
      priority: 10,
      remoteKey1: 'student_id',
      remoteValue1: 'OLD.student_id',
      remoteKey2: 'hizb_number',
      remoteValue2: 'CAST(OLD.hizb_number AS TEXT)',
      remoteKey3: 'thumun_number',
      remoteValue3: 'CAST(OLD.thumun_number AS TEXT)',
      useRemoteId: false,
    );
  }

  Future<void> _createDeleteOutboxTrigger(
    Database db, {
    required String localTable,
    required String remoteTable,
    required int priority,
    bool useRemoteId = true,
    String? remoteKey1,
    String? remoteValue1,
    String? remoteKey2,
    String? remoteValue2,
    String? remoteKey3,
    String? remoteValue3,
  }) async {
    final tableRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [localTable],
    );
    if (tableRows.isEmpty) {
      debugPrint(
        '[schema.v25] skip delete outbox trigger; missing optional table: $localTable',
      );
      return;
    }
    final trigger = 'sync_delete_outbox_${localTable}_delete';
    String sqlLiteral(String? value) =>
        value == null ? 'NULL' : "'${value.replaceAll("'", "''")}'";
    final remoteId = useRemoteId ? 'OLD.id' : 'NULL';
    await db.execute('DROP TRIGGER IF EXISTS $trigger');
    await db.execute('''
      CREATE TRIGGER $trigger
      AFTER DELETE ON $localTable
      WHEN COALESCE(
        (SELECT value FROM settings WHERE key = 'sync_remote_delete_replay'),
        '0'
      ) != '1'
      BEGIN
        INSERT OR IGNORE INTO sync_delete_outbox (
          local_table, local_id, remote_table, remote_id,
          remote_key1, remote_value1, remote_key2, remote_value2,
          remote_key3, remote_value3, priority
        ) VALUES (
          '${localTable.replaceAll("'", "''")}', OLD.id,
          '${remoteTable.replaceAll("'", "''")}', $remoteId,
          ${sqlLiteral(remoteKey1)}, ${remoteValue1 ?? 'NULL'},
          ${sqlLiteral(remoteKey2)}, ${remoteValue2 ?? 'NULL'},
          ${sqlLiteral(remoteKey3)}, ${remoteValue3 ?? 'NULL'},
          $priority
        );
      END
    ''');
  }

  Future<void> _upgradeToVersion24(Database db) async {
    await db.execute("""
      CREATE TABLE IF NOT EXISTS rules_config_history (
        id TEXT PRIMARY KEY,
        config_key TEXT NOT NULL,
        previous_snapshot TEXT,
        snapshot TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    """);

    const indexes = <String>[
      "CREATE INDEX IF NOT EXISTS idx_students_status_name ON students(status, name COLLATE NOCASE)",
      "CREATE INDEX IF NOT EXISTS idx_daily_records_date_attendance_student ON daily_records(date, attendance, student_id)",
      "CREATE INDEX IF NOT EXISTS idx_memorization_student_date_revision ON memorization_progress(student_id, date DESC, is_revision, created_at)",
      "CREATE INDEX IF NOT EXISTS idx_memorization_date_student ON memorization_progress(date DESC, student_id, is_revision)",
      "CREATE INDEX IF NOT EXISTS idx_behavior_student_date_type_resolved ON behavior_points(student_id, date DESC, type, resolved)",
      "CREATE INDEX IF NOT EXISTS idx_behavior_type_resolved_date ON behavior_points(type, resolved, date DESC, student_id)",
      "CREATE INDEX IF NOT EXISTS idx_exams_student_date ON exams(student_id, date DESC, created_at)",
      "CREATE INDEX IF NOT EXISTS idx_vacations_student_approved_dates ON vacations(student_id, approved, start_date, end_date)",
      "CREATE INDEX IF NOT EXISTS idx_student_holds_student_scope_dates ON student_holds(student_id, scope, start_date, end_date)",
      "CREATE INDEX IF NOT EXISTS idx_notifications_read_created ON notifications(read, created_at DESC)",
      "CREATE INDEX IF NOT EXISTS idx_fund_student_date_type ON fund_transactions(student_id, date DESC, type)",
      "CREATE INDEX IF NOT EXISTS idx_quran_course_enrollments_student_status ON quran_course_enrollments(student_id, status, course_id)",
      "CREATE INDEX IF NOT EXISTS idx_rules_config_history_key_created ON rules_config_history(config_key, created_at DESC)",
    ];
    for (final statement in indexes) {
      try {
        await db.execute(statement);
      } catch (_) {
        // بعض الجداول قد لا تكون موجودة في قواعد قديمة جدًا أثناء سلسلة
        // الترقية؛ تُنشأ فهارسها عند اكتمال ترقية الجدول نفسها.
      }
    }
  }

  Future<void> _upgradeToVersion23(Database db) async {
    final studentColumns = await db.rawQuery('PRAGMA table_info(students)');
    final studentNames = studentColumns.map((row) => row['name']).toSet();
    if (!studentNames.contains('review_plan_type')) {
      await db.execute(
        "ALTER TABLE students ADD COLUMN review_plan_type TEXT NOT NULL DEFAULT 'ayahs'",
      );
      await db.execute(
        "UPDATE students SET review_plan_type = COALESCE(plan_type, 'ayahs')",
      );
    }
    if (!studentNames.contains('talaqqin_enabled')) {
      await db.execute(
        'ALTER TABLE students ADD COLUMN talaqqin_enabled INTEGER NOT NULL DEFAULT 0',
      );
    }

    final planColumns = await db.rawQuery('PRAGMA table_info(plans)');
    final planNames = planColumns.map((row) => row['name']).toSet();
    if (!planNames.contains('review_unit')) {
      await db.execute(
        "ALTER TABLE plans ADD COLUMN review_unit TEXT NOT NULL DEFAULT 'ayahs'",
      );
      await db.execute(
        "UPDATE plans SET review_unit = COALESCE(unit, 'ayahs')",
      );
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS quran_courses (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'mixed',
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        memorization_unit TEXT NOT NULL DEFAULT 'ayahs',
        memorization_amount INTEGER NOT NULL DEFAULT 5,
        revision_unit TEXT NOT NULL DEFAULT 'pages',
        revision_amount INTEGER NOT NULL DEFAULT 2,
        study_weekdays TEXT NOT NULL DEFAULT '[7,1,2,3,4]',
        status TEXT NOT NULL DEFAULT 'planned',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK (type IN ('memorization', 'revision', 'mixed')),
        CHECK (status IN ('planned', 'active', 'completed', 'cancelled')),
        CHECK (end_date >= start_date)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quran_course_enrollments (
        id TEXT PRIMARY KEY,
        course_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        enrolled_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (course_id) REFERENCES quran_courses (id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        UNIQUE(course_id, student_id),
        CHECK (status IN ('active', 'completed', 'withdrawn'))
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quran_courses_dates_status '
      'ON quran_courses(start_date, end_date, status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quran_course_enrollments_course '
      'ON quran_course_enrollments(course_id, status, student_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quran_course_enrollments_student '
      'ON quran_course_enrollments(student_id, status, course_id)',
    );
    await _createAuditTriggersForTable(db, 'quran_courses');
    await _createAuditTriggersForTable(db, 'quran_course_enrollments');
  }

  Future<void> _upgradeToVersion22(Database db) async {
    final dailyColumns = await db.rawQuery('PRAGMA table_info(daily_records)');
    final dailyNames = dailyColumns.map((column) => column['name']).toSet();
    final dailyAdditions = <String, String>{
      'activity_type': 'TEXT',
      'activity_note': 'TEXT',
      'recitation_exempt': 'INTEGER NOT NULL DEFAULT 0',
      'talaqqin_done': 'INTEGER NOT NULL DEFAULT 0',
      'talaqqin_amount': 'INTEGER NOT NULL DEFAULT 0',
      'talaqqin_note': 'TEXT',
    };
    for (final entry in dailyAdditions.entries) {
      if (!dailyNames.contains(entry.key)) {
        await db.execute(
          'ALTER TABLE daily_records ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
    }

    final holdColumns = await db.rawQuery('PRAGMA table_info(student_holds)');
    if (!holdColumns.any((column) => column['name'] == 'scope')) {
      await db.execute(
        "ALTER TABLE student_holds ADD COLUMN scope TEXT NOT NULL "
        "DEFAULT 'recitation_only'",
      );
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS talaqqin_records (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        surah_id INTEGER NOT NULL,
        from_ayah INTEGER NOT NULL,
        to_ayah INTEGER NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        CHECK (from_ayah >= 1 AND to_ayah >= from_ayah)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_talaqqin_student_date '
      'ON talaqqin_records(student_id, date DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_talaqqin_session '
      'ON talaqqin_records(session_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS student_admin_actions (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        action_type TEXT NOT NULL,
        date TEXT NOT NULL,
        details TEXT NOT NULL,
        follow_up TEXT,
        resolved INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_admin_actions_student_date '
      'ON student_admin_actions(student_id, date DESC)',
    );
    await _createAuditTriggersForTable(db, 'talaqqin_records');
    await _createAuditTriggersForTable(db, 'student_admin_actions');
  }

  Future<void> _upgradeToVersion21(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(students)');
    if (!columns.any((column) => column['name'] == 'review_system')) {
      await db.execute(
        "ALTER TABLE students ADD COLUMN review_system TEXT NOT NULL "
        "DEFAULT 'adaptive_spaced'",
      );
    }
    await db.execute(
      "UPDATE students SET review_system = 'adaptive_spaced' "
      "WHERE review_system IS NULL OR trim(review_system) = ''",
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS competition_events (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'عام',
        maximum_score REAL NOT NULL DEFAULT 100,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS competition_results (
        id TEXT PRIMARY KEY,
        event_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        template_id TEXT,
        obvious_errors INTEGER NOT NULL DEFAULT 0,
        subtle_errors INTEGER NOT NULL DEFAULT 0,
        prompt_count INTEGER NOT NULL DEFAULT 0,
        stop_count INTEGER NOT NULL DEFAULT 0,
        tajweed_errors INTEGER NOT NULL DEFAULT 0,
        score REAL NOT NULL DEFAULT 0,
        notes TEXT,
        assessed_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (event_id) REFERENCES competition_events (id)
          ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES students (id)
          ON DELETE CASCADE,
        FOREIGN KEY (template_id) REFERENCES exam_templates (id)
          ON DELETE SET NULL,
        UNIQUE(event_id, student_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_competition_results_event_score '
      'ON competition_results(event_id, score DESC, assessed_at ASC)',
    );
    await _createAuditTriggersForTable(db, 'competition_events');
    await _createAuditTriggersForTable(db, 'competition_results');
  }

  Future<void> _upgradeToVersion20(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plan_recitation_records (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        plan_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        surah_id INTEGER NOT NULL,
        from_ayah INTEGER NOT NULL,
        to_ayah INTEGER NOT NULL,
        segment_order INTEGER NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        quality_rating INTEGER NOT NULL DEFAULT 3,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        CHECK (from_ayah >= 1 AND to_ayah >= from_ayah),
        CHECK (quality_rating BETWEEN 1 AND 5)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_plan_recitation_plan_date '
      'ON plan_recitation_records(plan_id, date DESC, segment_order ASC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_plan_recitation_student_date '
      'ON plan_recitation_records(student_id, date DESC)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_plan_recitation_session '
      'ON plan_recitation_records(session_id, segment_order ASC)',
    );
    await _createAuditTriggersForTable(db, 'plan_recitation_records');
  }

  Future<void> _upgradeToVersion19(Database db) async {
    final planColumns = await db.rawQuery('PRAGMA table_info(plans)');
    if (!planColumns.any((column) => column['name'] == 'recitation_amount')) {
      await db.execute(
        'ALTER TABLE plans ADD COLUMN recitation_amount INTEGER NOT NULL DEFAULT 1',
      );
    }

    final fundColumns = await db.rawQuery('PRAGMA table_info(fund_transactions)');
    if (!fundColumns.any((column) => column['name'] == 'settled_negative_points')) {
      await db.execute(
        'ALTER TABLE fund_transactions ADD COLUMN settled_negative_points INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  Future<void> _upgradeToVersion18(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(families)');
    if (!columns.any((column) => column['name'] == 'family_code')) {
      await db.execute('ALTER TABLE families ADD COLUMN family_code TEXT');
    }
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_families_family_code '
      'ON families(family_code) WHERE family_code IS NOT NULL',
    );
  }

  Future<void> _upgradeToVersion17(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(students)');
    if (!columns.any((column) => column['name'] == 'review_plan_amount')) {
      await db.execute(
        'ALTER TABLE students ADD COLUMN review_plan_amount INTEGER DEFAULT 10',
      );
    }
    await db.execute(
      'UPDATE students SET review_plan_amount = 10 '
      'WHERE review_plan_amount IS NULL OR review_plan_amount < 1',
    );
  }

  Future<void> _upgradeToVersion16(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(fund_transactions)');
    if (!columns.any((column) => column['name'] == 'behavior_point_id')) {
      await db.execute(
        'ALTER TABLE fund_transactions ADD COLUMN behavior_point_id TEXT',
      );
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_fund_transactions_behavior_point '
      'ON fund_transactions(behavior_point_id)',
    );
  }

  Future<void> _upgradeToVersion15(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(students)');
    final hasStudentCode = columns.any((column) => column['name'] == 'student_code');
    if (!hasStudentCode) {
      await db.execute('ALTER TABLE students ADD COLUMN student_code TEXT');
    }

    final rows = await db.query(
      'students',
      columns: ['id', 'qr_code', 'student_code'],
    );
    final used = <String>{};
    for (final row in rows) {
      final current = row['student_code']?.toString().trim() ?? '';
      var source = current.isNotEmpty
          ? current
          : (row['qr_code']?.toString().trim().isNotEmpty ?? false)
              ? row['qr_code'].toString()
              : row['id'].toString();
      source = source.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
      var candidate = source.length >= 20
          ? source.substring(0, 20)
          : source.padRight(20, '0');
      if (used.contains(candidate)) {
        final fallback = row['id']
            .toString()
            .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
            .toUpperCase();
        candidate = fallback.length >= 20
            ? fallback.substring(0, 20)
            : fallback.padRight(20, '0');
      }
      used.add(candidate);
      await db.update(
        'students',
        {'student_code': candidate},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_students_student_code '
      'ON students(student_code)',
    );
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
      await _createAuditTriggersForTable(db, table);
    }
  }

  Future<void> _createAuditTriggersForTable(Database db, String table) async {
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
        family_code TEXT,
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
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_families_family_code '
      'ON families(family_code) WHERE family_code IS NOT NULL',
    );
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
        points_snapshot REAL NOT NULL,
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
        behavior_point_id TEXT,
        settled_negative_points INTEGER NOT NULL DEFAULT 0,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE SET NULL,
        FOREIGN KEY (behavior_point_id) REFERENCES behavior_points (id) ON DELETE SET NULL
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
        review_unit TEXT NOT NULL DEFAULT 'ayahs',
        new_amount INTEGER NOT NULL DEFAULT 5,
        review_amount INTEGER NOT NULL DEFAULT 10,
        recitation_amount INTEGER NOT NULL DEFAULT 1,
        friday_mode TEXT NOT NULL DEFAULT 'catchup_recitation',
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
    await db.execute('CREATE INDEX IF NOT EXISTS idx_fund_transactions_behavior_point ON fund_transactions(behavior_point_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_plans_student ON plans(student_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notifications_student ON notifications(student_id)');
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
      debugPrint('Database upgrade v4 failed (${e.runtimeType})');
    }
  }

  Future<void> _upgradeToVersion5(Database db) async {
    try {
      await db.execute("ALTER TABLE students ADD COLUMN pre_memorized_start_surah INTEGER");
      await db.execute("ALTER TABLE students ADD COLUMN pre_memorized_start_ayah INTEGER");
      await db.execute("ALTER TABLE students ADD COLUMN pre_memorized_end_surah INTEGER");
      await db.execute("ALTER TABLE students ADD COLUMN pre_memorized_end_ayah INTEGER");
    } catch (e) {
      debugPrint('Database upgrade v5 failed (${e.runtimeType})');
    }
  }

}
