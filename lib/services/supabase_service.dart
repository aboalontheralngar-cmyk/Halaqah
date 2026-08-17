import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/student.dart';
import '../models/homework_grade.dart';
import '../models/daily_record.dart';
import '../models/mushaf_progress.dart';
import '../models/memorization.dart';
import '../models/plan.dart';
import '../models/quran_course.dart';
import '../models/plan_recitation_record.dart';
import '../models/daily_achievement.dart';
import '../models/behavior_point.dart';
import '../models/fund_transaction.dart';
import '../models/family.dart';
import '../models/family_guardian.dart';
import '../models/talaqqin_record.dart';
import '../models/student_admin_action.dart';
import '../models/student_hold.dart';
import '../models/vacation.dart';
import '../models/exam.dart';
import '../models/exam_template.dart';
import '../models/notification_log.dart';
import 'app_logger.dart';
import 'backup_service.dart';
import 'cloud_connection_diagnostics.dart';
import 'cloud_config.dart';
import 'database_service.dart';
import 'mushaf_service.dart';
import 'quran_service.dart';
import 'local_sync_delete_outbox.dart';
import 'study_suspension_sync_plan.dart';
import 'sync/cloud_sync_progress.dart';
import 'sync/exam_sync_policy.dart';

enum CloudSyncDirection { uploadOnly, downloadOnly, bidirectional }

extension CloudSyncDirectionPolicy on CloudSyncDirection {
  bool get shouldUpload => this != CloudSyncDirection.downloadOnly;
  bool get shouldDownload => this != CloudSyncDirection.uploadOnly;

  String get settingSuffix {
    switch (this) {
      case CloudSyncDirection.uploadOnly:
        return 'upload';
      case CloudSyncDirection.downloadOnly:
        return 'download';
      case CloudSyncDirection.bidirectional:
        return 'bidirectional';
    }
  }
}

class CloudSyncUnavailableException implements Exception {
  final String message;

  const CloudSyncUnavailableException(this.message);

  @override
  String toString() => message;
}

class CloudSyncResult {
  final CloudSyncDirection direction;
  final DateTime completedAt;
  final List<String> uploadedSections;
  final List<String> downloadedSections;

  const CloudSyncResult({
    required this.direction,
    required this.completedAt,
    this.uploadedSections = const [],
    this.downloadedSections = const [],
  });
}

class _CloudSyncScope {
  final String centerId;
  final String halaqahId;

  const _CloudSyncScope({
    required this.centerId,
    required this.halaqahId,
  });
}

class SupabaseService {
  static String get projectUrl => CloudConfig.projectUrl;
  static String get publishableKey => CloudConfig.publishableKey;
  static String get authRedirectUrl => CloudConfig.authRedirectUrl;

  static final SupabaseService instance = SupabaseService._internal();
  factory SupabaseService() => instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;
  final DatabaseService _db = DatabaseService();
  final MushafService _mushaf = MushafService();

  static const Duration _syncRpcTimeout = Duration(seconds: 12);
  static const Duration _syncRetryDelay = Duration(milliseconds: 700);
  static const Duration _syncStageSlowWarning = Duration(seconds: 30);
  static const Duration _identityRefreshTtl = Duration(hours: 6);
  static const String _studySuspensionFingerprintKey =
      'study_suspensions_upload_fingerprint_v1';

  final ValueNotifier<CloudSyncProgress?> syncProgress =
      ValueNotifier<CloudSyncProgress?>(null);
  final Map<String, Set<String>> _studentIdsByHalaqah =
      <String, Set<String>>{};

  Future<CloudSyncResult>? _activeSync;
  CloudSyncDirection? _activeSyncDirection;

  bool get isSynchronizing => _activeSync != null;

  /// Waits for a synchronization that was already in progress to settle.
  /// Used before an atomic backup restore so cloud writes and local snapshot
  /// replacement can never run concurrently.
  Future<void> waitForActiveSync() async {
    final active = _activeSync;
    if (active == null) return;
    try {
      await active;
    } catch (_) {
      // The original sync path already records its own diagnostic failure.
    }
  }

  static Future<void> initialize() async {
    CloudConfig.validate();
    await Supabase.initialize(
      url: projectUrl,
      publishableKey: publishableKey,
    );
  }

  Future<CloudConnectionDiagnostic> diagnoseConnection() {
    final baseUri = Uri.parse(projectUrl);
    return CloudConnectionDiagnostics(
      endpoint: baseUri.replace(path: '/auth/v1/health', query: null),
    ).run();
  }

  String describeSyncFailure(Object error) {
    if (error is CloudSyncStageException) {
      final cause = error.cause;
      if (cause is PostgrestException && cause.code == '42P10') {
        return 'توقفت المزامنة عند «${error.stageLabel}» لأن مخطط Supabase '
            'يفتقد قيد تفرّد تعتمد عليه النسخ الحالية. نفّذ '
            'P1.27_BUILD78_HOTFIX3_APPLY.sql ثم ملف VERIFY وأعد المزامنة. '
            'الرمز: ${error.safeCode}';
      }
      if (cause is PostgrestException && cause.code == '23503') {
        return 'توقفت المزامنة عند «${error.stageLabel}» لأن سجلًا يعتمد على '
            'مرجع سحابي لم يصل بعد أو لم يعد موجودًا. بيانات الجهاز لم تُحذف. '
            'أعد المحاولة بعد تحديث التطبيق، وإذا استمر الخطأ افتح مركز '
            'التشخيص. الرمز: ${error.safeCode}';
      }
      if (cause is CloudSyncUnavailableException) {
        return '${cause.message} المرحلة: ${error.stageLabel}. '
            'الرمز: ${error.safeCode}';
      }
      if (cause is TimeoutException || _isTransientNetworkError(cause)) {
        return 'انقطع الاتصال أثناء «${error.stageLabel}». بيانات الجهاز '
            'محفوظة محليًا وسيعاد إرسالها لاحقًا. الرمز: ${error.safeCode}';
      }
      if (cause is StateError) {
        return '${cause.message} الرمز: ${error.safeCode}';
      }
      return 'توقفت المزامنة عند «${error.stageLabel}». لم تُحذف بيانات '
          'الجهاز. افتح مركز التشخيص إذا تكرر الخطأ. الرمز: ${error.safeCode}';
    }
    if (error is CloudSyncUnavailableException) return error.message;
    if (error is TimeoutException || _isTransientNetworkError(error)) {
      return 'تعذر الوصول إلى السحابة الآن. بيانات الجهاز محفوظة محليًا، '
          'وسيُعاد إرسالها عند استقرار الاتصال.';
    }
    if (error is StateError) return error.message;

    final text = error.toString().replaceFirst('Exception: ', '').trim();
    if (text.startsWith('الرجاء اختيار المركز والحلقة') ||
        text.startsWith('تعذر إنشاء نسخة احتياطية')) {
      return text;
    }
    return 'تعذر إكمال المزامنة الآن. لم تُحذف بيانات الجهاز، ويمكن إعادة المحاولة لاحقًا.';
  }

  String _safeSyncErrorCode(String stageId, Object error) {
    String suffix;
    if (error is PostgrestException) {
      suffix = error.code?.trim().isNotEmpty == true
          ? error.code!.trim()
          : 'POSTGREST';
    } else if (error is TimeoutException) {
      suffix = 'TIMEOUT';
    } else if (_isTransientNetworkError(error)) {
      suffix = 'NETWORK';
    } else {
      suffix = error.runtimeType.toString().toUpperCase();
    }
    final sanitizedStage = stageId
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final sanitizedSuffix = suffix
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return 'SYNC_${sanitizedStage}_$sanitizedSuffix';
  }

  Future<void> _recordSyncFailure(
    CloudSyncStageException failure,
  ) async {
    try {
      await _db.saveSetting('last_cloud_sync_failed_stage', failure.stageId);
      await _db.saveSetting('last_cloud_sync_error_code', failure.safeCode);
      await _db.saveSetting(
        'last_cloud_sync_failed_at',
        DateTime.now().toIso8601String(),
      );
    } catch (_) {
      // Diagnostics must never replace the original synchronization error.
    }
  }

  Future<void> _clearSyncFailureMarker() async {
    try {
      await _db.saveSetting('last_cloud_sync_failed_stage', '');
      await _db.saveSetting('last_cloud_sync_error_code', '');
      await _db.saveSetting('last_cloud_sync_failed_at', '');
    } catch (_) {
      // A successful sync stays successful even if a diagnostic marker cannot
      // be cleared.
    }
  }

  Future<void> _runSyncStage({
    required String id,
    required String label,
    required int index,
    required int total,
    required Future<void> Function() action,
  }) async {
    syncProgress.value = CloudSyncProgress(
      state: CloudSyncProgressState.running,
      stageId: id,
      stageLabel: label,
      currentStage: index,
      totalStages: total,
    );
    final stopwatch = Stopwatch()..start();
    final slowStageTimer = Timer(_syncStageSlowWarning, () {
      AppLogger.warning('stage_slow', source: 'supabase.sync.$id');
    });
    try {
      // Do not wrap a whole sync stage in Future.timeout: Dart timeouts do not
      // cancel the underlying network operation and could allow a later sync
      // to overlap with an operation that is still mutating cloud data. RPCs
      // that are safe to retry have their own bounded timeout instead.
      await action();
      slowStageTimer.cancel();
      stopwatch.stop();
      AppLogger.info(
        'stage_completed:${stopwatch.elapsedMilliseconds}ms',
        source: 'supabase.sync.$id',
      );
    } catch (error, stackTrace) {
      slowStageTimer.cancel();
      stopwatch.stop();
      final failure = CloudSyncStageException(
        stageId: id,
        stageLabel: label,
        safeCode: _safeSyncErrorCode(id, error),
        cause: error,
      );
      syncProgress.value = CloudSyncProgress(
        state: CloudSyncProgressState.failed,
        stageId: id,
        stageLabel: label,
        currentStage: index,
        totalStages: total,
        safeCode: failure.safeCode,
      );
      await _recordSyncFailure(failure);
      AppLogger.error(
        error,
        source: 'supabase.sync.$id',
        stackTrace: stackTrace,
      );
      throw failure;
    }
  }

  Future<void> _ensureCloudReachable() async {
    final diagnostic = await diagnoseConnection();
    if (!diagnostic.isHealthy) {
      throw CloudSyncUnavailableException(
        '${diagnostic.title}. ${diagnostic.message}',
      );
    }
  }

