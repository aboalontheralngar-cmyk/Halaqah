import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/database_service.dart';
import '../../services/qr_service.dart';
import '../../services/student_learning_policy.dart';
import '../../models/settings.dart';
import '../../models/student.dart';
import '../../models/daily_record.dart';
import '../../models/vacation.dart';
import '../../models/student_hold.dart';
import '../../app/design_tokens.dart';
import '../../utils/helpers.dart';
import '../../utils/prayer_time_helper.dart';
import '../../widgets/app_design_widgets.dart';
import '../memorization/add_memorization_screen.dart';
import '../memorization/recitation_screen.dart';
import '../memorization/revision_screen.dart';
import '../settings/add_vacation_screen.dart';
import 'daily_closing_screen.dart';

class AttendanceScreen extends StatefulWidget {
  final VoidCallback? onOpenMenu;

  const AttendanceScreen({super.key, this.onOpenMenu});

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
  Map<String, StudentHold> _activeHolds = {};
  bool _isSuspended = false;
  String? _suspensionReason;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final dateKey = _selectedDate.toIso8601String().split('T')[0];
      final results = await Future.wait<dynamic>([
        _db.getStudents(status: 'active'),
        _db.getDailyRecordsForDate(_selectedDate),
        _db.getSettings(),
        _db.getAllVacations(),
        _db.getActiveStudentHolds(date: _selectedDate),
        _db.isDateSuspended(_selectedDate),
        _db.getSuspensionReasons(),
      ]);
      final students = results[0] as List<Student>;
      final records = results[1] as List<DailyRecord>;
      final settings = results[2] as HalaqahSettings;
      final vacations = results[3] as List<Vacation>;
      final holds = results[4] as List<StudentHold>;
      final isSuspended = results[5] as bool;
      final reasons = results[6] as Map<String, String>;
      final suspensionReason = reasons[dateKey] ??
          (settings.isHolidayWeekday(_selectedDate) ? 'إجازة أسبوعية' : null);

      final recordsMap = <String, DailyRecord>{
        for (final record in records) record.studentId: record,
      };
      final approvedVacationByStudent = <String, Vacation>{};
      for (final vacation in vacations) {
        if (vacation.approved && vacation.isDateInVacation(_selectedDate)) {
          approvedVacationByStudent.putIfAbsent(vacation.studentId, () => vacation);
        }
      }

      final automaticExcusedRecords = <DailyRecord>[];
      for (final student in students) {
        final activeVacation = approvedVacationByStudent[student.id];
        if (activeVacation == null) continue;
        final existing = recordsMap[student.id];
        if (existing != null &&
            existing.attendance.isNotEmpty &&
            existing.attendance != 'absent') {
          continue;
        }
        final reasonLabel = VacationReason.getLabel(activeVacation.reason);
        final newRecord = (existing ?? DailyRecord(
          studentId: student.id,
          date: _selectedDate,
        )).copyWith(
          attendance: 'excused',
          notes: 'إجازة تلقائية: $reasonLabel',
        );
        automaticExcusedRecords.add(newRecord);
        recordsMap[student.id] = newRecord;
      }
      await _db.saveDailyRecords(automaticExcusedRecords);

      if (!mounted) return;
      setState(() {
        _students = students;
        _todayRecords = recordsMap;
        _settings = settings;
        _vacations = vacations;
        _activeHolds = {for (final hold in holds) hold.studentId: hold};
        _isSuspended = isSuspended;
        _suspensionReason = suspensionReason;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
    final now = DateTime.now();
    final arrival = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      now.hour,
      now.minute,
      now.second,
    );
    final classStart =
        PrayerTimeHelper.calculateClassTimes(_settings, _selectedDate).start;
    final isToday = Helpers.isSameDay(_selectedDate, DateTime.now());
    final effectiveAttendance = attendance == 'present' &&
            isToday &&
            arrival.isAfter(classStart)
        ? 'late'
        : attendance;
    final isPresent =
        effectiveAttendance == 'present' || effectiveAttendance == 'late';
    final updated = record.copyWith(
      attendance: effectiveAttendance,
      arrivalTime:
          isPresent ? (record.arrivalTime ?? (isToday ? arrival : null)) : null,
      clearArrivalTime: !isPresent,
      clearAbsenceReason: isPresent,
      clearAbsenceNote: isPresent,
      clearActivityType: !isPresent,
      clearActivityNote: !isPresent,
      recitationExempt: !isPresent ? false : record.recitationExempt,
    );
    await _db.saveDailyRecord(updated);
    if (!mounted) return;
    setState(() => _todayRecords[studentId] = updated);
  }

