import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/settings.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../services/pdf_service.dart';
import '../../services/qr_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_design_widgets.dart';

class StudentReceiptScreen extends StatefulWidget {
  final Student student;

  const StudentReceiptScreen({
    super.key,
    required this.student,
  });

  @override
  State<StudentReceiptScreen> createState() => _StudentReceiptScreenState();
}

class _StudentReceiptScreenState extends State<StudentReceiptScreen> {
  final DatabaseService _db = DatabaseService();
  final PdfService _pdf = PdfService();

  Map<String, dynamic>? _statistics;
  double _points = 0;
  HalaqahSettings _settings = HalaqahSettings();
  bool _loading = true;
  String? _error;

  Map<String, dynamic> get _attendance =>
      _statistics?['attendance'] as Map<String, dynamic>? ??
      const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _db.getStudentStatistics(widget.student.id),
        _db.getStudentTotalPoints(widget.student.id),
        _db.getSettings(),
      ]);
      if (!mounted) return;
      setState(() {
        _statistics = Map<String, dynamic>.from(
          results[0] as Map<String, dynamic>,
        );
        _points = (results[1] as num).toDouble();
        _settings = results[2] as HalaqahSettings;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سند استلام الطالب')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? AppScreenBody(
                  child: AppEmptyState(
                    icon: Icons.error_outline,
                    title: 'تعذر إعداد السند',
                    message: _error!,
                    action: FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ),
                )
              : AppScreenBody(
                  scrollable: true,
                  maxWidth: 680,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppPageIntro(
                        title: widget.student.name,
                        subtitle:
                            '${_settings.halaqahName} · ${Helpers.getFullHijriDate(DateTime.now())}',
                        icon: Icons.receipt_long_outlined,
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              _row(
                                'إجمالي المحفوظ',
                                '${widget.student.totalMemorized} آية',
                              ),
                              _row(
                                'أيام الحضور',
                                '${_attendance['present'] ?? 0}',
                              ),
                              _row(
                                'أيام التأخير',
                                '${_attendance['late'] ?? 0}',
                              ),
                              _row(
                                'أيام الغياب',
                                '${_attendance['absent'] ?? 0}',
                              ),
                              _row('رصيد النقاط', Helpers.formatNumber(_points)),
                              const Divider(height: 28),
                              const Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  'توقيع ولي الأمر: ____________________',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _print,
                              icon: const Icon(Icons.print_outlined),
                              label: const Text('طباعة السند'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _shareSummary,
                              icon: const Icon(Icons.share_outlined),
                              label: const Text('مشاركة الملخص'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'تعتمد صحة السند على سجلات الحضور والتسميع المدخلة.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AppResponsiveInfoRow(
          label: label,
          value: value,
          valueStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );

  Future<void> _print() async {
    try {
      final stats = _statistics ?? const <String, dynamic>{};
      final qrData = QrService.generateQrData(widget.student.qrCode);
      final bytes = await _pdf.generateStudentReceipt(
        widget.student,
        stats,
        _settings.halaqahName,
        _settings.mosqueName,
        qrData,
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذرت طباعة السند: $error')),
      );
    }
  }

  Future<void> _shareSummary() => Share.share(
        'سند متابعة ${widget.student.name}\n'
        'الحفظ: ${widget.student.totalMemorized} آية\n'
        'الحضور: ${_attendance['present'] ?? 0}\n'
        'الغياب: ${_attendance['absent'] ?? 0}\n'
        'النقاط: $_points',
        subject: 'سند متابعة ${widget.student.name}',
      );
}