  bool _isTransientNetworkError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('clientexception') ||
        text.contains('socketexception') ||
        text.contains('connection abort') ||
        text.contains('connection reset') ||
        text.contains('connection closed') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('timed out') ||
        text.contains('timeout');
  }

  Future<dynamic> _callIdempotentSyncRpc(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await (() async {
          return await client.rpc(functionName, params: params);
        })().timeout(_syncRpcTimeout);
      } on TimeoutException catch (error) {
        lastError = error;
      } catch (error) {
        if (!_isTransientNetworkError(error) || attempt == 1) rethrow;
        lastError = error;
      }
      if (attempt == 0) await Future<void>.delayed(_syncRetryDelay);
    }
    throw CloudSyncUnavailableException(
      lastError is TimeoutException
          ? 'انتهت مهلة الاتصال أثناء مزامنة الإجازات العارضة.'
          : 'انقطع الاتصال أثناء مزامنة الإجازات العارضة.',
    );
  }

  String _studySuspensionFingerprint(Map<String, String> values) {
    final ordered = values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final payload = ordered
        .map((entry) => <String, String>{
              'date': entry.key,
              'reason': entry.value.trim(),
            })
        .toList(growable: false);
    return sha256.convert(utf8.encode(jsonEncode(payload))).toString();
  }

  // Auth Operations
  Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(email: email, password: password);
  }

  Future<bool> signInWithGoogle() {
    return client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: authRedirectUrl,
    );
  }

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // Verify invitation code
  Future<Map<String, dynamic>?> verifyInvitationCode(
    String code,
    String email,
  ) async {
    try {
      final response = await client.rpc(
        'inspect_invitation_code',
        params: {
          'p_code': code.trim().toUpperCase(),
          'p_email': email.trim().toLowerCase(),
        },
      );
      if (response is Map<String, dynamic> && response['valid'] == true) {
        return response;
      }
      if (response is Map && response['valid'] == true) {
        return Map<String, dynamic>.from(response);
      }
      return null;
    } catch (e) {
      AppLogger.error(e, source: 'supabase.invitation.verify');
      throw Exception('فشل التحقق من الكود: $e');
    }
  }

  // Register and link code
  Future<void> signUpAndLinkCode({
    required String email,
    required String password,
    required String code,
  }) async {
    try {
      final AuthResponse response = await client.auth.signUp(
        email: email,
        password: password,
      );
      
      if (response.user?.id == null) {
        throw Exception('فشل إنشاء حساب المستخدم');
      }

      if (response.session == null) {
        throw Exception(
          'تم إنشاء الحساب، لكن يلزم تأكيد البريد أولاً. بعد التأكيد سجّل الدخول ثم فعّل كود الدعوة.',
        );
      }

      await activateInvitationCode(code);
    } catch (e) {
      AppLogger.error(e, source: 'supabase.auth.signup_link');
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> activateInvitationCode(String code) async {
    final result = await client.rpc(
      'join_center_with_code',
      params: {'p_code': code.trim().toUpperCase()},
    );
    if (result is! Map || result['success'] != true) {
      final reason = result is Map ? result['error'] : null;
      throw Exception(_invitationErrorMessage(reason?.toString()));
    }
  }

  String _invitationErrorMessage(String? reason) {
    switch (reason) {
      case 'expired_code':
        return 'انتهت صلاحية كود الدعوة؛ اطلب كودًا جديدًا من مدير المركز';
      case 'already_used':
        return 'تم استخدام كود الدعوة من قبل';
      case 'email_mismatch':
        return 'البريد لا يطابق البريد المحدد في الدعوة';
      case 'not_authenticated':
        return 'يلزم تسجيل الدخول قبل تفعيل الدعوة';
      default:
        return 'كود الدعوة غير صحيح أو غير متاح';
    }
  }

  Future<void> signOut() async {
    await client.auth.signOut();
    await _db.saveSetting('sync_center_id', '');
    await _db.saveSetting('sync_halaqah_id', '');
    await _db.saveSetting('setup_completed', 'false');
  }

  bool get isAuthenticated => client.auth.currentSession != null;
  String? get currentUserEmail => client.auth.currentUser?.email;

  Future<Map<String, dynamic>> getStudentPortalStatus(String studentId) async {
    if (!isAuthenticated) {
      throw StateError('يلزم تسجيل الدخول لإدارة بوابة الطالب');
    }
    final response = await client.rpc(
      'get_student_portal_status',
      params: {'p_student_id': studentId},
    );
    return response is Map
        ? Map<String, dynamic>.from(response)
        : <String, dynamic>{'configured': false, 'enabled': false};
  }

  Future<void> setStudentPortalPin({
    required String studentId,
    required String pin,
  }) async {
    if (!isAuthenticated) {
      throw StateError('يلزم تسجيل الدخول لإدارة بوابة الطالب');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError('الرقم السري يجب أن يتكون من 6 أرقام');
    }
    await client.rpc(
      'set_student_portal_pin',
      params: {
        'p_student_id': studentId,
        'p_pin': pin,
        'p_enabled': true,
      },
    );
  }

  Future<void> disableStudentPortal(String studentId) async {
    if (!isAuthenticated) {
      throw StateError('يلزم تسجيل الدخول لإدارة بوابة الطالب');
    }
    await client.rpc(
      'disable_student_portal',
      params: {'p_student_id': studentId},
    );
  }

  Future<Map<String, dynamic>> getFamilyPortalStatus(String familyId) async {
    if (!isAuthenticated) {
      throw StateError('يلزم تسجيل الدخول لإدارة بوابة ولي الأمر');
    }
    final response = await client.rpc(
      'get_family_portal_status',
      params: {'p_family_id': familyId},
    );
    return response is Map
        ? Map<String, dynamic>.from(response)
        : <String, dynamic>{'configured': false, 'enabled': false};
  }

  Future<void> setFamilyPortalPin({
    required String familyId,
    required String pin,
  }) async {
    if (!isAuthenticated) {
      throw StateError('يلزم تسجيل الدخول لإدارة بوابة ولي الأمر');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError('الرقم السري يجب أن يتكون من 6 أرقام');
    }
    await client.rpc(
      'set_family_portal_pin',
      params: {
        'p_family_id': familyId,
        'p_pin': pin,
        'p_enabled': true,
      },
    );
  }

  Future<void> disableFamilyPortal(String familyId) async {
    if (!isAuthenticated) {
      throw StateError('يلزم تسجيل الدخول لإدارة بوابة ولي الأمر');
    }
    await client.rpc(
      'disable_family_portal',
      params: {'p_family_id': familyId},
    );
  }

  // Retrieve Teacher Membership Info (center_id and halaqah_id)
  Future<Map<String, dynamic>?> getTeacherInfo() async {
    if (!isAuthenticated) return null;
    final email = currentUserEmail;
    final currentUser = client.auth.currentUser;
    if (email == null || currentUser == null) return null;

    try {
      // 1. Try to find in center_members (case-insensitive)
      final response = await client
          .from('center_members')
          .select('center_id, halaqah_id, role, user_id')
          .eq('user_id', currentUser.id)
          .maybeSingle();
          
      if (response != null) {
        return response;
      }
      
      // 2. If not found in center_members, check if they own a center (center_admin)
      final centerResponse = await client
          .from('centers')
          .select('id')
          .eq('owner_id', currentUser.id)
          .limit(1)
          .maybeSingle();
          
      if (centerResponse != null) {
        // They own a center! Let's get the first halaqah of this center
        final halaqahResponse = await client
            .from('halaqat')
            .select('id')
            .eq('center_id', centerResponse['id'])
            .limit(1)
            .maybeSingle();
            
        return {
          'center_id': centerResponse['id'],
          'halaqah_id': halaqahResponse?['id'],
          'role': 'center_admin',
          'user_id': currentUser.id,
        };
      }
      
      return null;
    } catch (e) {
      AppLogger.error(e, source: 'supabase.teacher_info');
      return null;
    }
  }

  // Synchronize SQLite and Supabase
  Future<CloudSyncResult> synchronizeData({
    CloudSyncDirection direction = CloudSyncDirection.bidirectional,
  }) {
    final activeSync = _activeSync;
    final activeDirection = _activeSyncDirection;
    if (activeSync != null && activeDirection != null) {
      if (_syncDirectionCovers(activeDirection, direction)) {
        AppLogger.info(
          'sync_joined_active:${activeDirection.settingSuffix}',
          source: 'supabase.sync',
        );
        return activeSync;
      }
      return activeSync.then<CloudSyncResult>(
        (_) => synchronizeData(direction: direction),
        onError: (_) => synchronizeData(direction: direction),
      );
    }

    late final Future<CloudSyncResult> operation;
    _activeSyncDirection = direction;
    operation = _synchronizeDataOnce(direction).whenComplete(() {
      if (identical(_activeSync, operation)) {
        _activeSync = null;
        _activeSyncDirection = null;
      }
    });
    _activeSync = operation;
    return operation;
  }

  bool _syncDirectionCovers(
    CloudSyncDirection active,
    CloudSyncDirection requested,
  ) =>
      active == CloudSyncDirection.bidirectional || active == requested;

  Future<CloudSyncResult> _synchronizeDataOnce(
    CloudSyncDirection direction,
  ) async {
    if (!isAuthenticated) {
      throw StateError('يلزم تسجيل الدخول قبل المزامنة');
    }

    _studentIdsByHalaqah.clear();
    final totalStages = 23 +
        (direction.shouldDownload ? 2 : 0) +
        (direction.shouldUpload ? 3 : 0);
    var stageIndex = 0;

    Future<void> runStage(
      String id,
      String label,
      Future<void> Function() action,
    ) {
      stageIndex++;
      return _runSyncStage(
        id: id,
        label: label,
        index: stageIndex,
        total: totalStages,
        action: action,
      );
    }

    syncProgress.value = CloudSyncProgress(
      state: CloudSyncProgressState.preparing,
      stageId: 'prepare',
      stageLabel: 'تهيئة المزامنة',
      currentStage: 0,
      totalStages: totalStages,
    );

    try {
      await runStage('connection', 'فحص الاتصال بالسحابة', () async {
        await _ensureCloudReachable();
      });

      late final _CloudSyncScope scope;
      await runStage('scope', 'تحديد المركز والحلقة', () async {
        scope = await _resolveSyncScope();
      });
      final centerId = scope.centerId;
      final halaqahId = scope.halaqahId;

      if (direction.shouldDownload) {
        await runStage(
          'backup',
          'إنشاء نسخة حماية محلية',
          () => _createPreSyncBackupIfNeeded(direction),
        );
      }

      await runStage('identity', 'تحديث بيانات الحلقة', () async {
        await _refreshCloudIdentityIfNeeded(centerId, halaqahId);
      });

      // Cloud tombstones must be consumed before any local upload. This keeps
      // a stale offline device from resurrecting a record deleted elsewhere.
      if (direction.shouldDownload) {
        await runStage('tombstones', 'مزامنة الحذف القادم من السحابة', () async {
          await _syncCloudTombstones(centerId, halaqahId);
        });
      }
      if (direction.shouldUpload) {
        await runStage('delete_outbox', 'رفع عمليات الحذف المحلية', _syncDeleteOutbox);
      }

      await runStage('families', 'العائلات وأولياء الأمور', () async {
        await _syncFamilies(centerId, halaqahId, direction);
      });
      await runStage('students', 'الطلاب', () async {
        await _syncStudents(centerId, halaqahId, direction);
        _studentIdsByHalaqah.remove(halaqahId);
      });
      await runStage('homework', 'درجات الواجب', () async {
        await _syncHomeworkGrades(centerId, halaqahId, direction);
      });
      await runStage('attendance', 'الحضور', () async {
        await _syncAttendance(centerId, halaqahId, direction);
      });
      await runStage('study_suspensions', 'الإجازات العارضة', () async {
        await _syncStudySuspensions(centerId, halaqahId, direction);
      });
      await runStage('memorization', 'الحفظ والمراجعة', () async {
        await _syncMemorizationProgress(centerId, halaqahId, direction);
      });
      await runStage('mushaf', 'خريطة المصحف', () async {
        await _syncMushafProgress(centerId, halaqahId, direction);
      });
      await runStage('points', 'النقاط', () async {
        await _syncBehaviorPoints(centerId, halaqahId, direction);
      });
      if (direction.shouldUpload) {
        await runStage('point_corrections', 'تصحيحات النقاط', () async {
          await _syncBehaviorPointCorrections(centerId, halaqahId);
        });
      }
      await runStage('achievements', 'متميزو اليوم', () async {
        await _syncDailyAchievements(centerId, halaqahId, direction);
      });
      await runStage('vacations', 'إجازات الطلاب', () async {
        await _syncVacations(centerId, halaqahId, direction);
      });
      // Exam rows may reference exam_templates.template_id, so parent
      // templates must exist in Supabase before exam rows are uploaded. The
      // same ordering also makes downloaded local references immediately valid.
      await runStage('exam_templates', 'قوالب الاختبارات', () async {
        await _syncExamTemplates(centerId, halaqahId, direction);
      });
      await runStage('exams', 'الاختبارات والدرجات', () async {
        await _syncExams(centerId, halaqahId, direction);
      });
      if (direction.shouldUpload) {
        // Template deletes are deliberately last: exam upserts above first
        // clear any stale template_id references, avoiding SQLSTATE 23503.
        await runStage(
          'exam_template_cleanup',
          'تنظيف قوالب الاختبارات المحذوفة',
          _syncDeletedExamTemplates,
        );
      }
      await runStage('notifications', 'الإشعارات', () async {
        await _syncNotifications(centerId, halaqahId, direction);
      });
      await runStage('fund', 'صندوق الحلقة', () async {
        await _syncFundTransactions(centerId, halaqahId, direction);
      });
      await runStage('student_holds', 'إيقافات الطلاب', () async {
        await _syncStudentHolds(centerId, halaqahId, direction);
      });
      await runStage('talaqqin', 'التلقين', () async {
        await _syncTalaqqinRecords(centerId, halaqahId, direction);
      });
      await runStage('admin_actions', 'الإجراءات الإدارية', () async {
        await _syncStudentAdminActions(centerId, halaqahId, direction);
      });
      await runStage('plans', 'الخطط', () async {
        await _syncPlans(centerId, halaqahId, direction);
      });
      await runStage('courses', 'الدورات القرآنية', () async {
        await _syncQuranCourses(centerId, halaqahId, direction);
      });
      await runStage('plan_recitation', 'سجل السرد المرتبط بالخطط', () async {
        await _syncPlanRecitationRecords(centerId, halaqahId, direction);
      });

      final completedAt = DateTime.now();
      if (direction.shouldUpload) {
        await _db.saveSetting(
          'last_cloud_upload_at',
          completedAt.toIso8601String(),
        );
      }
      if (direction.shouldDownload) {
        await _db.saveSetting(
          'last_cloud_download_at',
          completedAt.toIso8601String(),
        );
      }
      await _db.saveSetting(
        'last_cloud_sync_at',
        completedAt.toIso8601String(),
      );
      await _db.saveSetting(
        'last_cloud_sync_direction',
        direction.settingSuffix,
      );
      await _clearSyncFailureMarker();

      syncProgress.value = CloudSyncProgress(
        state: CloudSyncProgressState.completed,
        stageId: 'completed',
        stageLabel: 'اكتملت المزامنة',
        currentStage: totalStages,
        totalStages: totalStages,
      );
      AppLogger.info('sync_completed', source: 'supabase.sync');
      return CloudSyncResult(
        direction: direction,
        completedAt: completedAt,
        uploadedSections: direction.shouldUpload
            ? const [
                'الطلاب',
                'العائلات',
                'الحضور',
                'التسميع والمراجعة',
                'خريطة المصحف',
                'النقاط والإنجازات',
                'الإجازات والإيقافات',
                'التلقين والإداريات',
                'الاختبارات والخطط والدورات',
                'سجل السرد المرتبط بالخطط',
                'الصندوق والإشعارات',
              ]
            : const [],
        downloadedSections: direction.shouldDownload
            ? const [
                'الطلاب',
                'العائلات',
                'الحضور',
                'التسميع والمراجعة',
                'خريطة المصحف',
                'متميزو اليوم',
                'النقاط والصندوق',
                'الإجازات والاختبارات والإشعارات',
                'الإيقافات والتلقين والإداريات',
                'الخطط والدورات',
                'سجل السرد المرتبط بالخطط',
              ]
            : const [],
      );
    } catch (error, stackTrace) {
      if (error is! CloudSyncStageException) {
        AppLogger.error(
          error,
          source: 'supabase.sync',
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
  }

  Future<_CloudSyncScope> _resolveSyncScope() async {
    String? centerId = await _db.getSetting('sync_center_id');
    String? halaqahId = await _db.getSetting('sync_halaqah_id');

    if ((centerId ?? '').isEmpty || (halaqahId ?? '').isEmpty) {
      final info = await getTeacherInfo();
      if (info != null) {
        centerId = info['center_id']?.toString();
        halaqahId = info['halaqah_id']?.toString();
        if ((centerId ?? '').isNotEmpty) {
          await _db.saveSetting('sync_center_id', centerId!);
        }
        if ((halaqahId ?? '').isNotEmpty) {
          await _db.saveSetting('sync_halaqah_id', halaqahId!);
        }
      }
    }

    if ((centerId ?? '').isEmpty || (halaqahId ?? '').isEmpty) {
      throw StateError('الرجاء اختيار المركز والحلقة أولاً لإجراء المزامنة.');
    }
    return _CloudSyncScope(centerId: centerId!, halaqahId: halaqahId!);
  }

  Future<void> _refreshCloudIdentityIfNeeded(
    String centerId,
    String halaqahId,
  ) async {
    final mosqueName = (await _db.getSetting('mosque_name'))?.trim() ?? '';
    final halaqahName = (await _db.getSetting('halaqah_name'))?.trim() ?? '';
    final lastRefresh = DateTime.tryParse(
      await _db.getSetting('last_cloud_identity_refresh_at') ?? '',
    );
    final refreshExpired = lastRefresh == null ||
        DateTime.now().difference(lastRefresh) >= _identityRefreshTtl;
    if (!refreshExpired && mosqueName.isNotEmpty && halaqahName.isNotEmpty) {
      await _db.saveSetting('setup_completed', 'true');
      return;
    }

    final results = await Future.wait<dynamic>([
      client.from('centers').select('name').eq('id', centerId).maybeSingle(),
      client
          .from('halaqat')
          .select('name, teacher_name')
          .eq('id', halaqahId)
          .maybeSingle(),
    ]);
    final center = results[0] as Map<String, dynamic>?;
    final halaqah = results[1] as Map<String, dynamic>?;
    final remoteMosqueName = center?['name']?.toString().trim() ?? '';
    final remoteHalaqahName = halaqah?['name']?.toString().trim() ?? '';
    final remoteTeacherName = halaqah?['teacher_name']?.toString().trim() ?? '';

    if (remoteMosqueName.isNotEmpty) {
      await _db.saveSetting('mosque_name', remoteMosqueName);
    }
    if (remoteHalaqahName.isNotEmpty) {
      await _db.saveSetting('halaqah_name', remoteHalaqahName);
    }
    if (remoteTeacherName.isNotEmpty) {
      await _db.saveSetting('teacher_name', remoteTeacherName);
    }
    await _db.saveSetting(
      'last_cloud_identity_refresh_at',
      DateTime.now().toIso8601String(),
    );
    await _db.saveSetting('setup_completed', 'true');
  }

  Future<void> _createPreSyncBackupIfNeeded(
    CloudSyncDirection direction,
  ) async {
    if (direction.shouldDownload) await _createDailyPreSyncBackup();
  }

  Future<void> _createDailyPreSyncBackup() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastBackupDate = await _db.getSetting('last_pre_sync_backup_date');
    if (lastBackupDate == today) return;

    try {
      await BackupService().createPreSyncBackup();
      await _db.saveSetting('last_pre_sync_backup_date', today);
    } catch (error) {
      throw Exception(
        'تعذر إنشاء نسخة احتياطية قبل المزامنة. تم إيقاف المزامنة لحماية بيانات الطلاب: $error',
      );
    }
  }

  Future<void> _syncDeleteOutbox() async {
    const pageSize = 500;
    const maxPagesPerRun = 50;
    final initialTotal = await _db.getPendingSyncDeleteCount();
    if (initialTotal == 0) return;

    var completed = 0;
    _updateDeleteOutboxProgress(completed, initialTotal);

    for (var page = 0; page < maxPagesPerRun; page++) {
      var pending = await _db.getPendingSyncDeletes(limit: pageSize);
      if (pending.isEmpty) break;

      // SQLite INSERT OR REPLACE emits an internal DELETE. Most of those rows
      // still exist locally and therefore must never be sent to Supabase. Prune
      // them with one SQL statement per table instead of one query per outbox
      // row, which is important after a restore or a large editing session.
      final pruned = await _db.pruneRestoredSyncDeletes(pending);
      if (pruned > 0) {
        completed += pruned;
        _updateDeleteOutboxProgress(completed, initialTotal);
        pending = await _db.getPendingSyncDeletes(limit: pageSize);
        if (pending.isEmpty) break;
      }

      var acknowledgedThisPage = 0;
      final sortedPriorities = pending
          .map((operation) => operation.priority)
          .toSet()
          .toList()
        ..sort();

      for (final priority in sortedPriorities) {
        final priorityOperations = pending
            .where((operation) => operation.priority == priority)
            .toList(growable: false);

        final directByTable = <String, List<LocalSyncDeleteOperation>>{};
        final filtered = <LocalSyncDeleteOperation>[];
        for (final operation in priorityOperations) {
          final remoteId = operation.remoteId?.trim() ?? '';
          if (remoteId.isNotEmpty && operation.remoteFilters.isEmpty) {
            directByTable
                .putIfAbsent(operation.remoteTable, () => <LocalSyncDeleteOperation>[])
                .add(operation);
          } else {
            filtered.add(operation);
          }
        }

        for (final entry in directByTable.entries) {
          final acknowledged = await _deleteRemoteIdOperations(
            entry.key,
            entry.value,
          );
          if (acknowledged.isEmpty) continue;
          await _db.acknowledgeSyncDeletes(acknowledged);
          acknowledgedThisPage += acknowledged.length;
          completed += acknowledged.length;
          _updateDeleteOutboxProgress(completed, initialTotal);
        }

        final filteredByTable = <String, List<LocalSyncDeleteOperation>>{};
        for (final operation in filtered) {
          filteredByTable
              .putIfAbsent(
                operation.remoteTable,
                () => <LocalSyncDeleteOperation>[],
              )
              .add(operation);
        }
        for (final entry in filteredByTable.entries) {
          final acknowledged = await _deleteRemoteFilterOperations(
            entry.key,
            entry.value,
          );
          if (acknowledged.isEmpty) continue;
          await _db.acknowledgeSyncDeletes(acknowledged);
          acknowledgedThisPage += acknowledged.length;
          completed += acknowledged.length;
          _updateDeleteOutboxProgress(completed, initialTotal);
        }
      }

      if (pending.length < pageSize || acknowledgedThisPage == 0) break;
    }

    final remaining = await _db.getPendingSyncDeleteCount();
    if (remaining > 0) {
      AppLogger.warning(
        'delete_outbox_pending:$remaining',
        source: 'supabase.sync.delete_outbox',
      );
      _updateDeleteOutboxProgress(
        (initialTotal - remaining).clamp(0, initialTotal).toInt(),
        initialTotal,
      );
    }
  }

  Future<List<int>> _deleteRemoteFilterOperations(
    String remoteTable,
    List<LocalSyncDeleteOperation> operations,
  ) async {
    if (operations.isEmpty) return const <int>[];

    final batchable = <LocalSyncDeleteOperation>[];
    final fallback = <LocalSyncDeleteOperation>[];
    for (final operation in operations) {
      if (_remoteCompositeDeleteClause(operation) == null) {
        fallback.add(operation);
      } else {
        batchable.add(operation);
      }
    }

    final acknowledged = <int>[];
    for (final chunk in _chunks(batchable, 20)) {
      acknowledged.addAll(
        await _deleteRemoteFilterChunkWithIsolation(remoteTable, chunk),
      );
    }

    // Unknown composite selectors stay on the safe generic path. Keep this
    // bounded because these should be exceptional rather than the common path.
    for (final chunk in _chunks(fallback, 6)) {
      final results = await Future.wait<int?>(
        chunk.map((operation) async {
          try {
            await _deleteRemoteOutboxOperation(operation);
            return operation.id;
          } catch (error) {
            AppLogger.error(
              error,
              source: 'supabase.sync.delete_outbox.${operation.remoteTable}',
            );
            return null;
          }
        }),
      );
      acknowledged.addAll(results.whereType<int>());
    }
    return acknowledged;
  }

  Future<List<int>> _deleteRemoteFilterChunkWithIsolation(
    String remoteTable,
    List<LocalSyncDeleteOperation> operations,
  ) async {
    if (operations.isEmpty) return const <int>[];
    try {
      final clauses = operations
          .map(_remoteCompositeDeleteClause)
          .whereType<String>()
          .toList(growable: false);
      if (clauses.length != operations.length) {
        throw const FormatException('Unsupported composite delete selector');
      }
      await client.from(remoteTable).delete().or(clauses.join(','));
      return operations.map((operation) => operation.id).toList(growable: false);
    } catch (error) {
      if (operations.length == 1 || !_shouldIsolateDeleteBatchError(error)) {
        AppLogger.error(
          error,
          source: 'supabase.sync.delete_outbox.$remoteTable',
        );
        return const <int>[];
      }
      final middle = operations.length ~/ 2;
      final left = await _deleteRemoteFilterChunkWithIsolation(
        remoteTable,
        operations.sublist(0, middle),
      );
      final right = await _deleteRemoteFilterChunkWithIsolation(
        remoteTable,
        operations.sublist(middle),
      );
      return <int>[...left, ...right];
    }
  }

  bool _shouldIsolateDeleteBatchError(Object error) {
    if (error is! PostgrestException) return false;
    return error.code == '23503' ||
        error.code == '23514' ||
        error.code == '22P02';
  }

  String? _remoteCompositeDeleteClause(LocalSyncDeleteOperation operation) {
    final filters = operation.remoteFilters;
    if (operation.remoteTable == 'attendance') {
      final studentId = filters['student_id'] ?? '';
      final date = filters['date'] ?? '';
      if (!_uuidPattern.hasMatch(studentId) || !_datePattern.hasMatch(date)) {
        return null;
      }
      return 'and(student_id.eq.$studentId,date.eq.$date)';
    }
    if (operation.remoteTable == 'mushaf_progress') {
      final studentId = filters['student_id'] ?? '';
      final hizb = filters['hizb_number'] ?? '';
      final thumun = filters['thumun_number'] ?? '';
      if (!_uuidPattern.hasMatch(studentId) ||
          !_positiveIntegerPattern.hasMatch(hizb) ||
          !_positiveIntegerPattern.hasMatch(thumun)) {
        return null;
      }
      return 'and(student_id.eq.$studentId,hizb_number.eq.$hizb,'
          'thumun_number.eq.$thumun)';
    }
    return null;
  }

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final RegExp _positiveIntegerPattern = RegExp(r'^\d+$');

  Future<List<int>> _deleteRemoteIdOperations(
    String remoteTable,
    List<LocalSyncDeleteOperation> operations,
  ) async {
    if (operations.isEmpty) return const <int>[];

    if (remoteTable == 'students') {
      final acknowledged = <int>[];
      for (final chunk in _chunks(operations, 2)) {
        final results = await Future.wait<int?>(
          chunk.map((operation) async {
            try {
              await _deleteRemoteOutboxOperation(operation);
              return operation.id;
            } catch (error) {
              AppLogger.error(
                error,
                source: 'supabase.sync.delete_outbox.students',
              );
              return null;
            }
          }),
        );
        acknowledged.addAll(results.whereType<int>());
      }
      return acknowledged;
    }

    final acknowledged = <int>[];
    for (final chunk in _chunks(operations, 80)) {
      acknowledged.addAll(
        await _deleteRemoteIdChunkWithIsolation(remoteTable, chunk),
      );
    }
    return acknowledged;
  }

  Future<List<int>> _deleteRemoteIdChunkWithIsolation(
    String remoteTable,
    List<LocalSyncDeleteOperation> operations,
  ) async {
    if (operations.isEmpty) return const <int>[];
    try {
      await _deleteRemoteIdChunk(remoteTable, operations);
      return operations.map((operation) => operation.id).toList(growable: false);
    } catch (error) {
      if (operations.length == 1 || !_shouldIsolateDeleteBatchError(error)) {
        AppLogger.error(
          error,
          source: 'supabase.sync.delete_outbox.$remoteTable',
        );
        return const <int>[];
      }

      // A single stale FK must not force all rows in a
      // batch back to one-by-one requests. Split only the failing batch until
      // the problematic row is isolated.
      final middle = operations.length ~/ 2;
      final left = await _deleteRemoteIdChunkWithIsolation(
        remoteTable,
        operations.sublist(0, middle),
      );
      final right = await _deleteRemoteIdChunkWithIsolation(
        remoteTable,
        operations.sublist(middle),
      );
      return <int>[...left, ...right];
    }
  }

  Future<void> _deleteRemoteIdChunk(
    String remoteTable,
    List<LocalSyncDeleteOperation> operations,
  ) async {
    final remoteIds = operations
        .map((operation) => operation.remoteId?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (remoteIds.isEmpty) return;

    if (remoteTable == 'exams') {
      await client.from('exam_scores').delete().inFilter('exam_id', remoteIds);
    } else if (remoteTable == 'exam_templates') {
      await client
          .from('exam_questions')
          .delete()
          .inFilter('template_id', remoteIds);
    } else if (remoteTable == 'quran_courses') {
      await client
          .from('quran_course_enrollments')
          .delete()
          .inFilter('course_id', remoteIds);
    }

    await client.from(remoteTable).delete().inFilter('id', remoteIds);
  }

  void _updateDeleteOutboxProgress(int completed, int total) {
    final progress = syncProgress.value;
    if (progress == null || progress.stageId != 'delete_outbox') return;
    final safeCompleted = completed.clamp(0, total);
    syncProgress.value = CloudSyncProgress(
      state: CloudSyncProgressState.running,
      stageId: progress.stageId,
      stageLabel: 'رفع عمليات الحذف المحلية ($safeCompleted/$total)',
      currentStage: progress.currentStage,
      totalStages: progress.totalStages,
    );
  }

  Iterable<List<T>> _chunks<T>(List<T> values, int size) sync* {
    if (size <= 0) throw ArgumentError.value(size, 'size');
    for (var start = 0; start < values.length; start += size) {
      final end = start + size < values.length ? start + size : values.length;
      yield values.sublist(start, end);
    }
  }

  Future<void> _deleteRemoteOutboxOperation(
    LocalSyncDeleteOperation operation,
  ) async {
    final remoteId = operation.remoteId;

    // Parent tables with restrictive cloud foreign keys need their dependent
    // rows removed first. All calls remain scoped by RLS/RPC authorization.
    if (operation.remoteTable == 'exams' && remoteId != null) {
      await client.from('exam_scores').delete().eq('exam_id', remoteId);
    } else if (operation.remoteTable == 'exam_templates' && remoteId != null) {
      await client.from('exam_questions').delete().eq('template_id', remoteId);
    } else if (operation.remoteTable == 'quran_courses' && remoteId != null) {
      await client
          .from('quran_course_enrollments')
          .delete()
          .eq('course_id', remoteId);
    } else if (operation.remoteTable == 'students' && remoteId != null) {
      await client.rpc('delete_student_for_sync', params: {
        'p_student_id': remoteId,
      });
      return;
    }

    var deletion = client.from(operation.remoteTable).delete();
    if (remoteId != null && remoteId.isNotEmpty) {
      await deletion.eq('id', remoteId);
      return;
    }
    if (operation.remoteFilters.isEmpty) {
      throw StateError('عملية حذف سحابية بلا محدد');
    }

    dynamic filtered = deletion;
    for (final entry in operation.remoteFilters.entries) {
      filtered = filtered.eq(entry.key, entry.value);
    }
    await filtered;
  }

  Future<void> _syncCloudTombstones(
    String centerId,
    String halaqahId,
  ) async {
    final cursorKey = 'cloud_tombstone_cursor_${centerId}_$halaqahId';
    var cursor = int.tryParse(await _db.getSetting(cursorKey) ?? '') ?? 0;
    const pageSize = 500;

    while (true) {
      dynamic response;
      try {
        response = await client.rpc('get_sync_tombstones', params: {
          'p_center_id': centerId,
          'p_halaqa_id': halaqahId,
          'p_after_id': cursor,
          'p_limit': pageSize,
        });
      } on PostgrestException catch (error) {
        // Build 74 remains usable until the owner applies the P1.27 SQL. The
        // durable remote-delete guarantee activates as soon as the RPC exists.
        if (error.code == 'PGRST202' ||
            error.code == '42883' ||
            error.message.toLowerCase().contains('get_sync_tombstones')) {
          AppLogger.warning(
            'cloud_tombstone_contract_missing',
            source: 'supabase.sync.tombstones',
          );
          return;
        }
        rethrow;
      }

      final rawRows = response is List ? response : const <dynamic>[];
      if (rawRows.isEmpty) return;
      final rows = rawRows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      if (rows.isEmpty) return;

      final affectedStudents = await _db.applyCloudTombstones(rows);
      for (final studentId in affectedStudents) {
        await _mushaf.rebuildStudentProgress(studentId);
      }

      var maxId = cursor;
      for (final row in rows) {
        final rawId = row['id'];
        final id = rawId is num
            ? rawId.toInt()
            : int.tryParse(rawId?.toString() ?? '') ?? cursor;
        if (id > maxId) maxId = id;
      }
      if (maxId <= cursor) return;
      cursor = maxId;
      await _db.saveSetting(cursorKey, cursor.toString());
      if (rows.length < pageSize) return;
    }
  }

  Future<void> _syncFamilies(
    String centerId,
    String halaqId,
    CloudSyncDirection direction,
  ) async {
    try {
      if (direction.shouldUpload) {
        await _syncDeletedRows(
          table: 'family_guardians',
          settingKey: 'deleted_family_guardian_ids',
        );
        await _syncDeletedRows(
          table: 'families',
          settingKey: 'deleted_family_ids',
        );

        final localFamilies = await _db.getFamilies();
        if (localFamilies.isNotEmpty) {
          await client.from('families').upsert(
                localFamilies
                    .map(
                      (family) => {
                        'id': family.id,
                        'center_id': centerId,
                        'halaqa_id': halaqId,
                        'name': family.name,
                        'reference_name': family.referenceName,
                        'notes': family.notes,
                        'created_at': family.createdAt.toIso8601String(),
                        'updated_at': family.updatedAt.toIso8601String(),
                      },
                    )
                    .toList(),
              );
        }

        final allGuardians = await _db.getAllFamilyGuardians();
        final guardianPayload = allGuardians
            .map(
              (guardian) => {
                'id': guardian.id,
                'family_id': guardian.familyId,
                'center_id': centerId,
                'halaqa_id': halaqId,
                'name': guardian.name,
                'phone': guardian.phone,
                'email': guardian.email,
                'relationship': guardian.relationship,
                'is_primary': guardian.isPrimary,
                'notes': guardian.notes,
                'created_at': guardian.createdAt.toIso8601String(),
                'updated_at': guardian.updatedAt.toIso8601String(),
              },
            )
            .toList();
        // Upload non-primary rows first, then primary rows, but do it in only two
        // network requests regardless of the number of families.
        for (final primaryState in const [false, true]) {
          final group = guardianPayload
              .where((row) => row['is_primary'] == primaryState)
              .toList();
          if (group.isNotEmpty) {
            await client.from('family_guardians').upsert(group);
          }
        }
      }

      if (direction.shouldDownload) {
        final remoteFamilies = await client
            .from('families')
            .select()
            .eq('halaqa_id', halaqId);
        await _db.upsertFamiliesFromSync(
          (remoteFamilies as List<dynamic>).map(
            (remote) => Family.fromMap(Map<String, dynamic>.from(remote)),
          ),
        );

        final remoteGuardians = await client
            .from('family_guardians')
            .select()
            .eq('halaqa_id', halaqId);
        await _db.upsertFamilyGuardiansFromSync(
          (remoteGuardians as List<dynamic>).map(
            (remote) =>
                FamilyGuardian.fromMap(Map<String, dynamic>.from(remote)),
          ),
        );
      }
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST205' ||
          error.code == '42P01' ||
          error.code == '42703') {
        AppLogger.warning('family_schema_missing', source: 'supabase.sync.families');
        return;
      }
      rethrow;
    }
  }

  // Sync Students: Push local changes, Pull remote changes
  Future<void> _syncStudents(
    String centerId,
    String halaqahId,
    CloudSyncDirection direction,
  ) async {
    if (direction.shouldUpload) {
      final localStudents = await _db.getStudents();
      final List<Map<String, dynamic>> studentsPayload = [];
      for (final student in localStudents) {
        studentsPayload.add({
          'id': student.id,
          'center_id': centerId,
          'halaqa_id': halaqahId,
          'name': student.name,
          'phone': student.phone,
          'parent_phone': student.guardianPhone,
          'family_id': student.familyId,
          'qr_code': student.qrCode,
          'student_code': student.studentCode,
          'plan_type': student.planType,
          'plan_amount': student.planAmount,
          'review_plan_amount': student.reviewPlanAmount,
          'review_plan_type': student.reviewPlanType,
          'review_system': student.reviewSystem,
          'talaqqin_enabled': student.talaqqinEnabled,
          'total_memorized': student.totalMemorized,
          'status': student.status,
          'notes': student.notes,
          'join_date': student.joinDate.toIso8601String().split('T')[0],
          'created_at': student.createdAt.toIso8601String(),
          'updated_at': student.updatedAt.toIso8601String(),
          'memorization_direction': student.memorizationDirection,
          'pre_memorized_start_surah': student.preMemorizedStartSurah,
          'pre_memorized_start_ayah': student.preMemorizedStartAyah,
          'pre_memorized_end_surah': student.preMemorizedEndSurah,
          'pre_memorized_end_ayah': student.preMemorizedEndAyah,
        });
      }
      for (var i = 0; i < studentsPayload.length; i += 500) {
        final chunk = studentsPayload.sublist(
          i,
          i + 500 > studentsPayload.length ? studentsPayload.length : i + 500,
        );
        await _upsertStudentsWithSchemaCompatibility(chunk);
      }
    }

    if (!direction.shouldDownload) return;
    final response = await client
        .from('students')
        .select()
        .eq('halaqa_id', halaqahId);

    final List<dynamic> remoteStudents = response as List<dynamic>;
    final localStudents = await _db.getStudents();
    final localById = {for (final student in localStudents) student.id: student};
    final mergedStudents = <Student>[];

    for (final remote in remoteStudents) {
      final existing = localById[remote['id']?.toString()];
      final remoteTotalMemorized =
          (remote['total_memorized'] as num?)?.toInt();
      final protectedTotalMemorized = existing != null &&
              existing.totalMemorized > (remoteTotalMemorized ?? 0)
          ? existing.totalMemorized
          : remoteTotalMemorized ?? 0;
      final localStudent = Student(
        id: remote['id'],
        name: remote['name'],
        phone: remote['phone'] ?? existing?.phone ?? '',
        guardianPhone: remote['parent_phone'] ?? existing?.guardianPhone ?? '',
        familyId: remote['family_id']?.toString() ?? existing?.familyId,
        qrCode: remote['qr_code'] ?? existing?.qrCode ?? remote['id'],
        studentCode:
            remote['student_code'] ?? existing?.studentCode,
        planType: remote['plan_type'] ?? existing?.planType ?? 'ayahs',
        planAmount: (remote['plan_amount'] as num?)?.toInt() ??
            existing?.planAmount ??
            5,
        reviewPlanAmount:
            (remote['review_plan_amount'] as num?)?.toInt() ??
                existing?.reviewPlanAmount ??
                10,
        reviewPlanType: remote['review_plan_type'] ??
            existing?.reviewPlanType ??
            remote['plan_type'] ??
            'ayahs',
        reviewSystem:
            remote['review_system'] ?? existing?.reviewSystem ?? 'adaptive_spaced',
        talaqqinEnabled: remote['talaqqin_enabled'] == null
            ? (existing?.talaqqinEnabled ?? false)
            : remote['talaqqin_enabled'] == true,
        // A zero introduced by a schema migration must not erase a larger
        // local total. Explicit progress resets will use a dedicated workflow.
        totalMemorized: protectedTotalMemorized,
        status: remote['status'] ?? existing?.status ?? 'active',
        photoPath: existing?.photoPath,
        notes: remote['notes'] ?? existing?.notes,
        memorizationDirection:
            remote['memorization_direction'] ??
                existing?.memorizationDirection ??
                'desc',
        preMemorizedStartSurah:
            (remote['pre_memorized_start_surah'] as num?)?.toInt() ??
                existing?.preMemorizedStartSurah,
        preMemorizedStartAyah:
            (remote['pre_memorized_start_ayah'] as num?)?.toInt() ??
                existing?.preMemorizedStartAyah,
        preMemorizedEndSurah:
            (remote['pre_memorized_end_surah'] as num?)?.toInt() ??
                existing?.preMemorizedEndSurah,
        preMemorizedEndAyah:
            (remote['pre_memorized_end_ayah'] as num?)?.toInt() ??
                existing?.preMemorizedEndAyah,
        joinDate: remote['join_date'] != null
            ? DateTime.parse(remote['join_date'])
            : existing?.joinDate ?? DateTime.now(),
        createdAt: remote['created_at'] != null
            ? DateTime.parse(remote['created_at'])
            : existing?.createdAt ?? DateTime.now(),
        updatedAt: remote['updated_at'] != null
            ? DateTime.parse(remote['updated_at'])
            : existing?.updatedAt ?? DateTime.now(),
      );

      mergedStudents.add(localStudent);
    }
    await _db.upsertStudentsFromSync(mergedStudents);
  }

  Future<void> _upsertStudentsWithSchemaCompatibility(
    List<Map<String, dynamic>> chunk,
  ) async {
    const optionalColumns = <String>{
      'family_id',
      'qr_code',
      'student_code',
      'total_memorized',
      'review_plan_amount',
      'review_plan_type',
      'review_system',
      'talaqqin_enabled',
      'notes',
      'updated_at',
      'pre_memorized_start_surah',
      'pre_memorized_start_ayah',
      'pre_memorized_end_surah',
      'pre_memorized_end_ayah',
    };
    final compatibleChunk =
        chunk.map((row) => Map<String, dynamic>.from(row)).toList();
    final remainingOptionalColumns = optionalColumns.toSet();

    while (true) {
      try {
        await client.from('students').upsert(compatibleChunk);
        return;
      } on PostgrestException catch (error) {
        if (error.code != 'PGRST204' && error.code != '42703') rethrow;
        final description = [error.message, error.details, error.hint]
            .whereType<Object>()
            .join(' ')
            .toLowerCase();
        String? missingColumn;
        for (final column in remainingOptionalColumns) {
          if (description.contains(column.toLowerCase())) {
            missingColumn = column;
            break;
          }
        }
        if (missingColumn == null) rethrow;

        remainingOptionalColumns.remove(missingColumn);
        for (final row in compatibleChunk) {
          row.remove(missingColumn);
        }
      }
    }
  }

  // Sync Grades: Push local changes, Pull remote changes
  Future<void> _syncHomeworkGrades(
    String centerId,
    String halaqahId,
    CloudSyncDirection direction,
  ) async {
    if (direction.shouldUpload) {
      await _syncDeletedRows(
        table: 'homework_grades',
        settingKey: 'deleted_homework_grade_ids',
      );
    }
    final beforeResponse = await client
        .from('homework_grades')
        .select()
        .eq('halaqa_id', halaqahId);
    final beforeRows = List<Map<String, dynamic>>.from(
      beforeResponse as List<dynamic>,
    );
    final deletedIds = beforeRows
        .where((row) => row['deleted_at'] != null)
        .map((row) => row['id'].toString())
        .toSet();
    if (direction.shouldDownload) {
      for (final id in deletedIds) {
        await _db.deleteHomeworkGrade(id);
      }
    }

    final remoteActive = <String, HomeworkGrade>{};
    for (final row in beforeRows.where((row) => row['deleted_at'] == null)) {
      final grade = _homeworkGradeFromRemote(row);
      remoteActive[grade.id] = grade;
    }

    if (direction.shouldUpload) {
      final payload = <Map<String, dynamic>>[];
      for (final grade in await _db.getAllHomeworkGrades()) {
        if (deletedIds.contains(grade.id)) continue;
        final remote = remoteActive[grade.id];
        if (remote != null && !grade.updatedAt.isAfter(remote.updatedAt)) {
          continue;
        }
        payload.add({
          'id': grade.id,
          'student_id': grade.studentId,
          'center_id': centerId,
          'halaqa_id': halaqahId,
          'surah': QuranService.instance.getSurahName(grade.surahId),
          'from_ayah': grade.fromAyah,
          'to_ayah': grade.toAyah,
          'date': grade.date.toIso8601String().split('T')[0],
          'grade_mark': grade.gradeMark,
          'mistakes_count': grade.mistakesCount,
          'is_revision': grade.isRevision,
          'remark': grade.remark,
          'created_at': grade.createdAt.toIso8601String(),
          'updated_at': grade.updatedAt.toIso8601String(),
        });
      }
      for (var i = 0; i < payload.length; i += 500) {
        final end = i + 500 > payload.length ? payload.length : i + 500;
        await client.from('homework_grades').upsert(payload.sublist(i, end));
      }
    }

    if (!direction.shouldDownload) return;
    final finalResponse = await client
        .from('homework_grades')
        .select()
        .eq('halaqa_id', halaqahId);
    for (final row in List<Map<String, dynamic>>.from(
      finalResponse as List<dynamic>,
    )) {
      if (row['deleted_at'] != null) {
        await _db.deleteHomeworkGrade(row['id'].toString());
      } else {
        await _db.insertHomeworkGrade(_homeworkGradeFromRemote(row));
      }
    }
  }

  HomeworkGrade _homeworkGradeFromRemote(Map<String, dynamic> remote) {
    final surah = QuranService.instance.surahs.where(
      (item) => item.name == remote['surah'],
    );
    final createdAt = DateTime.parse(remote['created_at']);
    return HomeworkGrade(
      id: remote['id'],
      studentId: remote['student_id'],
      surahId: surah.isEmpty ? 1 : surah.first.number,
      fromAyah: remote['from_ayah'],
      toAyah: remote['to_ayah'],
      date: DateTime.parse(remote['date']),
      gradeMark: remote['grade_mark'],
      mistakesCount: remote['mistakes_count'] ?? 0,
      isRevision: remote['is_revision'] ?? false,
      remark: remote['remark'],
      createdAt: createdAt,
      updatedAt: DateTime.tryParse(remote['updated_at']?.toString() ?? '') ??
          createdAt,
    );
  }

  // Sync Attendance: Push local, Pull remote
  Future<void> _syncAttendance(
    String centerId,
    String halaqahId,
    CloudSyncDirection direction,
  ) async {
    if (direction.shouldUpload) {
      final deletedRaw = await _db.getSetting('deleted_attendance_keys');
      if (deletedRaw != null && deletedRaw.trim().isNotEmpty) {
        final deletedKeys = <String>[];
        try {
          final decoded = jsonDecode(deletedRaw);
          if (decoded is List) deletedKeys.addAll(decoded.map((item) => item.toString()));
        } catch (_) {}
        for (final key in deletedKeys) {
          final separator = key.lastIndexOf('|');
          if (separator <= 0) continue;
          final studentId = key.substring(0, separator);
          final date = key.substring(separator + 1);
          await client
              .from('attendance')
              .delete()
              .eq('center_id', centerId)
              .eq('student_id', studentId)
              .eq('date', date);
        }
        await _db.saveSetting('deleted_attendance_keys', '[]');
      }

      final localRecords = await _db.getAllDailyRecords();
      final List<Map<String, dynamic>> attendancePayload = [];
      for (final record in localRecords) {
        final date = record.date.toIso8601String().split('T')[0];
        final uniqueId = '${record.studentId}_$date';
        attendancePayload.add({
          'id': remoteUUID(uniqueId),
          'student_id': record.studentId,
          'center_id': centerId,
          'halaqa_id': halaqahId,
          'date': date,
          'status': record.attendance,
          'arrival_time': record.arrivalTime?.toIso8601String().split('T')[1],
          'absence_reason': record.absenceReason,
          'notes': record.notes,
          'activity_type': record.activityType,
          'activity_note': record.activityNote,
          'recitation_exempt': record.recitationExempt,
          'talaqqin_done': record.talaqqinDone,
          'talaqqin_amount': record.talaqqinAmount,
          'talaqqin_note': record.talaqqinNote,
        });
      }
      for (var i = 0; i < attendancePayload.length; i += 500) {
        final chunk = attendancePayload.sublist(
          i,
          i + 500 > attendancePayload.length
              ? attendancePayload.length
              : i + 500,
        );
        await _upsertAttendanceWithSchemaCompatibility(chunk);
      }
    }

    if (!direction.shouldDownload) return;
    final scopedStudentIds = await _fetchHalaqahStudentIds(halaqahId);
    if (scopedStudentIds.isEmpty) return;
    final response = await client
        .from('attendance')
        .select()
        .eq('center_id', centerId);

    final remoteAttendance = (response as List<dynamic>)
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .where(
          (row) => scopedStudentIds.contains(row['student_id']?.toString()),
        )
        .toList(growable: false);
    if (remoteAttendance.isEmpty) return;

    final remoteDates = remoteAttendance
        .map((row) => DateTime.parse(row['date'].toString()))
        .toList(growable: false);
    var minDate = remoteDates.first;
    var maxDate = remoteDates.first;
    for (final date in remoteDates.skip(1)) {
      if (date.isBefore(minDate)) minDate = date;
      if (date.isAfter(maxDate)) maxDate = date;
    }

    // One indexed local read + one SQLite batch replaces a query/write pair for
    // every remote attendance row. This is especially noticeable on long-lived
    // halaqah databases during a full cloud pull.
    final existingRows = await _db.getDailyRecordsInRange(minDate, maxDate);
    final existingByStudentDate = <String, DailyRecord>{
      for (final record in existingRows)
        '${record.studentId}|${record.date.toIso8601String().split('T').first}':
            record,
    };
    final pending = <DailyRecord>[];

    for (final remote in remoteAttendance) {
      final remoteDate = DateTime.parse(remote['date'].toString());
      final studentId = remote['student_id'].toString();
      final key =
          '$studentId|${remoteDate.toIso8601String().split('T').first}';
      final existing = existingByStudentDate[key];
      final hasActivityFields = remote.containsKey('activity_type') ||
          remote.containsKey('activity_note') ||
          remote.containsKey('recitation_exempt');
      final hasTalaqqinFields = remote.containsKey('talaqqin_done') ||
          remote.containsKey('talaqqin_amount') ||
          remote.containsKey('talaqqin_note');
      pending.add(
        DailyRecord(
          id: existing?.id,
          studentId: studentId,
          date: remoteDate,
          attendance: remote['status'] ?? 'absent',
          arrivalTime: remote['arrival_time'] != null
              ? DateTime.parse(
                  '${remote['date']}T${remote['arrival_time']}',
                )
              : null,
          absenceReason: remote['absence_reason'],
          absenceNote: existing?.absenceNote,
          memorizationDone: existing?.memorizationDone ?? false,
          revisionDone: existing?.revisionDone ?? false,
          memorizationAmount: existing?.memorizationAmount ?? 0,
          revisionAmount: existing?.revisionAmount ?? 0,
          memorizationNote: existing?.memorizationNote,
          revisionNote: existing?.revisionNote,
          notes: remote['notes'] ?? '',
          activityType: hasActivityFields
              ? remote['activity_type']
              : existing?.activityType,
          activityNote: hasActivityFields
              ? remote['activity_note']
              : existing?.activityNote,
          recitationExempt: hasActivityFields
              ? remote['recitation_exempt'] == true
              : existing?.recitationExempt ?? false,
          talaqqinDone: hasTalaqqinFields
              ? remote['talaqqin_done'] == true
              : existing?.talaqqinDone ?? false,
          talaqqinAmount: hasTalaqqinFields
              ? (remote['talaqqin_amount'] as num?)?.toInt() ?? 0
              : existing?.talaqqinAmount ?? 0,
          talaqqinNote: hasTalaqqinFields
              ? remote['talaqqin_note']
              : existing?.talaqqinNote,
          createdAt: existing?.createdAt,
        ),
      );
    }

    await _db.saveDailyRecords(pending);
  }

  Future<void> _upsertAttendanceWithSchemaCompatibility(
    List<Map<String, dynamic>> chunk,
  ) async {
    Future<void> upsertRows(List<Map<String, dynamic>> rows) async {
      // Attendance identity is the student/day business key. Older web/cloud
      // writes may have created the same day with a random UUID, so targeting
      // only the synthetic id can raise 23505 on uq_attendance_student_date.
      // Do not send id here: inserts can use the server UUID default, while
      // updates preserve the existing row id and converge on student/date.
      final businessRows = rows
          .map((row) => Map<String, dynamic>.from(row)..remove('id'))
          .toList(growable: false);
      await client
          .from('attendance')
          .upsert(businessRows, onConflict: 'student_id,date');
    }

    try {
      await upsertRows(chunk);
      return;
    } on PostgrestException catch (error) {
      if (!_isMissingSchemaColumn(error)) rethrow;
    }

    // يسمح للتطبيق بالاستمرار مع Supabase P1.21 إلى أن ينفذ المسؤول
    // migration P1.22. الحقول الجديدة تبقى محفوظة محلياً ولا تضيع.
    final withoutP122 = chunk
        .map(
          (row) => Map<String, dynamic>.from(row)
            ..remove('activity_type')
            ..remove('activity_note')
            ..remove('recitation_exempt')
            ..remove('talaqqin_done')
            ..remove('talaqqin_amount')
            ..remove('talaqqin_note'),
        )
        .toList();
    try {
      await upsertRows(withoutP122);
      return;
    } on PostgrestException catch (error) {
      if (!_isMissingSchemaColumn(error)) rethrow;
    }

    final legacyRows = withoutP122
        .map((row) => Map<String, dynamic>.from(row)..remove('halaqa_id'))
        .toList();
    await upsertRows(legacyRows);
  }

  bool _isMissingSchemaColumn(PostgrestException error) {
    final description = [error.message, error.details, error.hint]
        .whereType<Object>()
        .join(' ')
        .toLowerCase();
    return (error.code == 'PGRST204' || error.code == '42703') &&
        (description.contains('column') || description.contains('schema'));
  }

  bool _isMissingSchemaTable(PostgrestException error) {
    return error.code == '42P01' || error.code == 'PGRST205';
  }

  Future<Set<String>> _fetchHalaqahStudentIds(String halaqahId) async {
    final cached = _studentIdsByHalaqah[halaqahId];
    if (cached != null) return cached;

    final rows = await client
        .from('students')
        .select('id')
        .eq('halaqa_id', halaqahId);
    final ids = (rows as List<dynamic>)
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .toSet();
    _studentIdsByHalaqah[halaqahId] = ids;
    return ids;
  }

  // Sync Mushaf Progress: Push local, Pull remote
  Future<void> _syncMushafProgress(
    String centerId,
    String halaqahId,
    CloudSyncDirection direction,
  ) async {
    if (direction.shouldUpload) {
      final localProgressList = await _db.getAllMushafProgress();
      final List<Map<String, dynamic>> mushafPayload = [];
      for (final progress in localProgressList) {
        final uniqueId =
            '${progress.studentId}_${progress.hizbNumber}_${progress.thumunNumber}';
        mushafPayload.add({
          'id': remoteUUID(uniqueId),
          'student_id': progress.studentId,
          'center_id': centerId,
          'hizb_number': progress.hizbNumber,
          'thumun_number': progress.thumunNumber,
          'average_grade': progress.averageGrade,
          'last_graded_date':
              progress.lastGradedDate?.toIso8601String().split('T')[0],
          'is_pre_memorized': progress.isPreMemorized,
        });
      }
      for (var i = 0; i < mushafPayload.length; i += 500) {
        final chunk = mushafPayload.sublist(
          i,
          i + 500 > mushafPayload.length ? mushafPayload.length : i + 500,
        );
        // The mobile id is deterministic for student+hizb+thumun, so the
        // primary key is sufficient for an idempotent upsert. Do not require a
        // composite UNIQUE constraint just to make mobile synchronization work.
        await client.from('mushaf_progress').upsert(chunk);
      }
    }

    if (!direction.shouldDownload) return;
    final scopedStudentIds = await _fetchHalaqahStudentIds(halaqahId);
    if (scopedStudentIds.isEmpty) return;
    final response = await client
        .from('mushaf_progress')
        .select()
        .eq('center_id', centerId);

    final List<dynamic> remoteProgressList = response as List<dynamic>;

    for (final remote in remoteProgressList) {
      if (!scopedStudentIds.contains(remote['student_id']?.toString())) {
        continue;
      }
      final localProgress = MushafProgress(
        id: remote['id'],
        studentId: remote['student_id'],
        hizbNumber: remote['hizb_number'],
        thumunNumber: remote['thumun_number'],
        averageGrade: (remote['average_grade'] ?? 0.0).toDouble(),
        lastGradedDate: remote['last_graded_date'] != null
            ? DateTime.parse(remote['last_graded_date'])
            : null,
        isPreMemorized: remote['is_pre_memorized'] ?? false,
      );

      await _db.insertOrUpdateMushafProgress(localProgress);
    }
  }

  // Fetch all centers associated with the current user
  Future<List<Map<String, dynamic>>> fetchUserCenters() async {
    if (!isAuthenticated) return [];
    final email = currentUserEmail;
    final currentUser = client.auth.currentUser;
    if (email == null || currentUser == null) return [];

    try {
      final List<Map<String, dynamic>> centersList = [];

      // 1. Fetch centers owned by the user
      final ownedCenters = await client
          .from('centers')
          .select('id, name')
          .eq('owner_id', currentUser.id);
      
      for (final c in ownedCenters as List<dynamic>) {
        centersList.add({
          'id': c['id'],
          'name': c['name'],
          'role': 'owner',
        });
      }

      // 2. Fetch centers where user is a member
      final memberCenters = await client
          .from('center_members')
          .select('center_id, centers(name)')
          .ilike('email', email.trim());
      
      for (final mc in memberCenters as List<dynamic>) {
        final cId = mc['center_id'];
        final centersObj = mc['centers'];
        final String cName = (centersObj != null && centersObj['name'] != null) ? centersObj['name'] : 'مركز غير محدد';
        if (cId != null) {
          // Avoid duplicates
          if (!centersList.any((item) => item['id'] == cId)) {
            centersList.add({
              'id': cId,
              'name': cName,
              'role': 'teacher',
            });
          }
        }
      }

      return centersList;
    } catch (e) {
      AppLogger.error(e, source: 'supabase.centers.fetch');
      return [];
    }
  }

  // Fetch all halaqas in a center
  Future<List<Map<String, dynamic>>> fetchHalaqas(String centerId) async {
    try {
      final response = await client
          .from('halaqat')
          .select('id, name, teacher_name')
          .eq('center_id', centerId);
      
      return List<Map<String, dynamic>>.from(response as List<dynamic>);
    } catch (e) {
      AppLogger.error(e, source: 'supabase.halaqat.fetch');
      return [];
    }
  }

  // Create a new halaqah in Supabase
  Future<Map<String, dynamic>?> createHalaqah(String centerId, String name, String teacherName) async {
    try {
      final response = await client
          .from('halaqat')
          .insert({
            'center_id': centerId,
            'name': name,
            'teacher_name': teacherName,
          })
          .select()
          .single();
      
      return response as Map<String, dynamic>?;
    } catch (e) {
      AppLogger.error(e, source: 'supabase.halaqat.create');
      throw Exception('فشل إنشاء الحلقة: $e');
    }
  }

  // Helper utility to generate reproducible namespace UUID v5 from string
  String remoteUUID(String input) {
    // Return standard UUID or format matching standard v4 format for simple primary keys
    // We can use the first 36 characters of md5 hash formatted as UUID
    final bytes = utf8.encode(input);
    final digest = md5.convert(bytes);
    final hex = digest.toString();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  Future<void> _syncStudySuspensions(
    String centerId,
    String halaqahId,
    CloudSyncDirection direction,
  ) async {
    final deletedRaw = direction.shouldUpload
        ? await _db.getSetting('deleted_suspension_dates')
        : null;
    final pendingDeletedDates = _decodeSuspensionDeleteDates(deletedRaw);

    final localSuspensions = <String, String>{};
    if (direction.shouldUpload) {
      final reasons = await _db.getSuspensionReasons();
      for (final date in await _db.getSuspendedDates()) {
        final reason = reasons[date]?.trim();
        localSuspensions[date] =
            reason == null || reason.length < 3 ? 'إجازة عارضة' : reason;
      }

      // Upload-only can skip the cloud read entirely when nothing local has
      // changed since the last successful suspension upload.
      if (!direction.shouldDownload && pendingDeletedDates.isEmpty) {
        final fingerprint = _studySuspensionFingerprint(localSuspensions);
        final uploadedFingerprint =
            await _db.getSetting(_studySuspensionFingerprintKey);
        if (fingerprint == uploadedFingerprint) return;
      }
    }

    final remoteSuspensions = await _fetchRemoteStudySuspensions(
      centerId,
      halaqahId,
    );
    var mergedRemoteState = remoteSuspensions;

    if (direction.shouldUpload) {
      final syncPlan = StudySuspensionSyncPlan.create(
        local: localSuspensions,
        remote: remoteSuspensions,
        pendingDeletedDates: pendingDeletedDates,
      );

      for (final date in syncPlan.datesToRemove) {
        await _callIdempotentSyncRpc('set_study_suspension', {
          'p_center_id': centerId,
          'p_halaqa_id': halaqahId,
          'p_date': date,
          'p_suspended': false,
          'p_reason': null,
        });
      }
      if (pendingDeletedDates.isNotEmpty) {
        await _db.saveSetting('deleted_suspension_dates', '[]');
      }

      for (final entry in syncPlan.suspensionsToSet.entries) {
        await _callIdempotentSyncRpc('set_study_suspension', {
          'p_center_id': centerId,
          'p_halaqa_id': halaqahId,
          'p_date': entry.key,
          'p_suspended': true,
          'p_reason': entry.value,
        });
      }

      mergedRemoteState = syncPlan.mergedRemoteState;
      await _db.saveSetting(
        _studySuspensionFingerprintKey,
        _studySuspensionFingerprint(localSuspensions),
      );
    }

    if (!direction.shouldDownload) return;
    await _db.replaceStudySuspensions(mergedRemoteState);
    await _db.saveSetting(
      _studySuspensionFingerprintKey,
      _studySuspensionFingerprint(mergedRemoteState),
    );
  }

  Set<String> _decodeSuspensionDeleteDates(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toSet();
      }
    } catch (_) {
      // A malformed legacy marker must not block the rest of cloud sync.
    }
    return <String>{};
  }

  Future<Map<String, String>> _fetchRemoteStudySuspensions(
    String centerId,
    String halaqahId,
  ) async {
    final response = await (() async {
      return await client
          .from('study_suspensions')
          .select('date, reason')
          .eq('center_id', centerId)
          .eq('halaqa_id', halaqahId);
    })().timeout(
      _syncRpcTimeout,
      onTimeout: () => throw const CloudSyncUnavailableException(
        'انتهت مهلة الاتصال أثناء مزامنة الإجازات العارضة.',
      ),
    );

    final byDate = <String, String>{};
    for (final raw in response as List<dynamic>) {
      final row = Map<String, dynamic>.from(raw as Map);
      final date = row['date']?.toString();
      if (date == null || date.isEmpty) continue;
      final reason = row['reason']?.toString().trim();
      byDate[date] = reason == null || reason.length < 3
          ? 'إجازة عارضة'
          : reason;
    }
    return byDate;
  }

  Future<void> _syncMemorizationProgress(
    String centerId,
    String halaqahId,
    CloudSyncDirection direction,
  ) async {
    if (direction.shouldUpload) {
      await _syncDeletedRows(
        table: 'memorization',
        settingKey: 'deleted_memorization_progress_ids',
      );
    }

    final beforeResponse = await client
        .from('memorization')
        .select()
        .eq('center_id', centerId)
        .eq('halaqa_id', halaqahId);
    final beforeRows = _remoteMapRows(beforeResponse);
    final deletedIds = beforeRows
        .where((row) => row['deleted_at'] != null)
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final affectedStudents = <String>{};

    if (direction.shouldDownload) {
      for (final id in deletedIds) {
        final studentId = await _db.deleteMemorizationProgressFromSync(id);
        if (studentId != null) affectedStudents.add(studentId);
      }
    }

    // Upload-only recovery must not depend on decoding every historical cloud
    // memorization row. Older schemas allowed nullable range fields, and one
    // malformed legacy row previously aborted the whole upload with an
    // ArgumentError before the valid local backup could repair the cloud.
    final remoteUpdatedAtById = <String, DateTime>{};
    for (final row in beforeRows.where((row) => row['deleted_at'] == null)) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      remoteUpdatedAtById[id] = _remoteDateTimeOrEpoch(
        row['updated_at'] ?? row['created_at'],
      );
    }

    if (direction.shouldUpload) {
      final payload = <Map<String, dynamic>>[];
      for (final progress in await _db.getAllMemorizationProgress()) {
        if (deletedIds.contains(progress.id)) continue;
        final remoteUpdatedAt = remoteUpdatedAtById[progress.id];
        if (remoteUpdatedAt != null &&
            !progress.updatedAt.isAfter(remoteUpdatedAt)) {
          continue;
        }
        payload.add({
          'id': progress.id,
          'student_id': progress.studentId,
          'center_id': centerId,
          'halaqa_id': halaqahId,
          'surah': QuranService.instance.getSurahName(progress.surahId),
          'from_ayah': progress.fromAyah,
          'to_ayah': progress.toAyah,
          'degree': progress.qualityRating,
          'session_type': progress.isRevision ? 'review' : 'new',
          'date': progress.date.toIso8601String().split('T')[0],
          'notes': progress.notes,
          'created_at': progress.createdAt.toIso8601String(),
          'updated_at': progress.updatedAt.toIso8601String(),
        });
      }
      for (var i = 0; i < payload.length; i += 100) {
        final end = i + 100 > payload.length ? payload.length : i + 100;
        await client.from('memorization').upsert(payload.sublist(i, end));
      }
    }

    if (!direction.shouldDownload) return;

    final finalResponse = await client
        .from('memorization')
        .select()
        .eq('center_id', centerId)
        .eq('halaqa_id', halaqahId);
    var skippedMalformedRows = 0;
    for (final row in _remoteMapRows(finalResponse)) {
      if (row['deleted_at'] != null) {
        final id = row['id']?.toString() ?? '';
        if (id.isEmpty) {
          skippedMalformedRows++;
          continue;
        }
        final studentId = await _db.deleteMemorizationProgressFromSync(id);
        if (studentId != null) affectedStudents.add(studentId);
        continue;
      }
      try {
        final progress = _memorizationProgressFromRemote(row);
        await _db.upsertMemorizationProgressFromSync(progress);
        affectedStudents.add(progress.studentId);
      } on Object catch (error) {
        if (!_isMalformedRemoteMemorizationError(error)) rethrow;
        skippedMalformedRows++;
        AppLogger.warning(
          'remote_row_skipped:${error.runtimeType}',
          source: 'supabase.sync.memorization',
        );
      }
    }
    await _db.saveSetting(
      'last_cloud_memorization_skipped_count',
      skippedMalformedRows.toString(),
    );
    for (final studentId in affectedStudents) {
      await _mushaf.rebuildStudentProgress(studentId);
    }
  }

  List<Map<String, dynamic>> _remoteMapRows(dynamic response) {
    if (response is! List) return const <Map<String, dynamic>>[];
    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  bool _isMalformedRemoteMemorizationError(Object error) =>
      error is ArgumentError ||
      error is FormatException ||
      error is TypeError;

  DateTime _remoteDateTimeOrEpoch(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  int _requiredRemoteInt(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      throw FormatException('Invalid remote memorization field: $key');
    }
    return parsed;
  }

  DateTime _requiredRemoteDate(Map<String, dynamic> row, String key) {
    final parsed = DateTime.tryParse(row[key]?.toString() ?? '');
    if (parsed == null) {
      throw FormatException('Invalid remote memorization field: $key');
    }
    return parsed;
  }

  MemorizationProgress _memorizationProgressFromRemote(
    Map<String, dynamic> remote,
  ) {
    final id = remote['id']?.toString().trim() ?? '';
    final studentId = remote['student_id']?.toString().trim() ?? '';
    final surahName = remote['surah']?.toString().trim() ?? '';
    if (id.isEmpty || studentId.isEmpty || surahName.isEmpty) {
      throw const FormatException(
        'Remote memorization identity/range metadata is incomplete',
      );
    }

    final matchingSurahs = QuranService.instance.surahs.where(
      (item) => item.name.trim() == surahName,
    );
    if (matchingSurahs.isEmpty) {
      throw const FormatException('Unknown remote memorization surah');
    }

    final fromAyah = _requiredRemoteInt(remote, 'from_ayah');
    final toAyah = _requiredRemoteInt(remote, 'to_ayah');
    if (fromAyah < 1 || toAyah < fromAyah) {
      throw const FormatException('Invalid remote memorization ayah range');
    }

    final date = _requiredRemoteDate(remote, 'date');
    final createdAt = DateTime.tryParse(remote['created_at']?.toString() ?? '') ??
        date;
    final rawDegree = remote['degree'];
    final parsedDegree = rawDegree is num
        ? rawDegree.toInt()
        : int.tryParse(rawDegree?.toString() ?? '') ?? 3;
    final qualityRating = parsedDegree.clamp(1, 5).toInt();

    return MemorizationProgress(
      id: id,
      studentId: studentId,
      surahId: matchingSurahs.first.number,
      fromAyah: fromAyah,
      toAyah: toAyah,
      date: date,
      qualityRating: qualityRating,
      isRevision: remote['session_type'] == 'review',
      notes: remote['notes']?.toString(),
      createdAt: createdAt,
      updatedAt: DateTime.tryParse(remote['updated_at']?.toString() ?? '') ??
          createdAt,
    );
  }

  Future<void> _syncDeletedRows({
    required String table,
    required String settingKey,
  }) async {
    final raw = await _db.getSetting(settingKey);
    if (raw == null || raw.isEmpty) return;
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! List) return;
    final remaining = decoded.map((id) => id.toString()).toList();
    final acknowledged = <String>{};
    for (final chunk in _chunks(remaining, 80)) {
      try {
        await client.from(table).delete().inFilter('id', chunk);
        acknowledged.addAll(chunk);
      } catch (error) {
        AppLogger.error(error, source: 'supabase.sync.delete.$table');
      }
    }
    remaining.removeWhere(acknowledged.contains);
    await _db.saveSetting(settingKey, jsonEncode(remaining));
  }

  Future<void> _syncBehaviorPoints(
    String centerId,
    String halaqahId,
    CloudSyncDirection direction,
  ) async {
    if (direction.shouldUpload) {
      await _syncDeletedRows(
        table: 'points',
        settingKey: 'deleted_behavior_point_ids',
      );
      final localData = await _db.getAllBehaviorPoints();
      if (localData.isNotEmpty) {
        final payload = localData.map((e) => {
          'id': e.id,
          'student_id': e.studentId,
          'center_id': centerId,
          'halaqa_id': halaqahId,
          'type': e.type,
          'amount': e.points,
          'reason': e.reason,
          'date': e.date.toIso8601String().split('T')[0],
          'resolved': e.resolved,
          'resolved_date': e.resolvedDate?.toIso8601String(),
          'notes': e.notes,
          'created_at': e.createdAt.toIso8601String(),
        }).toList();
        for (var i = 0; i < payload.length; i += 100) {
          final end = i + 100 > payload.length ? payload.length : i + 100;
          try {
            await client.from('points').upsert(payload.sublist(i, end));
          } on PostgrestException catch (error) {
            if (_isMissingSchemaColumn(error)) {
              final compatible = payload.sublist(i, end).map((row) =>
                Map<String, dynamic>.from(row)
                  ..remove('resolved_date')
                  ..remove('notes')
                  ..remove('created_at')
              ).toList();
              await client.from('points').upsert(compatible);
            } else {
              rethrow;
            }
          } catch (error) {
            AppLogger.error(error, source: 'supabase.sync.points');
            rethrow;
          }
        }
      }
    }

    if (!direction.shouldDownload) return;
    try {
      final response = await client
          .from('points')
          .select()
          .eq('center_id', centerId)
          .eq('halaqa_id', halaqahId);
      final points = <BehaviorPoint>[];
      for (final dynamic raw in response as List<dynamic>) {
        final row = Map<String, dynamic>.from(raw as Map);
        final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
        points.add(
          BehaviorPoint(
            id: row['id'].toString(),
            studentId: row['student_id'].toString(),
            type: row['type']?.toString() ??
                (amount < 0 ? 'negative' : 'positive'),
            reason: row['reason']?.toString() ?? 'سجل سحابي',
            points: amount,
            date: DateTime.parse(row['date'].toString()),
            resolved: row['resolved'] == true || row['resolved'] == 1,
            resolvedDate: DateTime.tryParse(
              row['resolved_date']?.toString() ?? '',
            ),
            notes: row['notes']?.toString(),
            createdAt: DateTime.tryParse(
                  row['created_at']?.toString() ?? '',
                ) ??
                DateTime.parse(row['date'].toString()),
          ),
        );
      }
      await _db.upsertBehaviorPointsFromSync(points);
    } on PostgrestException catch (error) {
      if (_isMissingSchemaTable(error)) return;
      rethrow;
    }
  }

  Future<void> _syncBehaviorPointCorrections(
    String centerId,
    String halaqahId,
  ) async {
    final localData = await _db.getAllBehaviorPointCorrections();
    if (localData.isEmpty) return;
    final payload = localData
        .map((correction) => {
              'id': correction.id,
              'point_id': correction.pointId,
              'original_student_id': correction.originalStudentId,
              'corrected_student_id': correction.correctedStudentId,
              'center_id': centerId,
              'halaqa_id': halaqahId,
              'action': correction.action,
              'reason': correction.reason,
              'point_reason_snapshot': correction.pointReasonSnapshot,
              'points_snapshot': correction.pointsSnapshot,
              'created_at': correction.createdAt.toIso8601String(),
            })
        .toList();
    for (var i = 0; i < payload.length; i += 100) {
      final end = i + 100 > payload.length ? payload.length : i + 100;
      try {
        await client
            .from('behavior_point_corrections')
            .upsert(payload.sublist(i, end));
      } on PostgrestException catch (error) {
        if (_isMissingSchemaTable(error)) return;
        rethrow;
      } catch (error) {
        AppLogger.error(error, source: 'supabase.sync.behavior_corrections');
        rethrow;
      }
    }
  }

  Future<void> _syncDailyAchievements(
    String centerId,
    String halaqahId,
    CloudSyncDirection direction,
  ) async {
    if (direction.shouldUpload) {
      final localData = await _db.getAllDailyAchievements();
      if (localData.isNotEmpty) {
        final payload = localData
            .map((achievement) => {
                'id': achievement.id,
                'student_id': achievement.studentId,
                'center_id': centerId,
                'halaqa_id': halaqahId,
                'date': achievement.date.toIso8601String().split('T')[0],
                'source': achievement.source,
                'reason': achievement.reason,
                'actual_amount': achievement.actualAmount,
                'plan_amount': achievement.planAmount,
                'unit': achievement.unit,
                'reward_type': achievement.rewardType,
                'reward_details': achievement.rewardDetails,
                'reward_points': achievement.rewardPoints,
                'awarded_at': achievement.awardedAt?.toIso8601String(),
                'notes': achievement.notes,
                'created_at': achievement.createdAt.toIso8601String(),
                'updated_at': achievement.updatedAt.toIso8601String(),
                })
            .toList();
        try {
          // Every local achievement has a stable UUID. Upsert by primary key
          // so synchronization also works on older schemas that missed the
          // optional student/date UNIQUE index.
          await client.from('daily_achievements').upsert(payload);
        } on PostgrestException catch (error) {
          if (_isMissingSchemaTable(error)) return;
          rethrow;
        }
      }
    }

    if (!direction.shouldDownload) return;
    try {
      final remoteRows = await client
          .from('daily_achievements')
          .select('*')
          .eq('center_id', centerId)
          .eq('halaqa_id', halaqahId);
      final achievements = List<Map<String, dynamic>>.from(remoteRows)
          .map(
            (remote) => DailyAchievement(
              id: remote['id'],
              studentId: remote['student_id'],
              date: DateTime.parse(remote['date']),
              source: remote['source'] ?? 'manual',
              reason: remote['reason'] ?? 'تميز يومي',
              actualAmount:
                  (remote['actual_amount'] as num?)?.toDouble() ?? 0,
              planAmount: (remote['plan_amount'] as num?)?.toDouble() ?? 0,
              unit: remote['unit'] ?? 'ayahs',
              rewardType: remote['reward_type'],
              rewardDetails: remote['reward_details'],
              rewardPoints: (remote['reward_points'] as num?)?.toInt() ?? 0,
              awardedAt: DateTime.tryParse(
                remote['awarded_at']?.toString() ?? '',
              ),
              notes: remote['notes'],
              createdAt: DateTime.tryParse(
                    remote['created_at']?.toString() ?? '',
                  ) ??
                  DateTime.now(),
              updatedAt: DateTime.tryParse(
                    remote['updated_at']?.toString() ?? '',
                  ) ??
                  DateTime.now(),
            ),
          )
          .toList(growable: false);
      await _db.upsertDailyAchievementsFromSync(achievements);
    } on PostgrestException catch (error) {
      if (_isMissingSchemaTable(error)) return;
      rethrow;
    }
  }

  Future<void> _syncVacations(
    String centerId,
    String halaqahId,
    CloudSyncDirection direction,
  ) async {
    if (direction.shouldUpload) {
      await _syncDeletedRows(
        table: 'vacations',
        settingKey: 'deleted_vacation_ids',
      );
      final localData = await _db.getAllVacations();
      final payload = localData.map((vacation) => {
        'id': vacation.id,
        'student_id': vacation.studentId,
        'center_id': centerId,
        'halaqa_id': halaqahId,
        'start_date': vacation.startDate.toIso8601String().split('T')[0],
        'end_date': vacation.endDate.toIso8601String().split('T')[0],
        'reason': vacation.reason,
        'notes': vacation.notes,
        'approved': vacation.approved,
        'created_at': vacation.createdAt.toIso8601String(),
      }).toList();
      for (var i = 0; i < payload.length; i += 100) {
        final chunk = payload.sublist(
          i,
          i + 100 > payload.length ? payload.length : i + 100,
        );
        try {
          await client.from('vacations').upsert(chunk);
        } on PostgrestException catch (error) {
          if (_isMissingSchemaTable(error)) return;
          if (!_isMissingSchemaColumn(error)) rethrow;
          final compatible = chunk.map((row) {
            final copy = Map<String, dynamic>.from(row)..remove('halaqa_id');
            final reason = copy['reason']?.toString() ?? '';
            final notes = copy.remove('notes')?.toString().trim();
            if (notes != null && notes.isNotEmpty) {
              copy['reason'] = '$reason - $notes';
            }
            return copy;
          }).toList();
          await client.from('vacations').upsert(compatible);
        }
      }
    }

    if (!direction.shouldDownload) return;
    final scopedStudentIds = await _fetchHalaqahStudentIds(halaqahId);
    if (scopedStudentIds.isEmpty) return;
    try {
      final response = await client
          .from('vacations')
          .select()
          .eq('center_id', centerId);
      final vacations = <Vacation>[];
      for (final dynamic raw in response as List<dynamic>) {
        final row = Map<String, dynamic>.from(raw as Map);
        final studentId = row['student_id']?.toString();
        if (studentId == null || !scopedStudentIds.contains(studentId)) continue;
        vacations.add(
          Vacation(
            id: row['id']?.toString(),
            studentId: studentId,
            startDate: DateTime.parse(row['start_date'].toString()),
            endDate: DateTime.parse(row['end_date'].toString()),
            reason: row['reason']?.toString() ?? VacationReason.other,
            approved: row['approved'] == true || row['approved'] == 1,
            notes: row['notes']?.toString(),
            createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                DateTime.now(),
          ),
        );
      }
      await _db.upsertVacationsFromSync(vacations);
    } on PostgrestException catch (error) {
      if (_isMissingSchemaTable(error)) return;
      rethrow;
    }
  }

  Future<void> _syncStudentHolds(
    String centerId,
    String halaqahId,
    CloudSyncDirection direction,
  ) async {
    if (direction.shouldUpload) {
      final holds = await _db.getAllStudentHolds();
      final payload = holds.map((hold) => {
        'id': hold.id,
        'student_id': hold.studentId,
        'center_id': centerId,
        'halaqa_id': halaqahId,
        'start_date': hold.startDate.toIso8601String().split('T')[0],
        'end_date': hold.endDate.toIso8601String().split('T')[0],
        'reason': hold.reason,
        'scope': hold.scope,
        'notes': hold.notes,
        'ended_at': hold.endedAt?.toIso8601String(),
        'created_at': hold.createdAt.toIso8601String(),
      }).toList();
      for (var i = 0; i < payload.length; i += 100) {
        final chunk = payload.sublist(
          i,
          i + 100 > payload.length ? payload.length : i + 100,
        );
        try {
          await client.from('student_holds').upsert(chunk);
        } on PostgrestException catch (error) {
          if (_isMissingSchemaTable(error)) {
            AppLogger.warning('student_holds_schema_missing', source: 'supabase.sync.student_holds');
            return;
          }
          if (!_isMissingSchemaColumn(error)) rethrow;
          final compatibleChunk = chunk
              .map((row) => Map<String, dynamic>.from(row)..remove('scope'))
              .toList();
          try {
            await client.from('student_holds').upsert(compatibleChunk);
          } on PostgrestException catch (fallbackError) {
            if (_isMissingSchemaTable(fallbackError)) {
              AppLogger.warning('student_holds_schema_missing', source: 'supabase.sync.student_holds');
              return;
            }
            rethrow;
          }
        }
      }
    }

    if (!direction.shouldDownload) return;
    final scopedStudentIds = await _fetchHalaqahStudentIds(halaqahId);
    if (scopedStudentIds.isEmpty) return;
    try {
      final response = await client
          .from('student_holds')
          .select()
          .eq('center_id', centerId);
      for (final dynamic raw in response as List<dynamic>) {
        final row = Map<String, dynamic>.from(raw as Map);
        if (!scopedStudentIds.contains(row['student_id']?.toString())) continue;
        try {
          await _db.saveStudentHold(StudentHold.fromMap(row));
        } on StateError {
          // Preserve a conflicting local hold for explicit user resolution.
        }
      }
    } on PostgrestException catch (error) {
      if (_isMissingSchemaTable(error)) return;
      rethrow;
    }
  }

  Future<void> _syncTalaqqinRecords(
    String centerId,
    String halaqahId,
    CloudSyncDirection direction,
  ) async {
    if (direction.shouldUpload) {
      final records = await _db.getAllTalaqqinRecords();
      final payload = records.map((record) => {
        'id': record.id,
        'session_id': record.sessionId,
        'student_id': record.studentId,
        'center_id': centerId,
        'halaqa_id': halaqahId,
        'surah_id': record.surahId,
        'from_ayah': record.fromAyah,
        'to_ayah': record.toAyah,
        'date': record.date.toIso8601String().split('T').first,
        'notes': record.notes,
        'created_at': record.createdAt.toIso8601String(),
      }).toList();
      for (var i = 0; i < payload.length; i += 100) {
        final chunk = payload.sublist(
          i,
          i + 100 > payload.length ? payload.length : i + 100,
        );
        try {
          await client.from('talaqqin_records').upsert(chunk);
        } on PostgrestException catch (error) {
          if (error.code == '42P01' || error.code == 'PGRST205') {
            AppLogger.warning('talaqqin_schema_missing', source: 'supabase.sync.talaqqin');
            return;
          }
          rethrow;
        }
      }
    }

    if (!direction.shouldDownload) return;
    final scopedStudentIds = await _fetchHalaqahStudentIds(halaqahId);
    if (scopedStudentIds.isEmpty) return;
    try {
      final response = await client
          .from('talaqqin_records')
          .select()
          .eq('center_id', centerId);
      final records = <TalaqqinRecord>[];
      for (final dynamic raw in response as List<dynamic>) {
        final row = Map<String, dynamic>.from(raw as Map);
        if (!scopedStudentIds.contains(row['student_id']?.toString())) continue;
        records.add(TalaqqinRecord.fromMap(row));
      }
      await _db.upsertTalaqqinRecordsFromSync(records);
    } on PostgrestException catch (error) {
      if (error.code == '42P01' || error.code == 'PGRST205') return;
      rethrow;
    }
  }

  Future<void> _syncStudentAdminActions(
    String centerId,
    String halaqahId,
    CloudSyncDirection direction,
  ) async {
    if (direction.shouldUpload) {
      final actions = await _db.getAllStudentAdminActions();
      final payload = actions.map((action) => {
        'id': action.id,
        'student_id': action.studentId,
        'center_id': centerId,
        'halaqa_id': halaqahId,
        'action_type': action.actionType,
        'date': action.date.toIso8601String().split('T').first,
        'details': action.details,
        'follow_up': action.followUp,
        'resolved': action.resolved,
        'created_at': action.createdAt.toIso8601String(),
        'updated_at': action.updatedAt.toIso8601String(),
      }).toList();
      for (var i = 0; i < payload.length; i += 100) {
        final chunk = payload.sublist(
          i,
          i + 100 > payload.length ? payload.length : i + 100,
        );
        try {
          await client.from('student_admin_actions').upsert(chunk);
        } on PostgrestException catch (error) {
          if (error.code == '42P01' || error.code == 'PGRST205') {
            AppLogger.warning('admin_actions_schema_missing', source: 'supabase.sync.admin_actions');
            return;
          }
          rethrow;
        }
      }
    }

    if (!direction.shouldDownload) return;
    final scopedStudentIds = await _fetchHalaqahStudentIds(halaqahId);
    if (scopedStudentIds.isEmpty) return;
    try {
      final response = await client
          .from('student_admin_actions')
          .select()
          .eq('center_id', centerId);
      final actions = <StudentAdminAction>[];
      for (final dynamic raw in response as List<dynamic>) {
        final row = Map<String, dynamic>.from(raw as Map);
        if (!scopedStudentIds.contains(row['student_id']?.toString())) continue;
        actions.add(StudentAdminAction.fromMap(row));
      }
      await _db.upsertStudentAdminActionsFromSync(actions);
    } on PostgrestException catch (error) {
      if (error.code == '42P01' || error.code == 'PGRST205') return;
      rethrow;
    }
  }

  Future<void> _syncDeletedExams() async {
    final raw = await _db.getSetting('deleted_exam_ids');
    if (raw == null || raw.isEmpty) return;
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! List) return;
    final remaining = decoded.map((id) => id.toString()).toList();
    final acknowledged = <String>{};
    for (final chunk in _chunks(remaining, 80)) {
      try {
        await client.from('exam_scores').delete().inFilter('exam_id', chunk);
        await client.from('exams').delete().inFilter('id', chunk);
        acknowledged.addAll(chunk);
      } catch (error) {
        AppLogger.error(error, source: 'supabase.sync.exams.delete');
      }
    }
    remaining.removeWhere(acknowledged.contains);
    await _db.saveSetting('deleted_exam_ids', jsonEncode(remaining));
  }

  Future<void> _syncExams(
    String centerId,
    String halaqahId,
    CloudSyncDirection direction,
  ) async {
    if (direction.shouldUpload) {
      await _syncDeletedExams();
      final localData = await _db.getAllExams();
      final activeTemplateIds = (await _db.getExamTemplates())
          .map((template) => template.id)
          .toSet();

      final examsPayload = localData.map((exam) => {
        'id': exam.id,
        'center_id': centerId,
        'halaqa_id': halaqahId,
        'title': 'اختبار ${ExamType.getLabel(exam.type)}',
        'date': exam.date.toIso8601String().split('T')[0],
        'type': exam.type,
        'template_id': ExamSyncPolicy.cloudTemplateId(
          exam.templateId,
          activeTemplateIds,
        ),
        'max_degree': 100,
        'from_surah': exam.fromSurah,
        'to_surah': exam.toSurah,
        'from_ayah': exam.fromAyah,
        'to_ayah': exam.toAyah,
        'created_at': exam.createdAt.toIso8601String(),
      }).toList();

      final scoresPayload = localData.map((exam) => {
        'id': exam.id,
        'exam_id': exam.id,
        'student_id': exam.studentId,
        'degree': exam.score,
        'notes': exam.notes,
        'created_at': exam.createdAt.toIso8601String(),
      }).toList();

      for (var i = 0; i < examsPayload.length; i += 100) {
        final end = i + 100 > examsPayload.length ? examsPayload.length : i + 100;
        final chunkExams = examsPayload.sublist(i, end);
        final chunkScores = scoresPayload.sublist(i, end);
        try {
          await client.from('exams').upsert(chunkExams);
        } on PostgrestException catch (error) {
          if (_isMissingSchemaTable(error)) return;
          if (!_isMissingSchemaColumn(error)) rethrow;
          final compatible = chunkExams.map((row) {
            final copy = Map<String, dynamic>.from(row);
            copy.remove('halaqa_id');
            copy.remove('template_id');
            copy.remove('from_surah');
            copy.remove('to_surah');
            copy.remove('from_ayah');
            copy.remove('to_ayah');
            return copy;
          }).toList();
          await client.from('exams').upsert(compatible);
        }
        try {
          await client.from('exam_scores').upsert(chunkScores);
        } on PostgrestException catch (error) {
          if (_isMissingSchemaTable(error)) return;
          rethrow;
        }
      }
    }

    if (!direction.shouldDownload) return;
    final scopedStudentIds = await _fetchHalaqahStudentIds(halaqahId);
    if (scopedStudentIds.isEmpty) return;
    try {
      final results = await Future.wait<dynamic>([
        client.from('exams').select().eq('center_id', centerId),
        client.from('exam_scores').select(),
      ]);
      final examsById = <String, Map<String, dynamic>>{
        for (final dynamic raw in results[0] as List<dynamic>)
          (raw as Map)['id'].toString(): Map<String, dynamic>.from(raw),
      };
      final exams = <Exam>[];
      for (final dynamic raw in results[1] as List<dynamic>) {
        final scoreRow = Map<String, dynamic>.from(raw as Map);
        final studentId = scoreRow['student_id']?.toString();
        if (studentId == null || !scopedStudentIds.contains(studentId)) continue;
        final examRow = examsById[scoreRow['exam_id']?.toString()];
        if (examRow == null) continue;
        final fromSurah = (examRow['from_surah'] as num?)?.toInt() ?? 1;
        final toSurah = (examRow['to_surah'] as num?)?.toInt() ?? fromSurah;
        exams.add(
          Exam(
            id: scoreRow['id']?.toString() ?? examRow['id'].toString(),
            studentId: studentId,
            date: DateTime.parse(examRow['date'].toString()),
            type: examRow['type']?.toString() ?? ExamType.oral,
            templateId: examRow['template_id']?.toString(),
            fromSurah: fromSurah,
            toSurah: toSurah,
            fromAyah: (examRow['from_ayah'] as num?)?.toInt(),
            toAyah: (examRow['to_ayah'] as num?)?.toInt(),
            score: (scoreRow['degree'] as num?)?.toInt() ?? 0,
            notes: scoreRow['notes']?.toString(),
            createdAt: DateTime.tryParse(
                  scoreRow['created_at']?.toString() ??
                      examRow['created_at']?.toString() ??
                      '',
                ) ??
                DateTime.now(),
          ),
        );
      }
      await _db.upsertExamsFromSync(exams);
    } on PostgrestException catch (error) {
      if (_isMissingSchemaTable(error)) return;
      rethrow;
    }
  }

  Future<void> _syncExamTemplates(
    String centerId,
    String halaqahId,
    CloudSyncDirection direction,
  ) async {
    if (direction.shouldUpload) {
      final templates = await _db.getExamTemplates();
      for (var i = 0; i < templates.length; i += 100) {
        final chunk = templates.sublist(
          i,
          i + 100 > templates.length ? templates.length : i + 100,
        );
        final payload = chunk.map((template) => {
          'id': template.id,
          'center_id': centerId,
          'halaqa_id': halaqahId,
          'student_id': template.studentId,
          'title': template.title,
          'type': 'custom',
          'category': template.category,
          'criteria_json': _decodeJsonObject(template.criteriaJson),
          'questions_count': template.questionsCount,
          'created_at': template.createdAt.toIso8601String(),
          'updated_at': template.updatedAt.toIso8601String(),
        }).toList();
        try {
          await client.from('exam_templates').upsert(payload);
        } on PostgrestException catch (error) {
          if (_isMissingSchemaTable(error)) return;
          rethrow;
        }

        for (final template in chunk) {
          final questions = await _db.getExamTemplateQuestions(template.id);
          try {
            await client
                .from('exam_questions')
                .delete()
                .eq('template_id', template.id);
          } on PostgrestException catch (error) {
            if (_isMissingSchemaTable(error)) return;
            rethrow;
          }
          if (questions.isEmpty) continue;
          final questionsPayload = questions.map((question) => {
            'id': question.id,
            'template_id': template.id,
            'question_order': question.questionOrder,
            'surah': question.surahId,
            'to_surah': question.toSurahId,
            'from_ayah': question.fromAyah,
            'to_ayah': question.toAyah,
            'question_type': question.questionType,
            'prompt_text': question.promptText,
            'answer_text': question.answerText,
            'page': question.page,
            'juz': question.juz,
            'hizb': question.hizb,
            'difficulty': question.difficulty,
            'lines': question.lines,
            'is_assessed': question.isAssessed,
            'memorization_errors': question.memorizationErrors,
            'tashkeel_errors': question.tashkeelErrors,
            'recitation_errors': question.recitationErrors,
            'prompt_count': question.promptCount,
            'question_score': question.questionScore,
            'created_at': question.createdAt.toIso8601String(),
          }).toList();
          try {
            await client.from('exam_questions').upsert(questionsPayload);
          } on PostgrestException catch (error) {
            if (_isMissingSchemaTable(error)) return;
            rethrow;
          }
        }
      }
    }

    if (!direction.shouldDownload) return;
    try {
      final remoteTemplates = await client
          .from('exam_templates')
          .select()
          .eq('center_id', centerId)
          .eq('halaqa_id', halaqahId);
      for (final dynamic raw in remoteTemplates as List<dynamic>) {
        final row = Map<String, dynamic>.from(raw as Map);
        final templateId = row['id']?.toString();
        final studentId = row['student_id']?.toString();
        if (templateId == null || studentId == null) continue;
        final template = ExamTemplate(
          id: templateId,
          studentId: studentId,
          title: row['title']?.toString() ?? 'نموذج اختبار',
          category: row['category']?.toString() ?? 'custom',
          criteriaJson: jsonEncode(row['criteria_json'] ?? const <String, dynamic>{}),
          questionsCount: (row['questions_count'] as num?)?.toInt() ?? 0,
          createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
              DateTime.now(),
          updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
              DateTime.now(),
        );
        final remoteQuestions = await client
            .from('exam_questions')
            .select()
            .eq('template_id', templateId)
            .order('question_order');
        final questions = <ExamTemplateQuestion>[];
        for (final dynamic rawQuestion in remoteQuestions as List<dynamic>) {
          final question = Map<String, dynamic>.from(rawQuestion as Map);
          questions.add(
            ExamTemplateQuestion(
              id: question['id']?.toString(),
              templateId: templateId,
              questionOrder: (question['question_order'] as num?)?.toInt() ?? 0,
              surahId: (question['surah'] as num?)?.toInt() ?? 1,
              toSurahId: (question['to_surah'] as num?)?.toInt(),
              fromAyah: (question['from_ayah'] as num?)?.toInt() ?? 1,
              toAyah: (question['to_ayah'] as num?)?.toInt() ?? 1,
              questionType: question['question_type']?.toString() ?? 'recite_from',
              promptText: question['prompt_text']?.toString() ?? '',
              answerText: question['answer_text']?.toString() ?? '',
              page: (question['page'] as num?)?.toInt() ?? 0,
              juz: (question['juz'] as num?)?.toInt() ?? 0,
              hizb: (question['hizb'] as num?)?.toInt() ?? 0,
              difficulty: (question['difficulty'] as num?)?.toInt() ?? 0,
              lines: (question['lines'] as num?)?.toDouble() ?? 0,
              isAssessed: question['is_assessed'] == true ||
                  question['is_assessed'] == 1,
              memorizationErrors:
                  (question['memorization_errors'] as num?)?.toInt() ?? 0,
              tashkeelErrors:
                  (question['tashkeel_errors'] as num?)?.toInt() ?? 0,
              recitationErrors:
                  (question['recitation_errors'] as num?)?.toInt() ?? 0,
              promptCount: (question['prompt_count'] as num?)?.toInt() ?? 0,
              questionScore:
                  (question['question_score'] as num?)?.toDouble() ?? 0,
              createdAt:
                  DateTime.tryParse(question['created_at']?.toString() ?? '') ??
                      template.createdAt,
            ),
          );
        }
        await _db.saveExamTemplate(template, questions);
      }
    } on PostgrestException catch (error) {
      if (_isMissingSchemaTable(error)) return;
      rethrow;
    }
  }

  Future<void> _syncDeletedExamTemplates() async {
    final raw = await _db.getSetting('deleted_exam_template_ids');
    if (raw == null || raw.isEmpty) return;
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! List) return;
    final remaining = decoded.map((id) => id.toString()).toList();
    final acknowledged = <String>{};
    for (final chunk in _chunks(remaining, 80)) {
      try {
        await client
            .from('exam_questions')
            .delete()
            .inFilter('template_id', chunk);
        await client.from('exam_templates').delete().inFilter('id', chunk);
        acknowledged.addAll(chunk);
      } catch (error) {
        AppLogger.error(
          error,
          source: 'supabase.sync.exam_templates.delete',
        );
      }
    }
    remaining.removeWhere(acknowledged.contains);
    await _db.saveSetting(
      'deleted_exam_template_ids',
      jsonEncode(remaining),
    );
  }

  Map<String, dynamic> _decodeJsonObject(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _syncFundTransactions(
    String centerId,
    String halaqahId,
    CloudSyncDirection direction,
  ) async {
    if (direction.shouldUpload) {
      final localData = await _db.getFundTransactions();
      final payload = localData.map((e) => {
        'id': e.id,
        'center_id': centerId,
        'halaqa_id': halaqahId,
        'student_id': e.studentId,
        'behavior_point_id': e.behaviorPointId,
        'settled_negative_points': e.settledNegativePoints,
        'type': e.type,
        'amount': e.amount,
        'note': e.note,
        'date': e.date.toIso8601String().split('T')[0],
        'created_at': e.createdAt.toIso8601String(),
      }).toList();
      for (var i = 0; i < payload.length; i += 100) {
        final end = i + 100 > payload.length ? payload.length : i + 100;
        final chunk = payload.sublist(i, end);
        try {
          await client.from('fund_transactions').upsert(chunk);
        } on PostgrestException catch (error) {
          if ((error.code == 'PGRST204' || error.code == '42703') &&
              [error.message, error.details, error.hint]
                  .whereType<Object>()
                  .join(' ')
                  .contains(RegExp('behavior_point_id|settled_negative_points|created_at'))) {
            final compatible = chunk
                .map((row) => Map<String, dynamic>.from(row)
                  ..remove('behavior_point_id')
                  ..remove('settled_negative_points')
                  ..remove('created_at'))
                .toList();
            await client.from('fund_transactions').upsert(compatible);
          } else {
            rethrow;
          }
        } catch (error) {
          AppLogger.error(error, source: 'supabase.sync.fund');
          rethrow;
        }
      }
    }

    if (!direction.shouldDownload) return;
    final scopedStudentIds = await _fetchHalaqahStudentIds(halaqahId);
    try {
      final response = await client
          .from('fund_transactions')
          .select()
          .eq('center_id', centerId);
      final transactions = <FundTransaction>[];
      for (final dynamic raw in response as List<dynamic>) {
        final row = Map<String, dynamic>.from(raw as Map);
        final studentId = row['student_id']?.toString();
        if (studentId != null && !scopedStudentIds.contains(studentId)) {
          continue;
        }
        transactions.add(
          FundTransaction(
            id: row['id'].toString(),
            studentId: studentId,
            behaviorPointId: row['behavior_point_id']?.toString(),
            settledNegativePoints:
                (row['settled_negative_points'] as num?)?.toInt() ?? 0,
            type: row['type']?.toString() ?? 'donation',
            amount: (row['amount'] as num?)?.toDouble() ?? 0,
            note: row['note']?.toString(),
            date: DateTime.parse(row['date'].toString()),
            createdAt: DateTime.tryParse(
                  row['created_at']?.toString() ?? '',
                ) ??
                DateTime.parse(row['date'].toString()),
          ),
        );
      }
      await _db.upsertFundTransactionsFromSync(transactions);
    } on PostgrestException catch (error) {
      if (_isMissingSchemaTable(error)) return;
      rethrow;
    }
  }

  Future<void> _syncPlans(
    String centerId,
    String halaqahId,
    CloudSyncDirection direction,
  ) async {
    if (direction.shouldUpload) {
      await _syncDeletedRows(
        table: 'plans',
        settingKey: 'deleted_plan_ids',
      );
    }
    final localData = await _db.getSmartPlans();
    final response = await client
        .from('plans')
        .select()
        .eq('center_id', centerId);
    final remoteRows = (response as List<dynamic>)
        .map((row) => row as Map<String, dynamic>)
        .toList();
    final scopedStudentIds = await _fetchHalaqahStudentIds(halaqahId);
    final scopedRemoteRows = remoteRows
        .where(
          (row) => scopedStudentIds.contains(row['student_id']?.toString()),
        )
        .toList();
    final remoteById = {
      for (final row in scopedRemoteRows) row['id'].toString(): row,
    };
    if (direction.shouldUpload) {
      final payload = localData.where((plan) {
        final remote = remoteById[plan.id];
        if (remote == null) return true;
        final remoteUpdated = DateTime.tryParse(
          remote['updated_at']?.toString() ?? '',
        );
        return remoteUpdated == null || plan.updatedAt.isAfter(remoteUpdated);
      }).map((e) => {
            'id': e.id,
            'center_id': centerId,
            'halaqa_id': halaqahId,
            'student_id': e.studentId,
            'period': e.period,
            'start_date': e.startDate.toIso8601String().split('T')[0],
            'end_date': e.endDate.toIso8601String().split('T')[0],
            'unit': e.unit,
            'review_unit': e.reviewUnit,
            'new_amount': e.newAmount,
            'review_amount': e.reviewAmount,
            'recitation_amount': e.recitationAmount,
            'friday_mode': e.fridayMode,
            'status': e.status,
            'test_status': e.testStatus,
            'completion_exam_id': e.completionExamId,
            'completed_at': e.completedAt?.toIso8601String(),
            'notes': e.notes,
            'created_at': e.createdAt.toIso8601String(),
            'updated_at': e.updatedAt.toIso8601String(),
          }).toList();
      for (var i = 0; i < payload.length; i += 100) {
        final chunk = payload.sublist(
          i,
          i + 100 > payload.length ? payload.length : i + 100,
        );
        try {
          await client.from('plans').upsert(chunk);
        } on PostgrestException catch (error) {
          final details = [error.message, error.details, error.hint]
              .whereType<Object>()
              .join(' ');
          if (error.code == 'PGRST204' || error.code == '42703') {
            final compatible = chunk
                .map((row) => Map<String, dynamic>.from(row))
                .toList();
            var changed = false;
            for (final optional in const ['review_unit', 'recitation_amount', 'friday_mode']) {
              if (details.contains(optional)) {
                for (final row in compatible) {
                  row.remove(optional);
                }
                changed = true;
              }
            }
            if (changed) {
              await client.from('plans').upsert(compatible);
            } else {
              rethrow;
            }
          } else {
            rethrow;
          }
        } catch (error) {
          AppLogger.error(error, source: 'supabase.sync.plans');
          rethrow;
        }
      }
    }

    if (!direction.shouldDownload) return;
    final localById = {for (final plan in localData) plan.id: plan};
    for (final remote in scopedRemoteRows) {
      final createdAt = DateTime.tryParse(
            remote['created_at']?.toString() ?? '',
          ) ??
          DateTime.now();
      final updatedAt = DateTime.tryParse(
            remote['updated_at']?.toString() ?? '',
          ) ??
          createdAt;
      final existing = localById[remote['id']];
      if (existing != null && !updatedAt.isAfter(existing.updatedAt)) continue;
      if (remote['deleted_at'] != null) {
        await _db.deleteSmartPlanFromSync(remote['id']);
        continue;
      }
      await _db.upsertSmartPlanFromSync(
        SmartPlan(
          id: remote['id'],
          studentId: remote['student_id'],
          period: remote['period'] ?? 'weekly',
          startDate: DateTime.parse(remote['start_date']),
          endDate: DateTime.parse(remote['end_date']),
          unit: remote['unit'] ?? 'ayahs',
          reviewUnit: remote['review_unit'] ?? remote['unit'] ?? 'ayahs',
          newAmount: (remote['new_amount'] as num?)?.toInt() ?? 5,
          reviewAmount: (remote['review_amount'] as num?)?.toInt() ?? 10,
          recitationAmount:
              (remote['recitation_amount'] as num?)?.toInt() ?? 1,
          fridayMode: const {'catchup_recitation', 'full_plan', 'holiday'}
                  .contains(remote['friday_mode'])
              ? remote['friday_mode']
              : 'catchup_recitation',
          status: remote['status'] ?? 'active',
          testStatus: remote['test_status'] ?? 'not_required',
          completionExamId: remote['completion_exam_id'],
          completedAt: DateTime.tryParse(
            remote['completed_at']?.toString() ?? '',
          ),
          notes: remote['notes'],
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      );
    }
  }

  Future<void> _syncQuranCourses(
    String centerId,
    String halaqahId,
    CloudSyncDirection direction,
  ) async {
    try {
      if (direction.shouldUpload) {
        await _syncDeletedRows(
          table: 'quran_course_enrollments',
          settingKey: 'deleted_quran_course_enrollment_ids',
        );
        await _syncDeletedRows(
          table: 'quran_courses',
          settingKey: 'deleted_quran_course_ids',
        );

        final courses = await _db.getQuranCourses();
        if (courses.isNotEmpty) {
          final payload = courses.map((course) => {
                'id': course.id,
                'center_id': centerId,
                'halaqa_id': halaqahId,
                'title': course.title,
                'type': course.type,
                'start_date': course.startDate.toIso8601String().split('T').first,
                'end_date': course.endDate.toIso8601String().split('T').first,
                'memorization_unit': course.memorizationUnit,
                'memorization_amount': course.memorizationAmount,
                'revision_unit': course.revisionUnit,
                'revision_amount': course.revisionAmount,
                'study_weekdays': course.studyWeekdays,
                'status': course.status,
                'notes': course.notes,
                'created_at': course.createdAt.toIso8601String(),
                'updated_at': course.updatedAt.toIso8601String(),
              }).toList();
          for (var index = 0; index < payload.length; index += 100) {
            await client.from('quran_courses').upsert(
                  payload.sublist(
                    index,
                    (index + 100).clamp(0, payload.length).toInt(),
                  ),
                );
          }
        }

        final enrollments = await _db.getAllQuranCourseEnrollments();
        if (enrollments.isNotEmpty) {
          final payload = enrollments.map((item) => {
                'id': item.id,
                'course_id': item.courseId,
                'student_id': item.studentId,
                'center_id': centerId,
                'halaqa_id': halaqahId,
                'enrolled_at': item.enrolledAt.toIso8601String(),
                'status': item.status,
                'notes': item.notes,
                'created_at': item.createdAt.toIso8601String(),
                'updated_at': item.updatedAt.toIso8601String(),
              }).toList();
          for (var index = 0; index < payload.length; index += 100) {
            await client.from('quran_course_enrollments').upsert(
                  payload.sublist(
                    index,
                    (index + 100).clamp(0, payload.length).toInt(),
                  ),
                );
          }
        }
      }

      if (!direction.shouldDownload) return;
      final courseResponse = await client
          .from('quran_courses')
          .select()
          .eq('center_id', centerId)
          .eq('halaqa_id', halaqahId);
      final remoteCourses = (courseResponse as List<dynamic>)
          .map((raw) => QuranCourse.fromMap(
                Map<String, dynamic>.from(raw as Map),
              ))
          .toList();
      await _db.upsertQuranCoursesFromSync(remoteCourses);

      final enrollmentResponse = await client
          .from('quran_course_enrollments')
          .select()
          .eq('center_id', centerId)
          .eq('halaqa_id', halaqahId);
      final remoteEnrollments = (enrollmentResponse as List<dynamic>)
          .map((raw) => QuranCourseEnrollment.fromMap(
                Map<String, dynamic>.from(raw as Map),
              ))
          .toList();
      await _db.upsertQuranCourseEnrollmentsFromSync(remoteEnrollments);
    } on PostgrestException catch (error) {
      if (error.code == '42P01' || error.code == 'PGRST205') {
        // P1.24 migration has not been applied yet. Local courses keep working.
        return;
      }
      rethrow;
    }
  }

  Future<void> _syncPlanRecitationRecords(
    String centerId,
    String halaqahId,
    CloudSyncDirection direction,
  ) async {
    await QuranService.instance.initialize();
    if (direction.shouldUpload) {
      await _syncDeletedRows(
        table: 'plan_recitation_records',
        settingKey: 'deleted_plan_recitation_record_ids',
      );
    }

    final local = await _db.getAllPlanRecitationRecords();
    final beforeResponse = await client
        .from('plan_recitation_records')
        .select()
        .eq('center_id', centerId)
        .eq('halaqa_id', halaqahId);
    final beforeRows = List<Map<String, dynamic>>.from(
      beforeResponse as List<dynamic>,
    );
    final remoteById = {
      for (final row in beforeRows) row['id'].toString(): row,
    };

    if (direction.shouldUpload) {
      final payload = local.where((record) {
        final remote = remoteById[record.id];
        if (remote == null) return true;
        final remoteUpdated = DateTime.tryParse(
          remote['updated_at']?.toString() ?? '',
        );
        return remoteUpdated == null || record.updatedAt.isAfter(remoteUpdated);
      }).map((record) => {
            'id': record.id,
            'session_id': record.sessionId,
            'center_id': centerId,
            'halaqa_id': halaqahId,
            'plan_id': record.planId,
            'student_id': record.studentId,
            'surah_id': record.surahId,
            'from_ayah': record.fromAyah,
            'to_ayah': record.toAyah,
            'segment_order': record.segmentOrder,
            'date': record.date.toIso8601String().split('T')[0],
            'quality_rating': record.qualityRating,
            'notes': record.notes,
            'created_at': record.createdAt.toIso8601String(),
            'updated_at': record.updatedAt.toIso8601String(),
          }).toList();
      for (var index = 0; index < payload.length; index += 100) {
        final end = index + 100 > payload.length ? payload.length : index + 100;
        await client
            .from('plan_recitation_records')
            .upsert(payload.sublist(index, end));
      }
    }

    if (!direction.shouldDownload) return;
    final finalResponse = await client
        .from('plan_recitation_records')
        .select()
        .eq('center_id', centerId)
        .eq('halaqa_id', halaqahId);
    final finalRows = List<Map<String, dynamic>>.from(
      finalResponse as List<dynamic>,
    );
    final finalIds = finalRows.map((row) => row['id'].toString()).toSet();
    for (final record in local.where((item) => !finalIds.contains(item.id))) {
      await _db.deletePlanRecitationRecordFromSync(record.id);
    }
    final localById = {for (final record in local) record.id: record};
    for (final row in finalRows) {
      final createdAt =
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
              DateTime.now();
      final updatedAt =
          DateTime.tryParse(row['updated_at']?.toString() ?? '') ?? createdAt;
      final existing = localById[row['id']?.toString()];
      if (existing != null && !updatedAt.isAfter(existing.updatedAt)) continue;
      await _db.upsertPlanRecitationRecordFromSync(
        PlanRecitationRecord(
          id: row['id']?.toString(),
          sessionId: row['session_id']?.toString(),
          planId: row['plan_id'].toString(),
          studentId: row['student_id'].toString(),
          surahId: (row['surah_id'] as num).toInt(),
          fromAyah: (row['from_ayah'] as num).toInt(),
          toAyah: (row['to_ayah'] as num).toInt(),
          segmentOrder: (row['segment_order'] as num?)?.toInt() ?? 0,
          date: DateTime.parse(row['date'].toString()),
          qualityRating: (row['quality_rating'] as num?)?.toInt() ?? 3,
          notes: row['notes']?.toString(),
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      );
    }
  }

  Future<void> _syncNotifications(
    String centerId,
    String halaqahId,
    CloudSyncDirection direction,
  ) async {
    if (direction.shouldUpload) {
      final localData = await _db.getNotifications();
      final payload = localData.map((notification) => {
        'id': notification.id,
        'center_id': centerId,
        'halaqa_id': halaqahId,
        'student_id': notification.studentId,
        'type': notification.type,
        'title': notification.title,
        'body': notification.body,
        'read': notification.read,
        'sent_via': 'none',
        'created_at': notification.createdAt.toIso8601String(),
      }).toList();
      for (var i = 0; i < payload.length; i += 100) {
        final chunk = payload.sublist(
          i,
          i + 100 > payload.length ? payload.length : i + 100,
        );
        try {
          await client.from('notifications').upsert(chunk);
        } on PostgrestException catch (error) {
          if (_isMissingSchemaTable(error)) return;
          if (!_isMissingSchemaColumn(error)) rethrow;
          final compatible = chunk
              .map((row) => Map<String, dynamic>.from(row)
                ..remove('halaqa_id')
                ..remove('created_at'))
              .toList();
          await client.from('notifications').upsert(compatible);
        }
      }
    }

    if (!direction.shouldDownload) return;
    final scopedStudentIds = await _fetchHalaqahStudentIds(halaqahId);
    if (scopedStudentIds.isEmpty) return;
    try {
      final response = await client
          .from('notifications')
          .select()
          .eq('center_id', centerId);
      final notifications = <NotificationLog>[];
      for (final dynamic raw in response as List<dynamic>) {
        final row = Map<String, dynamic>.from(raw as Map);
        final studentId = row['student_id']?.toString();
        if (studentId == null || !scopedStudentIds.contains(studentId)) continue;
        notifications.add(
          NotificationLog(
            id: row['id']?.toString(),
            studentId: studentId,
            type: row['type']?.toString() ?? 'general',
            title: row['title']?.toString() ?? 'إشعار',
            body: row['body']?.toString() ?? '',
            read: row['read'] == true || row['read'] == 1,
            createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                DateTime.now(),
          ),
        );
      }
      await _db.upsertNotificationsFromSync(notifications);
    } on PostgrestException catch (error) {
      if (_isMissingSchemaTable(error)) return;
      rethrow;
    }
  }

}
