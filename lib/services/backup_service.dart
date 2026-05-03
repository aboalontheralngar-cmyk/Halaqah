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
    final students = await _db.getStudents();
    final settings = await _db.getSettings();
    
    final allRecords = <Map<String, dynamic>>[];
    final allMemorizations = <Map<String, dynamic>>[];
    final allBehaviorPoints = <Map<String, dynamic>>[];
    final allExams = <Map<String, dynamic>>[];
    final allVacations = <Map<String, dynamic>>[];
    
    for (final student in students) {
      final records = await _db.getStudentRecords(student.id, limit: 1000);
      allRecords.addAll(records.map((r) => r.toMap()));
      
      final points = await _db.getStudentBehaviorPoints(student.id);
      allBehaviorPoints.addAll(points.map((p) => p.toMap()));
      
      final exams = await _db.getStudentExams(student.id);
      allExams.addAll(exams.map((e) => e.toMap()));
      
      final vacations = await _db.getStudentVacations(student.id);
      allVacations.addAll(vacations.map((v) => v.toMap()));
    }
    
    final backup = {
      'version': '1.0',
      'date': DateTime.now().toIso8601String(),
      'students': students.map((s) => s.toMap()).toList(),
      'records': allRecords,
      'memorizations': allMemorizations,
      'behavior_points': allBehaviorPoints,
      'exams': allExams,
      'vacations': allVacations,
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
      json.decode(jsonString) as Map<String, dynamic>;
      
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
