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
import 'quran_service.dart';

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
      version: 5,
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
        updated_at TEXT NOT NULL,
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
        notes TEXT,
        created_at TEXT NOT NULL,
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
        ? await db.query('students', where: 'status = ?', whereArgs: [status])
        : await db.query('students');
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
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
    await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
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

  Future<void> saveDailyRecord(DailyRecord record) async {
    final db = await database;
    await db.insert(
      'daily_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getConsecutiveAbsenceDays(String studentId) async {
    final db = await database;
    final maps = await db.query(
      'daily_records',
      where: 'student_id = ? AND attendance = ?',
      whereArgs: [studentId, 'absent'],
      orderBy: 'date DESC',
      limit: 30,
    );
    
    if (maps.isEmpty) return 0;
    
    final records = maps.map((m) => DailyRecord.fromMap(m)).toList();
    int count = 0;
    DateTime? lastDate;
    
    for (final record in records) {
      if (lastDate == null) {
        count = 1;
        lastDate = record.date;
      } else {
        final diff = lastDate.difference(record.date).inDays;
        if (diff == 1) {
          count++;
          lastDate = record.date;
        } else {
          break;
        }
      }
    }
    
    return count;
  }

  Future<void> insertMemorization(MemorizationProgress progress) async {
    final db = await database;
    await db.insert('memorization_progress', progress.toMap());
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

  Future<List<int>> getMemorizedSurahs(String studentId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT DISTINCT surah_id FROM memorization_progress 
      WHERE student_id = ? AND is_revision = 0
    ''', [studentId]);
    return maps.map((m) => m['surah_id'] as int).toList();
  }

  Future<void> insertBehaviorPoint(BehaviorPoint point) async {
    final db = await database;
    await db.insert('behavior_points', point.toMap());
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

  Future<int> getStudentTotalPoints(String studentId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(points), 0) as total 
      FROM behavior_points 
      WHERE student_id = ?
    ''', [studentId]);
    return (result.first['total'] as int?) ?? 0;
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

  Future<void> restoreFromBackup(Map<String, dynamic> backup) async {
    final db = await database;

    await db.transaction((txn) async {
      // Clear existing data (children first, then parents)
      await txn.delete('daily_records');
      await txn.delete('memorization_progress');
      await txn.delete('behavior_points');
      await txn.delete('vacations');
      await txn.delete('exams');
      await txn.delete('fund_transactions');
      await txn.delete('plans');
      await txn.delete('notifications');
      await txn.delete('homework_grades');
      await txn.delete('mushaf_progress');
      await txn.delete('message_templates');
      await txn.delete('students');
      await txn.delete('settings');

      Future<void> insertAll(String table, dynamic list) async {
        if (list is! List) return;
        for (final item in list) {
          if (item is Map) {
            await txn.insert(
              table,
              Map<String, dynamic>.from(item),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }

      await insertAll('students', backup['students']);
      await insertAll('daily_records', backup['records']);
      await insertAll('memorization_progress', backup['memorizations']);
      await insertAll('behavior_points', backup['behavior_points']);
      await insertAll('vacations', backup['vacations']);
      await insertAll('exams', backup['exams']);
      await insertAll('fund_transactions', backup['fund_transactions']);
      await insertAll('plans', backup['plans']);
      await insertAll('notifications', backup['notifications']);
      await insertAll('homework_grades', backup['homework_grades']);
      await insertAll('mushaf_progress', backup['mushaf_progress']);
      await insertAll('message_templates', backup['message_templates']);

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
    final db = await database;
    await db.insert('plans', plan.toMap());
  }

  Future<void> updateSmartPlan(SmartPlan plan) async {
    final db = await database;
    await db.update(
      'plans',
      plan.toMap(),
      where: 'id = ?',
      whereArgs: [plan.id],
    );
  }

  Future<List<SmartPlan>> getSmartPlans() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('plans', orderBy: 'created_at DESC');
    return List.generate(maps.length, (i) => SmartPlan.fromMap(maps[i]));
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
        } else if ((todayRecord.attendance == 'present' || todayRecord.attendance == 'late') &&
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
      
      // 3. Check for consecutive absences
      final consecutiveAbsences = await getConsecutiveAbsenceDays(student.id);
      if (consecutiveAbsences >= 3) {
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
    }
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
            conflictAlgorithm: ConflictAlgorithm.replace,
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
          conflictAlgorithm: ConflictAlgorithm.replace,
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
    ''');
    return results.map((r) => r['student_id'] as String).toList();
  }
}
