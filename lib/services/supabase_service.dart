import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/student.dart';
import '../models/homework_grade.dart';
import '../models/daily_record.dart';
import '../models/mushaf_progress.dart';
import '../models/memorization.dart';
import '../models/behavior_point.dart';
import '../models/vacation.dart';
import '../models/exam.dart';
import '../models/fund_transaction.dart';
import '../models/plan.dart';
import '../models/notification_log.dart';
import '../models/daily_achievement.dart';
import '../models/family.dart';
import '../models/family_guardian.dart';
import 'backup_service.dart';
import 'cloud_connection_diagnostics.dart';
import 'database_service.dart';
import 'mushaf_service.dart';
import 'quran_service.dart';

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

class SupabaseService {
  static const projectUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mcckekgvwtqtpwtslwqf.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_TksdkEVcn6VvNGVVjXNEpg_PkRZTdxz',
  );

  static final SupabaseService instance = SupabaseService._internal();
  factory SupabaseService() => instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;
  final DatabaseService _db = DatabaseService();
  final MushafService _mushaf = MushafService();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: projectUrl,
      anonKey: publishableKey,
    );
  }

  Future<CloudConnectionDiagnostic> diagnoseConnection() {
    final baseUri = Uri.parse(projectUrl);
    return CloudConnectionDiagnostics(
      endpoint: baseUri.replace(path: '/auth/v1/health', query: null),
    ).run();
  }

  // Auth Operations
  Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(email: email, password: password);
  }

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
      print('Error verifying invitation code: $e');
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
      print('Error in sign up & link: $e');
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
      print('Error getting teacher info: $e');
      return null;
    }
  }

  // Synchronize SQLite and Supabase
  Future<CloudSyncResult> synchronizeData({
    CloudSyncDirection direction = CloudSyncDirection.bidirectional,
  }) async {
    if (!isAuthenticated) {
      throw StateError('يلزم تسجيل الدخول قبل المزامنة');
    }

    try {
      if (direction.shouldDownload) await _createDailyPreSyncBackup();

      String? centerId = await _db.getSetting('sync_center_id');
      String? halaqahId = await _db.getSetting('sync_halaqah_id');

      // Fallback: check if we can get it from teacher info query
      if (centerId == null || centerId.isEmpty || halaqahId == null || halaqahId.isEmpty) {
        final info = await getTeacherInfo();
        if (info != null) {
          centerId = info['center_id'];
          halaqahId = info['halaqah_id'];
          if (centerId != null) {
            await _db.saveSetting('sync_center_id', centerId);
          }
          if (halaqahId != null) {
            await _db.saveSetting('sync_halaqah_id', halaqahId);
          }
        }
      }

      if (centerId == null || centerId.isEmpty || halaqahId == null || halaqahId.isEmpty) {
        throw Exception('الرجاء اختيار المركز والحلقة أولاً لإجراء المزامنة.');
      }

      // Fetch center name from Supabase
      String mosqueName = '';
      final centerRes = await client.from('centers').select('name').eq('id', centerId).maybeSingle();
      if (centerRes != null) {
        mosqueName = centerRes['name'] ?? '';
      }

      // Fetch halaqah name and teacher name from Supabase
      String halaqahName = '';
      String teacherName = '';
      final halaqahRes = await client.from('halaqat').select('name, teacher_name').eq('id', halaqahId).maybeSingle();
      if (halaqahRes != null) {
        halaqahName = halaqahRes['name'] ?? '';
        teacherName = halaqahRes['teacher_name'] ?? '';
      }

      // Save to local SQLite settings
      if (mosqueName.isNotEmpty) {
        await _db.saveSetting('mosque_name', mosqueName);
      }
      if (halaqahName.isNotEmpty) {
        await _db.saveSetting('halaqah_name', halaqahName);
      }
      if (teacherName.isNotEmpty) {
        await _db.saveSetting('teacher_name', teacherName);
      }
      await _db.saveSetting('setup_completed', 'true');

      await _syncFamilies(centerId, halaqahId, direction);
      await _syncStudents(centerId, halaqahId, direction);
      await _syncHomeworkGrades(centerId, halaqahId, direction);
      await _syncAttendance(centerId, halaqahId, direction);
      await _syncMemorizationProgress(centerId, halaqahId, direction);
      await _syncMushafProgress(centerId, halaqahId, direction);
      if (direction.shouldUpload) {
        await _syncBehaviorPoints(centerId, halaqahId);
        await _syncBehaviorPointCorrections(centerId, halaqahId);
      }
      await _syncDailyAchievements(centerId, halaqahId, direction);
      if (direction.shouldUpload) {
        await _syncVacations(centerId);
        await _syncStudentHolds(centerId, halaqahId);
        await _syncExams(centerId);
        await _syncExamTemplates(centerId, halaqahId);
        await _syncFundTransactions(centerId);
        await _syncNotifications(centerId);
      }
      await _syncPlans(centerId, halaqahId, direction);

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

      print('Supabase synchronization completed successfully!');
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
                'الاختبارات والخطط',
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
                'الخطط',
              ]
            : const [],
      );
    } catch (e) {
      print('Error during Supabase synchronization: $e');
      rethrow;
    }
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

        for (final family in localFamilies) {
          final guardians = await _db.getFamilyGuardians(family.id);
          if (guardians.isEmpty) continue;
          final nonPrimary = guardians.where((item) => !item.isPrimary).toList();
          final primary = guardians.where((item) => item.isPrimary).toList();
          for (final group in [nonPrimary, primary]) {
            if (group.isEmpty) continue;
            await client.from('family_guardians').upsert(
              group
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
                  .toList(),
            );
          }
        }
      }

      if (direction.shouldDownload) {
        final remoteFamilies = await client
            .from('families')
            .select()
            .eq('halaqa_id', halaqId);
        for (final remote in remoteFamilies as List<dynamic>) {
          await _db.saveFamily(
            Family.fromMap(Map<String, dynamic>.from(remote)),
          );
        }

        final remoteGuardians = await client
            .from('family_guardians')
            .select()
            .eq('halaqa_id', halaqId);
        for (final remote in remoteGuardians as List<dynamic>) {
          await _db.saveFamilyGuardian(
            FamilyGuardian.fromMap(Map<String, dynamic>.from(remote)),
          );
        }
      }
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST205' ||
          error.code == '42P01' ||
          error.code == '42703') {
        print('Family sync skipped until P5.4 migration is applied.');
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

    for (final remote in remoteStudents) {
      final existing = await _db.getStudent(remote['id']);
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

      if (existing == null) {
        await _db.insertStudent(localStudent);
      } else {
        await _db.updateStudent(localStudent);
      }
    }
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

    final List<dynamic> remoteAttendance = response as List<dynamic>;

    for (final remote in remoteAttendance) {
      if (!scopedStudentIds.contains(remote['student_id']?.toString())) {
        continue;
      }
      final localRecord = DailyRecord(
        studentId: remote['student_id'],
        date: DateTime.parse(remote['date']),
        attendance: remote['status'] ?? 'absent',
        arrivalTime: remote['arrival_time'] != null
            ? DateTime.parse('${remote['date']}T${remote['arrival_time']}')
            : null,
        absenceReason: remote['absence_reason'],
        notes: remote['notes'] ?? '',
      );

      await _db.saveDailyRecord(localRecord);
    }
  }

  Future<void> _upsertAttendanceWithSchemaCompatibility(
    List<Map<String, dynamic>> chunk,
  ) async {
    try {
      await client.from('attendance').upsert(chunk);
    } on PostgrestException catch (error) {
      final description = [error.message, error.details, error.hint]
          .whereType<Object>()
          .join(' ')
          .toLowerCase();
      final missingHalaqaColumn =
          (error.code == 'PGRST204' || error.code == '42703') &&
              description.contains('halaqa_id');
      if (!missingHalaqaColumn) rethrow;
      final compatibleChunk = chunk
          .map((row) => Map<String, dynamic>.from(row)..remove('halaqa_id'))
          .toList();
      await client.from('attendance').upsert(compatibleChunk);
    }
  }

  Future<Set<String>> _fetchHalaqahStudentIds(String halaqahId) async {
    final rows = await client
        .from('students')
        .select('id')
        .eq('halaqa_id', halaqahId);
    return (rows as List<dynamic>)
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .toSet();
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
        await client.from('mushaf_progress').upsert(
              chunk,
              onConflict: 'student_id,hizb_number,thumun_number',
            );
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
      print('Error fetching user centers: $e');
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
      print('Error fetching halaqas: $e');
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
      print('Error creating halaqah: $e');
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
    final beforeRows = List<Map<String, dynamic>>.from(
      beforeResponse as List<dynamic>,
    );
    final deletedIds = beforeRows
        .where((row) => row['deleted_at'] != null)
        .map((row) => row['id'].toString())
        .toSet();
    final affectedStudents = <String>{};
    if (direction.shouldDownload) {
      for (final id in deletedIds) {
        final studentId = await _db.deleteMemorizationProgressFromSync(id);
        if (studentId != null) affectedStudents.add(studentId);
      }
    }

    final remoteActive = <String, MemorizationProgress>{};
    for (final row in beforeRows.where((row) => row['deleted_at'] == null)) {
      final progress = _memorizationProgressFromRemote(row);
      remoteActive[progress.id] = progress;
    }
    if (direction.shouldUpload) {
      final payload = <Map<String, dynamic>>[];
      for (final progress in await _db.getAllMemorizationProgress()) {
        if (deletedIds.contains(progress.id)) continue;
        final remote = remoteActive[progress.id];
        if (remote != null && !progress.updatedAt.isAfter(remote.updatedAt)) {
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
    for (final row in List<Map<String, dynamic>>.from(
      finalResponse as List<dynamic>,
    )) {
      if (row['deleted_at'] != null) {
        final studentId = await _db.deleteMemorizationProgressFromSync(
          row['id'].toString(),
        );
        if (studentId != null) affectedStudents.add(studentId);
        continue;
      }
      final progress = _memorizationProgressFromRemote(row);
      await _db.upsertMemorizationProgressFromSync(progress);
      affectedStudents.add(progress.studentId);
    }
    for (final studentId in affectedStudents) {
      await _mushaf.rebuildStudentProgress(studentId);
    }
  }

  MemorizationProgress _memorizationProgressFromRemote(
    Map<String, dynamic> remote,
  ) {
    final surah = QuranService.instance.surahs.where(
      (item) => item.name == remote['surah'],
    );
    final createdAt = DateTime.parse(remote['created_at']);
    return MemorizationProgress(
      id: remote['id'],
      studentId: remote['student_id'],
      surahId: surah.isEmpty ? 1 : surah.first.number,
      fromAyah: remote['from_ayah'],
      toAyah: remote['to_ayah'],
      date: DateTime.parse(remote['date']),
      qualityRating: remote['degree'] ?? 3,
      isRevision: remote['session_type'] == 'review',
      notes: remote['notes'],
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
    for (final id in List<String>.from(remaining)) {
      try {
        await client.from(table).delete().eq('id', id);
        remaining.remove(id);
      } catch (error) {
        print('Error syncing deletion $table/$id: $error');
      }
    }
    await _db.saveSetting(settingKey, jsonEncode(remaining));
  }

  Future<void> _syncBehaviorPoints(String centerId, String halaqahId) async {
    await _syncDeletedRows(
      table: 'points',
      settingKey: 'deleted_behavior_point_ids',
    );
    final localData = await _db.getAllBehaviorPoints();
    if (localData.isEmpty) return;
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
    }).toList();
    for (var i = 0; i < payload.length; i += 100) {
      final chunk = payload.sublist(i, i + 100 > payload.length ? payload.length : i + 100);
      try {
        await client.from('points').upsert(chunk);
      } catch (e) {
        print('Error syncing points chunk: $e');
      }
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
      } catch (error) {
        print('Error syncing behavior corrections: $error');
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
          await client.from('daily_achievements').upsert(
                payload,
                onConflict: 'student_id,date',
              );
        } catch (error) {
          print('Error pushing daily achievements: $error');
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
      for (final remote in List<Map<String, dynamic>>.from(remoteRows)) {
        await _db.upsertDailyAchievementFromSync(
          DailyAchievement(
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
        );
      }
    } catch (error) {
      print('Error pulling daily achievements: $error');
    }
  }

  Future<void> _syncVacations(String centerId) async {
    final localData = await _db.getAllVacations();
    if (localData.isEmpty) return;
    final payload = localData.map((e) => {
      'id': e.id,
      'student_id': e.studentId,
      'center_id': centerId,
      'start_date': e.startDate.toIso8601String().split('T')[0],
      'end_date': e.endDate.toIso8601String().split('T')[0],
      'reason': [e.reason, e.notes].where((element) => element != null && element.isNotEmpty).join(' - '),
      'approved': e.approved,
    }).toList();
    for (var i = 0; i < payload.length; i += 100) {
      final chunk = payload.sublist(i, i + 100 > payload.length ? payload.length : i + 100);
      try {
        await client.from('vacations').upsert(chunk);
      } catch (e) {
        print('Error syncing vacations chunk: $e');
      }
    }
  }

  Future<void> _syncStudentHolds(String centerId, String halaqahId) async {
    final holds = await _db.getAllStudentHolds();
    if (holds.isEmpty) return;
    final payload = holds.map((hold) => {
      'id': hold.id,
      'student_id': hold.studentId,
      'center_id': centerId,
      'halaqa_id': halaqahId,
      'start_date': hold.startDate.toIso8601String().split('T')[0],
      'end_date': hold.endDate.toIso8601String().split('T')[0],
      'reason': hold.reason,
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
      } catch (e) {
        print('Error syncing student holds chunk: $e');
      }
    }
  }

  Future<void> _syncExams(String centerId) async {
    final localData = await _db.getAllExams();
    if (localData.isEmpty) return;
    
    final examsPayload = localData.map((e) => {
      'id': e.id,
      'center_id': centerId,
      'title': 'اختبار محلي',
      'date': e.date.toIso8601String().split('T')[0],
      'type': e.type,
      'max_degree': 100,
    }).toList();

    final scoresPayload = localData.map((e) => {
      'id': e.id,
      'exam_id': e.id,
      'student_id': e.studentId,
      'degree': e.score,
      'notes': e.notes,
    }).toList();

    for (var i = 0; i < examsPayload.length; i += 100) {
      final chunkExams = examsPayload.sublist(i, i + 100 > examsPayload.length ? examsPayload.length : i + 100);
      final chunkScores = scoresPayload.sublist(i, i + 100 > scoresPayload.length ? scoresPayload.length : i + 100);
      try {
        await client.from('exams').upsert(chunkExams);
        await client.from('exam_scores').upsert(chunkScores);
      } catch (e) {
        print('Error syncing exams chunk: $e');
      }
    }
  }

  Future<void> _syncExamTemplates(String centerId, String halaqahId) async {
    await _syncDeletedExamTemplates();
    final templates = await _db.getExamTemplates();
    if (templates.isEmpty) return;

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
      } catch (e) {
        print('Error syncing exam templates chunk: $e');
        continue;
      }

      for (final template in chunk) {
        final questions = await _db.getExamTemplateQuestions(template.id);
        try {
          await client
              .from('exam_questions')
              .delete()
              .eq('template_id', template.id);
        } catch (e) {
          print('Error clearing old questions for template ${template.id}: $e');
          continue;
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
        } catch (e) {
          print('Error syncing questions for template ${template.id}: $e');
        }
      }
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
    for (final templateId in List<String>.from(remaining)) {
      try {
        await client.from('exam_templates').delete().eq('id', templateId);
        remaining.remove(templateId);
      } catch (e) {
        print('Error syncing deleted exam template $templateId: $e');
      }
    }
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

  Future<void> _syncFundTransactions(String centerId) async {
    final localData = await _db.getFundTransactions();
    if (localData.isEmpty) return;
    final payload = localData.map((e) => {
      'id': e.id,
      'center_id': centerId,
      'student_id': e.studentId,
      'behavior_point_id': e.behaviorPointId,
      'type': e.type,
      'amount': e.amount,
      'note': e.note,
      'date': e.date.toIso8601String().split('T')[0],
    }).toList();
    for (var i = 0; i < payload.length; i += 100) {
      final chunk = payload.sublist(i, i + 100 > payload.length ? payload.length : i + 100);
      try {
        await client.from('fund_transactions').upsert(chunk);
      } on PostgrestException catch (error) {
        if ((error.code == 'PGRST204' || error.code == '42703') &&
            [error.message, error.details, error.hint]
                .whereType<Object>()
                .join(' ')
                .contains('behavior_point_id')) {
          final compatible = chunk
              .map((row) => Map<String, dynamic>.from(row)
                ..remove('behavior_point_id'))
              .toList();
          await client.from('fund_transactions').upsert(compatible);
        } else {
          print('Error syncing fund tx chunk: $error');
        }
      } catch (error) {
        print('Error syncing fund tx chunk: $error');
      }
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
            'new_amount': e.newAmount,
            'review_amount': e.reviewAmount,
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
        } catch (e) {
          print('Error syncing plans chunk: $e');
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
          newAmount: (remote['new_amount'] as num?)?.toInt() ?? 5,
          reviewAmount: (remote['review_amount'] as num?)?.toInt() ?? 10,
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

  Future<void> _syncNotifications(String centerId) async {
    final localData = await _db.getNotifications();
    if (localData.isEmpty) return;
    final payload = localData.map((e) => {
      'id': e.id,
      'center_id': centerId,
      'student_id': e.studentId,
      'type': e.type,
      'title': e.title,
      'body': e.body,
      'read': e.read,
      'sent_via': 'none',
    }).toList();
    for (var i = 0; i < payload.length; i += 100) {
      final chunk = payload.sublist(i, i + 100 > payload.length ? payload.length : i + 100);
      try {
        await client.from('notifications').upsert(chunk);
      } catch (e) {
        print('Error syncing notifications chunk: $e');
      }
    }
  }
}
