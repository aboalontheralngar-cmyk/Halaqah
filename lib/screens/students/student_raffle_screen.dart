import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';
import 'student_detail_screen.dart';
import '../memorization/recitation_screen.dart';

class StudentRaffleScreen extends StatefulWidget {
  const StudentRaffleScreen({super.key});

  @override
  State<StudentRaffleScreen> createState() => _StudentRaffleScreenState();
}

class _StudentRaffleScreenState extends State<StudentRaffleScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  List<Student> _students = [];
  List<Student> _excludedStudents = [];
  Set<String> _absentStudentIds = {};
  bool _excludeAbsent = true;
  bool _isLoading = true;

  Student? _selectedStudent;
  bool _isDrawing = false;

  // Animation variables
  late AnimationController _celebrationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.05).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.elasticOut),
    );
    _rotationAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.easeInOut),
    );
    _loadStudents();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final list = await _db.getStudents(status: 'active');
      final todayRecords = await _db.getDailyRecordsForDate(DateTime.now());
      final prefs = await SharedPreferences.getInstance();
      final excludedIds = prefs.getStringList('raffle_excluded_ids') ?? [];
      final selectedId = prefs.getString('raffle_selected_id');
      final excludeAbsent = prefs.getBool('raffle_exclude_absent') ?? true;
      final pendingWinnerId = prefs.getString('raffle_pending_winner_id');
      final pendingFinishText = prefs.getString('raffle_pending_finish_at');
      final pendingFinish = pendingFinishText == null
          ? null
          : DateTime.tryParse(pendingFinishText);
      
      setState(() {
        _students = list;
        _excludedStudents = list.where((s) => excludedIds.contains(s.id)).toList();
        _absentStudentIds = todayRecords
            .where((record) => record.attendance == 'absent')
            .map((record) => record.studentId)
            .toSet();
        _excludeAbsent = excludeAbsent;
        if (selectedId != null && selectedId.isNotEmpty) {
          _selectedStudent = list.cast<Student?>().firstWhere(
            (s) => s?.id == selectedId,
            orElse: () => null,
          );
        }
        _isLoading = false;
      });

      final pendingWinner = pendingWinnerId == null
          ? null
          : list.cast<Student?>().firstWhere(
              (student) => student?.id == pendingWinnerId,
              orElse: () => null,
            );
      if (pendingWinner != null && pendingFinish != null) {
        await _restorePendingDraw(pendingWinner, pendingFinish, prefs);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveRaffleState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('raffle_excluded_ids', _excludedStudents.map((s) => s.id).toList());
      await prefs.setString('raffle_selected_id', _selectedStudent?.id ?? '');
      await prefs.setBool('raffle_exclude_absent', _excludeAbsent);
    } catch (e) {
      debugPrint('Error saving raffle state: $e');
    }
  }

  List<Student> get _availableStudents => _students.where((student) {
        final manuallyExcluded =
            _excludedStudents.any((excluded) => excluded.id == student.id);
        final absentExcluded =
            _excludeAbsent && _absentStudentIds.contains(student.id);
        return !manuallyExcluded && !absentExcluded;
      }).toList();

  Future<void> _restorePendingDraw(
    Student winner,
    DateTime finishAt,
    SharedPreferences prefs,
  ) async {
    final remaining = finishAt.difference(DateTime.now());
    if (remaining.isNegative) {
      if (!mounted) return;
      setState(() {
        _selectedStudent = winner;
        _isDrawing = false;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _selectedStudent = winner;
        _isDrawing = true;
      });
      await Future.delayed(remaining);
      if (!mounted) return;
      setState(() {
        _selectedStudent = winner;
        _isDrawing = false;
      });
      _celebrationController.forward(from: 0);
    }
    await prefs.remove('raffle_pending_winner_id');
    await prefs.remove('raffle_pending_finish_at');
    await _saveRaffleState();
  }

  Future<void> _startDraw() async {
    final availableStudents = _availableStudents;

    if (availableStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _students.isEmpty
                ? 'الرجاء إضافة طلاب أولاً لإجراء القرعة!'
                : 'جميع الطلاب تم استبعادهم، يرجى إعادة تعيين المستبعدين!',
            style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isDrawing = true;
      _selectedStudent = null;
    });
    _celebrationController.reset();

    final random = Random();

    // Ticking delays sequence in ms (starts fast, gradually decelerates)
    final delays = [
      40, 40, 40, 40, 40, 45, 45, 45, 50, 50, 60, 70, 80, 95, 110, 130, 155, 185, 225, 275, 335, 405, 495, 605, 755, 955
    ];
    final winner = availableStudents[random.nextInt(availableStudents.length)];
    final prefs = await SharedPreferences.getInstance();
    final finishAt = DateTime.now().add(
      Duration(milliseconds: delays.fold<int>(0, (sum, delay) => sum + delay)),
    );
    await prefs.setString('raffle_pending_winner_id', winner.id);
    await prefs.setString('raffle_pending_finish_at', finishAt.toIso8601String());

    int lastIndex = -1;
    for (var step = 0; step < delays.length; step++) {
      final delay = delays[step];
      if (!mounted) return;

      int randIndex = availableStudents.indexWhere((s) => s.id == winner.id);
      if (step < delays.length - 1) {
        do {
          randIndex = random.nextInt(availableStudents.length);
        } while (availableStudents.length > 1 && randIndex == lastIndex);
      }

      lastIndex = randIndex;

      setState(() {
        _selectedStudent = availableStudents[randIndex];
      });

      // Provide haptic feedback click
      HapticFeedback.lightImpact();

      await Future.delayed(Duration(milliseconds: delay));
    }

    if (!mounted) return;

    // Final winner selection haptics and celebrate
    HapticFeedback.heavyImpact();
    _celebrationController.forward();

    setState(() {
      _selectedStudent = winner;
      _isDrawing = false;
    });
    await prefs.remove('raffle_pending_winner_id');
    await prefs.remove('raffle_pending_finish_at');
    _saveRaffleState();
  }

  Future<void> _drawAllAtOnce() async {
    final ordered = List<Student>.from(_availableStudents)..shuffle(Random());
    if (ordered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد طلاب متاحون للقرعة')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.format_list_numbered),
                title: Text('ترتيب التسميع — قرعة دفعة واحدة'),
                subtitle: Text('من الأول إلى الأخير'),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: ordered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) => ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(ordered[index].name),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _excludeStudent(Student student) {
    if (!_excludedStudents.any((s) => s.id == student.id)) {
      setState(() {
        _excludedStudents.add(student);
        if (_selectedStudent?.id == student.id) {
          _selectedStudent = null;
        }
      });
      _saveRaffleState();
    }
  }

  void _includeStudent(Student student) {
    setState(() {
      _excludedStudents.removeWhere((s) => s.id == student.id);
    });
    _saveRaffleState();
  }

  void _resetExclusions() {
    setState(() {
      _excludedStudents.clear();
      _selectedStudent = null;
    });
    _saveRaffleState();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final availableCount = _availableStudents.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'قرعة الطلاب العشوائية',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.format_list_numbered),
            tooltip: 'قرعة دفعة واحدة',
            onPressed: _isDrawing ? null : _drawAllAtOnce,
          ),
          if (_excludedStudents.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'إعادة تعيين القرعة',
              onPressed: _resetExclusions,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                      : [const Color(0xFFE2E8F0), const Color(0xFFF8FAFC)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Top Info Row
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildHeaderBadge(
                            'المتاحون للقرعة: $availableCount / ${_students.length}',
                            Colors.teal,
                          ),
                          _buildHeaderBadge(
                            'يدويًا: ${_excludedStudents.length}',
                            Colors.orange,
                          ),
                        ],
                      ),
                    ),
                    FilterChip(
                      avatar: const Icon(Icons.person_off_outlined, size: 18),
                      label: Text(
                        'استبعاد الغائبين اليوم (${_absentStudentIds.length})',
                        style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                      ),
                      selected: _excludeAbsent,
                      onSelected: (value) {
                        setState(() => _excludeAbsent = value);
                        _saveRaffleState();
                      },
                    ),

                    const Spacer(),

                    // Center Draw Board
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _celebrationController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _isDrawing ? 1.0 : _scaleAnimation.value,
                              child: Transform.rotate(
                                angle: _isDrawing ? 0.0 : _rotationAnimation.value,
                                child: child,
                              ),
                            );
                          },
                          child: _buildDrawCard(isDark, primaryColor),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Action buttons when a student is selected
                    if (_selectedStudent != null && !_isDrawing)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal[700],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.menu_book),
                                    label: Text(
                                      'تسميع مباشر',
                                      style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => RecitationScreen(student: _selectedStudent!),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.person),
                                    label: Text(
                                      'ملف الطالب',
                                      style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => StudentDetailScreen(student: _selectedStudent!),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.orange[800],
                              ),
                              icon: const Icon(Icons.block),
                              label: Text(
                                'استبعاد من السحبات القادمة مؤقتاً',
                                style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _excludeStudent(_selectedStudent!),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Draw triggers button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDrawing ? Colors.grey : const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: _isDrawing ? Colors.transparent : Colors.teal.withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            elevation: _isDrawing ? 0 : 8,
                          ),
                          onPressed: _isDrawing ? null : _startDraw,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isDrawing ? Icons.autorenew : Icons.casino,
                                color: Colors.teal[300],
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _isDrawing ? 'جاري السحب العشوائي...' : '🎲 اسحب اسماً عشوائياً',
                                style: GoogleFonts.tajawal(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Excluded Students Bottom List
                    _buildExcludedList(isDark),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.tajawal(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDrawCard(bool isDark, Color primaryColor) {
    if (_selectedStudent == null) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.question_mark,
                size: 48,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'من هو طالب اليوم المحظوظ؟',
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'اضغط على زر السحب لبدء القرعة العشوائية',
              style: GoogleFonts.tajawal(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _isDrawing
            ? (isDark ? const Color(0xFF1E293B) : Colors.white)
            : (isDark ? const Color(0xFF1E293B) : Colors.teal[55]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isDrawing ? Colors.teal.withOpacity(0.5) : Colors.amber,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: _isDrawing
                ? Colors.teal.withOpacity(0.1)
                : Colors.amber.withOpacity(isDark ? 0.25 : 0.15),
            blurRadius: _isDrawing ? 10 : 25,
            spreadRadius: _isDrawing ? 0 : 5,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!_isDrawing)
            Positioned(
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'تم الاختيار!',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: _isDrawing ? Colors.teal.withOpacity(0.1) : Colors.amber.withOpacity(0.15),
                child: Text(
                  _selectedStudent!.name.isNotEmpty ? _selectedStudent!.name[0] : '؟',
                  style: GoogleFonts.tajawal(
                    color: _isDrawing ? Colors.teal : Colors.amber[800],
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  _selectedStudent!.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExcludedList(bool isDark) {
    if (_excludedStudents.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : Colors.white.withOpacity(0.8),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الطلاب المستبعدون مؤقتاً (${_excludedStudents.length})',
                style: GoogleFonts.tajawal(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              GestureDetector(
                onTap: _resetExclusions,
                child: Text(
                  'إعادة إدراج الجميع',
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _excludedStudents.length,
              itemBuilder: (context, index) {
                final student = _excludedStudents[index];
                return Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Chip(
                    label: Text(
                      student.name.split(' ')[0], // Show first name only
                      style: GoogleFonts.tajawal(fontSize: 11),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 12),
                    onDeleted: () => _includeStudent(student),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
