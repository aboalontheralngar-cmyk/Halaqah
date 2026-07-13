import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/database_service.dart';
import '../../services/backup_service.dart';
import '../../services/cloud_backup_service.dart';
import '../../services/audit_log_service.dart';
import '../../services/supabase_service.dart';
import '../auth/login_screen.dart';
import '../../models/student.dart';
import '../../models/settings.dart';
import '../../utils/helpers.dart';
import '../students/students_screen.dart';
import '../students/student_raffle_screen.dart';
import '../students/families_screen.dart';
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
import '../honor_board/daily_excellence_screen.dart';
import '../vacations/vacations_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  final DatabaseService _db = DatabaseService();
  final BackupService _backup = BackupService();
  bool _backupMaintenanceChecked = false;
  
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
      if (!_backupMaintenanceChecked) {
        _backupMaintenanceChecked = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleBackupMaintenance();
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBackupMaintenance() async {
    await AuditLogService().prune(
      retentionDays: _settings.auditLogRetentionDays,
    );
    final automatic = await _backup.performAutomaticBackupIfDue(
      settings: _settings,
    );
    if (!mounted) return;

    if (automatic.attempted && !automatic.succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            automatic.error?.contains('عبارة حماية') == true
                ? 'النسخ التلقائي متوقف حتى تُعد عبارة حماية من الإعدادات.'
                : 'تعذر إنشاء النسخة التلقائية. تحقق من مساحة الجهاز أو افتح إعدادات البيانات.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }

    if (automatic.succeeded &&
        automatic.path != null &&
        _settings.cloudBackupEnabled &&
        SupabaseService.instance.isAuthenticated) {
      try {
        await CloudBackupService().uploadExisting(
          automatic.path!,
          retentionCount: _settings.cloudBackupRetentionCount,
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'حُفظت النسخة محليًا، لكن تعذر رفعها إلى السحابة. ستبقى النسخة المحلية آمنة.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }

    if (!await _backup.shouldShowReminder(settings: _settings) || !mounted) {
      return;
    }
    await _backup.markReminderShown();
    if (!mounted) return;
    final createNow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حماية بيانات الحلقة'),
        content: const Text(
          'لسلامة بيانات الطلاب، يرجى الاحتفاظ بنسخة احتياطية حديثة ومشاركة نسخة منها إلى مكان آمن خارج الجهاز.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لاحقًا'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.backup_outlined),
            label: const Text('نسخ الآن'),
          ),
        ],
      ),
    );
    if (createNow != true) return;
    try {
      await _backup.exportBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء نسخة احتياطية محلية بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر إنشاء النسخة الاحتياطية'),
          backgroundColor: Colors.red,
        ),
      );
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
        // Trigger center selection directly after login
        final selected = await _showCenterHalaqahSelectionDialog();
        if (selected) {
          await _syncWithCloud();
        } else {
          await _loadData();
        }
      }
    } else {
      final lastUpload = DateTime.tryParse(
        await _db.getSetting('last_cloud_upload_at') ?? '',
      );
      final lastDownload = DateTime.tryParse(
        await _db.getSetting('last_cloud_download_at') ?? '',
      );
      if (!mounted) return;
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'المزامنة السحابية',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اختر اتجاه نقل البيانات. لن ينفذ التطبيق الاتجاه الآخر '
                  'عند اختيار الرفع فقط أو التنزيل فقط.',
                ),
                const SizedBox(height: 10),
                Text(
                  supabase.currentUserEmail ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _syncActionButton(
                  icon: Icons.cloud_upload_outlined,
                  title: 'رفع تغييرات الجهاز',
                  subtitle: lastUpload == null
                      ? 'الجهاز ← السحابة فقط'
                      : 'الجهاز ← السحابة فقط\nآخر رفع: ${_formatSyncTime(lastUpload)}',
                  onPressed: () => Navigator.pop(context, 'upload'),
                ),
                const SizedBox(height: 8),
                _syncActionButton(
                  icon: Icons.cloud_download_outlined,
                  title: 'تنزيل بيانات السحابة',
                  subtitle: lastDownload == null
                      ? 'السحابة ← الجهاز فقط، مع نسخة حماية أولًا'
                      : 'السحابة ← الجهاز فقط\nآخر تنزيل: ${_formatSyncTime(lastDownload)}',
                  onPressed: () => Navigator.pop(context, 'download'),
                ),
                const SizedBox(height: 8),
                _syncActionButton(
                  icon: Icons.sync,
                  title: 'مزامنة ذكية ثنائية الاتجاه',
                  subtitle: 'ترفع تغييرات الجهاز، ثم تنزّل البيانات التشغيلية',
                  filled: true,
                  onPressed: () => Navigator.pop(context, 'sync'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'logout'),
              child: Text(
                'تسجيل الخروج',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'change'),
              child: Text(
                'تغيير النطاق',
                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'close'),
              child: Text(
                'إلغاء',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );

      if (action == 'logout') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تسجيل الخروج'),
            content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج وإلغاء ربط الحساب السحابي؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تسجيل خروج', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await supabase.signOut();
          _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم تسجيل الخروج بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else if (action == 'change') {
        final selected = await _showCenterHalaqahSelectionDialog();
        if (selected && mounted) {
          await _syncWithCloud();
        }
      } else if (action == 'sync' ||
          action == 'upload' ||
          action == 'download') {
        final centerId = await _db.getSetting('sync_center_id');
        final halaqahId = await _db.getSetting('sync_halaqah_id');
        if (centerId == null || centerId.isEmpty || halaqahId == null || halaqahId.isEmpty) {
          final selected = await _showCenterHalaqahSelectionDialog();
          if (!selected) return; // cancelled
        }

        final direction = action == 'upload'
            ? CloudSyncDirection.uploadOnly
            : action == 'download'
                ? CloudSyncDirection.downloadOnly
                : CloudSyncDirection.bidirectional;
        if (direction.shouldDownload &&
            !await _backup.passphrases.isConfigured) {
          if (!mounted) return;
          final openSettings = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('إعداد عبارة حماية مطلوب'),
              content: const Text(
                'لحماية بيانات الطلاب، يلزم إعداد عبارة حماية للنسخ '
                'الاحتياطية قبل أي تنزيل من السحابة. لن يبدأ التنزيل الآن.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('لاحقًا'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('فتح الإعدادات'),
                ),
              ],
            ),
          );
          if (openSettings == true && mounted) {
            setState(() => _currentIndex = 4);
          }
          return;
        }
        if (direction == CloudSyncDirection.downloadOnly) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('تنزيل بيانات السحابة؟'),
              content: const Text(
                'سيتم إنشاء نسخة احتياطية أولًا، ثم تُدمج بيانات السحابة '
                'مع هذا الجهاز. قد تُحدّث السجلات المحلية التي تحمل '
                'المعرّفات نفسها. لن يرفع هذا الخيار أي بيانات من الجهاز.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('تنزيل'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
        }

        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Text(
                  direction == CloudSyncDirection.uploadOnly
                      ? 'جاري رفع بيانات الجهاز...'
                      : direction == CloudSyncDirection.downloadOnly
                          ? 'جاري تنزيل بيانات السحابة...'
                          : 'جاري الرفع والتنزيل...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );

        try {
          final result = await supabase.synchronizeData(direction: direction);
          if (mounted) Navigator.pop(context);
          _loadData();
          if (mounted) {
            final successText = direction == CloudSyncDirection.uploadOnly
                ? 'تم الرفع فقط: الجهاز ← السحابة'
                : direction == CloudSyncDirection.downloadOnly
                    ? 'تم التنزيل فقط: السحابة ← الجهاز'
                    : 'اكتملت المزامنة الثنائية: رفع ثم تنزيل';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '$successText (${_formatSyncTime(result.completedAt)})',
                ),
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
  }

  Widget _syncActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
    bool filled = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: filled ? colors.primaryContainer : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSyncTime(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year}، $hour:$minute';
  }

  Future<bool> _showCenterHalaqahSelectionDialog() async {
    final supabase = SupabaseService.instance;
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    final centers = await supabase.fetchUserCenters();
    if (mounted) Navigator.pop(context); // Pop loading

    if (!mounted) return false;

    if (centers.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('خطأ في المزامنة', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'لا يوجد أي مركز مرتبط بهذا الحساب في السحابة. يرجى إنشاء مركز أولاً من لوحة تحكم الويب.',
            style: TextStyle(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('حسناً', style: TextStyle()),
            ),
          ],
        ),
      );
      return false;
    }

    // 1. Show Center Selection dialog
    final selectedCenter = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'اختر المركز للمزامنة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: centers.length,
            itemBuilder: (context, index) {
              final center = centers[index];
              return ListTile(
                leading: const Icon(Icons.business, color: Colors.teal),
                title: Text(center['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  center['role'] == 'owner' ? 'مالك المركز' : 'معلم في المركز',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () => Navigator.pop(context, center),
              );
            },
          ),
        ),
      ),
    );

    if (selectedCenter == null) return false;

    final centerId = selectedCenter['id'];
    final centerName = selectedCenter['name'];

    // 2. Fetch halaqat
    if (!mounted) return false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    final halaqat = await supabase.fetchHalaqas(centerId);
    if (mounted) Navigator.pop(context); // Pop loading

    if (!mounted) return false;

    // 3. Show Halaqah Selection dialog
    final selectedHalaqah = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'اختر الحلقة التابعة لمركز\n$centerName',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: halaqat.length + 1,
                  itemBuilder: (context, index) {
                    if (index == halaqat.length) {
                      // Create new option
                      return ListTile(
                        leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
                        title: Text(
                          '+ إنشاء حلقة جديدة',
                          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                        ),
                        onTap: () async {
                          final newName = await showDialog<String>(
                            context: context,
                            builder: (context) {
                              final nameController = TextEditingController();
                              return AlertDialog(
                                title: Text('اسم الحلقة الجديدة', style: TextStyle(fontWeight: FontWeight.bold)),
                                content: TextField(
                                  controller: nameController,
                                  decoration: InputDecoration(
                                    labelText: 'اسم الحلقة',
                                    labelStyle: TextStyle(),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('إلغاء', style: TextStyle()),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, nameController.text.trim()),
                                    child: Text('إنشاء', style: TextStyle()),
                                  ),
                                ],
                              );
                            },
                          );

                          if (newName != null && newName.isNotEmpty) {
                            // Show loading
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(child: CircularProgressIndicator()),
                            );

                            try {
                              final teacherName = await DatabaseService().getSetting('teacher_name') ?? 'معلم غير محدد';
                              final newHalaqah = await supabase.createHalaqah(centerId, newName, teacherName);
                              
                              if (mounted) Navigator.pop(context); // Pop loading
                              
                              if (newHalaqah != null) {
                                // Close dialog and choose it
                                Navigator.pop(context, newHalaqah);
                              }
                            } catch (e) {
                              if (mounted) Navigator.pop(context); // Pop loading
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('فشل إنشاء الحلقة: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          }
                        },
                      );
                    }

                    final halaqah = halaqat[index];
                    return ListTile(
                      leading: const Icon(Icons.class_, color: Colors.teal),
                      title: Text(halaqah['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'المعلم: ${halaqah['teacher_name'] ?? 'غير محدد'}',
                        style: TextStyle(fontSize: 12),
                      ),
                      onTap: () => Navigator.pop(context, halaqah),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text('إلغاء', style: TextStyle(color: Colors.grey)),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedHalaqah == null) return false;

    final halaqahId = selectedHalaqah['id'];
    final halaqahName = selectedHalaqah['name'];

    // 4. Save locally in SQLite
    final db = DatabaseService();
    await db.saveSetting('sync_center_id', centerId);
    await db.saveSetting('sync_halaqah_id', halaqahId);
    await db.saveSetting('mosque_name', centerName);
    await db.saveSetting('halaqah_name', halaqahName);
    await db.saveSetting('setup_completed', 'true');

    return true;
  }

  Future<bool?> _showExitConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: const Text('الخروج من التطبيق'),
        content: const Text(
          'هل تريد إغلاق تطبيق حلقتي الآن؟',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('البقاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خروج'),
          ),
        ],
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
        key: _scaffoldKey,
        drawer: _buildNavigationDrawer(),
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
    void openMenu() => _scaffoldKey.currentState?.openDrawer();
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return StudentsScreen(onOpenMenu: openMenu);
      case 2:
        return AttendanceScreen(onOpenMenu: openMenu);
      case 3:
        return ReportsScreen(onOpenMenu: openMenu);
      case 4:
        return SettingsScreen(onOpenMenu: openMenu);
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildNavigationDrawer() {
    final colorScheme = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.surface,
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 28,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _halaqahName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _mosqueName,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _drawerSectionTitle('الرئيسية'),
                  _drawerRootItem(
                    index: 0,
                    icon: Icons.dashboard_outlined,
                    selectedIcon: Icons.dashboard,
                    label: 'لوحة المتابعة',
                  ),
                  _drawerRootItem(
                    index: 1,
                    icon: Icons.people_outline,
                    selectedIcon: Icons.people,
                    label: GenderHelper.students(_settings.gender),
                  ),
                  _drawerRootItem(
                    index: 2,
                    icon: Icons.how_to_reg_outlined,
                    selectedIcon: Icons.how_to_reg,
                    label: 'الحضور والتسميع',
                  ),
                  _drawerRootItem(
                    index: 3,
                    icon: Icons.assessment_outlined,
                    selectedIcon: Icons.assessment,
                    label: 'التقارير',
                  ),
                  _drawerSectionTitle('إدارة الحلقة'),
                  _drawerPageItem(
                    icon: Icons.family_restroom_outlined,
                    label: 'العائلات وأولياء الأمور',
                    page: const FamiliesScreen(),
                  ),
                  _drawerPageItem(
                    icon: Icons.menu_book_outlined,
                    label: 'الحفظ والمراجعة',
                    page: const MemorizationScreen(),
                  ),
                  _drawerPageItem(
                    icon: Icons.track_changes_outlined,
                    label: 'الخطط الذكية',
                    page: const PlansScreen(),
                  ),
                  _drawerPageItem(
                    icon: Icons.quiz_outlined,
                    label: 'الاختبارات',
                    page: const ExamsScreen(),
                  ),
                  _drawerPageItem(
                    icon: Icons.thumb_up_alt_outlined,
                    label: 'النقاط والسلوك',
                    page: const BehaviorScreen(),
                  ),
                  _drawerPageItem(
                    icon: Icons.beach_access_outlined,
                    label: 'الإجازات',
                    page: const VacationsScreen(),
                  ),
                  _drawerSectionTitle('التحفيز والأدوات'),
                  _drawerPageItem(
                    icon: Icons.emoji_events_outlined,
                    label: 'لوحة الشرف',
                    page: const HonorBoardScreen(),
                  ),
                  _drawerPageItem(
                    icon: Icons.auto_awesome_outlined,
                    label: 'متميزو اليوم',
                    page: const DailyExcellenceScreen(),
                  ),
                  _drawerPageItem(
                    icon: Icons.casino_outlined,
                    label: 'القرعة العشوائية',
                    page: const StudentRaffleScreen(),
                  ),
                  _drawerPageItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'صندوق الحلقة',
                    page: const FundScreen(),
                  ),
                  _drawerPageItem(
                    icon: Icons.notifications_outlined,
                    label: 'التنبيهات',
                    page: const NotificationsScreen(),
                    badge: _unreadNotifications,
                  ),
                  const Divider(height: 24),
                  _drawerRootItem(
                    index: 4,
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: 'الإعدادات',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _syncWithCloud();
                },
                icon: Icon(
                  SupabaseService.instance.isAuthenticated
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_sync_outlined,
                ),
                label: const Text('المزامنة والنسخ السحابي'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerSectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 5),
        child: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  Widget _drawerRootItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final selected = _currentIndex == index;
    return ListTile(
      selected: selected,
      leading: Icon(selected ? selectedIcon : icon),
      title: Text(label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      onTap: () {
        Navigator.pop(context);
        setState(() => _currentIndex = index);
        if (index == 0) _loadData();
      },
    );
  }

  Widget _drawerPageItem({
    required IconData icon,
    required String label,
    required Widget page,
    int badge = 0,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: badge <= 0
          ? null
          : Badge(label: Text(badge > 99 ? '99+' : '$badge')),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        ).then((_) => _loadData());
      },
    );
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
            leading: IconButton(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu),
              tooltip: 'القائمة الرئيسية',
            ),
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
                style: TextStyle(
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
                          style: TextStyle(
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
              style: TextStyle(
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
          style: TextStyle(
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
              'متميزو اليوم',
              Icons.auto_awesome,
              const Color(0xFF14B8A6),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DailyExcellenceScreen(),
                ),
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
                    style: TextStyle(
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
                    style: TextStyle(
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
                    style: TextStyle(
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
                style: TextStyle(color: Colors.grey[600]),
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
              style: TextStyle(
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
                style: TextStyle(
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