  Future<void> _clearPresentAttendance(String studentId) async {
    final record = _todayRecords[studentId];
    if (record == null ||
        (record.attendance != 'present' && record.attendance != 'late')) {
      return;
    }

    // Undo only the attendance mark itself. Learning, activity and exemption
    // data may have been entered independently, so never erase them here.
    final updated = record.copyWith(
      attendance: 'unmarked',
      clearArrivalTime: true,
      clearAbsenceReason: true,
      clearAbsenceNote: true,
    );
    await _db.saveDailyRecord(updated);
    if (!mounted) return;
    setState(() => _todayRecords[studentId] = updated);
  }

  Future<void> _showActivityDialog(
    Student student,
    DailyRecord? existing,
  ) async {
    var selectedType = existing?.activityType ?? DailyActivityType.activity;
    final notesController = TextEditingController(text: existing?.activityNote ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('نشاط ${student.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'يُحسب الطالب حاضرًا، ويُعفى من متطلب التسميع لهذا اليوم ما لم يُسجل له تسميع فعلي.',
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: DailyActivityType.labels.entries.map((entry) {
                    return ChoiceChip(
                      label: Text(entry.value),
                      selected: selectedType == entry.key,
                      onSelected: (_) =>
                          setDialogState(() => selectedType = entry.key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل النشاط (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (existing?.hasActivity == true)
              TextButton(
                onPressed: () => Navigator.pop(context, 'remove'),
                child: const Text('إزالة النشاط'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('تحضير ضمن النشاط'),
            ),
          ],
        ),
      ),
    );
    if (result == null) {
      notesController.dispose();
      return;
    }

    final record = existing ?? _getOrCreateRecord(student.id);
    late final DailyRecord savedRecord;
    if (result == 'remove') {
      savedRecord = record.copyWith(
        clearActivityType: true,
        clearActivityNote: true,
        recitationExempt: false,
      );
      await _db.saveDailyRecord(savedRecord);
    } else {
      final now = DateTime.now();
      final isToday = Helpers.isSameDay(_selectedDate, now);
      final arrival = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        now.hour,
        now.minute,
        now.second,
      );
      final classStart =
          PrayerTimeHelper.calculateClassTimes(_settings, _selectedDate).start;
      final attendance = isToday && arrival.isAfter(classStart)
          ? 'late'
          : 'present';
      savedRecord = record.copyWith(
        attendance: attendance,
        arrivalTime: record.arrivalTime ?? (isToday ? arrival : null),
        clearAbsenceReason: true,
        clearAbsenceNote: true,
        activityType: selectedType,
        activityNote: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
        clearActivityNote: notesController.text.trim().isEmpty,
        recitationExempt: true,
      );
      await _db.saveDailyRecord(savedRecord);
    }
    notesController.dispose();
    if (!mounted) return;
    setState(() => _todayRecords[student.id] = savedRecord);
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
      if (!mounted) return;
      setState(() {
        _vacations = [vacation, ..._vacations];
        _todayRecords[student.id] = updated;
      });
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
          onStudentScanned: (qrToken) async {
            final student = await _db.getStudentByQrCode(qrToken) ??
                await _db.getStudent(qrToken);
            if (student != null && mounted) {
              Navigator.pop(context);
              await _showQrQuickActions(student);
            }
          },
        ),
      ),
    );
  }

