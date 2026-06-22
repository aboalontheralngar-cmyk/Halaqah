import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/database_service.dart';
import '../../services/supabase_service.dart';
import '../auth/login_screen.dart';
import '../../models/student.dart';
import '../../models/settings.dart';
import '../../utils/helpers.dart';
import '../students/students_screen.dart';
import '../students/student_raffle_screen.dart';
import '../attendance/attendance_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../memorization/memorization_screen.dart';
import '../behavior/behavior_screen.dart';
import '../exam/exams_screen.dart';
import '../fund/fund_screen.dart';
import '../plans/plans_screen.dart';
import '../notifications/notifications_screen.dart';
import '../honor_board/honor_board_screen.dart';
import '../vacations/vacations_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final DatabaseService _db = DatabaseService();
  
  List<Student> _students = [];
  bool _isLoading = true;
  int _presentToday = 0;
  int _absentToday = 0;
  int _unreadNotifications = 0;
  double _fundBalance = 0.0;
  String _halaqahName = 'حلقتي';
  String _mosqueName = 'المسجد';
  Map<String, String> _todayAttendance = {};
  HalaqahSettings _settings = HalaqahSettings();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final students = await _db.getStudents(status: 'active');
      final todayRecords = await _db.getDailyRecordsForDate(DateTime.now());
      final settings = await _db.getSettings();
      final unreadCount = await _db.getUnreadNotificationsCount();
      final balance = await _db.getFundBalance();

      int present = 0;
      int absent = 0;
      final Map<String, String> attMap = {};
      for (final record in todayRecords) {
        attMap[record.studentId] = record.attendance;
        if (record.attendance == 'present' || record.attendance == 'late') {
          present++;
        } else if (record.attendance == 'absent') {
          absent++;
        }
      }

      setState(() {
        _students = students;
        _presentToday = present;
        _absentToday = absent;
        _unreadNotifications = unreadCount;
        _fundBalance = balance;
        _halaqahName = settings.halaqahName;
        _mosqueName = settings.mosqueName.isNotEmpty ? settings.mosqueName : 'المسجد الرئيسي';
        _todayAttendance = attMap;
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncWithCloud() async {
    final supabase = SupabaseService.instance;
    if (!supabase.isAuthenticated) {
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (loggedIn == true) {
        _loadData();
      }
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text(
                'جاري مزامنة البيانات...',
                style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );

      try {
        await supabase.synchronizeData();
        if (mounted) Navigator.pop(context);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تمت المزامنة مع السحابة بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشلت المزامنة: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<bool?> _showExitConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E2124), // Dark charcoal
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تأكيد!',
                style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'هل تريد الخروج من تطبيق حلقتي؟',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  color: const Color(0xFF9EA3AC), // Slate grey
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        'حسناً',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white, // White
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'إلغاء',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF9EA3AC), // Grey
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _showExitConfirmationDialog(context);
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: _buildBody(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
            if (index == 0) _loadData();
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outlined),
              selectedIcon: const Icon(Icons.people),
              label: GenderHelper.students(_settings.gender),
            ),
            const NavigationDestination(
              icon: Icon(Icons.qr_code_scanner),
              selectedIcon: Icon(Icons.qr_code_scanner_outlined),
              label: 'القارئ',
            ),
            const NavigationDestination(
              icon: Icon(Icons.assessment_outlined),
              selectedIcon: Icon(Icons.assessment),
              label: 'التقارير',
            ),
            const NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return const StudentsScreen();
      case 2:
        return const AttendanceScreen();
      case 3:
        return const ReportsScreen();
      case 4:
        return const SettingsScreen();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 150,
            pinned: true,
            actions: [
              IconButton(
                icon: Icon(
                  SupabaseService.instance.isAuthenticated
                      ? Icons.cloud_done
                      : Icons.cloud_queue,
                  color: SupabaseService.instance.isAuthenticated ? Colors.green : null,
                ),
                onPressed: _syncWithCloud,
                tooltip: 'المزامنة السحابية',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(right: 20, bottom: 16),
              title: Text(
                _halaqahName,
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                        : [const Color(0xFFCCFBF1), const Color(0xFFF8FAFC)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: const EdgeInsets.only(right: 20, top: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.mosque_outlined,
                          size: 16,
                          color: isDark ? Colors.teal[300] : const Color(0xFF0D9488),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _mosqueName,
                          style: GoogleFonts.tajawal(
                            color: isDark ? Colors.grey[400] : const Color(0xFF475569),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildDateCard(),
                const SizedBox(height: 16),
                _buildStatsRow(),
                const SizedBox(height: 20),
                _buildQuickActions(),
                const SizedBox(height: 24),
                _buildRecentActivity(),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard() {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_today,
                color: Color(0xFF0D9488),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Helpers.getDayName(now),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Helpers.getFullHijriDate(now),
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            GenderHelper.students(_settings.gender),
            '${_students.length}',
            Icons.people_outline,
            const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '${GenderHelper.present(_settings.gender)} اليوم',
            '$_presentToday',
            Icons.check_circle_outline,
            const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '${GenderHelper.absent(_settings.gender)} اليوم',
            '$_absentToday',
            Icons.highlight_off,
            const Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إدارة وتطوير الحلقة',
          style: GoogleFonts.tajawal(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.9,
          children: [
            _buildActionItem(
              'تسجيل الحضور',
              Icons.qr_code_scanner,
              const Color(0xFF0D9488),
              () => setState(() => _currentIndex = 2),
            ),
            _buildActionItem(
              'الحفظ والتسميع',
              Icons.menu_book,
              const Color(0xFF3B82F6),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MemorizationScreen()),
              ).then((_) => _loadData()),
            ),
            _buildActionItem(
              'النقاط والسلوك',
              Icons.thumb_up_alt_outlined,
              const Color(0xFFEAB308),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BehaviorScreen()),
              ).then((_) => _loadData()),
            ),
            _buildActionItem(
              'لوحة الشرف',
              Icons.emoji_events,
              const Color(0xFFF59E0B),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HonorBoardScreen()),
              ).then((_) => _loadData()),
            ),
            _buildActionItem(
              'إجازات ${GenderHelper.students(_settings.gender)}',
              Icons.beach_access,
              const Color(0xFF06B6D4),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VacationsScreen()),
              ).then((_) => _loadData()),
            ),
            _buildActionItem(
              'الامتحانات والاختبار',
              Icons.quiz,
              const Color(0xFFA855F7),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ExamsScreen()),
              ).then((_) => _loadData()),
            ),
            _buildActionItem(
              'صندوق الحلقة',
              Icons.account_balance_wallet,
              const Color(0xFF10B981),
              badgeText: _fundBalance > 0 ? '${_fundBalance.toInt()}' : null,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FundScreen()),
              ).then((_) => _loadData()),
            ),
            _buildActionItem(
              'الخطط الذكية',
              Icons.track_changes,
              const Color(0xFFEC4899),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PlansScreen()),
              ).then((_) => _loadData()),
            ),
            _buildActionItem(
              'القرعة العشوائية',
              Icons.casino,
              const Color(0xFF0F766E),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StudentRaffleScreen()),
              ).then((_) => _loadData()),
            ),
            _buildActionItem(
              'سجل التنبيهات',
              Icons.notifications,
              const Color(0xFFEF4444),
              badgeCount: _unreadNotifications,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              ).then((_) => _loadData()),
            ),
            _buildActionItem(
              'التقارير والإحصاءات',
              Icons.assessment,
              const Color(0xFFF97316),
              () => setState(() => _currentIndex = 3),
            ),
            _buildActionItem(
              'الإعدادات',
              Icons.settings,
              const Color(0xFF64748B),
              () => setState(() => _currentIndex = 4),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem(String label, IconData icon, Color color, VoidCallback onTap, {int badgeCount = 0, String? badgeText}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.tajawal(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    '$badgeCount',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (badgeText != null)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669), // Emerald 600
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_students.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'ابدأ بإضافة طلاب للحلقة',
                style: GoogleFonts.tajawal(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'قائمة ${GenderHelper.students(_settings.gender)}',
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _currentIndex = 1),
              child: const Text('عرض الكل'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._students.take(4).map((student) => _buildStudentTile(student)),
      ],
    );
  }

  Widget _buildStudentTile(Student student) {
    final attendanceStatus = _todayAttendance[student.id] ?? 'none';
    
    Color statusColor;
    String statusText;
    switch (attendanceStatus) {
      case 'present':
        statusColor = const Color(0xFF10B981);
        statusText = 'حاضر';
        break;
      case 'late':
        statusColor = const Color(0xFFF59E0B);
        statusText = 'متأخر';
        break;
      case 'absent':
        statusColor = const Color(0xFFEF4444);
        statusText = 'غائب';
        break;
      case 'excused':
        statusColor = const Color(0xFF3B82F6);
        statusText = 'مستأذن';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'لم يسجل';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Text(
            student.name.isNotEmpty ? student.name[0] : '؟',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        title: Text(
          student.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              const Icon(Icons.menu_book, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '${student.totalMemorized} آية محفوظ',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () {
          setState(() => _currentIndex = 1);
        },
      ),
    );
  }
}
