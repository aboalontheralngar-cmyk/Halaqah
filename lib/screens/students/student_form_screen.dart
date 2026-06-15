import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';

class StudentFormScreen extends StatefulWidget {
  final Student? student;

  const StudentFormScreen({super.key, this.student});

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _planType = 'ayahs';
  int _planAmount = 5;
  final DatabaseService _db = DatabaseService();
  bool _isSaving = false;

  bool get isEditing => widget.student != null;

  @override
  void initState() {
    super.initState();
    if (widget.student != null) {
      _nameController.text = widget.student!.name;
      _phoneController.text = widget.student!.phone;
      _guardianPhoneController.text = widget.student!.guardianPhone;
      _notesController.text = widget.student!.notes ?? '';
      _planType = widget.student!.planType;
      _planAmount = widget.student!.planAmount;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _guardianPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      if (isEditing) {
        final updated = widget.student!.copyWith(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          guardianPhone: _guardianPhoneController.text.trim(),
          planType: _planType,
          planAmount: _planAmount,
          notes: _notesController.text.trim(),
        );
        await _db.updateStudent(updated);
      } else {
        final student = Student(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          guardianPhone: _guardianPhoneController.text.trim(),
          planType: _planType,
          planAmount: _planAmount,
          notes: _notesController.text.trim(),
        );
        await _db.insertStudent(student);
      }
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'تعديل طالب' : 'إضافة طالب'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم الطالب *',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'الرجاء إدخال اسم الطالب';
                }
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'رقم جوال الطالب',
                prefixIcon: Icon(Icons.phone),
                hintText: '05xxxxxxxx',
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _guardianPhoneController,
              decoration: const InputDecoration(
                labelText: 'رقم جوال ولي الأمر',
                prefixIcon: Icon(Icons.phone_android),
                hintText: '05xxxxxxxx',
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 24),
            
            const Text(
              'خطة الحفظ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('نوع المقرر'),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'ayahs', label: Text('آيات')),
                        ButtonSegment(value: 'lines', label: Text('أسطر')),
                        ButtonSegment(value: 'pages', label: Text('صفحات')),
                      ],
                      selected: {_planType},
                      onSelectionChanged: (set) {
                        setState(() => _planType = set.first);
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        const Text('المقدار اليومي: '),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: _planAmount > 1
                              ? () => setState(() => _planAmount--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$_planAmount',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _planAmount++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                        Text(_getPlanLabel(_planType)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                prefixIcon: Icon(Icons.note),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditing ? 'حفظ التعديلات' : 'إضافة الطالب'),
            ),
          ],
        ),
      ),
    );
  }

  String _getPlanLabel(String type) {
    switch (type) {
      case 'ayahs':
        return 'آية';
      case 'lines':
        return 'سطر';
      case 'pages':
        return 'صفحة';
      default:
        return '';
    }
  }
}
