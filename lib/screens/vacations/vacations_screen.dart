import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import '../../models/vacation.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';

class VacationsScreen extends StatefulWidget {
  const VacationsScreen({super.key});

  @override
  State<VacationsScreen> createState() => _VacationsScreenState();
}

class _VacationsScreenState extends State<VacationsScreen> {
  final DatabaseService _db = DatabaseService();
  List<Vacation> _vacations = [];
  List<Student> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final vacations = await _db.getAllVacations();
      final students = await _db.getStudents();
      setState(() {
        _vacations = vacations;
        _students = students;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _getStudentName(String studentId) {
    final student = _students.firstWhere(
      (s) => s.id == studentId,
      orElse: () => Student(name: 'طالب محذوف'),
    );
    return student.name;
  }

  void _showVacationDialog({Vacation? vacationToEdit}) {
    final isEditing = vacationToEdit != null;
    String? selectedStudentId = vacationToEdit?.studentId;
    final selectedStudentIds = <String>{
      if (vacationToEdit != null) vacationToEdit.studentId,
    };
    String selectedReason = vacationToEdit?.reason ?? VacationReason.sick;
    DateTime startDate = vacationToEdit?.startDate ?? DateTime.now();
    DateTime endDate = vacationToEdit?.endDate ?? DateTime.now().add(const Duration(days: 3));
    String notes = vacationToEdit?.notes ?? '';

    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'تعديل بيانات الإجازة' : 'تسجيل إجازة / غياب عذر',
                        style: GoogleFonts.tajawal(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (isEditing)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'الطالب',
                        prefixIcon: Icon(Icons.person),
                      ),
                      value: selectedStudentId,
                      items: _students.map((student) {
                        return DropdownMenuItem(
                          value: student.id,
                          child: Text(student.name),
                        );
                      }).toList(),
                      onChanged: null,
                    )
                  else
                    InkWell(
                      onTap: () async {
                        final result = await _pickVacationStudents(
                          selectedStudentIds,
                        );
                        if (result != null) {
                          setModalState(() {
                            selectedStudentIds
                              ..clear()
                              ..addAll(result);
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'الطلاب المشمولون بالإجازة',
                          prefixIcon: Icon(Icons.group_add_outlined),
                        ),
                        child: Text(
                          selectedStudentIds.isEmpty
                              ? 'اختر طالبًا أو أكثر'
                              : 'تم اختيار ${selectedStudentIds.length} طالب',
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Reason Dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'سبب الإجازة',
                      prefixIcon: Icon(Icons.help_outline),
                    ),
                    value: selectedReason,
                    items: VacationReason.getAll().map((r) {
                      return DropdownMenuItem(
                        value: r['value'],
                        child: Text(r['label']!),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedReason = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date picking display
                  InkWell(
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime.now().subtract(const Duration(days: 90)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDateRange: DateTimeRange(start: startDate, end: endDate),
                      );
                      if (picked != null) {
                        setModalState(() {
                          startDate = picked.start;
                          endDate = picked.end;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.date_range, color: Colors.teal),
                          Text(
                            'من: ${intl.DateFormat('yyyy-MM-dd').format(startDate)}  إلى: ${intl.DateFormat('yyyy-MM-dd').format(endDate)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextFormField(
                    initialValue: notes,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات / تفاصيل الإجازة',
                      prefixIcon: Icon(Icons.description),
                    ),
                    onChanged: (val) {
                      notes = val;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          if (!isEditing && selectedStudentIds.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('اختر طالبًا واحدًا على الأقل'),
                              ),
                            );
                            return;
                          }
                          final vac = Vacation(
                            id: vacationToEdit?.id,
                            studentId: isEditing
                                ? selectedStudentId!
                                : selectedStudentIds.first,
                            startDate: startDate,
                            endDate: endDate,
                            reason: selectedReason,
                            notes: notes.trim().isEmpty ? null : notes.trim(),
                            approved: vacationToEdit?.approved ?? true,
                            createdAt: vacationToEdit?.createdAt,
                          );
                          if (isEditing) {
                            await _db.updateVacation(vac);
                          } else {
                            final vacations = selectedStudentIds
                                .map((studentId) => Vacation(
                                      studentId: studentId,
                                      startDate: startDate,
                                      endDate: endDate,
                                      reason: selectedReason,
                                      notes: notes.trim().isEmpty
                                          ? null
                                          : notes.trim(),
                                    ))
                                .toList();
                            await _db.insertVacations(vacations);
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEditing
                                      ? 'تم تحديث الإجازة'
                                      : 'تم تسجيل الإجازة لـ ${selectedStudentIds.length} طالب',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadData();
                          }
                        }
                      },
                      child: Text(isEditing ? 'حفظ التعديلات' : 'تسجيل الغياب بعذر'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<Set<String>?> _pickVacationStudents(Set<String> initial) async {
    final selected = Set<String>.from(initial);
    return showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('اختيار الطلاب'),
          content: SizedBox(
            width: double.maxFinite,
            height: 420,
            child: Column(
              children: [
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setDialogState(() {
                        selected
                          ..clear()
                          ..addAll(_students
                              .where((student) => student.status == 'active')
                              .map((student) => student.id));
                      }),
                      child: const Text('اختيار الكل'),
                    ),
                    TextButton(
                      onPressed: () =>
                          setDialogState(() => selected.clear()),
                      child: const Text('إلغاء الاختيار'),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    children: _students
                        .where((student) => student.status == 'active')
                        .map((student) => CheckboxListTile(
                              value: selected.contains(student.id),
                              title: Text(student.name),
                              onChanged: (checked) => setDialogState(() {
                                if (checked == true) {
                                  selected.add(student.id);
                                } else {
                                  selected.remove(student.id);
                                }
                              }),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: Text('اعتماد (${selected.length})'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleApproval(Vacation vacation, bool status) async {
    await _db.updateVacationApproval(vacation.id, status);
    _loadData();
  }

  void _deleteVacation(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف طلب الإجازة'),
        content: const Text('هل أنت متأكد من حذف هذا الطلب وإعادة تسجيل أيام الغياب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteVacation(id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة إجازات الطلاب'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showVacationDialog(),
        icon: const Icon(Icons.add),
        label: const Text('تسجيل إجازة'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _vacations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.beach_access,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد طلبات إجازة مسجلة',
                            style: GoogleFonts.tajawal(
                              color: Colors.grey[600],
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _vacations.length,
                      itemBuilder: (context, index) {
                        final vac = _vacations[index];
                        final studentName = _getStudentName(vac.studentId);
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      studentName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: Colors.teal),
                                          onPressed: () => _showVacationDialog(vacationToEdit: vac),
                                          tooltip: 'تعديل الإجازة',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => _deleteVacation(vac.id),
                                          tooltip: 'حذف الإجازة',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'المدة الزمنية',
                                            style: TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'من: ${intl.DateFormat('yyyy/MM/dd').format(vac.startDate)}\nإلى: ${intl.DateFormat('yyyy/MM/dd').format(vac.endDate)}',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'السبب والمدة',
                                            style: TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${VacationReason.getLabel(vac.reason)} (${vac.durationDays} أيام)',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (vac.notes != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'ملاحظات: ${vac.notes}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          vac.isActive
                                              ? Icons.play_arrow
                                              : (vac.isPast ? Icons.done : Icons.hourglass_empty),
                                          size: 16,
                                          color: vac.isActive ? Colors.green : Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          vac.isActive
                                              ? 'سارية المفعول'
                                              : (vac.isPast ? 'منتهية' : 'مستقبلية'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: vac.isActive ? Colors.green : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          vac.approved ? 'معتمدة ومقبولة' : 'مرفوضة / معلقة',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: vac.approved ? Colors.teal : Colors.red,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Switch(
                                          value: vac.approved,
                                          onChanged: (val) => _toggleApproval(vac, val),
                                          activeColor: Colors.teal,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
