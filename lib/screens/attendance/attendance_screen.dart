import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/sound_service.dart';
import '../../services/database_service.dart';
import '../../services/qr_service.dart';
import '../../models/student.dart';
import '../../models/daily_record.dart';
import '../../utils/helpers.dart';
import '../memorization/recitation_screen.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final students = await _db.getStudents(status: 'active');
      final records = await _db.getDailyRecordsForDate(_selectedDate);
      
      final recordsMap = <String, DailyRecord>{};
      for (final record in records) {
        recordsMap[record.studentId] = record;
      }
      
      setState(() {
        _students = students;
        _todayRecords = recordsMap;
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

  Future<void> _updateAttendance(String studentId, String attendance) async {
    final record = _getOrCreateRecord(studentId);
    final updated = record.copyWith(
      attendance: attendance,
      arrivalTime: attendance == 'present' || attendance == 'late'
          ? DateTime.now()
          : null,
    );
    await _db.saveDailyRecord(updated);
    _loadData();
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
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: _QrScannerSheet(
          onRefresh: _loadData,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('الحضور اليومي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _openQrScanner,
            tooltip: 'مسح QR',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          _buildStatsBar(presentCount, absentCount),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _students.isEmpty
                    ? _buildEmptyState()
                    : _buildStudentList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openQrScanner,
        child: const Icon(Icons.qr_code_scanner),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Row(
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
    );
  }

  Widget _buildStatsBar(int present, int absent) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatChip('الطلاب', '${_students.length}', Colors.blue),
          _buildStatChip('حاضر', '$present', Colors.green),
          _buildStatChip('غائب', '$absent', Colors.red),
          _buildStatChip('متبقي', '${_students.length - present - absent}', Colors.grey),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
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

  Widget _buildStudentList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _students.length,
        itemBuilder: (context, index) {
          final student = _students[index];
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
                          'وصل: ${Helpers.formatTime(record!.arrivalTime!)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showStudentOptions(student, record),
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
                  'متأخر',
                  'late',
                  attendance,
                  Colors.orange,
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
              ],
            ),
            if (attendance == 'present' || attendance == 'late') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildToggleButton(
                      'حفظ',
                      record?.memorizationDone ?? false,
                      () => _toggleMemorization(student.id, record),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildToggleButton(
                      'مراجعة',
                      record?.revisionDone ?? false,
                      () => _toggleRevision(student.id, record),
                    ),
                  ),
                ],
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
        onTap: () => _updateAttendance(studentId, value),
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
      onTap: onTap,
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

  Future<void> _toggleMemorization(String studentId, DailyRecord? record) async {
    final r = record ?? DailyRecord(studentId: studentId, date: _selectedDate);
    final updated = r.copyWith(memorizationDone: !r.memorizationDone);
    await _db.saveDailyRecord(updated);
    _loadData();
  }

  Future<void> _toggleRevision(String studentId, DailyRecord? record) async {
    final r = record ?? DailyRecord(studentId: studentId, date: _selectedDate);
    final updated = r.copyWith(revisionDone: !r.revisionDone);
    await _db.saveDailyRecord(updated);
    _loadData();
  }

  void _showStudentOptions(Student student, DailyRecord? record) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
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
}

class _QrScannerSheet extends StatefulWidget {
  final VoidCallback onRefresh;

  const _QrScannerSheet({required this.onRefresh});

  @override
  State<_QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<_QrScannerSheet> {
  final DatabaseService _db = DatabaseService();
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  bool _torchEnabled = false;
  
  // Status feedback properties
  String _statusMessage = '';
  Color _statusColor = Colors.transparent;
  IconData _statusIcon = Icons.info;
  
  // Attendance mode selector: 'present' or 'late'
  String _attendanceMode = 'present';
  int _presentCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPresentCount();
  }

  Future<void> _loadPresentCount() async {
    try {
      final records = await _db.getDailyRecordsForDate(DateTime.now());
      final count = records.where((r) => r.attendance == 'present' || r.attendance == 'late').length;
      setState(() => _presentCount = count);
    } catch (_) {}
  }

  void _toggleTorch() {
    _controller.toggleTorch();
    setState(() => _torchEnabled = !_torchEnabled);
  }

  Future<Student?> _findStudentByBarcode(String barcode) async {
    // 1. Try decoding as Halaqah custom QR format
    final decodedId = QrService.decodeQrData(barcode);
    if (decodedId != null) {
      final s = await _db.getStudent(decodedId);
      if (s != null) return s;
    }
    
    // 2. Try raw ID match
    final sById = await _db.getStudent(barcode);
    if (sById != null) return sById;
    
    // 3. Try raw qr_code match
    final sByQr = await _db.getStudentByQrCode(barcode);
    if (sByQr != null) return sByQr;
    
    // 4. Try phone match
    final allStudents = await _db.getStudents();
    for (final s in allStudents) {
      if (s.phone == barcode || s.guardianPhone == barcode) {
        return s;
      }
    }
    
    return null;
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() => _isProcessing = true);
    final code = barcode.rawValue!;

    try {
      final student = await _findStudentByBarcode(code);
      if (student == null) {
        await SoundService.playError();
        _showStatus('طالب غير معروف!', Colors.red, Icons.person_off_outlined);
      } else {
        // Check if already checked in today
        final todayRecord = await _db.getDailyRecord(student.id, DateTime.now());
        if (todayRecord != null && (todayRecord.attendance == 'present' || todayRecord.attendance == 'late')) {
          await SoundService.playWarning();
          _showStatus('${student.name}\nمسجل مسبقاً ✓', Colors.orange[800]!, Icons.info_outline);
        } else {
          // Update attendance
          final record = todayRecord ?? DailyRecord(studentId: student.id, date: DateTime.now());
          final updated = record.copyWith(
            attendance: _attendanceMode,
            arrivalTime: DateTime.now(),
          );
          await _db.saveDailyRecord(updated);
          await _loadPresentCount();
          await SoundService.playSuccess();
          _showStatus(
            '${student.name}\nتم تسجيل ${_attendanceMode == 'present' ? 'الحضور' : 'التأخر'} ✓',
            const Color(0xFF047857),
            Icons.check_circle_outline,
          );
          widget.onRefresh();
        }
      }
    } catch (e) {
      await SoundService.playError();
      _showStatus('حدث خطأ أثناء التسجيل: $e', Colors.red, Icons.error_outline);
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _statusMessage = '';
      });
    }
  }

  void _showStatus(String message, Color color, IconData icon) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
        _statusColor = color;
        _statusIcon = icon;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        // App bar panel inside sheet
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'مسح التحضير اليومي',
                    style: GoogleFonts.tajawal(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _torchEnabled ? Icons.flash_on : Icons.flash_off,
                          color: _torchEnabled ? Colors.amber[600] : Colors.grey,
                        ),
                        onPressed: _toggleTorch,
                        tooltip: 'الفلاش',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Mode Selector Segmented Button
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'present',
                        label: Text('حضور'),
                        icon: Icon(Icons.check_circle_outline, size: 16),
                      ),
                      ButtonSegment(
                        value: 'late',
                        label: Text('تأخر'),
                        icon: Icon(Icons.access_time, size: 16),
                      ),
                    ],
                    selected: {_attendanceMode},
                    onSelectionChanged: (set) {
                      setState(() {
                        _attendanceMode = set.first;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  
                  // Total Scanned Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people_outline, size: 16, color: Color(0xFF0D9488)),
                        const SizedBox(width: 6),
                        Text(
                          'المسجلين اليوم: $_presentCount',
                          style: GoogleFonts.tajawal(
                            color: const Color(0xFF0D9488),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Scanner viewport
        Expanded(
          child: Stack(
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _handleBarcode,
              ),
              Positioned.fill(
                child: Container(
                  decoration: ShapeDecoration(
                    shape: QrScannerOverlayShape(
                      borderColor: _attendanceMode == 'present' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      borderRadius: 20,
                      borderLength: 30,
                      borderWidth: 6,
                      cutOutSize: 240,
                    ),
                  ),
                ),
              ),
              
              // Scanning delay overlay
              if (_isProcessing && _statusMessage.isEmpty)
                Positioned.fill(
                  child: Container(
                    color: Colors.black38,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
                
              // Floating animated status card
              if (_statusMessage.isNotEmpty)
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _statusColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _statusColor.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _statusIcon,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          color: isDark ? const Color(0xFF1E293B) : Colors.grey[50],
          child: Center(
            child: Text(
              'وجه الكاميرا نحو رمز الاستجابة السريعة للطالب لتسجيله تلقائياً',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double borderLength;
  final double borderRadius;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.teal,
    this.borderWidth = 6.0,
    this.borderLength = 30.0,
    this.borderRadius = 20.0,
    this.cutOutSize = 240.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final size = cutOutSize;

    final left = (width - size) / 2;
    final top = (height - size) / 2;

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Draw dark mask around the cutout area
    final clipPath = Path()
      ..addRect(rect)
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, size, size),
          Radius.circular(borderRadius),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(clipPath, backgroundPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final borderPath = Path();

    // Top Left Corner
    borderPath.moveTo(left, top + borderLength);
    borderPath.lineTo(left, top + borderRadius);
    borderPath.quadraticBezierTo(left, top, left + borderRadius, top);
    borderPath.lineTo(left + borderLength, top);

    // Top Right Corner
    borderPath.moveTo(left + size - borderLength, top);
    borderPath.lineTo(left + size - borderRadius, top);
    borderPath.quadraticBezierTo(left + size, top, left + size, top + borderRadius);
    borderPath.lineTo(left + size, top + borderLength);

    // Bottom Left Corner
    borderPath.moveTo(left, top + size - borderLength);
    borderPath.lineTo(left, top + size - borderRadius);
    borderPath.quadraticBezierTo(left, top + size, left + borderRadius, top + size);
    borderPath.lineTo(left + borderLength, top + size);

    // Bottom Right Corner
    borderPath.moveTo(left + size - borderLength, top + size);
    borderPath.lineTo(left + size - borderRadius, top + size);
    borderPath.quadraticBezierTo(left + size, top + size, left + size, top + size - borderRadius);
    borderPath.lineTo(left + size, top + size - borderLength);

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  ShapeBorder scale(double t) => this;
}
