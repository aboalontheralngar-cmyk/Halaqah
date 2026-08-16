import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/student.dart';
import '../models/daily_record.dart';
import '../models/exam.dart';
import '../models/plan.dart';
import '../models/behavior_point.dart';
import '../models/student_period_report.dart';
import '../models/halaqah_period_report.dart';
import '../models/vacation.dart';
import '../services/quran_service.dart';
import '../services/qr_service.dart';
import '../services/smart_plan_schedule_service.dart';
import '../services/smart_plan_print_policy.dart';
import '../services/student_learning_policy.dart';
import '../utils/helpers.dart';
import '../utils/quran_data.dart';

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  late pw.Font _pdfRegularFont;
  late pw.Font _pdfBoldFont;
  bool _fontsLoaded = false;

  // هوية PDF هي نفس هوية التطبيق الأصلية: أخضر هادئ + ذهبي دافئ.
  static const PdfColor _pdfPrimary = PdfColor(0.090, 0.420, 0.341);
  static const PdfColor _pdfPrimaryDark = PdfColor(0.059, 0.310, 0.251);
  static const PdfColor _pdfPrimaryLight = PdfColor(0.231, 0.545, 0.459);
  static const PdfColor _pdfPrimarySoft = PdfColor(0.863, 0.937, 0.906);
  static const PdfColor _pdfAccent = PdfColor(0.608, 0.424, 0.184);
  static const PdfColor _pdfAccentSoft = PdfColor(0.953, 0.906, 0.820);
  static const PdfColor _pdfBackground = PdfColor(0.961, 0.953, 0.929);
  static const PdfColor _pdfSurface = PdfColor(1.000, 0.996, 0.980);
  static const PdfColor _pdfInk = PdfColor(0.090, 0.141, 0.122);
  static const PdfColor _pdfMuted = PdfColor(0.349, 0.408, 0.380);
  static const PdfColor _pdfBorder = PdfColor(0.882, 0.871, 0.835);
  static const PdfColor _pdfDanger = PdfColor(0.706, 0.137, 0.184);
  static const PdfColor _pdfDanger50 = PdfColor(0.988, 0.929, 0.937);
  static const PdfColor _pdfSuccess = PdfColor(0.086, 0.639, 0.290);
  static const PdfColor _pdfWarning = PdfColor(0.718, 0.475, 0.122);
  static const PdfColor _pdfWarning50 = PdfColor(0.992, 0.957, 0.882);
  static const PdfColor _pdfPrimaryLight50 = PdfColor(0.925, 0.969, 0.949);

  Future<void> _loadFonts() async {
    if (_fontsLoaded) return;

    // package:pdf يعالج العربية داخل محرك PDF نفسه، لذلك نستخدم خطوط
    // Tajawal الثابت هو نفس خط واجهة التطبيق في P1.26، ويستخدم للواجهة وPDF
    // حتى لا تتغير أشكال الحروف بين التطبيق والتقرير ولا يدخل خط متغير في المحرك.
    final fonts = await Future.wait([
      rootBundle.load('assets/fonts/Tajawal-400.ttf'),
      rootBundle.load('assets/fonts/Tajawal-700.ttf'),
    ]);

    _pdfRegularFont = pw.Font.ttf(fonts[0]);
    _pdfBoldFont = pw.Font.ttf(fonts[1]);
    _fontsLoaded = true;
  }

  pw.ThemeData get _pdfTheme => pw.ThemeData.withFont(
        base: _pdfRegularFont,
        bold: _pdfBoldFont,
        italic: _pdfRegularFont,
        boldItalic: _pdfBoldFont,
      );

  pw.Font _fontForWeight(pw.FontWeight? fontWeight) {
    if (fontWeight == pw.FontWeight.bold) return _pdfBoldFont;
    return _pdfRegularFont;
  }

  pw.TextStyle _textStyle({
    double fontSize = 12,
    pw.FontWeight? fontWeight,
    PdfColor? color,
  }) {
    return pw.TextStyle(
      font: _fontForWeight(fontWeight),
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? _pdfInk,
      lineSpacing: 1.2,
    );
  }

  /// `package:pdf` يرسم أعمدة Table بحسب ترتيبها الفيزيائي؛ TextDirection
  /// وحده لا يعكس الأعمدة. لذلك نعكس الصفوف الدلالية حتى يصبح أول عمود
  /// منطقي هو العمود الأيمن بصريًا في التقارير العربية.
  /// خط Tajawal الثابت متوافق مع تشكيل العربية في package:pdf، لكنه لا
  /// يحتوي محرف ألف الوصل القرآني U+0671. في نص سؤال الاختبار فقط نعرضه
  /// كألف عادية حتى يبقى النص مقروءًا بدل ظهور محرف مفقود داخل الكلمة.
  String _normalizeQuranTextForPdf(String value) =>
      value.replaceAll('ٱ', 'ا').replaceAll('\uFE0F', '');

  pw.TableRow _rtlTableRow(
    List<pw.Widget> logicalChildren, {
    pw.BoxDecoration? decoration,
    bool repeat = false,
  }) =>
      pw.TableRow(
        decoration: decoration,
        repeat: repeat,
        children: logicalChildren.reversed.toList(),
      );

  Map<int, pw.TableColumnWidth> _rtlColumnWidths(
    Map<int, pw.TableColumnWidth> logicalWidths,
    int count,
  ) =>
      {
        for (final entry in logicalWidths.entries) count - 1 - entry.key: entry.value,
      };

  Future<Uint8List> generateDailyReport(
    DateTime date,
    List<DailyRecord> records,
    List<Student> students,
    String halaqahName,
  ) async {
    await _loadFonts();

    final pdf = pw.Document(theme: _pdfTheme);

    pdf.addPage(
      pw.MultiPage(
        theme: _pdfTheme,
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

  Future<Uint8List> generateStudentPeriodReport({
    required StudentPeriodReport report,
    required PdfPageFormat pageFormat,
    required String halaqahName,
    String mosqueName = '',
    bool useHijriCalendar = false,
    bool compactSummary = false,
  }) async {
    await _loadFonts();
    final pdf = pw.Document(theme: _pdfTheme);
    if (compactSummary) {
      _addStudentPeriodSummaryPage(
        pdf: pdf,
        report: report,
        pageFormat: pageFormat,
        halaqahName: halaqahName,
        mosqueName: mosqueName,
        useHijriCalendar: useHijriCalendar,
      );
      return pdf.save();
    }
    _addStudentPeriodReportPages(
      pdf: pdf,
      report: report,
      pageFormat: pageFormat,
      halaqahName: halaqahName,
      mosqueName: mosqueName,
      useHijriCalendar: useHijriCalendar,
    );
    return pdf.save();
  }

  /// ينشئ ملفًا واحدًا لجميع الطلاب، مع بدء تقرير كل طالب في صفحة مستقلة.
  Future<Uint8List> generateAllStudentPeriodReports({
    required List<StudentPeriodReport> reports,
    required PdfPageFormat pageFormat,
    required String halaqahName,
    String mosqueName = '',
    bool useHijriCalendar = false,
    bool compactSummary = false,
  }) async {
    if (reports.isEmpty) {
      throw ArgumentError('لا توجد تقارير طلاب للتصدير');
    }
    await _loadFonts();
    final pdf = pw.Document(theme: _pdfTheme);
    for (var index = 0; index < reports.length; index++) {
      if (compactSummary) {
        _addStudentPeriodSummaryPage(
          pdf: pdf,
          report: reports[index],
          pageFormat: pageFormat,
          halaqahName: halaqahName,
          mosqueName: mosqueName,
          useHijriCalendar: useHijriCalendar,
          batchPosition: index + 1,
          batchTotal: reports.length,
        );
      } else {
        _addStudentPeriodReportPages(
          pdf: pdf,
          report: reports[index],
          pageFormat: pageFormat,
          halaqahName: halaqahName,
          mosqueName: mosqueName,
          useHijriCalendar: useHijriCalendar,
          batchPosition: index + 1,
          batchTotal: reports.length,
        );
      }
    }
    return pdf.save();
  }

  Future<Uint8List> generateHalaqahPeriodReport({
    required HalaqahPeriodReport report,
    required String halaqahName,
    String mosqueName = '',
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    bool useHijriCalendar = false,
  }) async {
    await _loadFonts();
    final pdf = pw.Document(theme: _pdfTheme);
    final scoreColor = _scorePdfColor(report.performanceScore);
    // Build 77: the aggregate report is deliberately a single A4 landscape
    // page. The student table is fitted into the remaining height so a normal
    // halaqah (including ~20-30 students) does not spill onto a second page.
    pdf.addPage(
      pw.Page(
        theme: _pdfTheme,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(18, 16, 18, 14),
        textDirection: pw.TextDirection.rtl,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: pw.BoxDecoration(
                color: _pdfPrimarySoft,
                border: pw.Border.all(color: _pdfPrimaryLight, width: 0.7),
                borderRadius: pw.BorderRadius.circular(7),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'التقرير التجميعي للحلقة',
                          style: _textStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: _pdfPrimaryDark,
                          ),
                        ),
                        pw.Text(
                          'حلقة $halaqahName${mosqueName.isEmpty ? '' : ' — مسجد $mosqueName'}',
                          style: _textStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _pdfInk,
                          ),
                        ),
                        pw.Text(
                          '${_reportDate(report.startDate, hijri: useHijriCalendar)} — '
                          '${_reportDate(report.endDate, hijri: useHijriCalendar)} · '
                          '${report.studyDays} أيام دراسية'
                          '${report.rankingExcludedCount == 0 ? '' : ' · ${report.rankingExcludedCount} مستبعد من ترتيب الأوائل'}',
                          style: _textStyle(fontSize: 7.5, color: _pdfMuted),
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    width: 64,
                    height: 50,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: scoreColor, width: 1.5),
                      borderRadius: pw.BorderRadius.circular(7),
                    ),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          '${report.performanceScore}%',
                          style: _textStyle(
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                        pw.Text('أداء الحلقة', style: _textStyle(fontSize: 6.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 7),
            pw.Row(
              children: [
                _compactReportMetric('الطلاب', '${report.studentCount}', _pdfPrimary),
                pw.SizedBox(width: 5),
                _compactReportMetric('سمّعوا', '${report.recitedStudentCount}', _pdfSuccess),
                pw.SizedBox(width: 5),
                _compactReportMetric('الحفظ', '${report.totalMemorizedAyahs} آية', _pdfSuccess),
                pw.SizedBox(width: 5),
                _compactReportMetric('المراجعة', '${report.totalRevisedAyahs} آية', _pdfPrimaryLight),
                pw.SizedBox(width: 5),
                _compactReportMetric('الصفحات', report.totalCompletedPages.toStringAsFixed(1), _pdfAccent),
                pw.SizedBox(width: 5),
                _compactReportMetric('الحضور', '${report.attendanceRate}%', _pdfPrimary),
                pw.SizedBox(width: 5),
                _compactReportMetric('متابعة', '${report.attentionStudents.length}', _pdfWarning),
              ],
            ),
            pw.SizedBox(height: 7),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(7),
                    decoration: pw.BoxDecoration(
                      color: _pdfSurface,
                      border: pw.Border.all(color: _pdfBorder, width: 0.5),
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        _compactAggregateValue('حاضر', report.presentDays, _pdfSuccess),
                        _compactAggregateValue('متأخر', report.lateDays, _pdfWarning),
                        _compactAggregateValue('غائب', report.absentDays, _pdfDanger),
                        _compactAggregateValue('مستأذن', report.excusedDays, _pdfPrimaryLight),
                        _compactAggregateValue('لم يسمّع', report.noRecitationDays, _pdfWarning),
                        _compactAggregateValue(
                          'رصيد النقاط',
                          report.positivePoints - report.negativePoints,
                          _pdfAccent,
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 7),
                pw.Expanded(
                  flex: 4,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(7),
                    decoration: pw.BoxDecoration(
                      color: _pdfAccentSoft,
                      border: pw.Border.all(color: _pdfAccent, width: 0.4),
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'الأوائل في الفترة',
                          style: _textStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: _pdfInk,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        if (report.topStudents.isEmpty)
                          pw.Text('لا توجد بيانات كافية', style: _textStyle(fontSize: 7))
                        else
                          ...report.topStudents.take(3).toList().asMap().entries.map(
                            (entry) => pw.Text(
                              '${entry.key + 1}. ${entry.value.student.name} — ${entry.value.performanceScore}%',
                              maxLines: 1,
                              overflow: pw.TextOverflow.clip,
                              style: _textStyle(
                                fontSize: 7.2,
                                fontWeight: pw.FontWeight.bold,
                                color: _pdfInk,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 7),
            pw.Row(
              children: [
                pw.Text(
                  'ملخص جميع الطلاب',
                  style: _textStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _pdfPrimaryDark,
                  ),
                ),
                pw.Spacer(),
                pw.Text(
                  'الصف المظلل يحتاج متابعة · الطالب المستبعد يبقى في الجدول ولا يدخل ترتيب الأوائل',
                  style: _textStyle(fontSize: 6.5, color: _pdfMuted),
                ),
              ],
            ),
            pw.SizedBox(height: 3),
            pw.Expanded(
              child: pw.FittedBox(
                fit: pw.BoxFit.contain,
                alignment: pw.Alignment.topCenter,
                child: pw.SizedBox(
                  width: 790,
                  child: _buildAggregateStudentsTable(report),
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'حلقتي — تقرير مولّد من السجلات المعتمدة',
                  style: _textStyle(fontSize: 6.3, color: _pdfMuted),
                ),
                pw.Text(
                  'إجمالي الصفحات ${report.totalCompletedPages.toStringAsFixed(1)} · '
                  'حفظ ${report.totalMemorizedPages.toStringAsFixed(1)} · '
                  'مراجعة ${report.totalRevisedPages.toStringAsFixed(1)} · '
                  'سرد ${report.totalRecitedPages.toStringAsFixed(1)} · '
                  'مدفوعات ${Helpers.formatNumber(report.totalPaidAmount)}',
                  style: _textStyle(fontSize: 6.3, color: _pdfMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  pw.Widget _compactReportMetric(String label, String value, PdfColor color) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          decoration: pw.BoxDecoration(
            color: _pdfSurface,
            border: pw.Border.all(color: color, width: 0.55),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                value,
                maxLines: 1,
                style: _textStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                ),
              ),
              pw.Text(label, style: _textStyle(fontSize: 6.5, color: _pdfInk)),
            ],
          ),
        ),
      );

  /// ورقة إدارية موحدة لبطاقات هوية الطلاب، جاهزة للقص والتوزيع.
  Future<Uint8List> generatePeerGroupRoster({
    required String groupTitle,
    required String rangeLabel,
    required List<Map<String, Object?>> members,
    required String halaqahName,
  }) async {
    await _loadFonts();
    final pdf = pw.Document(theme: _pdfTheme);
    pdf.addPage(
      pw.Page(
        theme: _pdfTheme,
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _buildHeader(halaqahName, 'مجموعة المستوى المتقارب'),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: _pdfPrimarySoft,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(groupTitle, style: _textStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: _pdfPrimaryDark)),
                  pw.SizedBox(height: 3),
                  pw.Text(rangeLabel, style: _textStyle(fontSize: 10, color: _pdfMuted)),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Table(
              border: pw.TableBorder.all(color: _pdfBorder, width: .6),
              columnWidths: _rtlColumnWidths({
                0: const pw.FixedColumnWidth(34),
                1: const pw.FlexColumnWidth(2.8),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(1.3),
                4: const pw.FlexColumnWidth(1.3),
                5: const pw.FlexColumnWidth(1.0),
              }, 6),
              children: [
                _rtlTableRow([
                  _periodCell('#', bold: true),
                  _periodCell('الطالب', bold: true),
                  _periodCell('المحفوظ', bold: true),
                  _periodCell('حفظ الأسبوع', bold: true),
                  _periodCell('مراجعة الأسبوع', bold: true),
                  _periodCell('النقاط', bold: true),
                ], decoration: const pw.BoxDecoration(color: _pdfPrimarySoft), repeat: true),
                for (var i = 0; i < members.length; i++)
                  _rtlTableRow([
                    _periodCell('${i + 1}'),
                    _periodCell('${members[i]['name'] ?? ''}', fontSize: 8, color: _pdfInk),
                    _periodCell('${members[i]['memorized'] ?? 0}'),
                    _periodCell('${members[i]['new'] ?? 0}'),
                    _periodCell('${members[i]['review'] ?? 0}'),
                    _periodCell('${members[i]['score'] ?? 0}'),
                  ]),
              ],
            ),
            pw.Spacer(),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _pdfAccentSoft,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'اقتراح نشاط: تحدٍ أسبوعي بين أفراد المجموعة في الحفظ والمراجعة والسرد، مع إعلان المتقدم أسبوعيًا دون إخراج الطالب من مجموعته.',
                style: _textStyle(fontSize: 9, color: _pdfInk),
              ),
            ),
            pw.SizedBox(height: 10),
            _buildFooter(),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  Future<Uint8List> generateStudentQrCards({
    required List<Student> students,
    required String halaqahName,
    String mosqueName = '',
  }) async {
    if (students.isEmpty) {
      throw ArgumentError('لا يوجد طلاب لطباعة بطاقاتهم');
    }
    await _loadFonts();
    final pdf = pw.Document(theme: _pdfTheme);
    final sorted = List<Student>.from(students)
      ..sort((a, b) => a.name.compareTo(b.name));
    final rows = <pw.Widget>[];

    for (var index = 0; index < sorted.length; index += 3) {
      final rowStudents = sorted.sublist(
        index,
        (index + 3).clamp(0, sorted.length).toInt(),
      );
      rows.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: List.generate(3, (column) {
              if (column >= rowStudents.length) {
                return pw.Expanded(child: pw.SizedBox());
              }
              final student = rowStudents[column];
              return pw.Expanded(
                child: pw.Container(
                  height: 142,
                  margin: pw.EdgeInsets.only(left: column == 2 ? 0 : 6),
                  padding: const pw.EdgeInsets.all(7),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(color: _pdfPrimaryLight, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(7),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.BarcodeWidget(
                        data: QrService.generateQrData(student.qrCode),
                        barcode: pw.Barcode.qrCode(),
                        width: 76,
                        height: 76,
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        student.name,
                        maxLines: 1,
                        overflow: pw.TextOverflow.clip,
                        textAlign: pw.TextAlign.center,
                        style: _textStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        student.displayCode,
                        textAlign: pw.TextAlign.center,
                        style: _textStyle(fontSize: 6.5, color: _pdfPrimaryDark),
                      ),
                      pw.Text(
                        'للحضور وخدمات الطالب — لا يشارك علنًا',
                        textAlign: pw.TextAlign.center,
                        style: _textStyle(fontSize: 5.5, color: _pdfMuted),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        theme: _pdfTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        textDirection: pw.TextDirection.rtl,
        header: (_) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'بطاقات QR للطلاب',
                style: _textStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'حلقة $halaqahName${mosqueName.isEmpty ? '' : ' — مسجد $mosqueName'}',
                style: _textStyle(fontSize: 9, color: _pdfMuted),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Text(
          'صفحة ${context.pageNumber} من ${context.pagesCount} — تحفظ البطاقات بعناية',
          textAlign: pw.TextAlign.center,
          style: _textStyle(fontSize: 6.5, color: _pdfMuted),
        ),
        build: (_) => rows,
      ),
    );
    return pdf.save();
  }

  /// ملخص أفقي من صفحة واحدة للإدارة، مهما كان عدد طلاب الحلقة.
  Future<Uint8List> generateHalaqahManagementSummary({
    required HalaqahPeriodReport report,
    required String halaqahName,
    String mosqueName = '',
    bool useHijriCalendar = false,
  }) async {
    await _loadFonts();
    final pdf = pw.Document(theme: _pdfTheme);
    pdf.addPage(
      pw.Page(
        theme: _pdfTheme,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        textDirection: pw.TextDirection.rtl,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'الملخص الإداري لجميع الطلاب',
                      style: _textStyle(
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'حلقة $halaqahName${mosqueName.isEmpty ? '' : ' — مسجد $mosqueName'}',
                      style: _textStyle(fontSize: 9),
                    ),
                    pw.Text(
                      '${_reportDate(report.startDate, hijri: useHijriCalendar)} — '
                      '${_reportDate(report.endDate, hijri: useHijriCalendar)}',
                      style: _textStyle(fontSize: 8, color: _pdfMuted),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const pw.BoxDecoration(color: _pdfPrimarySoft),
                  child: pw.Text(
                    'الأداء ${report.performanceScore}% · الحضور ${report.attendanceRate}% · '
                    'الحفظ ${report.totalMemorizedAyahs} آية · المراجعة ${report.totalRevisedAyahs} آية',
                    style: _textStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Expanded(
              child: pw.FittedBox(
                fit: pw.BoxFit.contain,
                alignment: pw.Alignment.topCenter,
                child: pw.SizedBox(
                  width: 790,
                  child: _buildAggregateStudentsTable(report),
                ),
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'تم إنشاء هذا الملخص من السجلات المعتمدة في تطبيق حلقتي — جميع الأعمدة مرتبة من اليمين إلى اليسار.',
              style: _textStyle(fontSize: 6.5, color: _pdfMuted),
            ),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  pw.Widget _compactAggregateValue(
    String label,
    num value,
    PdfColor color,
  ) =>
      pw.Column(
        children: [
          pw.Text(
            Helpers.formatNumber(value),
            style: _textStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.Text(label, style: _textStyle(fontSize: 7)),
        ],
      );

  pw.Widget _buildAggregateStudentsTable(HalaqahPeriodReport report) => pw.Table(
        border: pw.TableBorder.all(color: _pdfBorder, width: 0.35),
        columnWidths: _rtlColumnWidths(
          const {
            0: pw.FlexColumnWidth(2.1),
            1: pw.FixedColumnWidth(43),
            2: pw.FixedColumnWidth(43),
            3: pw.FixedColumnWidth(45),
            4: pw.FixedColumnWidth(45),
            5: pw.FixedColumnWidth(45),
            6: pw.FixedColumnWidth(45),
            7: pw.FixedColumnWidth(52),
            8: pw.FixedColumnWidth(40),
            9: pw.FixedColumnWidth(40),
          },
          10,
        ),
        children: [
          _rtlTableRow(
            [
              _periodCell('الطالب', bold: true, color: PdfColors.white, fontSize: 6.7),
              _periodCell('الأداء', bold: true, color: PdfColors.white, fontSize: 6.7),
              _periodCell('الحضور', bold: true, color: PdfColors.white, fontSize: 6.7),
              _periodCell('حفظ ص', bold: true, color: PdfColors.white, fontSize: 6.7),
              _periodCell('مراجعة ص', bold: true, color: PdfColors.white, fontSize: 6.7),
              _periodCell('سرد ص', bold: true, color: PdfColors.white, fontSize: 6.7),
              _periodCell('الإجمالي', bold: true, color: PdfColors.white, fontSize: 6.7),
              _periodCell('المدفوع', bold: true, color: PdfColors.white, fontSize: 6.7),
              _periodCell('الغياب', bold: true, color: PdfColors.white, fontSize: 6.7),
              _periodCell('النقاط', bold: true, color: PdfColors.white, fontSize: 6.7),
            ],
            decoration: const pw.BoxDecoration(color: _pdfPrimaryDark),
            repeat: true,
          ),
          ...report.students.asMap().entries.map((entry) {
            final item = entry.value;
            final excluded = report.isExcludedFromRanking(item.student.id);
            final baseDecoration = item.needsAttention
                ? const pw.BoxDecoration(color: _pdfWarning50)
                : entry.key.isEven
                    ? const pw.BoxDecoration(color: _pdfSurface)
                    : const pw.BoxDecoration(color: PdfColors.white);
            final totalPages =
                item.memorizedPages + item.revisedPages + item.recitedPages;
            return _rtlTableRow(
              [
                _periodCell(
                  '${item.student.name}${excluded ? '  • مستبعد من الأوائل' : ''}',
                  bold: true,
                  color: _pdfInk,
                  fontSize: 7.0,
                  textAlign: pw.TextAlign.right,
                ),
                _periodCell('${item.performanceScore}%', color: _pdfInk, fontSize: 6.6),
                _periodCell('${item.attendanceRate}%', color: _pdfInk, fontSize: 6.6),
                _periodCell(item.memorizedPages.toStringAsFixed(1), color: _pdfInk, fontSize: 6.6),
                _periodCell(item.revisedPages.toStringAsFixed(1), color: _pdfInk, fontSize: 6.6),
                _periodCell(item.recitedPages.toStringAsFixed(1), color: _pdfInk, fontSize: 6.6),
                _periodCell(totalPages.toStringAsFixed(1), color: _pdfInk, fontSize: 6.6),
                _periodCell(item.paidAmount.toStringAsFixed(2), color: _pdfInk, fontSize: 6.6),
                _periodCell('${item.absentDays}', color: _pdfInk, fontSize: 6.6),
                _periodCell(Helpers.formatNumber(item.pointBalance), color: _pdfInk, fontSize: 6.6),
              ],
              decoration: baseDecoration,
            );
          }),
        ],
      );

  void _addStudentPeriodSummaryPage({
    required pw.Document pdf,
    required StudentPeriodReport report,
    required PdfPageFormat pageFormat,
    required String halaqahName,
    required String mosqueName,
    bool useHijriCalendar = false,
    int? batchPosition,
    int? batchTotal,
  }) {
    final scoreColor = _scorePdfColor(report.performanceScore);
    final recentPayments = report.payments.take(5).toList();
    pdf.addPage(
      pw.Page(
        theme: _pdfTheme,
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.fromLTRB(24, 22, 24, 22),
        textDirection: pw.TextDirection.rtl,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(11),
              decoration: pw.BoxDecoration(
                color: _pdfPrimarySoft,
                border: pw.Border.all(color: _pdfPrimaryLight, width: 0.7),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'ملخص مستوى الطالب',
                          style: _textStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: _pdfPrimaryDark,
                          ),
                        ),
                        pw.Text(
                          report.student.name,
                          style: _textStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'حلقة $halaqahName${mosqueName.isEmpty ? '' : ' — مسجد $mosqueName'}',
                          style: _textStyle(fontSize: 8, color: _pdfMuted),
                        ),
                        pw.Text(
                          '${_reportDate(report.startDate, hijri: useHijriCalendar)} — ${_reportDate(report.endDate, hijri: useHijriCalendar)}'
                          '${batchPosition == null || batchTotal == null ? '' : ' · $batchPosition/$batchTotal'}',
                          style: _textStyle(fontSize: 7.2, color: _pdfMuted),
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    width: 68,
                    height: 58,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: scoreColor, width: 1.4),
                      borderRadius: pw.BorderRadius.circular(7),
                    ),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          '${report.performanceScore}%',
                          style: _textStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: scoreColor),
                        ),
                        pw.Text('تقييم الفترة', style: _textStyle(fontSize: 6.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 9),
            pw.Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _periodStat('إجمالي الصفحات', report.totalCompletedPages.toStringAsFixed(1), _pdfAccent),
                _periodStat('صفحات حفظ', report.memorizedPages.toStringAsFixed(1), _pdfSuccess),
                _periodStat('صفحات مراجعة', report.revisedPages.toStringAsFixed(1), _pdfPrimaryLight),
                _periodStat('صفحات سرد', report.recitedPages.toStringAsFixed(1), _pdfAccent),
                _periodStat('الحضور', '${report.attendanceRate}%', _pdfPrimary),
                _periodStat('الغياب', '${report.absentDays}', _pdfDanger),
                _periodStat('الإيجابيات', '+${Helpers.formatNumber(report.positivePoints)}', _pdfSuccess),
                _periodStat('السلبيات', '-${Helpers.formatNumber(report.negativePoints)}', _pdfDanger),
                _periodStat('المدفوع', Helpers.formatNumber(report.paidAmount), _pdfPrimaryDark),
              ],
            ),
            pw.SizedBox(height: 10),
            _periodSectionTitle('المدفوعات خلال الفترة'),
            pw.SizedBox(height: 5),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: _pdfSurface,
                border: pw.Border.all(color: _pdfBorder, width: 0.5),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: recentPayments.isEmpty
                  ? pw.Text('لا توجد مدفوعات مسجلة خلال الفترة.', style: _textStyle(fontSize: 8, color: _pdfMuted))
                  : pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        for (final payment in recentPayments)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 2),
                            child: pw.Text(
                              '• ${_reportDate(payment.date, hijri: useHijriCalendar)} — ${_fundTypeLabel(payment.type)}: ${Helpers.formatNumber(payment.amount)}${payment.note?.trim().isNotEmpty == true ? ' — ${payment.note!.trim()}' : ''}',
                              style: _textStyle(fontSize: 7.2, color: _pdfInk),
                              maxLines: 1,
                              overflow: pw.TextOverflow.clip,
                            ),
                          ),
                        if (report.payments.length > recentPayments.length)
                          pw.Text(
                            'ومدفوعات أخرى: ${report.payments.length - recentPayments.length}',
                            style: _textStyle(fontSize: 6.5, color: _pdfMuted),
                          ),
                      ],
                    ),
            ),
            pw.SizedBox(height: 10),
            _periodSectionTitle('خلاصة المتابعة'),
            pw.SizedBox(height: 5),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: const pw.BoxDecoration(color: _pdfPrimarySoft),
              child: pw.Text(
                'الحفظ ${report.memorizedAyahs} آية · المراجعة ${report.revisedAyahs} آية · السرد ${report.recitedAyahs} آية · '
                'حاضر ${report.presentDays} · متأخر ${report.lateDays} · مستأذن ${report.excusedDays} · '
                'حاضر ولم يسمّع ${report.noRecitationDays} يوم · متوسط الجودة ${report.averageQuality.toStringAsFixed(1)}/5.',
                style: _textStyle(fontSize: 8),
              ),
            ),
            pw.Spacer(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('توقيع المعلم: ________________', style: _textStyle(fontSize: 8)),
                pw.Text('توقيع ولي الأمر: ________________', style: _textStyle(fontSize: 8)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addStudentPeriodReportPages({
    required pw.Document pdf,
    required StudentPeriodReport report,
    required PdfPageFormat pageFormat,
    required String halaqahName,
    required String mosqueName,
    bool useHijriCalendar = false,
    int? batchPosition,
    int? batchTotal,
  }) {
    pdf.addPage(
      pw.MultiPage(
        theme: _pdfTheme,
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.fromLTRB(22, 20, 22, 20),
        textDirection: pw.TextDirection.rtl,
        build: (context) => _studentPeriodReportContent(
          report: report,
          halaqahName: halaqahName,
          mosqueName: mosqueName,
          useHijriCalendar: useHijriCalendar,
          batchPosition: batchPosition,
          batchTotal: batchTotal,
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.only(top: 5),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'صفحة ${context.pageNumber} من ${context.pagesCount}',
                style: _textStyle(fontSize: 7, color: _pdfMuted),
              ),
              pw.Text(
                'تقرير ${report.student.name} — ${report.student.displayCode}',
                style: _textStyle(fontSize: 7, color: _pdfMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<pw.Widget> _studentPeriodReportContent({
    required StudentPeriodReport report,
    required String halaqahName,
    required String mosqueName,
    bool useHijriCalendar = false,
    int? batchPosition,
    int? batchTotal,
  }) {
    final scoreColor = _scorePdfColor(report.performanceScore);
    final scoredDays = report.days
        .where((day) => day.isRecitationRequiredDay && day.record != null)
        .toList();

    return [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(11),
        decoration: pw.BoxDecoration(
          color: _pdfPrimarySoft,
          border: pw.Border.all(color: _pdfPrimaryLight, width: 0.7),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 62,
              padding: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: _pdfPrimaryLight, width: 0.6),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                children: [
                  pw.BarcodeWidget(
                    data: QrService.generateQrData(report.student.qrCode),
                    barcode: pw.Barcode.qrCode(),
                    width: 46,
                    height: 46,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'هوية الطالب',
                    style: _textStyle(fontSize: 5.5, color: _pdfMuted),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'تقرير مستوى الطالب',
                    style: _textStyle(
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                      color: _pdfPrimaryDark,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'حلقة $halaqahName${mosqueName.isEmpty ? '' : ' — مسجد $mosqueName'}',
                    style: _textStyle(fontSize: 9, color: _pdfMuted),
                  ),
                  if (batchPosition != null && batchTotal != null)
                    pw.Text(
                      'التقرير $batchPosition من $batchTotal',
                      style: _textStyle(fontSize: 7, color: _pdfMuted),
                    ),
                ],
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Container(
              width: 72,
              height: 72,
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: scoreColor, width: 2),
                shape: pw.BoxShape.circle,
              ),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    '${report.performanceScore}%',
                    style: _textStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                  pw.Text('تقييم الفترة', style: _textStyle(fontSize: 7)),
                  if (report.rankLabel != null)
                    pw.Text(
                      report.rankLabel!,
                      style: _textStyle(
                        fontSize: 6.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.amber900,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 9),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: _pdfBackground,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
              flex: 3,
              child: _periodIdentityItem('اسم الطالب', report.student.name),
            ),
            pw.Expanded(
              flex: 2,
              child: _periodIdentityItem('كود الطالب', report.student.displayCode),
            ),
            pw.Expanded(
              flex: 3,
              child: _periodIdentityItem(
                'الفترة',
                '${_reportDate(report.startDate, hijri: useHijriCalendar)} — ${_reportDate(report.endDate, hijri: useHijriCalendar)}',
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 10),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: pw.BoxDecoration(
          color: _pdfPrimarySoft,
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Text(
          'المقرر الشخصي: حفظ ${report.student.planAmount} ${_getPlanLabel(report.student.planType)} يوميًا، '
          'ومراجعة ${report.student.reviewPlanAmount} ${_getPlanLabel(report.student.reviewPlanType)} يوميًا. '
          'تُمنح مكافأة إتمام المقرر عند بلوغه كاملًا، وتُمنح مكافأة الزيادة فقط عند تجاوز المقرر فعليًا.',
          style: _textStyle(fontSize: 7.5),
        ),
      ),
      pw.SizedBox(height: 8),
      _periodSectionTitle('ملخص الإنجاز والمواظبة'),
      pw.SizedBox(height: 6),
      pw.Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _periodStat('الحفظ الجديد', '${report.memorizedAyahs} آية', _pdfSuccess),
          _periodStat('المراجعة', '${report.revisedAyahs} آية', _pdfPrimaryLight),
          _periodStat('إجمالي الصفحات', report.totalCompletedPages.toStringAsFixed(1), _pdfAccent),
          _periodStat('صفحات حفظ', report.memorizedPages.toStringAsFixed(1), _pdfSuccess),
          _periodStat('صفحات مراجعة', report.revisedPages.toStringAsFixed(1), _pdfPrimaryLight),
          _periodStat('صفحات سرد', report.recitedPages.toStringAsFixed(1), _pdfAccent),
          _periodStat('نسبة الحضور', '${report.attendanceRate}%', _pdfPrimary),
          _periodStat('حاضر ولم يسمّع', '${report.noRecitationDays} يوم', _pdfWarning),
          _periodStat('الإيجابيات', '+${Helpers.formatNumber(report.positivePoints)}', _pdfSuccess),
          _periodStat('السلبيات', '-${Helpers.formatNumber(report.negativePoints)}', _pdfDanger),
          _periodStat('وقت التأخر', '${report.totalLateMinutes} د', _pdfWarning),
          _periodStat('المخالفات', '${report.violationEvents}', _pdfDanger),
          _periodStat('تمت تسويته', '${report.settledNegativePoints}', _pdfPrimaryLight),
          _periodStat('المتبقي السلبي', '-${Helpers.formatNumber(report.outstandingNegativePoints)}', _pdfDanger),
        ],
      ),
      if (report.exams.isNotEmpty) ...[
        pw.SizedBox(height: 10),
        _periodSectionTitle('اختبارات الفترة'),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: _pdfBorder, width: 0.45),
          columnWidths: _rtlColumnWidths(
            const {
              0: pw.FixedColumnWidth(48),
              1: pw.FixedColumnWidth(44),
              2: pw.FlexColumnWidth(2.4),
              3: pw.FixedColumnWidth(42),
              4: pw.FixedColumnWidth(48),
            },
            5,
          ),
          children: [
            _rtlTableRow(
              ['التاريخ', 'النوع', 'النطاق', 'الدرجة', 'التقدير']
                  .map((text) => _periodCell(text, bold: true))
                  .toList(),
              decoration: const pw.BoxDecoration(color: _pdfPrimarySoft),
              repeat: true,
            ),
            ...report.exams.map(
              (exam) => _rtlTableRow([
                _periodCell(_reportDate(exam.date, hijri: useHijriCalendar)),
                _periodCell(ExamType.getLabel(exam.type)),
                _periodCell(_getExamRange(exam)),
                _periodCell('${exam.score}%'),
                _periodCell(exam.scoreGrade),
              ]),
            ),
          ],
        ),
      ],
      pw.SizedBox(height: 10),
      _periodSectionTitle('مدفوعات الطالب خلال الفترة'),
      pw.SizedBox(height: 6),
      if (report.payments.isEmpty)
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          child: pw.Text(
            'لا توجد مدفوعات مسجلة لهذا الطالب خلال الفترة.',
            style: _textStyle(fontSize: 8, color: _pdfMuted),
            textAlign: pw.TextAlign.center,
          ),
        )
      else ...[
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const pw.BoxDecoration(color: _pdfPrimarySoft),
          child: pw.Text(
            'إجمالي ما دفعه الطالب: ${Helpers.formatNumber(report.paidAmount)}',
            style: _textStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: _pdfBorder, width: 0.4),
          columnWidths: _rtlColumnWidths(
            const {
              0: pw.FixedColumnWidth(62),
              1: pw.FixedColumnWidth(70),
              2: pw.FixedColumnWidth(58),
              3: pw.FlexColumnWidth(2.5),
            },
            4,
          ),
          children: [
            _rtlTableRow(
              ['التاريخ', 'النوع', 'المبلغ', 'البيان']
                  .map((text) => _periodCell(text, bold: true))
                  .toList(),
              decoration: const pw.BoxDecoration(color: _pdfPrimarySoft),
              repeat: true,
            ),
            ...report.payments.map(
              (payment) => _rtlTableRow([
                _periodCell(_reportDate(payment.date, hijri: useHijriCalendar)),
                _periodCell(_fundTypeLabel(payment.type)),
                _periodCell(Helpers.formatNumber(payment.amount), bold: true),
                _periodCell(payment.note?.trim().isNotEmpty == true ? payment.note!.trim() : '—'),
              ]),
            ),
          ],
        ),
      ],
      pw.SizedBox(height: 10),
      _periodSectionTitle('مؤشر الأداء اليومي'),
      pw.SizedBox(height: 6),
      if (scoredDays.isEmpty)
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          color: PdfColors.grey100,
          child: pw.Text(
            'لا توجد أيام دراسية مسجلة لحساب المؤشر خلال هذه الفترة.',
            style: _textStyle(fontSize: 8, color: _pdfMuted),
            textAlign: pw.TextAlign.center,
          ),
        )
      else
        ...scoredDays.map(
          (day) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 58,
                  child: pw.Text(
                    _reportDate(day.date, hijri: useHijriCalendar),
                    style: _textStyle(fontSize: 7),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.SizedBox(width: 5),
                pw.Container(
                  width: 160,
                  height: 8,
                  alignment: pw.Alignment.centerRight,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Container(
                    width: 1.6 * day.performanceScore,
                    decoration: pw.BoxDecoration(
                      color: _scorePdfColor(day.performanceScore),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                  ),
                ),
                pw.SizedBox(width: 5),
                pw.SizedBox(
                  width: 30,
                  child: pw.Text(
                    '${day.performanceScore}%',
                    style: _textStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.left,
                  ),
                ),
              ],
            ),
          ),
        ),
      pw.SizedBox(height: 10),
      _periodSectionTitle('التفاصيل اليومية'),
      pw.SizedBox(height: 6),
      _buildRtlPeriodTable(report, useHijriCalendar: useHijriCalendar),
      pw.SizedBox(height: 10),
      ..._periodAttendanceAndViolationSections(
        report,
        useHijriCalendar: useHijriCalendar,
      ),
      pw.SizedBox(height: 10),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: _pdfAccentSoft,
          border: pw.Border.all(color: _pdfAccent, width: 0.5),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Text(
          'خلاصة الفترة: ${report.totalCompletedPages.toStringAsFixed(1)} صفحة إجمالًا: '
          '${report.memorizedPages.toStringAsFixed(1)} حفظ، '
          '${report.revisedPages.toStringAsFixed(1)} مراجعة، '
          '${report.recitedPages.toStringAsFixed(1)} سرد. '
          'المدفوعات ${Helpers.formatNumber(report.paidAmount)}. '
          'ومتوسط جودة ${report.averageQuality.toStringAsFixed(1)} من 5. '
          'الحضور: ${report.presentDays}، التأخر: ${report.lateDays}، '
          'بإجمالي ${report.totalLateMinutes} دقيقة، الغياب: ${report.absentDays}، '
          'والاستئذان: ${report.excusedDays}.',
          style: _textStyle(fontSize: 8),
        ),
      ),
      pw.SizedBox(height: 10),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: _pdfPrimarySoft,
          border: pw.Border.all(color: _pdfPrimaryLight, width: 0.5),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Text(
          'إلى ولي الأمر الكريم: حرصًا على ولدكم نضع بين أيديكم هذا التقرير، '
          'وننتظر ملاحظاتكم وتعاونكم. الغرامات والعقوبات المالية — إن وُجدت — '
          'تُصرف لصالح أنشطة وفعاليات الحلقة، وغرضها تعزيز الالتزام بالحفظ والمراجعة وآداب الحلقة.',
          style: _textStyle(fontSize: 8),
        ),
      ),
      pw.SizedBox(height: 10),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('توقيع المعلم: ________________', style: _textStyle(fontSize: 8)),
          pw.Text('توقيع ولي الأمر: ________________', style: _textStyle(fontSize: 8)),
        ],
      ),
    ];
  }

  pw.Widget _periodIdentityItem(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: _textStyle(fontSize: 7, color: _pdfMuted)),
            pw.Text(
              value,
              style: _textStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );

  pw.Widget _periodSectionTitle(String title) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            right: pw.BorderSide(color: _pdfPrimary, width: 3),
          ),
        ),
        child: pw.Text(
          title,
          style: _textStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      );

  /// جدول PDF لا يعكس ترتيب أعمدته تلقائيًا؛ لذلك نرتبه ماديًا من اليسار
  /// إلى اليمين: الملاحظة ... التاريخ، ليُقرأ بصريًا من أقصى اليمين.
  pw.Widget _buildRtlPeriodTable(
    StudentPeriodReport report, {
    bool useHijriCalendar = false,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: _pdfBorder, width: 0.4),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FixedColumnWidth(35),
        2: pw.FlexColumnWidth(2.3),
        3: pw.FlexColumnWidth(2.3),
        4: pw.FixedColumnWidth(46),
        5: pw.FixedColumnWidth(50),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _pdfPrimarySoft),
          children: const ['الملاحظة', 'النقاط', 'المراجعة', 'الحفظ', 'الحالة', 'التاريخ']
              .map((text) => _periodCell(text, bold: true))
              .toList(),
        ),
        ...report.days.map(
          (day) => pw.TableRow(
            decoration: _periodDayDecoration(day),
            children: [
              _periodCell(_periodNote(day)),
              _periodCell(Helpers.formatNumber(day.positivePoints - day.negativePoints)),
              _periodCell(
                '${_progressText(day.revision)}\nتقييم المراجعة: ${day.revisionRating}',
              ),
              _periodCell(
                '${_progressText(day.memorization)}\nتقييم الحفظ: ${day.memorizationRating}',
              ),
              _periodCell(_periodAttendance(day)),
              _periodCell(_reportDate(day.date, hijri: useHijriCalendar)),
            ],
          ),
        ),
      ],
    );
  }

  pw.BoxDecoration? _periodDayDecoration(StudentPeriodDay day) {
    if (day.isSuspended || day.isWeeklyHoliday) {
      return const pw.BoxDecoration(color: PdfColors.grey100);
    }
    switch (day.record?.attendance) {
      case 'absent':
        return const pw.BoxDecoration(color: _pdfDanger50);
      case 'excused':
        return const pw.BoxDecoration(color: _pdfPrimaryLight50);
      case 'late':
        return const pw.BoxDecoration(color: PdfColors.amber50);
      default:
        return null;
    }
  }

  List<pw.Widget> _periodAttendanceAndViolationSections(
    StudentPeriodReport report, {
    required bool useHijriCalendar,
  }) {
    final absences = report.days
        .where((day) => day.record?.attendance == 'absent')
        .toList();
    final excuses = report.days
        .where((day) => day.record?.attendance == 'excused')
        .toList();
    final late = report.days
        .where((day) => day.record?.attendance == 'late')
        .toList();
    final violationRows = <({DateTime date, BehaviorPoint point})>[
      for (final day in report.days)
        for (final point in day.violations) (date: day.date, point: point),
    ];

    pw.Widget listSection({
      required String title,
      required PdfColor color,
      required List<String> rows,
      required String emptyText,
    }) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(7),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: color, width: 0.5),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: _textStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                ),
              ),
              pw.SizedBox(height: 4),
              if (rows.isEmpty)
                pw.Text(emptyText, style: _textStyle(fontSize: 6.5))
              else
                ...rows.map(
                  (row) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Text('• $row', style: _textStyle(fontSize: 6.5)),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return [
      _periodSectionTitle('الفصل الإداري للحضور والمخالفات'),
      pw.SizedBox(height: 6),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          listSection(
            title: 'أيام الغياب (${absences.length})',
            color: _pdfDanger,
            emptyText: 'لا يوجد غياب',
            rows: absences
                .map((day) => _reportDate(day.date, hijri: useHijriCalendar))
                .toList(),
          ),
          pw.SizedBox(width: 6),
          listSection(
            title: 'الاستئذانات (${excuses.length})',
            color: _pdfPrimaryLight,
            emptyText: 'لا توجد استئذانات',
            rows: excuses
                .map(
                  (day) =>
                      '${_reportDate(day.date, hijri: useHijriCalendar)} — ${day.record?.absenceNote ?? day.record?.absenceReason ?? ''}',
                )
                .toList(),
          ),
          pw.SizedBox(width: 6),
          listSection(
            title: 'التأخر (${late.length})',
            color: _pdfWarning,
            emptyText: 'لا يوجد تأخر',
            rows: late
                .map(
                  (day) =>
                      '${_reportDate(day.date, hijri: useHijriCalendar)} — ${day.lateMinutes} دقيقة',
                )
                .toList(),
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(7),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _pdfAccent, width: 0.5),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'المخالفات المستقلة (${report.violationEvents})',
              style: _textStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: _pdfAccent,
              ),
            ),
            pw.SizedBox(height: 4),
            if (violationRows.isEmpty)
              pw.Text('لا توجد مخالفات مسجلة', style: _textStyle(fontSize: 6.5))
            else
              ...violationRows.map(
                (row) => pw.Text(
                  '• ${_reportDate(row.date, hijri: useHijriCalendar)} — '
                  '${BehaviorReason.getLabel(row.point.reason)} (${Helpers.formatNumber(row.point.points)})',
                  style: _textStyle(fontSize: 6.5),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  Future<Uint8List> generateSmartPlan({
    required Student student,
    required SmartPlan plan,
    required String halaqahName,
    String mosqueName = '',
    bool cashier = false,
    List<int> holidayWeekdays = const [5],
    required List<SmartPlanDailyAssignment> dailyAssignments,
  }) async {
    SmartPlanPrintPolicy.validateExactAssignments(
      student: student,
      plan: plan,
      assignments: dailyAssignments,
    );
    await _loadFonts();
    final pdf = pw.Document(theme: _pdfTheme);
    final format = cashier
        ? PdfPageFormat(
            80 * PdfPageFormat.mm,
            297 * PdfPageFormat.mm,
            marginAll: 4 * PdfPageFormat.mm,
          )
        : PdfPageFormat.a4;
    final assignmentByDate = {
      for (final assignment in dailyAssignments)
        _dateKey(assignment.date): assignment,
    };
    final days = dailyAssignments.map((assignment) => assignment.date).toList();
    final unit = _getPlanLabel(plan.unit);
    final reviewUnit = _getPlanLabel(plan.reviewUnit);
    final revisionOnly = StudentLearningPolicy.hasCompletedQuran(student);
    final tableHeaders = revisionOnly
        ? const ['اليوم', 'المراجعة', 'السرد', 'تم']
        : const ['اليوم', 'الحفظ', 'المراجعة', 'السرد', 'تم'];
    final Map<int, pw.TableColumnWidth> columnWidths = revisionOnly
        ? {
            0: const pw.FlexColumnWidth(1.5),
            1: const pw.FlexColumnWidth(1.25),
            2: const pw.FlexColumnWidth(1.25),
            3: const pw.FlexColumnWidth(0.7),
          }
        : {
            0: const pw.FlexColumnWidth(1.5),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(0.7),
          };
    pdf.addPage(
      pw.MultiPage(
        theme: _pdfTheme,
        pageFormat: format,
        margin: pw.EdgeInsets.all(cashier ? 8 : 24),
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          pw.Text(
            '${revisionOnly ? 'خطة المراجعة والسرد' : 'خطة الحفظ والمراجعة والسرد'} '
            '${plan.period == 'weekly' ? 'الأسبوعية' : 'الشهرية'}',
            style: _textStyle(
              fontSize: cashier ? 14 : 20,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'حلقة $halaqahName${mosqueName.isEmpty ? '' : ' — مسجد $mosqueName'}',
            style: _textStyle(fontSize: cashier ? 8 : 11),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(7),
            color: _pdfPrimarySoft,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(student.name, style: _textStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  'من ${Helpers.formatPlanDate(plan.startDate)} إلى ${Helpers.formatPlanDate(plan.endDate)}',
                  style: _textStyle(fontSize: cashier ? 7 : 10),
                ),
                pw.Text(
                  '${revisionOnly ? '' : 'الحفظ: ${plan.newAmount} $unit — '}'
                  'المراجعة: ${plan.reviewAmount} $reviewUnit — '
                  'السرد/التلاوة: ${plan.recitationAmount} $unit يوميًا',
                  style: _textStyle(fontSize: cashier ? 7 : 10),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: _pdfMuted, width: 0.5),
            columnWidths: _rtlColumnWidths(columnWidths, tableHeaders.length),
            children: [
              _rtlTableRow(
                tableHeaders.map((label) =>
                    pw.Padding(
                      padding: pw.EdgeInsets.all(cashier ? 3 : 6),
                      child: pw.Text(
                        label,
                        style: _textStyle(
                          fontSize: cashier ? 7 : 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    )).toList(),
                decoration: const pw.BoxDecoration(color: _pdfPrimarySoft),
              ),
              ...days.map(
                (day) {
                  final assignment = assignmentByDate[_dateKey(day)]!;
                  return _rtlTableRow(<pw.Widget>[
                      _planCell(Helpers.formatPlanDate(day, separator: '\n'), cashier),
                      if (!revisionOnly)
                        _planCell(
                          assignment.memorizationRange,
                          cashier,
                        ),
                      _planCell(
                        assignment.reviewRange,
                        cashier,
                      ),
                      _planCell(
                        assignment.recitationRange,
                        cashier,
                      ),
                      _planCheckCell(cashier),
                    ]);
                },
              ),
            ],
          ),
          if (plan.notes?.isNotEmpty ?? false) ...[
            pw.SizedBox(height: 8),
            pw.Text('ملاحظات: ${plan.notes}', style: _textStyle(fontSize: cashier ? 7 : 10)),
          ],
          pw.SizedBox(height: 14),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('المعلم: __________', style: _textStyle(fontSize: cashier ? 7 : 10)),
              pw.Text('ولي الأمر: __________', style: _textStyle(fontSize: cashier ? 7 : 10)),
            ],
          ),
        ],
      ),
    );
    return pdf.save();
  }

  /// ملف A4 واحد لخطط عدة طلاب، مع بدء كل طالب في صفحة مستقلة.
  Future<Uint8List> generateAllSmartPlans({
    required List<Student> students,
    required List<SmartPlan> plans,
    required String halaqahName,
    String mosqueName = '',
    List<int> holidayWeekdays = const [5],
    required Map<String, List<SmartPlanDailyAssignment>> dailyAssignmentsByPlan,
  }) async {
    if (plans.isEmpty) throw ArgumentError('لا توجد خطط للتصدير');
    await _loadFonts();
    final studentById = {for (final student in students) student.id: student};
    final pdf = pw.Document(theme: _pdfTheme);

    for (final plan in plans) {
      final student = studentById[plan.studentId];
      if (student == null) continue;
      final assignments = dailyAssignmentsByPlan[plan.id] ?? const [];
      SmartPlanPrintPolicy.validateExactAssignments(
        student: student,
        plan: plan,
        assignments: assignments,
      );
      final assignmentByDate = {
        for (final assignment in assignments)
          _dateKey(assignment.date): assignment,
      };
      final days = assignments.map((assignment) => assignment.date).toList();
      final unit = _getPlanLabel(plan.unit);
      final reviewUnit = _getPlanLabel(plan.reviewUnit);
      final revisionOnly = StudentLearningPolicy.hasCompletedQuran(student);
      final tableHeaders = revisionOnly
          ? const ['اليوم', 'المراجعة', 'السرد', 'تم']
          : const ['اليوم', 'الحفظ', 'المراجعة', 'السرد', 'تم'];
      pdf.addPage(
        pw.MultiPage(
        theme: _pdfTheme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          textDirection: pw.TextDirection.rtl,
          build: (_) => [
            pw.Text(
              'خطة ${student.name}',
              style: _textStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              'حلقة $halaqahName${mosqueName.isEmpty ? '' : ' — مسجد $mosqueName'}',
              style: _textStyle(fontSize: 10, color: _pdfMuted),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: const pw.BoxDecoration(color: _pdfPrimarySoft),
              child: pw.Text(
                '${student.displayCode} — من ${Helpers.formatPlanDate(plan.startDate)} إلى '
                '${Helpers.formatPlanDate(plan.endDate)} — '
                '${revisionOnly ? '' : 'حفظ ${plan.newAmount} $unit و'}'
                'مراجعة ${plan.reviewAmount} $reviewUnit وسرد '
                '${plan.recitationAmount} $unit يوميًا',
                style: _textStyle(fontSize: 10),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: _pdfMuted, width: 0.5),
              columnWidths: _rtlColumnWidths(
                revisionOnly
                    ? const {
                        0: pw.FlexColumnWidth(1.5),
                        1: pw.FlexColumnWidth(1.25),
                        2: pw.FlexColumnWidth(1.25),
                        3: pw.FlexColumnWidth(0.7),
                      }
                    : const {
                        0: pw.FlexColumnWidth(1.5),
                        1: pw.FlexColumnWidth(1),
                        2: pw.FlexColumnWidth(1),
                        3: pw.FlexColumnWidth(1),
                        4: pw.FlexColumnWidth(0.7),
                      },
                tableHeaders.length,
              ),
              children: [
                _rtlTableRow(
                  tableHeaders.map((label) => _planCell(label, false)).toList(),
                  decoration: const pw.BoxDecoration(color: _pdfPrimarySoft),
                ),
                ...days.map(
                  (day) {
                    final assignment = assignmentByDate[_dateKey(day)]!;
                    return _rtlTableRow(<pw.Widget>[
                        _planCell(Helpers.formatPlanDate(day, separator: '\n'), false),
                        if (!revisionOnly)
                          _planCell(
                            assignment.memorizationRange,
                            false,
                          ),
                        _planCell(
                          assignment.reviewRange,
                          false,
                        ),
                        _planCell(
                          assignment.recitationRange,
                          false,
                        ),
                        _planCheckCell(false),
                      ]);
                  },
                ),
              ],
            ),
            if (plan.notes?.isNotEmpty ?? false) ...[
              pw.SizedBox(height: 8),
              pw.Text('ملاحظات: ${plan.notes}', style: _textStyle(fontSize: 10)),
            ],
            pw.SizedBox(height: 14),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('المعلم: __________', style: _textStyle(fontSize: 10)),
                pw.Text('ولي الأمر: __________', style: _textStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
      );
    }
    return pdf.save();
  }

  pw.Widget _planCell(String value, bool cashier) => pw.Padding(
        padding: pw.EdgeInsets.all(cashier ? 3 : 6),
        child: pw.Text(
          value,
          style: _textStyle(fontSize: cashier ? 6.5 : 9),
          textAlign: pw.TextAlign.center,
        ),
      );

  pw.Widget _planCheckCell(bool cashier) => pw.Center(
        child: pw.Container(
          width: cashier ? 9 : 13,
          height: cashier ? 9 : 13,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _pdfMuted, width: 0.8),
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
      );


  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  pw.Widget _periodStat(String label, String value, PdfColor color) {
    return pw.Container(
      width: 105,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 0.6),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(children: [
        pw.Text(value, style: _textStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
        pw.Text(label, style: _textStyle(fontSize: 7)),
      ]),
    );
  }

  pw.Widget _periodCell(
    String text, {
    bool bold = false,
    PdfColor? color,
    double fontSize = 6.5,
    pw.TextAlign textAlign = pw.TextAlign.center,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3.5, vertical: 3),
        child: pw.Text(
          text,
          style: _textStyle(
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : null,
            color: color ?? _pdfInk,
          ),
          textAlign: textAlign,
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
        ),
      );

  String _fundTypeLabel(String type) {
    switch (type) {
      case 'subscription':
        return 'اشتراك';
      case 'penalty':
        return 'غرامة';
      case 'donation':
        return 'تبرع';
      case 'expense':
        return 'مصروف';
      default:
        return type;
    }
  }

  String _reportDate(DateTime date, {bool hijri = false}) => hijri
      ? Helpers.getFullHijriDate(date)
      : '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

  String _periodAttendance(StudentPeriodDay day) {
    if (day.isSuspended) return 'معلّق';
    if (day.isWeeklyHoliday) return 'إجازة أسبوعية';
    if (day.hold != null) return 'حاضر — التسميع موقوف';
    switch (day.record?.attendance) {
      case 'present':
        return 'حاضر';
      case 'late':
        return day.lateMinutes > 0
            ? 'متأخر ${day.lateMinutes} د'
            : 'متأخر';
      case 'absent':
        return 'غائب';
      case 'excused':
        return 'مستأذن';
      default:
        return 'لا يوجد سجل';
    }
  }

  String _progressText(List<dynamic> items) {
    if (items.isEmpty) return '—';
    return items.map((dynamic item) {
      final surah = QuranService.instance.getSurahName(item.surahId as int);
      return '$surah ${item.fromAyah}-${item.toAyah}';
    }).join('، ');
  }

  String _periodNote(StudentPeriodDay day) {
    if (day.isSuspended) return day.suspensionReason ?? 'تعليق الدراسة';
    if (day.isWeeklyHoliday) return 'الإجازة الأسبوعية';
    if (day.hold != null) {
      final note = day.hold!.notes?.trim();
      return 'إيقاف التسميع: ${day.hold!.reason}'
          '${note == null || note.isEmpty ? '' : ' — $note'}';
    }
    if (day.vacation != null) {
      final vacation = day.vacation!;
      final note = vacation.notes?.trim();
      return '${VacationReason.getLabel(vacation.reason)}${note == null || note.isEmpty ? '' : ': $note'}';
    }
    final pointReasons = day.points
        .map((point) => BehaviorReason.getLabel(point.reason))
        .toList();
    final notes = [
      day.record?.absenceNote,
      day.record?.memorizationNote,
      day.record?.revisionNote,
      day.record?.notes,
      ...pointReasons,
    ].where((item) => item != null && item.toString().trim().isNotEmpty);
    return notes.join('، ');
  }

  PdfColor _scorePdfColor(int score) {
    if (score >= 80) return _pdfSuccess;
    if (score >= 60) return _pdfWarning;
    return _pdfDanger;
  }

  Future<Uint8List> generateWeeklyReport(
    DateTime startDate,
    List<Student> students,
    Map<String, List<DailyRecord>> weeklyRecords,
    String halaqahName,
  ) async {
    await _loadFonts();

    final pdf = pw.Document(theme: _pdfTheme);

    pdf.addPage(
      pw.MultiPage(
        theme: _pdfTheme,
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

    final pdf = pw.Document(theme: _pdfTheme);

    pdf.addPage(
      pw.MultiPage(
        theme: _pdfTheme,
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

    final pdf = pw.Document(theme: _pdfTheme);

    pdf.addPage(
      pw.Page(
        theme: _pdfTheme,
        pageFormat: PdfPageFormat.a5,
        textDirection: pw.TextDirection.rtl,
        build: (context) => pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _pdfPrimaryLight, width: 0.8),
            borderRadius: pw.BorderRadius.circular(10),
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
                style: _textStyle(fontSize: 14, color: _pdfMuted),
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
                  color: _pdfAccentSoft,
                  border: pw.Border.all(color: _pdfAccent, width: 0.35),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Text(
                  'تعتمد صحة هذا التقرير على البيانات المدخلة',
                  style: _textStyle(fontSize: 9, color: _pdfMuted),
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

    final pdf = pw.Document(theme: _pdfTheme);

    pdf.addPage(
      pw.MultiPage(
        theme: _pdfTheme,
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
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: pw.BoxDecoration(
        color: _pdfPrimarySoft,
        border: pw.Border.all(color: _pdfPrimaryLight, width: 0.6),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 6,
            height: 48,
            decoration: pw.BoxDecoration(
              color: _pdfPrimary,
              borderRadius: pw.BorderRadius.circular(3),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  reportTitle,
                  style: _textStyle(
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                    color: _pdfPrimaryDark,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'حلقة $halaqahName',
                  style: _textStyle(fontSize: 10, color: _pdfMuted),
                ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: pw.BoxDecoration(
              color: _pdfSurface,
              border: pw.Border.all(color: _pdfBorder),
              borderRadius: pw.BorderRadius.circular(999),
            ),
            child: pw.Text(
              'حلقتي',
              style: _textStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: _pdfAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(color: _pdfBorder),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: pw.BoxDecoration(
            color: _pdfAccentSoft,
            border: pw.Border.all(color: _pdfAccent, width: 0.35),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Text(
            'تعتمد صحة هذا التقرير على البيانات المدخلة · تم الإنشاء بواسطة تطبيق حلقتي',
            style: _textStyle(fontSize: 8, color: _pdfMuted),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildDateRow(DateTime date) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _pdfPrimarySoft,
        border: pw.Border.all(color: _pdfPrimaryLight, width: 0.4),
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
        color: _pdfPrimarySoft,
        border: pw.Border.all(color: _pdfPrimaryLight, width: 0.4),
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
        color: _pdfAccentSoft,
        border: pw.Border.all(color: _pdfAccent, width: 0.4),
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
        _buildStatBox('حاضر', '$present', _pdfSuccess),
        _buildStatBox('متأخر', '$late', _pdfWarning),
        _buildStatBox('غائب', '$absent', _pdfDanger),
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
        _buildStatBox('عدد الطلاب', '${students.length}', _pdfPrimary),
        _buildStatBox('إجمالي الحضور', '$totalPresent', _pdfSuccess),
        _buildStatBox('إجمالي التأخير', '$totalLate', _pdfWarning),
        _buildStatBox('إجمالي الغياب', '$totalAbsent', _pdfDanger),
      ],
    );
  }

  pw.Widget _buildMonthlyStatsSection(Map<String, dynamic> stats) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatBox('الطلاب', '${stats['totalStudents'] ?? 0}', _pdfPrimary),
        _buildStatBox('نسبة الحضور', '${stats['attendanceRate'] ?? 0}%', _pdfSuccess),
        _buildStatBox('إجمالي الحفظ', '${stats['totalMemorized'] ?? 0}', _pdfAccent),
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
            style: _textStyle(fontSize: 10, color: _pdfMuted),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStudentsDailyTable(List<DailyRecord> records, List<Student> students) {
    final studentMap = {for (var s in students) s.id: s};
    
    return pw.Table(
      border: pw.TableBorder.all(color: _pdfBorder, width: 0.45),
      children: [
        _rtlTableRow(
          [
            _buildTableCell('الطالب', isHeader: true),
            _buildTableCell('الحضور', isHeader: true),
            _buildTableCell('الحفظ', isHeader: true),
            _buildTableCell('المراجعة', isHeader: true),
          ],
          decoration: const pw.BoxDecoration(color: _pdfPrimarySoft),
        ),
        ...records.map((record) {
          final student = studentMap[record.studentId];
          return _rtlTableRow([
            _buildTableCell(student?.name ?? '-'),
            _buildTableCell(_getAttendanceLabel(record.attendance)),
            _buildTableCell(record.memorizationDone ? 'مكتمل' : '-'),
            _buildTableCell(record.revisionDone ? 'مكتمل' : '-'),
          ]);
        }),
      ],
    );
  }

  pw.Widget _buildStudentsWeeklyTable(
    List<Student> students,
    Map<String, List<DailyRecord>> weeklyRecords,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: _pdfBorder, width: 0.45),
      children: [
        _rtlTableRow(
          [
            _buildTableCell('الطالب', isHeader: true),
            _buildTableCell('الحضور', isHeader: true),
            _buildTableCell('الغياب', isHeader: true),
            _buildTableCell('الحفظ', isHeader: true),
          ],
          decoration: const pw.BoxDecoration(color: _pdfPrimarySoft),
        ),
        ...students.map((student) {
          final records = weeklyRecords[student.id] ?? [];
          final present = records.where((r) => r.attendance == 'present' || r.attendance == 'late').length;
          final absent = records.where((r) => r.attendance == 'absent').length;
          final memorized = records.where((r) => r.memorizationDone).length;

          return _rtlTableRow([
            _buildTableCell(student.name),
            _buildTableCell('$present'),
            _buildTableCell('$absent'),
            _buildTableCell('$memorized'),
          ]);
        }),
      ],
    );
  }

  pw.Widget _buildStudentsMonthlyTable(List<Student> students, Map<String, dynamic> stats) {
    return pw.Table(
      border: pw.TableBorder.all(color: _pdfBorder, width: 0.45),
      children: [
        _rtlTableRow(
          [
            _buildTableCell('الطالب', isHeader: true),
            _buildTableCell('الحفظ', isHeader: true),
            _buildTableCell('النقاط', isHeader: true),
          ],
          decoration: const pw.BoxDecoration(color: _pdfPrimarySoft),
        ),
        ...students.map((student) {
          return _rtlTableRow([
            _buildTableCell(student.name),
            _buildTableCell('${student.totalMemorized}'),
            _buildTableCell('${stats['points_${student.id}'] ?? 0}'),
          ]);
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
        color: _pdfPrimarySoft,
        border: pw.Border.all(color: _pdfPrimaryLight, width: 0.4),
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
            color: _pdfBackground,
            border: pw.Border.all(color: _pdfBorder, width: 0.4),
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
        color: _pdfPrimarySoft,
        border: pw.Border.all(color: _pdfPrimaryLight, width: 0.4),
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
            style: _textStyle(fontSize: 11, color: _pdfMuted),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStudentStatsSection(Map<String, dynamic> data) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatBox('إجمالي الحفظ', '${data['totalMemorized'] ?? 0}', _pdfSuccess),
        _buildStatBox('النقاط', '${data['points'] ?? 0}', _pdfPrimary),
        _buildStatBox('الحضور', '${data['attendanceRate'] ?? 0}%', _pdfAccent),
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
          border: pw.TableBorder.all(color: _pdfBorder, width: 0.45),
          children: [
            _rtlTableRow(
              [
                _buildTableCell('التاريخ', isHeader: true),
                _buildTableCell('السورة', isHeader: true),
                _buildTableCell('الآيات', isHeader: true),
              ],
              decoration: const pw.BoxDecoration(color: _pdfPrimarySoft),
            ),
            ...memorization.take(10).map((m) => _rtlTableRow([
                  _buildTableCell(m['date'] ?? '-'),
                  _buildTableCell(m['surah'] ?? '-'),
                  _buildTableCell('${m['from'] ?? ''}-${m['to'] ?? ''}'),
                ])),
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
          border: pw.TableBorder.all(color: _pdfBorder, width: 0.45),
          children: [
            _rtlTableRow(
              [
                _buildTableCell('التاريخ', isHeader: true),
                _buildTableCell('النطاق', isHeader: true),
                _buildTableCell('النتيجة', isHeader: true),
              ],
              decoration: const pw.BoxDecoration(color: _pdfPrimarySoft),
            ),
            ...exams.take(10).map((e) => _rtlTableRow([
                  _buildTableCell(e['date'] ?? '-'),
                  _buildTableCell(e['range'] ?? '-'),
                  _buildTableCell('${e['score'] ?? 0}%'),
                ])),
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
      case 'hizbs':
        return 'حزب';
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

    final pdf = pw.Document(theme: _pdfTheme);

    String scoreLabel;
    PdfColor scoreColor;
    if (exam.score >= 90) {
      scoreLabel = 'ممتاز';
      scoreColor = _pdfSuccess;
    } else if (exam.score >= 80) {
      scoreLabel = 'جيد جداً';
      scoreColor = _pdfPrimaryLight;
    } else if (exam.score >= 70) {
      scoreLabel = 'جيد';
      scoreColor = _pdfAccent;
    } else if (exam.score >= 60) {
      scoreLabel = 'مقبول';
      scoreColor = _pdfWarning;
    } else {
      scoreLabel = 'ضعيف';
      scoreColor = _pdfDanger;
    }

    pdf.addPage(
      pw.Page(
        theme: _pdfTheme,
        pageFormat: PdfPageFormat.a5,
        textDirection: pw.TextDirection.rtl,
        build: (context) => pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _pdfPrimaryLight, width: 0.8),
            borderRadius: pw.BorderRadius.circular(10),
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
                style: _textStyle(fontSize: 14, color: _pdfMuted),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 15),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: _pdfPrimarySoft,
                  border: pw.Border.all(color: _pdfPrimaryLight, width: 0.45),
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
                style: _textStyle(fontSize: 9, color: _pdfMuted),
              ),
              pw.SizedBox(height: 15),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: _pdfAccentSoft,
                  border: pw.Border.all(color: _pdfAccent, width: 0.35),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Text(
                  'تم الإنشاء بواسطة تطبيق حلقتي',
                  style: _textStyle(fontSize: 8, color: _pdfMuted),
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

  Future<Uint8List> generateExamPaper({
    required Student student,
    required String category,
    required List<Map<String, dynamic>> questions,
    required PdfPageFormat pageFormat,
    String halaqahName = 'حلقتي',
  }) async {
    await _loadFonts();
    final pdf = pw.Document(theme: _pdfTheme);
    final assessedQuestions = questions
        .where((question) => question['is_assessed'] == true)
        .toList();
    final assessedScore = assessedQuestions.fold<double>(
      0,
      (sum, question) =>
          sum + ((question['question_score'] as num?)?.toDouble() ?? 0),
    );

    pdf.addPage(
      pw.MultiPage(
        theme: _pdfTheme,
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(24),
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: pw.BoxDecoration(
              color: _pdfPrimarySoft,
              border: pw.Border.all(color: _pdfPrimaryLight, width: 0.7),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('حلقة $halaqahName', style: _textStyle(fontSize: 10, color: _pdfMuted)),
                pw.Text(
                  'نموذج اختبار القرآن الكريم',
                  style: _textStyle(
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                    color: _pdfPrimaryDark,
                  ),
                ),
                pw.Text('التاريخ:    /    /', style: _textStyle(fontSize: 9, color: _pdfMuted)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _pdfMuted),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('اسم الطالب: ${student.name}', style: _textStyle(fontSize: 11)),
                pw.Text('كود الطالب: ${student.displayCode}', style: _textStyle(fontSize: 9)),
                pw.Text('الفئة: $category', style: _textStyle(fontSize: 10)),
                pw.Text('النموذج: ........', style: _textStyle(fontSize: 10)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: _pdfBorder, width: 0.6),
            columnWidths: _rtlColumnWidths(
              const {
                0: pw.FixedColumnWidth(24),
                1: pw.FlexColumnWidth(4),
                2: pw.FixedColumnWidth(32),
                3: pw.FixedColumnWidth(32),
                4: pw.FixedColumnWidth(32),
                5: pw.FixedColumnWidth(32),
                6: pw.FixedColumnWidth(34),
              },
              7,
            ),
            children: [
              _rtlTableRow(
                ['م', 'السؤال', 'الحفظ', 'التشكيل', 'التلاوة', 'التنبيه', 'الدرجة']
                    .map((text) => pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            text,
                            textAlign: pw.TextAlign.center,
                            style: _textStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                          ),
                        ))
                    .toList(),
                decoration: const pw.BoxDecoration(color: _pdfPrimarySoft),
                repeat: true,
              ),
              ...questions.asMap().entries.map((entry) {
                final question = entry.value;
                final questionType = question['question_type'] as String?;
                final instruction = switch (questionType) {
                  'complete_ayah' => 'أكمل الآية من قوله تعالى',
                  'ayah_location' => 'اذكر السورة وموضع قوله تعالى',
                  _ => 'اقرأ من قوله تعالى في سورة ${question['surah_name']}',
                };
                final startText = _normalizeQuranTextForPdf(
                    question['start_text']?.toString() ?? '',
                  );
                final prompt = '$instruction: «$startText ...»';
                final assessed = question['is_assessed'] == true;
                String count(String field) =>
                    assessed ? '${(question[field] as num?)?.toInt() ?? 0}' : '';
                return _rtlTableRow(
                  [
                    '${entry.key + 1}',
                    prompt,
                    count('memorization_errors'),
                    count('tashkeel_errors'),
                    count('recitation_errors'),
                    count('prompt_count'),
                    assessed
                        ? ((question['question_score'] as num?) ?? 0)
                            .toStringAsFixed(1)
                        : '',
                  ].map((text) => pw.Container(
                        constraints: const pw.BoxConstraints(minHeight: 42),
                        padding: const pw.EdgeInsets.all(5),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          text,
                          textAlign: pw.TextAlign.center,
                          style: _textStyle(fontSize: 8),
                        ),
                      )).toList(),
                );
              }),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            assessedQuestions.isEmpty
                ? 'النتيجة: ........ / ........    التقدير: ....................'
                : 'النتيجة: ${assessedScore.toStringAsFixed(1)} / '
                    '${assessedQuestions.length * 10}    '
                    'نسبة الأسئلة المرصودة: '
                    '${(assessedScore / (assessedQuestions.length * 10) * 100).toStringAsFixed(0)}٪',
            style: _textStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 12),
          pw.Text('ملاحظة: ................................................................................', style: _textStyle(fontSize: 9)),
          pw.SizedBox(height: 30),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Text('مدرس الحلقة\n................', textAlign: pw.TextAlign.center, style: _textStyle(fontSize: 9)),
              pw.Text('لجنة الاختبار\n................', textAlign: pw.TextAlign.center, style: _textStyle(fontSize: 9)),
              pw.Text('المشرف\n................', textAlign: pw.TextAlign.center, style: _textStyle(fontSize: 9)),
            ],
          ),
        ],
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
          pw.Text(label, style: _textStyle(fontSize: 11, color: _pdfMuted)),
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

  pw.Widget _diagnosticSectionTitle(String title) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 6),
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(
          color: _pdfPrimarySoft,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: _pdfBorder),
        ),
        child: pw.Text(
          title,
          textAlign: pw.TextAlign.right,
          style: _textStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
      );

  Future<Uint8List> generateArabicFontDiagnosticPdf() async {
    await _loadFonts();
    final pdf = pw.Document(theme: _pdfTheme);
    const alphabet = 'ابتثجحخدذرزسشصضطظعغفقكلمنهوي ة ى ئ ؤ أ إ آ';
    const sample =
        'بسم الله الرحمن الرحيم — هذا اختبار لاتصال الحروف العربية ووضوحها في ملف PDF.';
    const quranSample =
        'الحمد لله رب العالمين الرحمن الرحيم مالك يوم الدين';
    pdf.addPage(
      pw.Page(
        theme: _pdfTheme,
        textDirection: pw.TextDirection.rtl,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildHeader('حلقتي', 'اختبار الخط العربي - Tajawal موحد'),
              pw.SizedBox(height: 20),
              _diagnosticSectionTitle('نص عربي متصل'),
              pw.Text(sample, style: _textStyle(fontSize: 16)),
              pw.SizedBox(height: 14),
              _diagnosticSectionTitle('الحروف'),
              pw.Text(alphabet, style: _textStyle(fontSize: 16)),
              pw.SizedBox(height: 14),
              _diagnosticSectionTitle('نص قرآني مبسط'),
              pw.Text(
                _normalizeQuranTextForPdf(quranSample),
                style: _textStyle(fontSize: 16),
              ),
              pw.SizedBox(height: 14),
              _diagnosticSectionTitle('أرقام ورموز أساسية'),
              pw.Text(
                '١٢٣٤٥٦٧٨٩٠ — 1234567890 — % / - :',
                style: _textStyle(fontSize: 14),
              ),
              pw.Spacer(),
              pw.Text(
                'إذا ظهرت هذه الصفحة سليمة فمحرك الخط العربي يعمل، وأي خلل لاحق يكون في قالب التقرير نفسه.',
                textAlign: pw.TextAlign.center,
                style: _textStyle(fontSize: 10, color: _pdfMuted),
              ),
            ],
          ),
        ),
      ),
    );
    return pdf.save();
  }

  Future<void> printDocument(Uint8List pdfData) async {
    await Printing.layoutPdf(onLayout: (_) => pdfData);
  }

  Future<void> sharePdf(Uint8List pdfData, String filename) async {
    await Printing.sharePdf(bytes: pdfData, filename: filename);
  }
}
