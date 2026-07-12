import 'package:flutter/foundation.dart';
import '../models/mushaf_progress.dart';
import '../models/homework_grade.dart';
import 'database_service.dart';
import 'quran_service.dart';

class MushafService {
  final DatabaseService _db = DatabaseService();
  final QuranService _quran = QuranService.instance;

  // Update student mushaf progress based on a new homework grade
  Future<void> updateProgressAfterGrading(HomeworkGrade grade) async {
    if (grade.gradeMark == 'absent') return; // Do not record progress for absent students
    
    // Fetch ayahs in the range
    final ayahs = _quran.getAyahRange(grade.surahId, grade.fromAyah, grade.toAyah);
    if (ayahs.isEmpty) return;

    // Convert grade mark to numeric value for average
    double gradeVal = 3.0; // good
    switch (grade.gradeMark) {
      case 'excellent':
        gradeVal = 5.0;
        break;
      case 'very_good':
        gradeVal = 4.0;
        break;
      case 'good':
        gradeVal = 3.0;
        break;
      case 'needs_work':
        gradeVal = 2.0;
        break;
    }

    // Get current progress list for this student to avoid repeated db reads
    final currentProgressList = await _db.getStudentMushafProgress(grade.studentId);
    
    // Map of key: 'hizb_thumun' -> MushafProgress
    final progressMap = {
      for (var p in currentProgressList) '${p.hizbNumber}_${p.thumunNumber}': p
    };

    // Keep track of unique (hizb, thumun) covered by this grade
    final Set<String> coveredKeys = {};

    for (final ayah in ayahs) {
      final hizb = ayah.hizb;
      final quarter = ayah.quarter;
      if (hizb < 1 || hizb > 60 || quarter < 1 || quarter > 240) continue;

      final quarterInHizb = ((quarter - 1) % 4) + 1;
      final thumun1 = (quarterInHizb - 1) * 2 + 1;
      final thumun2 = (quarterInHizb - 1) * 2 + 2;

      coveredKeys.add('${hizb}_$thumun1');
      coveredKeys.add('${hizb}_$thumun2');
    }

    for (final key in coveredKeys) {
      final parts = key.split('_');
      final hizb = int.parse(parts[0]);
      final thumun = int.parse(parts[1]);

      final existing = progressMap[key];
      if (existing == null) {
        final newProgress = MushafProgress(
          studentId: grade.studentId,
          hizbNumber: hizb,
          thumunNumber: thumun,
          averageGrade: gradeVal,
          lastGradedDate: grade.date,
          isPreMemorized: false,
        );
        await _db.insertOrUpdateMushafProgress(newProgress);
      } else {
        // Average the grades or update
        double newAvg;
        if (existing.lastGradedDate == null) {
          newAvg = gradeVal;
        } else {
          newAvg = (existing.averageGrade + gradeVal) / 2.0;
        }
        final updatedProgress = MushafProgress(
          id: existing.id,
          studentId: grade.studentId,
          hizbNumber: hizb,
          thumunNumber: thumun,
          averageGrade: newAvg,
          lastGradedDate: grade.date,
          isPreMemorized: existing.isPreMemorized,
        );
        await _db.insertOrUpdateMushafProgress(updatedProgress);
      }
    }
  }

  Future<void> rebuildStudentProgress(String studentId) async {
    await _db.clearStudentGradedMushafProgress(studentId);
    final grades = (await _db.getStudentHomeworkGrades(studentId))
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
      });
    for (final grade in grades) {
      await updateProgressAfterGrading(grade);
    }
  }

  // Pre-populate/mark a thumun directly as pre-memorized
  Future<void> togglePreMemorized(String studentId, int hizb, int thumun, bool isPreMemorized) async {
    final currentProgressList = await _db.getStudentMushafProgress(studentId);
    final existing = currentProgressList.firstWhere(
      (p) => p.hizbNumber == hizb && p.thumunNumber == thumun,
      orElse: () => MushafProgress(
        studentId: studentId,
        hizbNumber: hizb,
        thumunNumber: thumun,
      ),
    );

    final updated = MushafProgress(
      id: existing.id,
      studentId: studentId,
      hizbNumber: hizb,
      thumunNumber: thumun,
      averageGrade: existing.averageGrade,
      lastGradedDate: existing.lastGradedDate,
      isPreMemorized: isPreMemorized,
    );

    await _db.insertOrUpdateMushafProgress(updated);
  }
}
