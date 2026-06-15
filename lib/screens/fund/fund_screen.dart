import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import '../../models/fund_transaction.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../app/theme.dart';
import '../../models/settings.dart';

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
      final balance = await _db.getFundBalance();
      final transactions = await _db.getFundTransactions();
      final students = await _db.getStudents();
      final settings = await _db.getSettings();
      setState(() {
        _balance = balance;
        _transactions = transactions;
        _students = students;
        _settings = settings;
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
                  
                  // Transaction Type Segmented Control
                  Center(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'subscription', label: Text('اشتراك')),
                        ButtonSegment(value: 'penalty', label: Text('غرامة')),
                        ButtonSegment(value: 'expense', label: Text('مصروف')),
                        ButtonSegment(value: 'donation', label: Text('تبرع')),
                      ],
                      selected: {selectedType},
                      onSelectionChanged: (set) {
                        setModalState(() {
                          selectedType = set.first;
                        });
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
                        if ((selectedType == 'subscription' || selectedType == 'penalty') && val == null) {
                          return 'الرجاء اختيار الطالب';
                        }
                        return null;
                      },
                    ),
                  if (selectedType == 'subscription' || selectedType == 'penalty')
                    const SizedBox(height: 16),

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
                        height: 160,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFF0D9488), const Color(0xFF0F766E)]
                                : [const Color(0xFF14B8A6), const Color(0xFF0D9488)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0D9488).withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'رصيد الصندوق الحالي',
                              style: GoogleFonts.tajawal(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_balance.toStringAsFixed(2)} ${_settings.currencySymbol}',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet,
                                    color: Colors.white,
                                    size: 28,
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
                            style: GoogleFonts.tajawal(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'إجمالي ${_transactions.length} معاملة',
                            style: GoogleFonts.tajawal(
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
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
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد عمليات مسجلة في الصندوق حالياً',
                              style: GoogleFonts.tajawal(
                                color: Colors.grey[600],
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
                                    color: color.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getTypeIcon(tx.type),
                                    color: color,
                                    size: 24,
                                  ),
                                ),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _getTypeLabel(tx.type),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${isExpense ? "-" : "+"}${tx.amount.toStringAsFixed(1)} ${_settings.currencySymbol}',
                                      style: GoogleFonts.outfit(
                                        color: isExpense ? Colors.red : const Color(0xFF10B981),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        tx.note ?? 'المرتبط: ${_getStudentName(tx.studentId)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                        ),
                                      ),
                                      Text(
                                        intl.DateFormat('yyyy/MM/dd').format(tx.date),
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: Colors.grey,
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
