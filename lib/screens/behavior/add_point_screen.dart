import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';
import '../../models/behavior_point.dart';
import '../../models/settings.dart';
import '../../utils/helpers.dart';

class AddPointScreen extends StatefulWidget {
  final Student? student;

  const AddPointScreen({super.key, this.student});

  @override
  State<AddPointScreen> createState() => _AddPointScreenState();
}

class _AddPointScreenState extends State<AddPointScreen> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  final Set<String> _selectedStudentIds = <String>{};
  List<Student> _students = [];
  bool _isPositive = true;
  final Set<String> _selectedReasonIds = <String>{};
  int _customPoints = 0;
  String _notes = '';
  bool _isLoading = true;
  bool _isSaving = false;

  HalaqahSettings _settings = HalaqahSettings();

  List<PointReason> get positiveReasons {
    final list = [
      PointReason('memorization_complete', 'إتمام الحفظ اليومي', _settings.pointsConfig['daily_memorization'] ?? 5),
      PointReason('extra_memorization', 'زيادة عن المقرر', _settings.pointsConfig['extra_memorization'] ?? 2),
      PointReason('early_attendance', 'الحضور المبكر', _settings.pointsConfig['early_attendance'] ?? 2),
      PointReason('revision_complete', 'إتمام المراجعة', _settings.pointsConfig['revision_complete'] ?? 3),
      PointReason('exam_success', 'نجاح في الامتحان', _settings.pointsConfig['monthly_exam_pass'] ?? 10),
      PointReason('good_appearance', 'المظهر الحسن', _settings.pointsConfig['good_appearance'] ?? 1),
    ];
    
    _settings.pointsConfig.forEach((key, val) {
      if (key.startsWith('c_') && val >= 0) {
        final label = key.substring(2);
        list.add(PointReason(key, label, val));
      }
    });
    
    list.add(const PointReason('custom_positive', 'أخرى (مخصص)', 0));
    return list;
  }

  List<PointReason> get negativeReasons {
    final list = [
      PointReason('late', 'التأخير', _settings.pointsConfig['late_penalty'] ?? -2),
      PointReason('incomplete_memorization', 'عدم إتمام المقرر', _settings.pointsConfig['incomplete_penalty'] ?? -3),
      PointReason('absence_no_excuse', 'الغياب بدون عذر', _settings.pointsConfig['unexcused_absence'] ?? -5),
      PointReason('appearance_violation', 'مخالفة المظهر/الحلاقة', _settings.pointsConfig['appearance_violation'] ?? -3),
      PointReason('no_thobe', 'عدم لبس الثوب', _settings.pointsConfig['no_thobe'] ?? -3),
    ];
    
    _settings.pointsConfig.forEach((key, val) {
      if (key.startsWith('c_') && val < 0) {
        final label = key.substring(2);
        list.add(PointReason(key, label, val));
      }
    });
    
    list.add(const PointReason('custom_negative', 'أخرى (مخصص)', 0));
    return list;
  }

  @override
  void initState() {
    super.initState();
    if (widget.student != null) {
      _selectedStudentIds.add(widget.student!.id);
    }
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final students = await _db.getStudents(status: 'active');
      final settings = await _db.getSettings();
      setState(() {
        _students = students;
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<PointReason> get _currentReasons =>
      _isPositive ? positiveReasons : negativeReasons;

  List<PointReason> get _selectedReasons => _currentReasons
      .where((reason) => _selectedReasonIds.contains(reason.id))
      .toList();

  bool get _hasCustomReason =>
      _selectedReasonIds.any((id) => id.startsWith('custom'));

  int _pointsForReason(PointReason reason) {
    if (reason.id.startsWith('custom')) {
      return _isPositive ? _customPoints.abs() : -_customPoints.abs();
    }
    return reason.points;
  }

  int get _pointsPerStudent => _selectedReasons.fold<int>(
        0,
        (sum, reason) => sum + _pointsForReason(reason),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة نقاط'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.student == null) _buildStudentSelector(),
                  if (_selectedStudentIds.isNotEmpty) ...[
                    _buildStudentInfo(),
                    const SizedBox(height: 16),
                  ],
                  _buildTypeSelector(),
                  const SizedBox(height: 16),
                  _buildReasonSelector(),
                  if (_hasCustomReason) ...[
                    const SizedBox(height: 16),
                    _buildCustomPointsInput(),
                  ],
                  const SizedBox(height: 16),
                  _buildPointsPreview(),
                  const SizedBox(height: 16),
                  _buildNotesField(),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  List<Student> get _selectedStudents {
    if (widget.student != null) return [widget.student!];
    return _students
        .where((student) => _selectedStudentIds.contains(student.id))
        .toList();
  }

  Widget _buildStudentSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'اختر طالبًا أو أكثر',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    if (_selectedStudentIds.length == _students.length) {
                      _selectedStudentIds.clear();
                    } else {
                      _selectedStudentIds
                        ..clear()
                        ..addAll(_students.map((student) => student.id));
                    }
                  }),
                  child: Text(
                    _selectedStudentIds.length == _students.length
                        ? 'إلغاء الكل'
                        : 'تحديد الكل',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _students.map((student) {
                final selected = _selectedStudentIds.contains(student.id);
                return FilterChip(
                  label: Text(_studentIdentity(student)),
                  selected: selected,
                  avatar: CircleAvatar(
                    child: Text(student.name.isEmpty ? '؟' : student.name[0]),
                  ),
                  onSelected: (value) => setState(() {
                    if (value) {
                      _selectedStudentIds.add(student.id);
                    } else {
                      _selectedStudentIds.remove(student.id);
                    }
                  }),
                );
              }).toList(),
            ),
            if (_selectedStudentIds.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'اختر طالبًا واحدًا على الأقل',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStudentInfo() {
    final selected = _selectedStudents;
    return Card(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            selected.length == 1
                ? (selected.first.name.isNotEmpty ? selected.first.name[0] : '؟')
                : '${selected.length}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          selected.length == 1
              ? selected.first.name
              : '${selected.length} طلاب محددين',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selected.length == 1
                  ? _guardianIdentity(selected.first)
                  : selected.map(_studentIdentity).join('، '),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (selected.length == 1)
              FutureBuilder<double>(
                future: _db.getStudentTotalPoints(selected.first.id),
                builder: (context, snapshot) => Text(
                  'الرصيد الحالي: ${Helpers.formatNumber(snapshot.data ?? 0)} نقطة',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('نوع النقاط', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() {
                      _isPositive = true;
                      _selectedReasonIds.clear();
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isPositive
                            ? Colors.green
                            : Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green,
                          width: _isPositive ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.add_circle,
                            color: _isPositive ? Colors.white : Colors.green,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'إيجابية',
                            style: TextStyle(
                              color: _isPositive ? Colors.white : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() {
                      _isPositive = false;
                      _selectedReasonIds.clear();
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: !_isPositive
                            ? Colors.red
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red,
                          width: !_isPositive ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.remove_circle,
                            color: !_isPositive ? Colors.white : Colors.red,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'سلبية',
                            style: TextStyle(
                              color: !_isPositive ? Colors.white : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonSelector() {
    final semantic = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'الأسباب',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  _selectedReasonIds.isEmpty
                      ? 'اختر واحدًا أو أكثر'
                      : '${_selectedReasonIds.length} محدد',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: semantic.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _currentReasons.map((reason) {
                final selected = _selectedReasonIds.contains(reason.id);
                final points = _pointsForReason(reason);
                return FilterChip(
                  selected: selected,
                  showCheckmark: true,
                  label: Text(
                    reason.id.startsWith('custom')
                        ? reason.label
                        : '${reason.label}  ${points > 0 ? '+' : ''}$points',
                  ),
                  onSelected: (value) => setState(() {
                    if (value) {
                      _selectedReasonIds.add(reason.id);
                    } else {
                      _selectedReasonIds.remove(reason.id);
                    }
                  }),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomPointsInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('عدد النقاط', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.star),
                suffixText: 'نقطة',
                hintText: _isPositive ? 'مثال: 5' : 'مثال: 3',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _customPoints = int.tryParse(value) ?? 0;
                });
              },
              validator: (value) {
                if (_hasCustomReason) {
                  final points = int.tryParse(value ?? '') ?? 0;
                  if (points <= 0) return 'يرجى إدخال عدد صحيح موجب';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsPreview() {
    if (_selectedReasonIds.isEmpty) return const SizedBox.shrink();

    final points = _pointsPerStudent;
    final accent = _isPositive ? Colors.green : Colors.red;
    final recordsCount = _selectedStudents.length * _selectedReasons.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(_isPositive ? Icons.add_circle_outline : Icons.remove_circle_outline,
              color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${points > 0 ? '+' : ''}$points نقطة لكل طالب',
                  style: TextStyle(fontWeight: FontWeight.bold, color: accent),
                ),
                Text(
                  '${_selectedReasons.length} أسباب × ${_selectedStudents.length} طلاب = $recordsCount سجلات مستقلة',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ملاحظات', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                hintText: 'أضف ملاحظات (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (value) => _notes = value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _savePoint,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isPositive ? Colors.green : Colors.red,
        ),
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('حفظ النقاط'),
      ),
    );
  }

  Future<void> _savePoint() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار طالب واحد على الأقل')),
      );
      return;
    }
    if (_selectedReasonIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر سببًا واحدًا على الأقل')),
      );
      return;
    }
    if (_hasCustomReason && _customPoints <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال عدد النقاط المخصصة')),
      );
      return;
    }

    final reasons = _selectedReasons;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد إسناد النقاط'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الطلاب: ${_selectedStudents.map(_studentIdentity).join('، ')}'),
            Text('عدد الطلاب: ${_selectedStudents.length}'),
            const SizedBox(height: 8),
            Text('الأسباب: ${reasons.map((reason) => reason.label).join('، ')}'),
            const SizedBox(height: 8),
            Text(
              'الإجمالي لكل طالب: ${_pointsPerStudent > 0 ? '+' : ''}$_pointsPerStudent نقطة',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isPositive ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد وحفظ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final points = <BehaviorPoint>[];
      for (final student in _selectedStudents) {
        for (final reason in reasons) {
          final isPersistentAppearance = reason.id == 'appearance_violation' ||
              reason.id == 'no_thobe';
          points.add(
            BehaviorPoint(
              studentId: student.id,
              type: _isPositive ? 'positive' : 'negative',
              reason: reason.label,
              points: _pointsForReason(reason),
              date: now,
              resolved: !isPersistentAppearance,
              notes: _notes.isEmpty ? null : _notes,
            ),
          );
        }
      }

      // عملية واحدة ذرية: إذا تعذر سجل واحد لا يُحفظ شيء لبقية الطلاب.
      await _db.insertBehaviorPoints(points);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إسناد ${reasons.length} أسباب إلى ${_selectedStudents.length} طالب',
            ),
            backgroundColor: _isPositive ? Colors.green : Colors.red,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _studentIdentity(Student student) {
    final guardian = student.guardianPhone.trim();
    return guardian.isEmpty
        ? student.name
        : '${student.name} — ولي الأمر ${_maskedPhone(guardian)}';
  }

  String _guardianIdentity(Student student) {
    final guardian = student.guardianPhone.trim();
    return guardian.isEmpty
        ? 'رقم ولي الأمر غير مسجل'
        : 'ولي الأمر: ${_maskedPhone(guardian)}';
  }

  String _maskedPhone(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), '');
    if (normalized.length <= 4) return normalized;
    return '••••${normalized.substring(normalized.length - 4)}';
  }

}

class PointReason {
  final String id;
  final String label;
  final int points;

  const PointReason(this.id, this.label, this.points);
}
