import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import '../../models/plan.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../app/theme.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final DatabaseService _db = DatabaseService();
  List<SmartPlan> _plans = [];
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
      final plans = await _db.getSmartPlans();
      final students = await _db.getStudents();
      setState(() {
        _plans = plans;
        _students = students;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _getStudentName(String studentId) {
    final student = _students.firstWhere((s) => s.id == studentId, orElse: () => Student(name: 'طالب محذوف'));
    return student.name;
  }

  void _showAddPlanDialog() {
    String? selectedStudentId;
    String selectedPeriod = 'weekly';
    String selectedUnit = 'ayahs';
    int newAmount = 5;
    int reviewAmount = 10;
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 7));
    String notes = '';

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
                        'إنشاء خطة ذكية جديدة',
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

                  // Student Dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'اختر الطالب',
                      prefixIcon: Icon(Icons.person),
                    ),
                    value: selectedStudentId,
                    items: _students.map((student) {
                      return DropdownMenuItem(
                        value: student.id,
                        child: Text(student.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setModalState(() {
                        selectedStudentId = val;
                      });
                    },
                    validator: (val) {
                      if (val == null) return 'الرجاء اختيار طالب';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Period selection
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'المدة الزمنية',
                            prefixIcon: Icon(Icons.timer),
                          ),
                          value: selectedPeriod,
                          items: const [
                            DropdownMenuItem(value: 'weekly', child: Text('أسبوعية')),
                            DropdownMenuItem(value: 'monthly', child: Text('شهرية')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedPeriod = val;
                                final days = val == 'weekly' ? 7 : 30;
                                endDate = startDate.add(Duration(days: days));
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'وحدة القياس',
                            prefixIcon: Icon(Icons.view_headline),
                          ),
                          value: selectedUnit,
                          items: const [
                            DropdownMenuItem(value: 'ayahs', child: Text('آيات')),
                            DropdownMenuItem(value: 'pages', child: Text('صفحات')),
                            DropdownMenuItem(value: 'lines', child: Text('أسطر')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedUnit = val;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Targets Amount inputs
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: newAmount.toString(),
                          decoration: const InputDecoration(
                            labelText: 'مقدار الحفظ اليومي',
                            prefixIcon: Icon(Icons.add_circle_outline),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'مطلوب';
                            if (int.tryParse(val) == null || int.parse(val) <= 0) return 'خطأ';
                            return null;
                          },
                          onChanged: (val) {
                            newAmount = int.tryParse(val) ?? 5;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: reviewAmount.toString(),
                          decoration: const InputDecoration(
                            labelText: 'مقدار المراجعة اليومي',
                            prefixIcon: Icon(Icons.replay_outlined),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'مطلوب';
                            if (int.tryParse(val) == null || int.parse(val) <= 0) return 'خطأ';
                            return null;
                          },
                          onChanged: (val) {
                            reviewAmount = int.tryParse(val) ?? 10;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Date picking display
                  InkWell(
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
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
                    decoration: const InputDecoration(
                      labelText: 'توجيهات أو ملاحظات إضافية',
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
                          final plan = SmartPlan(
                            studentId: selectedStudentId!,
                            period: selectedPeriod,
                            startDate: startDate,
                            endDate: endDate,
                            unit: selectedUnit,
                            newAmount: newAmount,
                            reviewAmount: reviewAmount,
                            notes: notes.trim().isEmpty ? null : notes.trim(),
                          );
                          await _db.insertSmartPlan(plan);
                          if (context.mounted) {
                            Navigator.pop(context);
                            _loadData();
                          }
                        }
                      },
                      child: const Text('تفعيل الخطة'),
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

  void _updatePlanStatus(SmartPlan plan, String status) async {
    final updated = SmartPlan(
      id: plan.id,
      studentId: plan.studentId,
      period: plan.period,
      startDate: plan.startDate,
      endDate: plan.endDate,
      unit: plan.unit,
      newAmount: plan.newAmount,
      reviewAmount: plan.reviewAmount,
      status: status,
      notes: plan.notes,
      createdAt: plan.createdAt,
    );
    await _db.updateSmartPlan(updated);
    _loadData();
  }

  String _getUnitLabel(String unit) {
    switch (unit) {
      case 'ayahs':
        return 'آية';
      case 'pages':
        return 'صفحة';
      case 'lines':
        return 'سطر';
      default:
        return 'وحدة';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الخطط الذكية'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPlanDialog,
        icon: const Icon(Icons.playlist_add),
        label: const Text('خطة جديدة'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _plans.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.track_changes,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد خطط مخصصة حالياً للطلاب',
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
                      itemCount: _plans.length,
                      itemBuilder: (context, index) {
                        final plan = _plans[index];
                        final isActive = plan.status == 'active';
                        
                        Color statusColor = Colors.grey;
                        String statusText = 'غير نشط';
                        if (plan.status == 'active') {
                          statusColor = Colors.teal;
                          statusText = 'نشطة';
                        } else if (plan.status == 'completed') {
                          statusColor = const Color(0xFF10B981);
                          statusText = 'مكتملة';
                        } else if (plan.status == 'cancelled') {
                          statusColor = Colors.red;
                          statusText = 'ملغاة';
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _getStudentName(plan.studentId),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'الحفظ المطلوب',
                                            style: TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${plan.newAmount} ${_getUnitLabel(plan.unit)} / يومياً',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'المراجعة المطلوبة',
                                            style: TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${plan.reviewAmount} ${_getUnitLabel(plan.unit)} / يومياً',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.date_range, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                      'المدة: من ${intl.DateFormat('yyyy/MM/dd').format(plan.startDate)} إلى ${intl.DateFormat('yyyy/MM/dd').format(plan.endDate)}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                if (plan.notes != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'ملاحظات: ${plan.notes}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                if (isActive) ...[
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _updatePlanStatus(plan, 'cancelled'),
                                        icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                                        label: const Text('إلغاء الخطة', style: TextStyle(color: Colors.red)),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.red),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton.icon(
                                        onPressed: () => _updatePlanStatus(plan, 'completed'),
                                        icon: const Icon(Icons.check_circle_outline, size: 16),
                                        label: const Text('أكمل الخطة'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
