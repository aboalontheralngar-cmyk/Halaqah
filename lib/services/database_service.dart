import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/student.dart';
import '../models/daily_record.dart';
import '../models/memorization.dart';
import '../models/behavior_point.dart';
import '../models/vacation.dart';
import '../models/exam.dart';
import '../models/settings.dart';

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
      version: 1,
      onCreate: _onCreate,
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
    await db.delete('vacations', where: 'id = ?', whereArgs: [id]);
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
}
