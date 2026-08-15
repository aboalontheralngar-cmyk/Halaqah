import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../../models/fund_transaction.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../models/settings.dart';
import '../../models/behavior_point.dart';

class FundScreen extends StatefulWidget {
  const FundScreen({super.key});

  @override
  State<FundScreen> createState() => _FundScreenState();
}

class _FundScreenState extends State<FundScreen> {
  final DatabaseService _db = DatabaseService();
  double _balance = 0.0;
  List<FundTransaction> _transactions = [];
  List<Student> _students = [];
  HalaqahSettings _settings = HalaqahSettings();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final values = await Future.wait<dynamic>([
        _db.getFundBalance(),
        _db.getFundTransactions(),
        _db.getStudents(),
        _db.getSettings(),
      ]);
      if (!mounted) return;
      setState(() {
        _balance = values[0] as double;
        _transactions = values[1] as List<FundTransaction>;
        _students = values[2] as List<Student>;
        _settings = values[3] as HalaqahSettings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _getStudentName(String? id) {
    if (id == null) return 'عام';
    final student = _students.firstWhere((s) => s.id == id, orElse: () => Student(name: 'طالب محذوف'));
    return student.name;
  }

  void _showAddTransactionDialog() {
    String? selectedStudentId;
    String? selectedBehaviorPointId;
    List<BehaviorPoint> studentPenalties = [];
    int outstandingNegativePoints = 0;
    int settledNegativePoints = 0;
    String selectedType = 'subscription';
    double amount = 0.0;
    String note = '';
    DateTime selectedDate = DateTime.now();
    
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
                        'إضافة معاملة مالية',
                        style: TextStyle(
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
                  
                  // Transaction Type Segmented Control
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'subscription', label: Text('اشتراك')),
                        ButtonSegment(value: 'penalty', label: Text('غرامة')),
                        ButtonSegment(value: 'expense', label: Text('مصروف')),
                        ButtonSegment(value: 'donation', label: Text('تبرع')),
                      ],
                      selected: {selectedType},
                      onSelectionChanged: (set) async {
                        setModalState(() {
                          selectedType = set.first;
                          selectedBehaviorPointId = null;
                          studentPenalties = [];
                          outstandingNegativePoints = 0;
                          settledNegativePoints = 0;
                        });
                        if (set.first == 'penalty' &&
                            selectedStudentId != null) {
                          final values = await Future.wait<dynamic>([
                            _db.getStudentBehaviorPoints(selectedStudentId!),
                            _db.getOutstandingNegativePoints(selectedStudentId!),
                          ]);
                          final points = values[0] as List<BehaviorPoint>;
                          if (!context.mounted) return;
                          setModalState(() {
                            studentPenalties = points
                                .where((point) => point.points < 0)
                                .toList();
                            outstandingNegativePoints = values[1] as int;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Amount Field
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'المبلغ (${_settings.currencySymbol})',
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'الرجاء إدخال المبلغ';
                      if (double.tryParse(val) == null) return 'الرجاء إدخال رقم صحيح';
                      if (double.parse(val) <= 0) return 'يجب أن يكون المبلغ أكبر من صفر';
                      return null;
                    },
                    onChanged: (val) {
                      amount = double.tryParse(val) ?? 0.0;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Optional Student Selection
                  if (selectedType == 'subscription' || selectedType == 'penalty')
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'الطالب المرتبط',
                        prefixIcon: Icon(Icons.person),
                      ),
                      initialValue: selectedStudentId,
                      items: (List<Student>.from(_students)
                            ..sort((a, b) => a.name.compareTo(b.name)))
                          .map((student) {
                        return DropdownMenuItem(
                          value: student.id,
                          child: Text(student.name),
                        );
                      }).toList(),
                      onChanged: (val) async {
                        setModalState(() {
                          selectedStudentId = val;
                          selectedBehaviorPointId = null;
                          studentPenalties = [];
                          outstandingNegativePoints = 0;
                          settledNegativePoints = 0;
                        });
                        if (val != null && selectedType == 'penalty') {
                          final values = await Future.wait<dynamic>([
                            _db.getStudentBehaviorPoints(val),
                            _db.getOutstandingNegativePoints(val),
                          ]);
                          final points = values[0] as List<BehaviorPoint>;
                          if (!context.mounted) return;
                          setModalState(() {
                            studentPenalties = points
                                .where((point) => point.points < 0)
                                .toList();
                            outstandingNegativePoints = values[1] as int;
                          });
                        }
                      },
                      validator: (val) {
                        if ((selectedType == 'subscription' || selectedType == 'penalty') && val == null) {
                          return 'الرجاء اختيار الطالب';
                        }
                        return null;
                      },
                    ),
                  if (selectedType == 'subscription' || selectedType == 'penalty')
                    const SizedBox(height: 16),

                  if (selectedType == 'penalty' && selectedStudentId != null) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedBehaviorPointId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'المخالفة المرتبطة (اختياري)',
                        prefixIcon: Icon(Icons.link_outlined),
                      ),
                      hint: Text(
                        studentPenalties.isEmpty
                            ? 'لا توجد مخالفات مسجلة لهذا الطالب'
                            : 'اختر المخالفة التي نتجت عنها الغرامة',
                      ),
                      items: studentPenalties
                          .map(
                            (point) => DropdownMenuItem(
                              value: point.id,
                              child: Text(
                                '${BehaviorReason.getLabel(point.reason)} (${point.points})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: studentPenalties.isEmpty
                          ? null
                          : (value) => setModalState(
                                () => selectedBehaviorPointId = value,
                              ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'الرصيد السلبي غير المسوّى: $outstandingNegativePoints نقطة. '
                        'حدد عدد النقاط التي يغطيها هذا السداد؛ تبقى المخالفة محفوظة في السجل التاريخي.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: '0',
                      enabled: outstandingNegativePoints > 0,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'النقاط السلبية التي ستُسوّى',
                        prefixIcon: Icon(Icons.remove_circle_outline),
                        helperText: 'يمكن تسوية جزء من الرصيد أو الرصيد كاملًا',
                      ),
                      validator: (value) {
                        final points = int.tryParse(value ?? '') ?? 0;
                        if (points < 0 || points > outstandingNegativePoints) {
                          return 'أدخل قيمة بين 0 و$outstandingNegativePoints';
                        }
                        return null;
                      },
                      onChanged: (value) =>
                          settledNegativePoints = int.tryParse(value) ?? 0,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Note Field
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات / بيان السبب',
                      prefixIcon: Icon(Icons.note),
                    ),
                    onChanged: (val) {
                      note = val;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          final tx = FundTransaction(
                            studentId: selectedStudentId,
                            behaviorPointId: selectedBehaviorPointId,
                            settledNegativePoints: settledNegativePoints,
                            type: selectedType,
                            amount: amount,
                            note: note.trim().isEmpty ? null : note.trim(),
                            date: selectedDate,
                          );
                          await _db.insertFundTransaction(tx);
                          if (context.mounted) {
                            Navigator.pop(context);
                            _loadData();
                          }
                        }
                      },
                      child: const Text('إضافة المعاملة'),
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

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'subscription':
        return Icons.card_membership;
      case 'penalty':
        return Icons.gavel;
      case 'expense':
        return Icons.shopping_bag;
      case 'donation':
        return Icons.volunteer_activism;
      default:
        return Icons.attach_money;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'subscription':
        return const Color(0xFF10B981);
      case 'penalty':
        return Colors.orange;
      case 'expense':
        return Colors.red;
      case 'donation':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'subscription':
        return 'اشتراك شهري';
      case 'penalty':
        return 'غرامة / جزاء';
      case 'expense':
        return 'مصروفات حلقة';
      case 'donation':
        return 'تبرع / مساهمة';
      default:
        return 'معاملة';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('صندوق الحلقة'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTransactionDialog,
        icon: const Icon(Icons.add),
        label: const Text('إضافة معاملة'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // Balance Card Header
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        height: 132,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'رصيد الصندوق الحالي',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_balance.toStringAsFixed(2)} ${_settings.currencySymbol}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 23,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Recent Transactions Header
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المعاملات الأخيرة',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'إجمالي ${_transactions.length} معاملة',
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Transaction List
                  if (_transactions.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد عمليات مسجلة في الصندوق حالياً',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final tx = _transactions[index];
                            final isExpense = tx.type == 'expense';
                            final color = _getTypeColor(tx.type);
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getTypeIcon(tx.type),
                                    color: color,
                                    size: 24,
                                  ),
                                ),
                                title: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      _getTypeLabel(tx.type),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${isExpense ? "-" : "+"}${tx.amount.toStringAsFixed(1)} ${_settings.currencySymbol}',
                                      style: TextStyle(
                                        color: isExpense
                                            ? Colors.red
                                            : const Color(0xFF10B981),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.note ?? 'المرتبط: ${_getStudentName(tx.studentId)}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                        ),
                                      ),
                                      if (tx.settledNegativePoints > 0)
                                        Text(
                                          'تمت تسوية ${tx.settledNegativePoints} نقطة سلبية مع إبقاء المخالفة في السجل',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.orange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      const SizedBox(height: 2),
                                      Text(
                                        intl.DateFormat('yyyy/MM/dd').format(tx.date),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: _transactions.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
