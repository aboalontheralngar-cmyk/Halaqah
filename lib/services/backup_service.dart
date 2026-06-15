import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'database_service.dart';

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final DatabaseService _db = DatabaseService();

  Future<String> exportBackup() async {
    final db = await _db.database;

    // Load all data from tables in bulk (high efficiency O(1) query count)
    final students = await db.query('students');
    final records = await db.query('daily_records');
    final memorizations = await db.query('memorization_progress');
    final behaviorPoints = await db.query('behavior_points');
    final exams = await db.query('exams');
    final vacations = await db.query('vacations');
    final fundTransactions = await db.query('fund_transactions');
    final plans = await db.query('plans');
    final notifications = await db.query('notifications');
    final homeworkGrades = await db.query('homework_grades');
    final mushafProgress = await db.query('mushaf_progress');
    final messageTemplates = await db.query('message_templates');
    final settings = await _db.getSettings();
    
    final backup = {
      'version': '3.0',
      'date': DateTime.now().toIso8601String(),
      'students': students,
      'records': records,
      'memorizations': memorizations,
      'behavior_points': behaviorPoints,
      'exams': exams,
      'vacations': vacations,
      'fund_transactions': fundTransactions,
      'plans': plans,
      'notifications': notifications,
      'homework_grades': homeworkGrades,
      'mushaf_progress': mushafProgress,
      'message_templates': messageTemplates,
      'settings': settings.toMap(),
    };
    
    final jsonString = const JsonEncoder.withIndent('  ').convert(backup);
    
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    final filePath = '${directory.path}/halaqah_backup_$timestamp.json';
    
    final file = File(filePath);
    await file.writeAsString(jsonString);
    
    return filePath;
  }

  Future<bool> importBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final jsonString = await file.readAsString();
      final backup = json.decode(jsonString) as Map<String, dynamic>;

      // Validate basic backup structure
      if (backup['students'] is! List) {
        return false;
      }

      await _db.restoreFromBackup(backup);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<FileSystemEntity>> getBackupFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync()
        .where((f) => f.path.contains('halaqah_backup_') && f.path.endsWith('.json'))
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }
}
