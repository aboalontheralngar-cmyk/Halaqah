import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';
import '../../models/behavior_point.dart';
import '../../models/settings.dart';

class AddPointScreen extends StatefulWidget {
  final Student? student;

  const AddPointScreen({super.key, this.student});

  @override
  State<AddPointScreen> createState() => _AddPointScreenState();
}

class _AddPointScreenState extends State<AddPointScreen> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  Student? _selectedStudent;
  List<Student> _students = [];
  bool _isPositive = true;
  String? _selectedReason;
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
    _selectedStudent = widget.student;
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

  int get _selectedPoints {
    if (_selectedReason == null) return 0;
    final reason = _currentReasons.firstWhere(
      (r) => r.id == _selectedReason,
      orElse: () => const PointReason('', '', 0),
    );
    if (reason.id.startsWith('custom')) {
      return _isPositive ? _customPoints : -_customPoints.abs();
    }
    return reason.points;
  }

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
                  if (_selectedStudent != null) ...[
                    _buildStudentInfo(),
                    const SizedBox(height: 16),
                  ],
                  _buildTypeSelector(),
                  const SizedBox(height: 16),
                  _buildReasonSelector(),
                  if (_selectedReason?.startsWith('custom') == true) ...[
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

  Widget _buildStudentSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اختر الطالب', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<Student>(
              value: _selectedStudent,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              hint: const Text('اختر طالباً'),
              items: _students.map((student) {
                return DropdownMenuItem(value: student, child: Text(student.name));
              }).toList(),
              onChanged: (student) => setState(() => _selectedStudent = student),
              validator: (value) => value == null ? 'يرجى اختيار طالب' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentInfo() {
    final student = _selectedStudent!;
    return Card(
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            student.name.isNotEmpty ? student.name[0] : '؟',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: FutureBuilder<int>(
          future: _db.getStudentTotalPoints(student.id),
          builder: (context, snapshot) {
            final points = snapshot.data ?? 0;
            return Text('الرصيد الحالي: $points نقطة');
          },
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
                      _selectedReason = null;
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isPositive
                            ? Colors.green
                            : Colors.green.withOpacity(0.1),
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
                      _selectedReason = null;
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: !_isPositive
                            ? Colors.red
                            : Colors.red.withOpacity(0.1),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('السبب', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._currentReasons.map((reason) => RadioListTile<String>(
                  value: reason.id,
                  groupValue: _selectedReason,
                  title: Text(reason.label),
                  subtitle: reason.points != 0
                      ? Text(
                          '${reason.points > 0 ? '+' : ''}${reason.points} نقطة',
                          style: TextStyle(
                            color: reason.points > 0 ? Colors.green : Colors.red,
                          ),
                        )
                      : null,
                  onChanged: (value) => setState(() => _selectedReason = value),
                )),
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
                if (_selectedReason?.startsWith('custom') == true) {
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
    if (_selectedReason == null) return const SizedBox.shrink();

    final points = _selectedPoints;
    final isPositive = points >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (isPositive ? Colors.green : Colors.red).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isPositive ? Colors.green : Colors.red).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            isPositive ? Icons.add_circle : Icons.remove_circle,
            color: isPositive ? Colors.green : Colors.red,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            '${isPositive ? '+' : ''}$points',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green : Colors.red,
            ),
          ),
          const Text('نقطة'),
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
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار طالب')),
      );
      return;
    }

    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار السبب')),
      );
      return;
    }

    if (_selectedReason!.startsWith('custom') && _customPoints <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال عدد النقاط')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final reason = _currentReasons.firstWhere((r) => r.id == _selectedReason);
      final isAppearanceViolation = _selectedReason == 'appearance_violation';

      final point = BehaviorPoint(
        studentId: _selectedStudent!.id,
        type: _isPositive ? 'positive' : 'negative',
        reason: reason.label,
        points: _selectedPoints,
        date: DateTime.now(),
        resolved: !isAppearanceViolation,
        notes: _notes.isEmpty ? null : _notes,
      );

      await _db.insertBehaviorPoint(point);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إضافة ${_selectedPoints} نقطة'),
            backgroundColor: _isPositive ? Colors.green : Colors.red,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class PointReason {
  final String id;
  final String label;
  final int points;

  const PointReason(this.id, this.label, this.points);
}
