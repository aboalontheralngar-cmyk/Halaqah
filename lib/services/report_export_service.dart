import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database_service.dart';
import 'quran_service.dart';
import '../models/student.dart';

class ReportExportService {
  final DatabaseService _db = DatabaseService();

  // Helper to save and share file
  Future<void> _shareFile(String fileName, String content) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    
    // Write with UTF-8 BOM to support Excel reading Arabic properly
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(content)];
    await file.writeAsBytes(bytes);
    
    await Share.shareXFiles([XFile(file.path)], text: fileName);
  }

  // Export and share a single student's report
  Future<void> exportStudentReport(Student student) async {
    final records = await _db.getStudentRecords(student.id, limit: 100);
    final grades = await _db.getStudentHomeworkGrades(student.id);
    final points = await _db.getStudentBehaviorPoints(student.id);
    final exams = await _db.getStudentExams(student.id);

    final csv = StringBuffer();
    
    // Header Info
    csv.writeln('تقرير الطالب: ${student.name}');
    csv.writeln('تاريخ التصدير: ${DateTime.now().toIso8601String().split('T')[0]}');
    csv.writeln('الهاتف: ${student.phone ?? "لا يوجد"} | هاتف ولي الأمر: ${student.guardianPhone ?? "لا يوجد"}');
    csv.writeln('إجمالي الحفظ: ${student.totalMemorized} آية');
    csv.writeln();

    // Section 1: Attendance and Daily Records
    csv.writeln('--- سجل الحضور والتسميع اليومي ---');
    csv.writeln('التاريخ,الحضور,وقت الوصول,عذر الغياب,حفظ جديد (آيات),مراجعة (آيات),ملاحظات');
    for (final r in records) {
      final att = r.attendance == 'present' ? 'حاضر' : (r.attendance == 'late' ? 'متأخر' : 'غائب');
      csv.writeln('${r.date.toIso8601String().split('T')[0]},$att,${r.arrivalTime ?? ""},${r.absenceReason ?? ""},${r.memorizationAmount},${r.revisionAmount},"${r.notes ?? ""}"');
    }
    csv.writeln();

    // Section 2: Detailed Grades
    csv.writeln('--- سجل التقييمات التفصيلية (الواجبات) ---');
    csv.writeln('التاريخ,السورة,من آية,إلى آية,التقييم,عدد الأخطاء,النوع,الملاحظة');
    for (final g in grades) {
      final type = g.isRevision ? 'مراجعة' : 'حفظ جديد';
      final surahName = QuranService.instance.getSurahName(g.surahId);
      csv.writeln('${g.date.toIso8601String().split('T')[0]},$surahName,${g.fromAyah},${g.toAyah},${g.gradeMarkArabic},${g.mistakesCount},$type,"${g.remark ?? ""}"');
    }
    csv.writeln();

    // Section 3: Exams
    csv.writeln('--- سجل الاختبارات ---');
    csv.writeln('التاريخ,من سورة,إلى سورة,الدرجة,ملاحظات');
    for (final e in exams) {
      final fromSurah = QuranService.instance.getSurahName(e.fromSurah);
      final toSurah = QuranService.instance.getSurahName(e.toSurah);
      csv.writeln('${e.date.toIso8601String().split('T')[0]},$fromSurah,$toSurah,${e.score},"${e.notes ?? ""}"');
    }
    csv.writeln();

    // Section 4: Behavior Points
    csv.writeln('--- سجل نقاط السلوك ---');
    csv.writeln('التاريخ,النوع,السبب,النقاط,ملاحظات');
    for (final p in points) {
      final type = p.type == 'positive' ? 'إيجابي' : 'سلبي';
      csv.writeln('${p.date.toIso8601String().split('T')[0]},$type,"${p.reason}",${p.points},"${p.notes ?? ""}"');
    }

    final safeName = student.name.replaceAll(' ', '_');
    await _shareFile('تقرير_$safeName.csv', csv.toString());
  }

  // Export and share a summary report of the entire circle
  Future<void> exportCircleReport(List<Student> students) async {
    final csv = StringBuffer();
    csv.writeln('تقرير حلقة تحفيظ القرآن الكلي');
    csv.writeln('تاريخ التصدير: ${DateTime.now().toIso8601String().split('T')[0]}');
    csv.writeln();
    csv.writeln('اسم الطالب,رقم الهاتف,هاتف ولي الأمر,حالة الطالب,إجمالي الحفظ (آية),الخطة الحالية,تاريخ الانضمام');

    for (final s in students) {
      final status = s.status == 'active' ? 'نشط' : 'غير نشط';
      final plan = '${s.planAmount} ${s.planType == "ayahs" ? "آية" : (s.planType == "lines" ? "سطر" : "صفحة")}';
      csv.writeln('"${s.name}","${s.phone ?? ""}","${s.guardianPhone ?? ""}",$status,${s.totalMemorized},"$plan",${s.joinDate.toIso8601String().split('T')[0]}');
    }

    await _shareFile('تقرير_الحلقة_الكلي.csv', csv.toString());
  }
}
