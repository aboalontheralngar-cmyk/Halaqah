import '../models/memorization.dart';
import 'database_service.dart';
import 'quran_service.dart';

/// مصالحة لمرة واحدة لطلاب النسخ القديمة.
///
/// قبل Build 75 كان من الممكن أن توجد سجلات حفظ فعلية بدون أن تتحول إلى
/// خريطة محفوظ متصلة في `mushaf_progress`. هذا يجعل ملف الطالب يبدو وكأنه
/// حفظ سورًا متناثرة فقط. تعتمد المصالحة على اتجاه الحفظ + أبعد سجل حفظ
/// حقيقي، وتضيف خلايا المصحف الناقصة فقط، لذلك لا تمس التقييمات الموجودة.
class LegacyMemorizedReconciliationService {
  LegacyMemorizedReconciliationService({DatabaseService? database})
      : _database = database ?? DatabaseService();

  final DatabaseService _database;

  static const String _completedKey = 'build78_legacy_memorized_reconciled_v1';

  Future<int> reconcileAllOnce() async {
    if (await _database.getSetting(_completedKey) == '1') return 0;
    final students = await _database.getStudents();
    var reconciled = 0;
    for (final student in students) {
      final changed = await reconcileStudent(student.id);
      if (changed) reconciled++;
    }
    await _database.saveSetting(_completedKey, '1');
    return reconciled;
  }

  Future<bool> reconcileStudent(String studentId) async {
    await QuranService.instance.initialize();
    final student = await _database.getStudent(studentId);
    if (student == null) return false;
    final rows = (await _database.getStudentMemorization(studentId))
        .where((row) => !row.isRevision)
        .toList();
    if (rows.isEmpty) {
      await _database.reconcileStudentMemorizedTotal(studentId);
      return false;
    }

    final frontier = _frontier(rows, student.memorizationDirection);
    if (student.memorizationDirection == 'desc') {
      await _database.initializeMushafProgressForRange(
        studentId,
        114,
        1,
        frontier.surahId,
        frontier.toAyah,
      );
    } else {
      await _database.initializeMushafProgressForRange(
        studentId,
        1,
        1,
        frontier.surahId,
        frontier.toAyah,
      );
    }
    await _database.reconcileStudentMemorizedTotal(studentId);
    return true;
  }

  MemorizationProgress _frontier(
    List<MemorizationProgress> rows,
    String direction,
  ) {
    final ordered = List<MemorizationProgress>.from(rows)
      ..sort((a, b) {
        if (a.surahId != b.surahId) {
          return direction == 'desc'
              ? a.surahId.compareTo(b.surahId)
              : b.surahId.compareTo(a.surahId);
        }
        return b.toAyah.compareTo(a.toAyah);
      });
    return ordered.first;
  }
}
