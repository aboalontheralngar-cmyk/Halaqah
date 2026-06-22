import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';
import '../../models/vacation.dart';
import '../../utils/helpers.dart';

class AddVacationScreen extends StatefulWidget {
  final Student? student;

  const AddVacationScreen({super.key, this.student});

  @override
  State<AddVacationScreen> createState() => _AddVacationScreenState();
}

class _AddVacationScreenState extends State<AddVacationScreen> {
  final DatabaseService _db = DatabaseService();

  Student? _selectedStudent;
  List<Student> _students = [];
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  String _reason = 'travel';
  String _notes = '';
  bool _isLoading = true;
  bool _isSaving = false;

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
      setState(() {
        _students = students;
        if (_selectedStudent != null) {
          _selectedStudent = students.firstWhere(
            (s) => s.id == _selectedStudent!.id,
            orElse: () => _selectedStudent!,
          );
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  int get _daysCount => _endDate.difference(_startDate).inDays + 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة إجازة'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.student == null) _buildStudentSelector(),
                if (_selectedStudent != null) ...[
                  _buildStudentInfo(),
                  const SizedBox(height: 16),
                ],
                _buildDateRangeSelector(),
                const SizedBox(height: 16),
                _buildDurationInfo(),
                const SizedBox(height: 16),
                _buildReasonSelector(),
                const SizedBox(height: 16),
                _buildNotesField(),
                const SizedBox(height: 24),
                _buildSaveButton(),
              ],
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
        subtitle: Text('الحفظ: ${student.totalMemorized} آية'),
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('فترة الإجازة', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateButton('من', _startDate, (date) {
                    setState(() {
                      _startDate = date;
                      if (_endDate.isBefore(_startDate)) {
                        _endDate = _startDate.add(const Duration(days: 1));
                      }
                    });
                  }),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateButton('إلى', _endDate, (date) {
                    setState(() => _endDate = date);
                  }, firstDate: _startDate),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateButton(
    String label,
    DateTime date,
    Function(DateTime) onDateSelected, {
    DateTime? firstDate,
  }) {
    return InkWell(
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: firstDate ?? DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (selected != null) {
          onDateSelected(selected);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Helpers.formatHijriDate(date),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timelapse, color: Colors.blue),
          const SizedBox(width: 12),
          Text(
            'مدة الإجازة: $_daysCount يوم',
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
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
            const Text('سبب الإجازة', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildReasonChip('سفر', 'travel', Icons.flight),
                _buildReasonChip('مرض', 'illness', Icons.local_hospital),
                _buildReasonChip('ظرف عائلي', 'family', Icons.family_restroom),
                _buildReasonChip('أخرى', 'other', Icons.more_horiz),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonChip(String label, String value, IconData icon) {
    final isSelected = _reason == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _reason = value);
        }
      },
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
        onPressed: _isSaving ? null : _saveVacation,
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('حفظ الإجازة'),
      ),
    );
  }

  Future<void> _saveVacation() async {
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار طالب')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final vacation = Vacation(
        studentId: _selectedStudent!.id,
        startDate: _startDate,
        endDate: _endDate,
        reason: _reason,
        notes: _notes.isEmpty ? null : _notes,
      );

      await _db.insertVacation(vacation);

      // Auto-update records to excused if they exist and are 'absent'
      final db = await _db.database;
      final startStr = _startDate.toIso8601String().split('T')[0];
      final endStr = _endDate.toIso8601String().split('T')[0];
      
      await db.update(
        'daily_records',
        {
          'attendance': 'excused',
          'notes': 'تحولت لإجازة تلقائيًا: ${VacationReason.getLabel(_reason)}',
        },
        where: 'student_id = ? AND date BETWEEN ? AND ? AND attendance = ?',
        whereArgs: [_selectedStudent!.id, startStr, endStr, 'absent'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة الإجازة بنجاح، وتحديث الحضور التلقائي'),
            backgroundColor: Colors.green,
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
