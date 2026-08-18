import 'dart:async';

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
import '../attendance/daily_closing_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../memorization/memorization_screen.dart';
import '../behavior/behavior_screen.dart';
import '../exam/exams_screen.dart';
import '../competition/competitions_screen.dart';
import '../competition/peer_level_groups_screen.dart';
import '../fund/fund_screen.dart';
import '../plans/plans_screen.dart';
import '../courses/quran_courses_screen.dart';
import '../notifications/notifications_screen.dart';
import '../honor_board/honor_board_screen.dart';
import '../honor_board/daily_excellence_screen.dart';
import '../vacations/vacations_screen.dart';
import '../settings/usage_guide_screen.dart';
import '../settings/offline_exchange_screen.dart';
import '../../services/daily_closing_service.dart';
import '../../app/design_tokens.dart';
import '../../widgets/app_design_widgets.dart';
import '../../widgets/cloud_sync_progress_dialog.dart';


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
  Timer? _dailyClosingTimer;
  
  List<Student> _students = [];
  bool _isLoading = true;
  int _presentToday = 0;
  int _absentToday = 0;
  int _unreadNotifications = 0;
  int _dailyClosingActionCount = 0;
  double _fundBalance = 0.0;
  String _halaqahName = 'حلقتي';
  String _mosqueName = 'المسجد';
  Map<String, String> _todayAttendance = {};
  HalaqahSettings _settings = HalaqahSettings();

  @override
  void initState() {
    super.initState();
    // نعرض الإطار الأول قبل تشغيل إغلاق الأيام وقراءات لوحة التحكم الثقيلة.
    // هذا يقلل التقطّع الملحوظ عند فتح التطبيق على الأجهزة المتوسطة.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _dailyClosingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final closingService = DailyClosingService(database: _db);
      final closingFuture = Future<dynamic>(() async {
        try {
          return await closingService.closeOverdueDays();
        } catch (_) {
          return null;
        }
      });
      final results = await Future.wait<dynamic>([
        _db.getStudents(status: 'active'),
        _db.getDailyRecordsForDate(DateTime.now()),
        _db.getSettings(),
        _db.getUnreadNotificationsCount(),
        _db.getFundBalance(),
        Future<dynamic>(() async {
          try {
            return await closingService.load();
          } catch (_) {
            return null;
          }
        }),
      ]);
      final students = results[0] as List<Student>;
      final todayRecords = results[1] as List;
      final settings = results[2] as HalaqahSettings;
      final unreadCount = results[3] as int;
      final balance = results[4] as double;
      final closingActionCount =
          (results[5] as dynamic)?.actionRequiredCount as int? ?? 0;

      var present = 0;
      var absent = 0;
      final attMap = <String, String>{};
      for (final record in todayRecords) {
        attMap[record.studentId] = record.attendance;
        if (record.attendance == 'present' || record.attendance == 'late') {
          present++;
        } else if (record.attendance == 'absent') {
          absent++;
        }
      }

      if (!mounted) return;
      setState(() {
        _students = students;
        _presentToday = present;
        _absentToday = absent;
        _unreadNotifications = unreadCount;
        _dailyClosingActionCount = closingActionCount;
        _fundBalance = balance;
        _halaqahName = settings.halaqahName;
        _mosqueName = settings.mosqueName.isNotEmpty
            ? settings.mosqueName
            : 'المسجد الرئيسي';
        _todayAttendance = attMap;
        _settings = settings;
        _isLoading = false;
      });
      _scheduleAutomaticDailyClosing();

      // صيانة النسخ الاحتياطي تبدأ بعد ظهور بيانات الرئيسية، لا قبلها.
      if (!_backupMaintenanceChecked) {
        _backupMaintenanceChecked = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleBackupMaintenance();
        });
      }

      // الإغلاق التلقائي قد يكتب سجلات كثيرة؛ ننتظر نتيجته بعد عرض الواجهة.
      final automaticClosing = await closingFuture;
      final automaticallyClosedDays =
          (automaticClosing as dynamic)?.closedCount as int? ?? 0;
      if (!mounted || automaticallyClosedDays <= 0) return;
      final refreshed = await Future.wait<dynamic>([
        _db.getDailyRecordsForDate(DateTime.now()),
        Future<dynamic>(() async {
          try {
            return await closingService.load();
          } catch (_) {
            return null;
          }
        }),
      ]);
      final refreshedRecords = refreshed[0] as List;
      var refreshedPresent = 0;
      var refreshedAbsent = 0;
      final refreshedMap = <String, String>{};
      for (final record in refreshedRecords) {
        refreshedMap[record.studentId] = record.attendance;
        if (record.attendance == 'present' || record.attendance == 'late') {
          refreshedPresent++;
        } else if (record.attendance == 'absent') {
          refreshedAbsent++;
        }
      }
      if (!mounted) return;
      setState(() {
        _presentToday = refreshedPresent;
        _absentToday = refreshedAbsent;
        _todayAttendance = refreshedMap;
        _dailyClosingActionCount =
            (refreshed[1] as dynamic)?.actionRequiredCount as int? ??
                _dailyClosingActionCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'أُغلق تلقائيًا ${automaticallyClosedDays == 1 ? 'اليوم السابق' : '$automaticallyClosedDays أيام سابقة'} بعد انتهاء اليوم.',
          ),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scheduleAutomaticDailyClosing() {
    _dailyClosingTimer?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1, seconds: 2));
    _dailyClosingTimer = Timer(nextDay.difference(now), () async {
      if (!mounted) return;
      await _loadData();
    });
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
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اعمل دون إنترنت واحم بياناتك'),
        content: const Text(
          'يمكنك استخدام حلقتي دائمًا دون إنترنت. وعند توفر الاتصال، '
          'انضم إلى الخدمة السحابية مجانًا لحفظ نسخة مشفرة ومتابعة '
          'البيانات من أجهزتك الأخرى.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'later'),
            child: const Text('لاحقًا'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, 'local'),
            icon: const Icon(Icons.backup_outlined),
            label: const Text('نسخة محلية'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'cloud'),
            icon: const Icon(Icons.cloud_outlined),
            label: Text(
              SupabaseService.instance.isAuthenticated
                  ? 'فتح السحابة'
                  : 'انضم مجانًا',
            ),
          ),
        ],
      ),
    );
    if (action == 'cloud') {
      await _syncWithCloud();
      return;
    }
    if (action != 'local') return;
    if (!await _backup.passphrases.isConfigured) {
      if (!mounted) return;
      setState(() => _currentIndex = 4);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'أعد عبارة حماية من الإعدادات أولًا، ثم أنشئ النسخة المحلية.',
          ),
        ),
      );
      return;
    }
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
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => CloudSyncProgressDialog(
            service: supabase,
            direction: direction,
          ),
        );

        try {
          final result = await supabase.synchronizeData(direction: direction);
          if (mounted) Navigator.pop(context);
          _loadData();
          if (mounted) {
            final completedDirection = result.direction;
            final successText = completedDirection == CloudSyncDirection.uploadOnly
                ? 'تم الرفع فقط: الجهاز ← السحابة'
                : completedDirection == CloudSyncDirection.downloadOnly
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
                content: Text(supabase.describeSyncFailure(e)),
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
                  child: Text(
                    'إلغاء',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
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
              selectedIcon: Icon(Icons.dashboard_outlined),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outlined),
              selectedIcon: const Icon(Icons.people_outlined),
              label: GenderHelper.students(_settings.gender),
            ),
            const NavigationDestination(
              icon: Icon(Icons.qr_code_scanner),
              selectedIcon: Icon(Icons.qr_code_scanner),
              label: 'القارئ',
            ),
            const NavigationDestination(
              icon: Icon(Icons.assessment_outlined),
              selectedIcon: Icon(Icons.assessment_outlined),
              label: 'التقارير',
            ),
            const NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_outlined),
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
                color: colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colorScheme.onPrimary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
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
                      color: colorScheme.onPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _mosqueName,
                    style: TextStyle(
                      color: colorScheme.onPrimary.withValues(alpha: 0.72),
                    ),
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
                  _drawerPageItem(
                    icon: Icons.fact_check_outlined,
                    label: 'مراجعة وإغلاق اليوم',
                    page: const DailyClosingScreen(),
                    badge: _dailyClosingActionCount,
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
                    icon: Icons.event_repeat_outlined,
                    label: 'دورات الحفظ والمراجعة',
                    page: const QuranCoursesScreen(),
                  ),
                  _drawerPageItem(
                    icon: Icons.quiz_outlined,
                    label: 'الاختبارات',
                    page: const ExamsScreen(),
                  ),
                  _drawerPageItem(
                    icon: Icons.emoji_events_outlined,
                    label: 'المسابقات والتحكيم',
                    page: const CompetitionsScreen(),
                  ),
                  _drawerPageItem(
                    icon: Icons.groups_2_outlined,
                    label: 'مجموعات المستوى المتقارب',
                    page: const PeerLevelGroupsScreen(),
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
                  _drawerPageItem(
                    icon: Icons.help_outline,
                    label: 'دليل الاستخدام',
                    page: const UsageGuideScreen(),
                  ),
                  _drawerPageItem(
                    icon: Icons.wifi_tethering_outlined,
                    label: 'التبادل دون إنترنت',
                    page: const OfflineExchangeScreen(),
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
    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverAppBar(
            toolbarHeight: 52,
            pinned: true,
            leading: IconButton(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu_rounded),
              tooltip: 'القائمة الرئيسية',
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_halaqahName),
                Text(
                  _mosqueName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withValues(alpha: 0.72),
                      ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Badge(
                  isLabelVisible: _unreadNotifications > 0,
                  label: Text(
                    _unreadNotifications > 99
                        ? '99+'
                        : '$_unreadNotifications',
                  ),
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                ).then((_) => _loadData()),
                tooltip: 'التنبيهات',
              ),
              IconButton(
                icon: Icon(
                  SupabaseService.instance.isAuthenticated
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_sync_outlined,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: _syncWithCloud,
                tooltip: 'المزامنة السحابية',
              ),
            ],
          ),
          SliverPadding(
            padding: AppSpacing.pageFor(context),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                AppFocusPanel(
                  eyebrow: Helpers.getFullHijriDate(DateTime.now()),
                  title: _dailyClosingActionCount > 0
                      ? 'أكمل متابعة اليوم قبل الإغلاق'
                      : 'مساحة العمل اليومية جاهزة',
                  description: _dailyClosingActionCount > 0
                      ? 'تبقّى $_dailyClosingActionCount إجراء يحتاج مراجعتك.'
                      : 'ابدأ بالحضور ثم انتقل إلى الحفظ والمراجعة.',
                  icon: _dailyClosingActionCount > 0
                      ? Icons.pending_actions_outlined
                      : Icons.auto_stories_outlined,
                  footer: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _dailyClosingActionCount > 0
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const DailyClosingScreen(),
                                ),
                              ).then((_) => _loadData())
                          : () => setState(() => _currentIndex = 2),
                      icon: Icon(
                        _dailyClosingActionCount > 0
                            ? Icons.fact_check_outlined
                            : Icons.qr_code_scanner_rounded,
                      ),
                      label: Text(
                        _dailyClosingActionCount > 0
                            ? 'مراجعة العمليات'
                            : 'تسجيل الحضور',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildStatsRow(),
                const SizedBox(height: AppSpacing.lg),
                _buildQuickActions(),
                const SizedBox(height: AppSpacing.xl),
                _buildRecentActivity(),
                const SizedBox(height: AppSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final veryLargeText = textScale > 1.35;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: veryLargeText ? 11 : 8,
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildCompactStat(
                  GenderHelper.students(_settings.gender),
                  '${_students.length}',
                  Icons.people_outline,
                  context.semanticColors.info,
                ),
              ),
              const VerticalDivider(width: 8),
              Expanded(
                child: _buildCompactStat(
                  GenderHelper.present(_settings.gender),
                  '$_presentToday',
                  Icons.check_circle_outline,
                  context.semanticColors.success,
                ),
              ),
              const VerticalDivider(width: 8),
              Expanded(
                child: _buildCompactStat(
                  GenderHelper.absent(_settings.gender),
                  '$_absentToday',
                  Icons.highlight_off,
                  Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16.5,
                    height: 1.05,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المهام اليومية',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'العمليات الأكثر استخدامًا مرتبة حسب سير يوم الحلقة.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCompactActionGrid(
          children: [
            _buildCompactActionItem(
              'تسجيل الحضور',
              Icons.qr_code_scanner,
              Theme.of(context).colorScheme.primary,
              () => setState(() => _currentIndex = 2),
            ),
            _buildCompactActionItem(
              'مراجعة وإغلاق اليوم',
              Icons.fact_check_outlined,
              context.semanticColors.warning,
              badgeCount: _dailyClosingActionCount,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DailyClosingScreen(),
                ),
              ).then((_) => _loadData()),
            ),
            _buildCompactActionItem(
              'الحفظ والتسميع',
              Icons.menu_book_outlined,
              context.semanticColors.info,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MemorizationScreen()),
              ).then((_) => _loadData()),
            ),
            _buildCompactActionItem(
              GenderHelper.students(_settings.gender),
              Icons.people_outline,
              const Color(0xFF6366F1),
              () => setState(() => _currentIndex = 1),
            ),
            _buildCompactActionItem(
              'التقارير',
              Icons.assessment_outlined,
              const Color(0xFFF97316),
              () => setState(() => _currentIndex = 3),
            ),
            _buildCompactActionItem(
              'الخطط الذكية',
              Icons.track_changes,
              const Color(0xFFEC4899),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PlansScreen()),
              ).then((_) => _loadData()),
            ),
            _buildCompactActionItem(
              'الدورات القرآنية',
              Icons.event_repeat_outlined,
              Theme.of(context).colorScheme.secondary,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QuranCoursesScreen()),
              ).then((_) => _loadData()),
            ),
            _buildCompactActionItem(
              'سجل التنبيهات',
              Icons.notifications_none_rounded,
              const Color(0xFFEF4444),
              badgeCount: _unreadNotifications,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              ).then((_) => _loadData()),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          margin: EdgeInsets.zero,
          child: ExpansionTile(
            leading: const Icon(Icons.tune_rounded),
            title: const Text(
              'الأدوات والإدارة المتقدمة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('النقاط والاختبارات والصندوق والإدارة'),
            childrenPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            children: [
              AppCompactActionGrid(children: [
            _buildCompactActionItem(
              'النقاط والسلوك',
              Icons.thumb_up_alt_outlined,
              const Color(0xFFEAB308),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BehaviorScreen()),
              ).then((_) => _loadData()),
            ),
            _buildCompactActionItem(
              'لوحة الشرف',
              Icons.emoji_events_outlined,
              const Color(0xFFF59E0B),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HonorBoardScreen()),
              ).then((_) => _loadData()),
            ),
            _buildCompactActionItem(
              'متميزو اليوم',
              Icons.auto_awesome_outlined,
              const Color(0xFF14B8A6),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DailyExcellenceScreen(),
                ),
              ).then((_) => _loadData()),
            ),
            _buildCompactActionItem(
              'إجازات ${GenderHelper.students(_settings.gender)}',
              Icons.beach_access_outlined,
              const Color(0xFF06B6D4),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VacationsScreen()),
              ).then((_) => _loadData()),
            ),
            _buildCompactActionItem(
              'الامتحانات والاختبار',
              Icons.quiz_outlined,
              const Color(0xFFA855F7),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ExamsScreen()),
              ).then((_) => _loadData()),
            ),
            _buildCompactActionItem(
              'المسابقات والتحكيم',
              Icons.emoji_events_outlined,
              const Color(0xFFD97706),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CompetitionsScreen(),
                ),
              ).then((_) => _loadData()),
            ),
            _buildCompactActionItem(
              'مجموعات المستوى المتقارب',
              Icons.groups_2_outlined,
              const Color(0xFF7C3AED),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PeerLevelGroupsScreen(),
                ),
              ).then((_) => _loadData()),
            ),
            _buildCompactActionItem(
              'صندوق الحلقة',
              Icons.account_balance_wallet_outlined,
              const Color(0xFF10B981),
              badgeText: _fundBalance > 0 ? '${_fundBalance.toInt()}' : null,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FundScreen()),
              ).then((_) => _loadData()),
            ),
            _buildCompactActionItem(
              'القرعة العشوائية',
              Icons.casino_outlined,
              const Color(0xFF0F766E),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StudentRaffleScreen()),
              ).then((_) => _loadData()),
            ),
            _buildCompactActionItem(
              'الإعدادات',
              Icons.settings_outlined,
              const Color(0xFF64748B),
              () => setState(() => _currentIndex = 4),
            ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactActionItem(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    int badgeCount = 0,
    String? badgeText,
  }) {
    final badge = badgeCount > 0
        ? AppStatusPill(
            label: badgeCount > 99 ? '99+' : '$badgeCount',
            color: Theme.of(context).colorScheme.error,
          )
        : badgeText == null
            ? null
            : AppStatusPill(
                label: badgeText,
                color: context.semanticColors.success,
              );
    return AppCompactActionTile(
      label: label,
      icon: icon,
      color: color,
      onTap: onTap,
      badge: badge,
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
              Icon(Icons.info_outline, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'ابدأ بإضافة طلاب للحلقة',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
              style: Theme.of(context).textTheme.titleMedium,
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
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        leading: CircleAvatar(
          radius: 19,
          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          child: Text(
            student.name.isNotEmpty ? student.name[0] : '؟',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
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
              Icon(
                Icons.menu_book,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${student.totalMemorized} آية محفوظ',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        trailing: AppStatusPill(
          label: statusText,
          color: statusColor,
        ),
        onTap: () {
          setState(() => _currentIndex = 1);
        },
      ),
    );
  }
}
