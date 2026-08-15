import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/database_service.dart';

class ModelHalaqahScreen extends StatefulWidget {
  const ModelHalaqahScreen({super.key});

  @override
  State<ModelHalaqahScreen> createState() => _ModelHalaqahScreenState();
}

class _ModelHalaqahScreenState extends State<ModelHalaqahScreen> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _notesController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _saving = false;

  static const List<String> _criteria = [
    'انتظام التحضير',
    'اكتمال التسميع',
    'تنفيذ المراجعة',
    'التلقين والمتابعة التعليمية',
    'الانضباط والسلوك',
    'النشاط التربوي',
    'التواصل مع الأسرة',
    'تهيئة الحلقة ونظافة المكان',
  ];

  final Map<String, int> _scores = {
    for (final criterion in _criteria) criterion: 0,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String get _dateKey =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await _db.getSetting('model_halaqah_evaluation_$_dateKey');
      for (final criterion in _criteria) {
        _scores[criterion] = 0;
      }
      _notesController.clear();
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final storedScores = decoded['scores'];
          if (storedScores is Map) {
            for (final criterion in _criteria) {
              final value = storedScores[criterion];
              if (value is num) _scores[criterion] = value.toInt().clamp(0, 2).toInt();
            }
          }
          _notesController.text = decoded['notes']?.toString() ?? '';
        }
      }
    } catch (_) {
      // يبقى النموذج فارغاً عند فساد سجل يوم منفرد، دون تعطيل الشاشة كلها.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _earned => _scores.values.fold<int>(0, (sum, value) => sum + value);
  int get _maximum => _criteria.length * 2;
  int get _percentage => _maximum == 0 ? 0 : ((_earned / _maximum) * 100).round();

  String get _level {
    if (_percentage >= 90) return 'حلقة نموذجية متميزة';
    if (_percentage >= 75) return 'حلقة نموذجية';
    if (_percentage >= 60) return 'جيدة وتحتاج تحسينات محددة';
    return 'تحتاج خطة تحسين';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _date = picked);
    await _load();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _db.saveSetting(
        'model_halaqah_evaluation_$_dateKey',
        jsonEncode({
          'date': _dateKey,
          'scores': _scores,
          'earned': _earned,
          'maximum': _maximum,
          'percentage': _percentage,
          'level': _level,
          'notes': _notesController.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ تقييم الحلقة النموذجية')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نظام الحلقة النموذجية'),
        actions: [
          IconButton(
            tooltip: 'اختيار اليوم',
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.workspace_premium_outlined),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'تقييم $_dateKey',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              '$_percentage%',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: _percentage / 100),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(_level),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ..._criteria.map(
                  (criterion) => Card(
                    child: ListTile(
                      title: Text(criterion),
                      subtitle: Text(
                        switch (_scores[criterion] ?? 0) {
                          2 => 'مكتمل',
                          1 => 'جزئي',
                          _ => 'غير منفذ',
                        },
                      ),
                      trailing: DropdownButton<int>(
                        value: _scores[criterion] ?? 0,
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('0')),
                          DropdownMenuItem(value: 1, child: Text('1')),
                          DropdownMenuItem(value: 2, child: Text('2')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _scores[criterion] = value);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات وخطة التحسين',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ تقييم اليوم'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'كل معيار من درجتين: 0 غير منفذ، 1 جزئي، 2 مكتمل. '
                  'التقييم يومي ومستقل، ويمكن الرجوع لأي يوم من زر التقويم.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}
