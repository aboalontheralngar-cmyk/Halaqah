import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/student.dart';
import '../models/daily_record.dart';
import '../models/exam.dart';
import '../utils/helpers.dart';
import '../utils/quran_data.dart';

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  late pw.Font _arabicFont;
  bool _fontsLoaded = false;

  Future<void> _loadFonts() async {
    if (_fontsLoaded) return;
    try {
      _arabicFont = await PdfGoogleFonts.tajawalRegular();
      _fontsLoaded = true;
    } catch (e) {
      _arabicFont = pw.Font.helvetica();
      _fontsLoaded = true;
    }
  }

  pw.TextStyle _textStyle({
    double fontSize = 12,
    pw.FontWeight? fontWeight,
    PdfColor? color,
  }) {
    return pw.TextStyle(
      font: _arabicFont,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  Future<Uint8List> generateDailyReport(
    DateTime date,
    List<DailyRecord> records,
    List<Student> students,
    String halaqahName,
  ) async {
    await _loadFonts();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          _buildHeader(halaqahName, 'التقرير اليومي'),
          pw.SizedBox(height: 10),
          _buildDateRow(date),
          pw.SizedBox(height: 20),
          _buildDailyStatsSection(records),
          pw.SizedBox(height: 20),
          _buildStudentsDailyTable(records, students),
          pw.SizedBox(height: 30),
          _buildFooter(),
        ],
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> generateWeeklyReport(
    DateTime startDate,
    List<Student> students,
    Map<String, List<DailyRecord>> weeklyRecords,
    String halaqahName,
  ) async {
    await _loadFonts();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          _buildHeader(halaqahName, 'التقرير الأسبوعي'),
          pw.SizedBox(height: 10),
          _buildWeekRange(startDate),
          pw.SizedBox(height: 20),
          _buildWeeklyStatsSection(students, weeklyRecords),
          pw.SizedBox(height: 20),
          _buildStudentsWeeklyTable(students, weeklyRecords),
          pw.SizedBox(height: 30),
          _buildFooter(),
        ],
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> generateMonthlyReport(
    DateTime month,
    List<Student> students,
    Map<String, dynamic> stats,
    String halaqahName,
  ) async {
    await _loadFonts();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          _buildHeader(halaqahName, 'التقرير الشهري'),
          pw.SizedBox(height: 10),
          _buildMonthInfo(month),
          pw.SizedBox(height: 20),
          _buildMonthlyStatsSection(stats),
          pw.SizedBox(height: 20),
          _buildStudentsMonthlyTable(students, stats),
          pw.SizedBox(height: 30),
          _buildFooter(),
        ],
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> generateStudentReceipt(
    Student student,
    Map<String, dynamic> stats,
    String halaqahName,
    String mosqueName,
    String qrData,
  ) async {
    await _loadFonts();

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        textDirection: pw.TextDirection.rtl,
        build: (context) => pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'حلقة $halaqahName',
                style: _textStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'مسجد $mosqueName',
                style: _textStyle(fontSize: 14, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text(
                'سند استلام',
                style: _textStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              _buildReceiptStudentInfo(student),
              pw.SizedBox(height: 15),
              _buildReceiptSection('ملخص الحفظ', [
                _buildReceiptRow('الحفظ الكلي', '${student.totalMemorized} آية'),
                _buildReceiptRow('المقرر اليومي', '${student.planAmount} ${_getPlanLabel(student.planType)}'),
                _buildReceiptRow('نسبة الإنجاز', '${stats['completionRate'] ?? 0}%'),
              ]),
              pw.SizedBox(height: 15),
              _buildReceiptSection('الحضور', [
                _buildReceiptRow('أيام الحضور', '${stats['presentDays'] ?? 0}'),
                _buildReceiptRow('أيام الغياب', '${stats['absentDays'] ?? 0}'),
                _buildReceiptRow('أيام التأخير', '${stats['lateDays'] ?? 0}'),
              ]),
              pw.SizedBox(height: 15),
              _buildReceiptSection('النقاط', [
                _buildReceiptRow('الرصيد الحالي', '${stats['points'] ?? 0} نقطة'),
              ]),
              pw.SizedBox(height: 20),
              pw.BarcodeWidget(
                data: qrData,
                barcode: pw.Barcode.qrCode(),
                width: 80,
                height: 80,
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'التاريخ: ${Helpers.getFullHijriDate(DateTime.now())}',
                    style: _textStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'توقيع ولي الأمر: _________________',
                style: _textStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange50,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'تعتمد صحة هذا التقرير على البيانات المدخلة',
                  style: _textStyle(fontSize: 9, color: PdfColors.orange800),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> generateStudentFullReport(
    Student student,
    Map<String, dynamic> data,
    String halaqahName,
  ) async {
    await _loadFonts();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          _buildHeader(halaqahName, 'تقرير الطالب الشامل'),
          pw.SizedBox(height: 10),
          _buildStudentInfoSection(student),
          pw.SizedBox(height: 20),
          _buildStudentStatsSection(data),
          pw.SizedBox(height: 20),
          if (data['memorization'] != null) _buildMemorizationSection(data['memorization']),
          pw.SizedBox(height: 20),
          if (data['exams'] != null) _buildExamsSection(data['exams']),
          pw.SizedBox(height: 30),
          _buildFooter(),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(String halaqahName, String reportTitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'حلقة $halaqahName',
          style: _textStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          reportTitle,
          style: _textStyle(fontSize: 16, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.grey400),
      ],
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.orange50,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            'تعتمد صحة هذا التقرير على البيانات المدخلة',
            style: _textStyle(fontSize: 10, color: PdfColors.orange800),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'تم الإنشاء بواسطة تطبيق حلقتي',
          style: _textStyle(fontSize: 8, color: PdfColors.grey500),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  pw.Widget _buildDateRow(DateTime date) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            Helpers.getDayName(date),
            style: _textStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(' - '),
          pw.Text(
            Helpers.getFullHijriDate(date),
            style: _textStyle(),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildWeekRange(DateTime startDate) {
    final endDate = startDate.add(const Duration(days: 6));
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        'من ${Helpers.formatHijriDate(startDate)} إلى ${Helpers.formatHijriDate(endDate)}',
        style: _textStyle(),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildMonthInfo(DateTime month) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.orange50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        Helpers.getHijriMonth(month),
        style: _textStyle(fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildDailyStatsSection(List<DailyRecord> records) {
    final present = records.where((r) => r.attendance == 'present').length;
    final late = records.where((r) => r.attendance == 'late').length;
    final absent = records.where((r) => r.attendance == 'absent').length;

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatBox('حاضر', '$present', PdfColors.green),
        _buildStatBox('متأخر', '$late', PdfColors.orange),
        _buildStatBox('غائب', '$absent', PdfColors.red),
      ],
    );
  }

  pw.Widget _buildWeeklyStatsSection(
    List<Student> students,
    Map<String, List<DailyRecord>> weeklyRecords,
  ) {
    int totalPresent = 0;
    int totalLate = 0;
    int totalAbsent = 0;

    for (final records in weeklyRecords.values) {
      totalPresent += records.where((r) => r.attendance == 'present').length;
      totalLate += records.where((r) => r.attendance == 'late').length;
      totalAbsent += records.where((r) => r.attendance == 'absent').length;
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatBox('عدد الطلاب', '${students.length}', PdfColors.blue),
        _buildStatBox('إجمالي الحضور', '$totalPresent', PdfColors.green),
        _buildStatBox('إجمالي التأخير', '$totalLate', PdfColors.orange),
        _buildStatBox('إجمالي الغياب', '$totalAbsent', PdfColors.red),
      ],
    );
  }

  pw.Widget _buildMonthlyStatsSection(Map<String, dynamic> stats) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatBox('الطلاب', '${stats['totalStudents'] ?? 0}', PdfColors.blue),
        _buildStatBox('نسبة الحضور', '${stats['attendanceRate'] ?? 0}%', PdfColors.green),
        _buildStatBox('إجمالي الحفظ', '${stats['totalMemorized'] ?? 0}', PdfColors.purple),
      ],
    );
  }

  pw.Widget _buildStatBox(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: color.shade(0.9),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: _textStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: color),
          ),
          pw.Text(
            label,
            style: _textStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStudentsDailyTable(List<DailyRecord> records, List<Student> students) {
    final studentMap = {for (var s in students) s.id: s};
    
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('الطالب', isHeader: true),
            _buildTableCell('الحضور', isHeader: true),
            _buildTableCell('الحفظ', isHeader: true),
            _buildTableCell('المراجعة', isHeader: true),
          ],
        ),
        ...records.map((record) {
          final student = studentMap[record.studentId];
          return pw.TableRow(
            children: [
              _buildTableCell(student?.name ?? '-'),
              _buildTableCell(_getAttendanceLabel(record.attendance)),
              _buildTableCell(record.memorizationDone ? 'مكتمل' : '-'),
              _buildTableCell(record.revisionDone ? 'مكتمل' : '-'),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildStudentsWeeklyTable(
    List<Student> students,
    Map<String, List<DailyRecord>> weeklyRecords,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('الطالب', isHeader: true),
            _buildTableCell('الحضور', isHeader: true),
            _buildTableCell('الغياب', isHeader: true),
            _buildTableCell('الحفظ', isHeader: true),
          ],
        ),
        ...students.map((student) {
          final records = weeklyRecords[student.id] ?? [];
          final present = records.where((r) => r.attendance == 'present' || r.attendance == 'late').length;
          final absent = records.where((r) => r.attendance == 'absent').length;
          final memorized = records.where((r) => r.memorizationDone).length;

          return pw.TableRow(
            children: [
              _buildTableCell(student.name),
              _buildTableCell('$present'),
              _buildTableCell('$absent'),
              _buildTableCell('$memorized'),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildStudentsMonthlyTable(List<Student> students, Map<String, dynamic> stats) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('الطالب', isHeader: true),
            _buildTableCell('الحفظ', isHeader: true),
            _buildTableCell('النقاط', isHeader: true),
          ],
        ),
        ...students.map((student) {
          return pw.TableRow(
            children: [
              _buildTableCell(student.name),
              _buildTableCell('${student.totalMemorized}'),
              _buildTableCell('${stats['points_${student.id}'] ?? 0}'),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: _textStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : null,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildReceiptStudentInfo(Student student) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        student.name,
        style: _textStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildReceiptSection(String title, List<pw.Widget> children) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            title,
            style: _textStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 8),
        ...children,
      ],
    );
  }

  pw.Widget _buildReceiptRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: _textStyle(fontSize: 11)),
          pw.Text(value, style: _textStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _buildStudentInfoSection(Student student) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            student.name,
            style: _textStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'تاريخ الانضمام: ${Helpers.formatHijriDate(student.joinDate)}',
            style: _textStyle(fontSize: 11, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStudentStatsSection(Map<String, dynamic> data) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatBox('إجمالي الحفظ', '${data['totalMemorized'] ?? 0}', PdfColors.green),
        _buildStatBox('النقاط', '${data['points'] ?? 0}', PdfColors.blue),
        _buildStatBox('الحضور', '${data['attendanceRate'] ?? 0}%', PdfColors.orange),
      ],
    );
  }

  pw.Widget _buildMemorizationSection(List<dynamic> memorization) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'سجل الحفظ الأخير',
          style: _textStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('التاريخ', isHeader: true),
                _buildTableCell('السورة', isHeader: true),
                _buildTableCell('الآيات', isHeader: true),
              ],
            ),
            ...memorization.take(10).map((m) => pw.TableRow(
                  children: [
                    _buildTableCell(m['date'] ?? '-'),
                    _buildTableCell(m['surah'] ?? '-'),
                    _buildTableCell('${m['from'] ?? ''}-${m['to'] ?? ''}'),
                  ],
                )),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildExamsSection(List<dynamic> exams) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'الامتحانات',
          style: _textStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('التاريخ', isHeader: true),
                _buildTableCell('النطاق', isHeader: true),
                _buildTableCell('النتيجة', isHeader: true),
              ],
            ),
            ...exams.take(10).map((e) => pw.TableRow(
                  children: [
                    _buildTableCell(e['date'] ?? '-'),
                    _buildTableCell(e['range'] ?? '-'),
                    _buildTableCell('${e['score'] ?? 0}%'),
                  ],
                )),
          ],
        ),
      ],
    );
  }

  String _getAttendanceLabel(String attendance) {
    switch (attendance) {
      case 'present':
        return 'حاضر';
      case 'late':
        return 'متأخر';
      case 'absent':
        return 'غائب';
      default:
        return '-';
    }
  }

  String _getPlanLabel(String planType) {
    switch (planType) {
      case 'ayahs':
        return 'آية';
      case 'lines':
        return 'سطر';
      case 'pages':
        return 'صفحة';
      default:
        return planType;
    }
  }

  Future<Uint8List> generateExamResult(
    Student student,
    Exam exam,
    String halaqahName,
  ) async {
    await _loadFonts();

    final pdf = pw.Document();

    String scoreLabel;
    PdfColor scoreColor;
    if (exam.score >= 90) {
      scoreLabel = 'ممتاز';
      scoreColor = PdfColors.green;
    } else if (exam.score >= 80) {
      scoreLabel = 'جيد جداً';
      scoreColor = PdfColors.lightGreen;
    } else if (exam.score >= 70) {
      scoreLabel = 'جيد';
      scoreColor = PdfColors.amber;
    } else if (exam.score >= 60) {
      scoreLabel = 'مقبول';
      scoreColor = PdfColors.orange;
    } else {
      scoreLabel = 'ضعيف';
      scoreColor = PdfColors.red;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        textDirection: pw.TextDirection.rtl,
        build: (context) => pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'حلقة $halaqahName',
                style: _textStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'نتيجة الامتحان',
                style: _textStyle(fontSize: 14, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 15),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  student.name,
                  style: _textStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                width: 100,
                height: 100,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: scoreColor, width: 4),
                ),
                child: pw.Center(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        '${exam.score}',
                        style: _textStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: scoreColor),
                      ),
                      pw.Text(
                        '%',
                        style: _textStyle(fontSize: 14, color: scoreColor),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: scoreColor.shade(0.9),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Text(
                  scoreLabel,
                  style: _textStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: scoreColor),
                ),
              ),
              pw.SizedBox(height: 20),
              _buildExamDetailRow('التاريخ', Helpers.getFullHijriDate(exam.date)),
              _buildExamDetailRow('نوع الامتحان', exam.type == 'oral' ? 'شفهي' : 'تحريري'),
              _buildExamDetailRow('النطاق', _getExamRange(exam)),
              if (exam.notes != null && exam.notes!.isNotEmpty)
                _buildExamDetailRow('ملاحظات', exam.notes!),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text(
                'التاريخ: ${Helpers.getFullHijriDate(DateTime.now())}',
                style: _textStyle(fontSize: 9, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 15),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange50,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'تم الإنشاء بواسطة تطبيق حلقتي',
                  style: _textStyle(fontSize: 8, color: PdfColors.orange800),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildExamDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: _textStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.Text(value, style: _textStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  String _getExamRange(Exam exam) {
    final fromSurah = QuranData.getSurahName(exam.fromSurah);
    final toSurah = QuranData.getSurahName(exam.toSurah);
    if (fromSurah == toSurah) {
      return 'سورة $fromSurah';
    }
    return 'من $fromSurah إلى $toSurah';
  }

  Future<void> printDocument(Uint8List pdfData) async {
    await Printing.layoutPdf(onLayout: (_) => pdfData);
  }

  Future<void> sharePdf(Uint8List pdfData, String filename) async {
    await Printing.sharePdf(bytes: pdfData, filename: filename);
  }
}