  Future<void> _showQrQuickActions(Student student) async {
    if (!mounted) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('وصول سريع عبر رمز الطالب · ${student.displayCode}'),
              ),
              const SizedBox(height: 4),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 1.15,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  _qrAction(context, 'present', 'تحضير', Icons.how_to_reg, Colors.green),
                  _qrAction(context, 'absent', 'غياب', Icons.person_off_outlined, Colors.red),
                  _qrAction(context, 'excused', 'استئذان', Icons.event_busy_outlined, Colors.blue),
                  _qrAction(context, 'memorization_session', 'جلسة تسميع', Icons.record_voice_over_outlined, Colors.teal),
                  _qrAction(context, 'memorization_direct', 'حفظ مباشر', Icons.fact_check_outlined, Colors.green),
                  _qrAction(context, 'revision', 'تسجيل مراجعة', Icons.replay, Colors.indigo),
                  _qrAction(context, 'vacation', 'إجازة', Icons.beach_access_outlined, Colors.orange),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (const {'present', 'absent', 'excused'}.contains(action)) {
      await _updateAttendance(student.id, action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث حالة ${student.name}')),
        );
      }
      return;
    }
    if (const {
      'memorization_session',
      'memorization_direct',
      'revision',
    }.contains(action)) {
      if (!await _canOpenRecitation(student) || !mounted) return;
    }
    if (const {
      'memorization_session',
      'memorization_direct',
    }.contains(action) &&
        !StudentLearningPolicy.canReceiveNewMemorization(student)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${student.name} أتم حفظ القرآن؛ المتاح له من رمز QR هو المراجعة فقط.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (action == 'memorization_session') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RecitationScreen(student: student)),
      );
    } else if (action == 'memorization_direct') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddMemorizationScreen(student: student),
        ),
      );
    } else if (action == 'revision') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RevisionScreen(student: student)),
      );
    } else if (action == 'vacation') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AddVacationScreen(student: student)),
      );
    }
    await _loadData(silent: true);
  }

  Widget _qrAction(
    BuildContext sheetContext,
    String value,
    String label,
    IconData icon,
    Color color,
  ) => InkWell(
        onTap: () => Navigator.pop(sheetContext, value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            border: Border.all(color: color.withValues(alpha: 0.28)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    bool isPaused(Student student) =>
        _activeHolds[student.id]?.exemptsAttendance == true;
    final presentCount = _students.where((student) {
      if (isPaused(student)) return false;
      final attendance = _todayRecords[student.id]?.attendance;
      return attendance == 'present' || attendance == 'late';
    }).length;
    final absentCount = _students.where((student) {
      if (isPaused(student)) return false;
      return _todayRecords[student.id]?.attendance == 'absent';
    }).length;
    final excusedCount = _students.where((student) {
      if (isPaused(student)) return false;
      return _todayRecords[student.id]?.attendance == 'excused';
    }).length;
    final pausedCount = _students.where(isPaused).length;
    final remainingCount = (_students.length -
            pausedCount -
            presentCount -
            absentCount -
            excusedCount)
        .clamp(0, _students.length)
        .toInt();

    return Scaffold(
      appBar: AppBar(
        leading: widget.onOpenMenu == null
            ? null
            : IconButton(
                onPressed: widget.onOpenMenu,
                icon: const Icon(Icons.menu),
                tooltip: 'القائمة الرئيسية',
              ),
        title: const Text('الحضور اليومي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DailyClosingScreen(initialDate: _selectedDate),
              ),
            ).then((_) => _loadData(silent: true)),
            tooltip: 'مراجعة وإغلاق اليوم',
          ),
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
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      color: scheme.primaryContainer.withValues(alpha: 0.45),
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
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Text(
                        Helpers.getDayName(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        Helpers.getFullHijriDate(_selectedDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
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
            style: TextStyle(
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
            color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
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
                  color: color.withValues(alpha: isSelected ? 0.35 : 0.1),
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    return const AppEmptyState(
      icon: Icons.people_outline,
      title: 'لا يوجد طلاب',
      message: 'أضف طالبًا إلى الحلقة ليظهر في سجل الحضور.',
    );
  }

  List<Student> _getFilteredStudents() {
    switch (_filter) {
      case 'present':
        return _students.where((s) {
          if (_activeHolds[s.id]?.exemptsAttendance == true) return false;
          final r = _todayRecords[s.id];
          return r?.attendance == 'present' || r?.attendance == 'late';
        }).toList();
      case 'absent':
        return _students.where((s) {
          if (_activeHolds[s.id]?.exemptsAttendance == true) return false;
          final r = _todayRecords[s.id];
          return r?.attendance == 'absent';
        }).toList();
      case 'excused':
        return _students.where((s) {
          if (_activeHolds[s.id]?.exemptsAttendance == true) return false;
          final r = _todayRecords[s.id];
          return r?.attendance == 'excused';
        }).toList();
      case 'remaining':
        return _students.where((s) {
          if (_activeHolds[s.id]?.exemptsAttendance == true) return false;
          final r = _todayRecords[s.id];
          return r == null || r.attendance.isEmpty || r.attendance == 'unmarked';
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
              Icon(Icons.filter_list_off, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(
                'لا يوجد طلاب في هذا التصنيف',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
    final activeHold = _activeHolds[student.id];
    final isFullPause = activeHold?.exemptsAttendance == true;
    
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
                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
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
                            color: isLate(record) ? Colors.orange : Theme.of(context).colorScheme.onSurfaceVariant,
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
                      if (isFullPause)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.pause_circle_outline,
                                  size: 14, color: Colors.blueGrey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'متوقف مؤقتًا: ${activeHold!.reason}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.blueGrey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (record?.hasActivity == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.celebration_outlined,
                                  size: 14, color: Colors.purple),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${DailyActivityType.label(record!.activityType)} — معفى من التسميع اليوم',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.purple,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: _isSuspended || isFullPause
                      ? null
                      : () => _showStudentOptions(student, record),
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
                  disabled: isFullPause,
                ),
                const SizedBox(width: 8),
                _buildAttendanceButton(
                  'غائب',
                  'absent',
                  attendance,
                  Colors.red,
                  student.id,
                  disabled: isFullPause,
                ),
                const SizedBox(width: 8),
                _buildAttendanceButton(
                  'مستأذن',
                  'excused',
                  attendance,
                  Colors.orange,
                  student.id,
                  disabled: isFullPause,
                ),
              ],
            ),
            if (!isFullPause) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSuspended
                      ? null
                      : () => _showActivityDialog(student, record),
                  icon: Icon(record?.hasActivity == true
                      ? Icons.celebration
                      : Icons.celebration_outlined),
                  label: Text(record?.hasActivity == true
                      ? 'تعديل نشاط: ${DailyActivityType.label(record!.activityType)}'
                      : 'تحضير ضمن نشاط / فعالية'),
                ),
              ),
            ],
            if (!isFullPause &&
                (attendance == 'present' || attendance == 'late')) ...[
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
    String studentId, {
    bool disabled = false,
  }) {
    final isSelected = current == value ||
        (value == 'present' && current == 'late');
    return Expanded(
      child: InkWell(
        onTap: _isSuspended || disabled
            ? null
            : () {
                if (value == 'present' && isSelected) {
                  _clearPresentAttendance(studentId);
                } else {
                  _updateAttendance(studentId, value);
                }
              },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
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
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.outlineVariant,
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
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasFinishedQuran(Student student) =>
      StudentLearningPolicy.hasCompletedQuran(student);

  Future<void> _openMemorization(Student student) async {
    if (!await _canOpenRecitation(student)) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RecitationScreen(student: student)),
    );
    if (result == true) _loadData(silent: true);
  }

  Future<void> _openRevision(Student student) async {
    if (!await _canOpenRecitation(student)) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RevisionScreen(student: student)),
    );
    if (result == true) _loadData(silent: true);
  }

  Future<bool> _canOpenRecitation(Student student) async {
    final now = DateTime.now();
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    if (selected != today) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('التسميع المباشر متاح لليوم الحالي فقط'),
        ),
      );
      return false;
    }
    final hold = await _db.getActiveStudentHold(student.id, date: now);
    if (hold != null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'التسميع موقوف مؤقتًا: ${hold.reason} — حتى '
            '${Helpers.formatHijriDate(hold.endDate)}',
          ),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return false;
    }
    return true;
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
          content: RadioGroup<String>(
            groupValue: selectedReason,
            onChanged: (value) => setState(() => selectedReason = value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                RadioListTile<String>(
                  title: Text('مرض'),
                  value: 'sick',
                ),
                RadioListTile<String>(
                  title: Text('عمل/ظرف'),
                  value: 'work',
                ),
                RadioListTile<String>(
                  title: Text('بدون عذر'),
                  value: 'no_excuse',
                ),
                RadioListTile<String>(
                  title: Text('أخرى'),
                  value: 'other',
                ),
              ],
            ),
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
    _openMemorization(student);
  }

  Widget _buildSuspendedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        border: Border(bottom: BorderSide(color: Colors.orange.withValues(alpha: 0.3))),
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
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[900]),
                ),
                if (_suspensionReason != null && _suspensionReason!.isNotEmpty)
                  Text(
                    'السبب: $_suspensionReason',
                    style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _toggleSuspension,
            icon: const Icon(Icons.play_circle_outline, size: 16),
            label: Text('تفعيل الحلقة الآن', style: TextStyle(fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(foregroundColor: Colors.teal),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSuspension() async {
    if (_isSuspended) {
      await _db.setStudySuspension(
        date: _selectedDate,
        suspended: false,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء تعليق الحلقة لهذا اليوم')),
        );
      }
    } else {
      final result = await _showSuspensionDialog();
      if (result == null) return;

      final reason = result['reason'] as String;
      final days = result['days'] as int;
      var removedAttendance = 0;
      var removedPoints = 0;
      for (int i = 0; i < days; i++) {
        final d = _selectedDate.add(Duration(days: i));
        final cleanup = await _db.setStudySuspension(
          date: d,
          suspended: true,
          reason: reason,
        );
        removedAttendance += cleanup['deleted_attendance'] ?? 0;
        removedPoints += cleanup['deleted_points'] ?? 0;
      }

      if (mounted) {
        final cleanupText = removedAttendance + removedPoints == 0
            ? ''
            : ' وتم التراجع عن $removedAttendance غياب تلقائي و$removedPoints عقوبة تلقائية.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تعليق الدراسة ${days > 1 ? 'لـ $days أيام' : 'لهذا اليوم'} بنجاح 🗓️$cleanupText',
            ),
          ),
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
          title: Text('تعليق الدراسة', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('سبب تعليق الدراسة (إلزامي):', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  textDirection: TextDirection.rtl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'مثال: امتحانات عامة، ظرف طارئ، إجازة رسمية...',
                    hintStyle: TextStyle(fontSize: 12),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text('مدة التعليق:', style: TextStyle(fontWeight: FontWeight.w600)),
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
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: TextStyle()),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('الرجاء إدخال سبب التعليق', style: TextStyle())),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'reason': reasonController.text.trim(),
                  'days': days,
                });
              },
              child: Text('تأكيد التعليق', style: TextStyle()),
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
              
              final qrToken = QrService.decodeQrData(code);
              if (qrToken != null) {
                setState(() => _isProcessing = true);
                _controller?.stop();
                widget.onStudentScanned(qrToken);
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'وجه الكاميرا نحو QR Code الخاص بالطالب',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
