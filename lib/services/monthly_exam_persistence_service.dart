import 'package:sqflite/sqflite.dart';

import '../models/exam.dart';
import '../models/exam_template.dart';
import 'database_service.dart';

/// Persists the monthly exam, its structured template, and its six questions
/// in one SQLite transaction. This prevents an orphan template if saving the
/// final exam record fails midway through the workflow.
class MonthlyExamPersistenceService {
  final DatabaseService databaseService;

  MonthlyExamPersistenceService({DatabaseService? databaseService})
      : databaseService = databaseService ?? DatabaseService();

  Future<void> save({
    required ExamTemplate template,
    required List<ExamTemplateQuestion> questions,
    required Exam exam,
  }) async {
    if (exam.templateId != template.id) {
      throw ArgumentError('exam_template_mismatch');
    }
    final database = await databaseService.database;
    await database.transaction((txn) async {
      await txn.insert(
        'exam_templates',
        template.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'exam_template_questions',
        where: 'template_id = ?',
        whereArgs: [template.id],
      );
      for (final question in questions) {
        if (question.templateId != template.id) {
          throw ArgumentError('question_template_mismatch');
        }
        await txn.insert('exam_template_questions', question.toMap());
      }
      await txn.insert(
        'exams',
        exam.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    });
  }
}
