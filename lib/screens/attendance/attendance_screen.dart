import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/database_service.dart';
import '../../services/qr_service.dart';
import '../../models/settings.dart';
import '../../models/student.dart';
import '../../models/daily_record.dart';
import '../../models/vacation.dart';
import '../../utils/helpers.dart';
import '../../utils/prayer_time_helper.dart';
import '../memorization/recitation_screen.dart';
import '../memorization/revision_screen.dart';
import '../settings/add_vacation_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final DatabaseService _db = DatabaseService();
  List<Student> _students = [];
  Map<String, DailyRecord> _todayRecords = {};
  DateTime _selectedDate = DateTime.now();
  HalaqahSettings _settings = HalaqahSettings();
  bool _isLoading = true;
  String _filter = 'all'; // 'all', 'present', 'absent', 'excused', 'remaining'
  List<Vacation> _vacations = [];
  bool _isSuspended = false;
  String? _suspensionReason;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final students = await _db.getStudents(status: 'active');
      final records = await _db.getDailyRecordsForDate(_selectedDate);
      final settings = await _db.getSettings();
      final vacations = await _db.getAllVacations();
      final isSuspended = await _db.isDateSuspended(_selectedDate);
      final dateKey = _selectedDate.toIso8601String().split('T')[0];
      final reasons = await _db.getSuspensionReasons();
      final suspensionReason = reasons[dateKey] ??
          (settings.isHolidayWeekday(_selectedDate) ? 'إجازة أسبوعية' : null);
      
      final recordsMap = <String, DailyRecord>{};
      for (final record in records) {
        recordsMap[record.studentId] = record;
      }
      
      // Auto-mark students on approved vacation as 'excused' if they have no record yet or are marked as 'absent'
      for (final student in students) {
        Vacation? activeVac;
        for (final v in vacations) {
          if (v.studentId == student.id && v.approved && v.isDateInVacation(_selectedDate)) {
            activeVac = v;
            break;
          }
        }
        
        if (activeVac != null) {
          final existing = recordsMap[student.id];
          if (existing == null || 
              existing.attendance == null || 
              existing.attendance!.isEmpty || 
              existing.attendance == 'absent') {
            final reasonLabel = VacationReason.getLabel(activeVac.reason);
            final newRecord = (existing ?? DailyRecord(
              studentId: student.id,
              date: _selectedDate,
            )).copyWith(
              attendance: 'excused',
              notes: 'إجازة تلقائية: $reasonLabel',
            );
            await _db.saveDailyRecord(newRecord);
            recordsMap[student.id] = newRecord;
          }
        }
      }
      
      setState(() {
        _students = students;
        _todayRecords = recordsMap;
        _settings = settings;
        _vacations = vacations;
        _isSuspended = isSuspended;
        _suspensionReason = suspensionReason;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  DailyRecord _getOrCreateRecord(String studentId) {
    return _todayRecords[studentId] ??
        DailyRecord(studentId: studentId, date: _selectedDate);
  }

  bool isLate(DailyRecord? record) {
    if (record == null || record.arrivalTime == null) return false;
    final arrival = record.arrivalTime!;
    final classTimes = PrayerTimeHelper.calculateClassTimes(_settings, record.date);
    final start = classTimes.start;
    
    if (arrival.hour > start.hour) return true;
    if (arrival.hour == start.hour && arrival.minute > start.minute) return true;
    return false;
  }

  Future<void> _updateAttendance(String studentId, String attendance) async {
    if (attendance == 'excused') {
      final student = _students.firstWhere((s) => s.id == studentId);
      final hasVacation = _vacations.any(
        (v) => v.studentId == studentId && v.approved && v.isDateInVacation(_selectedDate),
      );
      
      if (!hasVacation) {
        await _showQuickVacationDialog(student);
        return;
      }
    }

    final record = _getOrCreateRecord(studentId);
    final updated = record.copyWith(
      attendance: attendance,
      arrivalTime: attendance == 'present'
          ? (record.arrivalTime ?? DateTime.now())
          : null,
    );
    await _db.saveDailyRecord(updated);
    _loadData(silent: true);
  }

  Future<void> _showQuickVacationDialog(Student student) async {
    String selectedReason = 'travel';
    String notes = '';
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('تسجيل إجازة لـ ${student.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الرجاء اختيار سبب الاستئذان لتسجيل الإجازة:'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: VacationReason.getAll().map((item) {
                      final val = item['value']!;
                      final label = item['label']!;
                      final isSelected = selectedReason == val;
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => selectedReason = val);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات الإجازة (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => notes = val,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('إجازة اليوم فقط'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, false);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddVacationScreen(student: student),
                      ),
                    ).then((val) {
                      if (val == true) {
                        _loadData(silent: true);
                      }
                    });
                  },
                  child: const Text('إجازة مطولة/مخصصة'),
                ),
              ],
            );
          },
        );
      },
    );
    
    if (result == true) {
      final vacation = Vacation(
        studentId: student.id,
        startDate: _selectedDate,
        endDate: _selectedDate,
        reason: selectedReason,
        notes: notes.isEmpty ? null : notes,
      );
      await _db.insertVacation(vacation);
      
      final record = _getOrCreateRecord(student.id);
      final updated = record.copyWith(
        attendance: 'excused',
        arrivalTime: null,
        notes: 'إجازة: ${VacationReason.getLabel(selectedReason)}',
      );
      await _db.saveDailyRecord(updated);
      _loadData(silent: true);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  void _openQrScanner() async {
    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('يرجى السماح بالوصول للكاميرا لاستخدام الماسح'),
            action: SnackBarAction(
              label: 'الإعدادات',
              onPressed: openAppSettings,
            ),
          ),
        );
      }
      return;
    }
    
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: _QrScannerSheet(
          onStudentScanned: (studentId) async {
            final student = await _db.getStudent(studentId);
            if (student != null && mounted) {
              Navigator.pop(context);
              await _updateAttendance(studentId, 'present');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم تحضير ${student.name}'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final presentCount = _todayRecords.values
        .where((r) => r.attendance == 'present' || r.attendance == 'late')
        .length;
    final absentCount = _todayRecords.values
        .where((r) => r.attendance == 'absent')
        .length;
    final excusedCount = _todayRecords.values
        .where((r) => r.attendance == 'excused')
        .length;
    final remainingCount = _students.length - presentCount - absentCount - excusedCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الحضور اليومي'),
        actions: [
          IconButton(
            icon: Icon(_isSuspended ? Icons.play_circle_fill : Icons.pause_circle_filled, color: _isSuspended ? Colors.green : Colors.orange),
            onPressed: _toggleSuspension,
            tooltip: _isSuspended ? 'تفعيل الحلقة' : 'تعليق الحلقة',
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _openQrScanner,
            tooltip: 'مسح QR',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildDateSelector(),
            if (_isSuspended) _buildSuspendedBanner(),
            _buildStatsBar(presentCount, absentCount, excusedCount, remainingCount),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _students.isEmpty
                      ? _buildEmptyState()
                      : _buildStudentList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openQrScanner,
        child: const Icon(Icons.qr_code_scanner),
      ),
    );
  }

  Widget _buildDateSelector() {
    final classTimes = PrayerTimeHelper.calculateClassTimes(_settings, _selectedDate);
    final startTimeFormatted = Helpers.formatTime(classTimes.start, format: _settings.timeFormat, context: context);
    final sourceText = classTimes.calculationSource ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                  });
                  _loadData();
                },
              ),
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        Helpers.getDayName(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        Helpers.getFullHijriDate(_selectedDate),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: Helpers.isSameDay(_selectedDate, DateTime.now())
                    ? null
                    : () {
                        setState(() {
                          _selectedDate = _selectedDate.add(const Duration(days: 1));
                        });
                        _loadData();
                      },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'وقت بدء اليوم: $startTimeFormatted ($sourceText)',
            style: GoogleFonts.tajawal(
              fontSize: 12,
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(int present, int absent, int excused, int remaining) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatChip('الكل', '${_students.length}', Colors.blue, 'all'),
          _buildStatChip(GenderHelper.present(_settings.gender), '$present', Colors.green, 'present'),
          _buildStatChip(GenderHelper.absent(_settings.gender), '$absent', Colors.red, 'absent'),
          _buildStatChip(GenderHelper.excused(_settings.gender), '$excused', Colors.orange, 'excused'),
          _buildStatChip(GenderHelper.remaining(_settings.gender), '$remaining', Colors.grey, 'remaining'),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color, String filterType) {
    final isSelected = _filter == filterType;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _filter = filterType;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(isSelected ? 0.35 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('لا يوجد طلاب', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  List<Student> _getFilteredStudents() {
    switch (_filter) {
      case 'present':
        return _students.where((s) {
          final r = _todayRecords[s.id];
          return r?.attendance == 'present' || r?.attendance == 'late';
        }).toList();
      case 'absent':
        return _students.where((s) {
          final r = _todayRecords[s.id];
          return r?.attendance == 'absent';
        }).toList();
      case 'excused':
        return _students.where((s) {
          final r = _todayRecords[s.id];
          return r?.attendance == 'excused';
        }).toList();
      case 'remaining':
        return _students.where((s) {
          final r = _todayRecords[s.id];
          return r == null || r.attendance == null || r.attendance!.isEmpty;
        }).toList();
      case 'all':
      default:
        return _students;
    }
  }

  Widget _buildStudentList() {
    final filtered = _getFilteredStudents();
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.filter_list_off, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'لا يوجد طلاب في هذا التصنيف',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final student = filtered[index];
          final record = _todayRecords[student.id];
          return _buildStudentCard(student, record);
        },
      ),
    );
  }

  Widget _buildStudentCard(Student student, DailyRecord? record) {
    final attendance = record?.attendance ?? '';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Text(
                    student.name.isNotEmpty ? student.name[0] : '؟',
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (record?.arrivalTime != null)
                        Text(
                          '${GenderHelper.arrivalWord(_settings.gender)}: ${Helpers.formatTime(record!.arrivalTime!, format: _settings.timeFormat, context: context)}' + (isLate(record) ? ' (${GenderHelper.lateWord(_settings.gender)})' : ''),
                          style: TextStyle(
                            fontSize: 12, 
                            color: isLate(record) ? Colors.orange : Colors.grey[600],
                            fontWeight: isLate(record) ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      (() {
                        Vacation? studentVacation;
                        for (final v in _vacations) {
                          if (v.studentId == student.id && v.approved && v.isDateInVacation(_selectedDate)) {
                            studentVacation = v;
                            break;
                          }
                        }
                        if (studentVacation != null) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.beach_access, size: 14, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text(
                                  'إجازة: ${VacationReason.getLabel(studentVacation.reason)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      })(),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: _isSuspended ? null : () => _showStudentOptions(student, record),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildAttendanceButton(
                  'حاضر',
                  'present',
                  attendance,
                  Colors.green,
                  student.id,
                ),
                const SizedBox(width: 8),
                _buildAttendanceButton(
                  'غائب',
                  'absent',
                  attendance,
                  Colors.red,
                  student.id,
                ),
                const SizedBox(width: 8),
                _buildAttendanceButton(
                  'مستأذن',
                  'excused',
                  attendance,
                  Colors.orange,
                  student.id,
                ),
              ],
            ),
            if (attendance == 'present' || attendance == 'late') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (!_hasFinishedQuran(student))
                    Expanded(
                      child: _buildToggleButton(
                        'حفظ',
                        record?.memorizationDone ?? false,
                        () => _openMemorization(student),
                      ),
                    ),
                  if (!_hasFinishedQuran(student)) const SizedBox(width: 8),
                  Expanded(
                    child: _buildToggleButton(
                      'مراجعة',
                      record?.revisionDone ?? false,
                      () => _openRevision(student),
                    ),
                  ),
                ],
              ),
              if (_hasFinishedQuran(student))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(Icons.verified, size: 14, color: Colors.amber[800]),
                      const SizedBox(width: 4),
                      Text(
                        'أتم حفظ القرآن الكريم — المراجعة فقط',
                        style: TextStyle(fontSize: 11, color: Colors.amber[800], fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceButton(
    String label,
    String value,
    String current,
    Color color,
    String studentId,
  ) {
    final isSelected = current == value;
    return Expanded(
      child: InkWell(
        onTap: _isSuspended ? null : () => _updateAttendance(studentId, value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: _isSuspended ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? Theme.of(context).primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: isActive ? Theme.of(context).primaryColor : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? Theme.of(context).primaryColor
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // الطالب الذي ختم القرآن: إجمالي محفوظه يساوي أو يتجاوز آيات المصحف (6236)
  bool _hasFinishedQuran(Student student) {
    return student.totalMemorized >= 6236;
  }

  Future<void> _openMemorization(Student student) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RecitationScreen(student: student)),
    );
    if (result == true) _loadData(silent: true);
  }

  Future<void> _openRevision(Student student) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RevisionScreen(student: student)),
    );
    if (result == true) _loadData(silent: true);
  }

  void _showStudentOptions(Student student, DailyRecord? record) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add),
              title: const Text('إضافة ملاحظة'),
              onTap: () {
                Navigator.pop(context);
                _showNotesDialog(student, record);
              },
            ),
            if (record?.attendance == 'absent')
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('سبب الغياب'),
                onTap: () {
                  Navigator.pop(context);
                  _showAbsenceReasonDialog(student, record!);
                },
              ),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('تسجيل الحفظ'),
              onTap: () {
                Navigator.pop(context);
                _showMemorizationDialog(student);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNotesDialog(Student student, DailyRecord? record) {
    final controller = TextEditingController(text: record?.notes ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ملاحظات ${student.name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'أدخل الملاحظة...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              final r = record ?? DailyRecord(studentId: student.id, date: _selectedDate);
              final updated = r.copyWith(notes: controller.text);
              await _db.saveDailyRecord(updated);
              if (context.mounted) Navigator.pop(context);
              _loadData();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showAbsenceReasonDialog(Student student, DailyRecord record) {
    String? selectedReason = record.absenceReason;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('سبب الغياب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('مرض'),
                value: 'sick',
                groupValue: selectedReason,
                onChanged: (v) => setState(() => selectedReason = v),
              ),
              RadioListTile<String>(
                title: const Text('عمل/ظرف'),
                value: 'work',
                groupValue: selectedReason,
                onChanged: (v) => setState(() => selectedReason = v),
              ),
              RadioListTile<String>(
                title: const Text('بدون عذر'),
                value: 'no_excuse',
                groupValue: selectedReason,
                onChanged: (v) => setState(() => selectedReason = v),
              ),
              RadioListTile<String>(
                title: const Text('أخرى'),
                value: 'other',
                groupValue: selectedReason,
                onChanged: (v) => setState(() => selectedReason = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                final updated = record.copyWith(absenceReason: selectedReason);
                await _db.saveDailyRecord(updated);
                if (context.mounted) Navigator.pop(context);
                _loadData();
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMemorizationDialog(Student student) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RecitationScreen(student: student)),
    );
  }

  Widget _buildSuspendedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        border: Border(bottom: BorderSide(color: Colors.orange.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'الدراسة معلّقة في هذا اليوم.',
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: Colors.orange[900]),
                ),
                if (_suspensionReason != null && _suspensionReason!.isNotEmpty)
                  Text(
                    'السبب: $_suspensionReason',
                    style: GoogleFonts.tajawal(fontSize: 12, color: Colors.orange[800]),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _toggleSuspension,
            icon: const Icon(Icons.play_circle_outline, size: 16),
            label: Text('تفعيل الحلقة الآن', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(foregroundColor: Colors.teal),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSuspension() async {
    final dateStr = _selectedDate.toIso8601String().split('T')[0];
    final suspendedDates = await _db.getSuspendedDates();
    if (_isSuspended) {
      suspendedDates.remove(dateStr);
      await _db.saveSuspendedDates(suspendedDates);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء تعليق الحلقة لهذا اليوم')),
      );
    } else {
      final result = await _showSuspensionDialog();
      if (result == null) return;

      final reason = result['reason'] as String;
      final days = result['days'] as int;

      final db = await _db.database;
      for (int i = 0; i < days; i++) {
        final d = _selectedDate.add(Duration(days: i));
        final dStr = d.toIso8601String().split('T')[0];
        if (!suspendedDates.contains(dStr)) {
          suspendedDates.add(dStr);
        }
        await _db.setSuspensionReason(dStr, reason);
        await db.delete('daily_records', where: 'date = ?', whereArgs: [dStr]);
      }
      await _db.saveSuspendedDates(suspendedDates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تعليق الدراسة ${days > 1 ? 'لـ $days أيام' : 'لهذا اليوم'} بنجاح 🗓️')),
        );
      }
    }
    _loadData();
  }

  Future<Map<String, dynamic>?> _showSuspensionDialog() async {
    final reasonController = TextEditingController();
    int days = 1;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('تعليق الدراسة', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('سبب تعليق الدراسة (إلزامي):', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  textDirection: TextDirection.rtl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'مثال: امتحانات عامة، ظرف طارئ، إجازة رسمية...',
                    hintStyle: GoogleFonts.tajawal(fontSize: 12),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text('مدة التعليق:', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      onPressed: days > 1 ? () => setDialogState(() => days--) : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Expanded(
                      child: Text(
                        days == 1 ? 'هذا اليوم فقط' : '$days أيام متتالية',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    IconButton(
                      onPressed: days < 30 ? () => setDialogState(() => days++) : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'لن يُحتسب حضور أو غياب أو نقاط سلبية خلال أيام التعليق.',
                  style: GoogleFonts.tajawal(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.tajawal()),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('الرجاء إدخال سبب التعليق', style: GoogleFonts.tajawal())),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'reason': reasonController.text.trim(),
                  'days': days,
                });
              },
              child: Text('تأكيد التعليق', style: GoogleFonts.tajawal()),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrScannerSheet extends StatefulWidget {
  final Function(String) onStudentScanned;

  const _QrScannerSheet({required this.onStudentScanned});

  @override
  State<_QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<_QrScannerSheet> {
  MobileScannerController? _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'مسح QR Code',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_isProcessing) return;
              
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              
              final code = barcodes.first.rawValue;
              if (code == null) return;
              
              final studentId = QrService.decodeQrData(code);
              if (studentId != null) {
                setState(() => _isProcessing = true);
                widget.onStudentScanned(studentId);
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'وجه الكاميرا نحو QR Code الخاص بالطالب',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }
}
