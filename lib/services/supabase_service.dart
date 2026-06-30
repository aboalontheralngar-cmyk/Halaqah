import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/student.dart';
import '../models/homework_grade.dart';
import '../models/daily_record.dart';
import '../models/mushaf_progress.dart';
import 'database_service.dart';
import 'quran_service.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  factory SupabaseService() => instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;
  final DatabaseService _db = DatabaseService();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://mcckekgvwtqtpwtslwqf.supabase.co',
      anonKey: 'sb_publishable_TksdkEVcn6VvNGVVjXNEpg_PkRZTdxz',
    );
  }

  // Auth Operations
  Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(email: email, password: password);
  }

  // Verify invitation code
  Future<Map<String, dynamic>?> verifyInvitationCode(String code) async {
    try {
      final response = await client.rpc(
        'get_member_by_code',
        params: {'code_to_check': code},
      ) as List<dynamic>;
      if (response.isNotEmpty) {
        return response.first as Map<String, dynamic>;
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
      
      final String? newUserId = response.user?.id;
      if (newUserId == null) {
        throw Exception('فشل إنشاء حساب المستخدم');
      }

      final bool linked = await client.rpc(
        'activate_member_by_code',
        params: {
          'code_to_check': code,
          'new_user_id': newUserId,
        },
      );

      if (!linked) {
        throw Exception('فشل ربط كود المعلم بالحساب الجديد');
      }
    } catch (e) {
      print('Error in sign up & link: $e');
      throw Exception(e.toString().replaceAll('Exception: ', ''));
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
          .ilike('email', email.trim())
          .maybeSingle();
          
      if (response != null) {
        if (response['user_id'] == null) {
          await client
              .from('center_members')
              .update({'user_id': currentUser.id})
              .ilike('email', email.trim());
        }
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
  Future<void> synchronizeData() async {
    if (!isAuthenticated) return;

    try {
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

      await _syncStudents(centerId, halaqahId);
      await _syncHomeworkGrades(centerId, halaqahId);
      await _syncAttendance(centerId, halaqahId);
      await _syncMushafProgress(centerId, halaqahId);

      print('Supabase synchronization completed successfully!');
    } catch (e) {
      print('Error during Supabase synchronization: $e');
      rethrow;
    }
  }

  // Sync Students: Push local changes, Pull remote changes
  Future<void> _syncStudents(String centerId, String halaqahId) async {
    // 1. Fetch local students
    final localStudents = await _db.getStudents();

    // 2. Upload/Upsert to Supabase
    for (final student in localStudents) {
      await client.from('students').upsert({
        'id': student.id,
        'center_id': centerId,
        'halaqa_id': halaqahId,
        'name': student.name,
        'phone': student.phone,
        'parent_phone': student.guardianPhone,
        'plan_type': student.planType,
        'plan_amount': student.planAmount,
        'status': student.status,
        'join_date': student.joinDate.toIso8601String().split('T')[0],
        'created_at': student.createdAt.toIso8601String(),
        'memorization_direction': student.memorizationDirection,
      });
    }

    // 3. Download latest from Supabase
    final response = await client
        .from('students')
        .select()
        .eq('halaqa_id', halaqahId);

    final List<dynamic> remoteStudents = response as List<dynamic>;

    for (final remote in remoteStudents) {
      final localStudent = Student(
        id: remote['id'],
        name: remote['name'],
        phone: remote['phone'] ?? '',
        guardianPhone: remote['parent_phone'] ?? '',
        qrCode: remote['id'], // QR code maps to student ID
        planType: remote['plan_type'] ?? 'ayahs',
        planAmount: remote['plan_amount'] ?? 5,
        status: remote['status'] ?? 'active',
        memorizationDirection: remote['memorization_direction'] ?? 'desc',
        joinDate: remote['join_date'] != null ? DateTime.parse(remote['join_date']) : DateTime.now(),
        createdAt: remote['created_at'] != null ? DateTime.parse(remote['created_at']) : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Check if student exists locally
      final existing = await _db.getStudent(localStudent.id);
      if (existing == null) {
        await _db.insertStudent(localStudent);
      } else {
        await _db.updateStudent(localStudent);
      }
    }
  }

  // Sync Grades: Push local changes, Pull remote changes
  Future<void> _syncHomeworkGrades(String centerId, String halaqahId) async {
    // 1. Fetch local grades
    final localGrades = await _db.getAllHomeworkGrades();

    // 2. Upload/Upsert to Supabase
    for (final grade in localGrades) {
      final surahName = QuranService.instance.getSurahName(grade.surahId);
      await client.from('homework_grades').upsert({
        'id': grade.id,
        'student_id': grade.studentId,
        'center_id': centerId,
        'halaqa_id': halaqahId,
        'surah': surahName,
        'from_ayah': grade.fromAyah,
        'to_ayah': grade.toAyah,
        'date': grade.date.toIso8601String().split('T')[0],
        'grade_mark': grade.gradeMark,
        'mistakes_count': grade.mistakesCount,
        'is_revision': grade.isRevision,
        'remark': grade.remark,
        'created_at': grade.createdAt.toIso8601String(),
      });
    }

    // 3. Download latest from Supabase
    final response = await client
        .from('homework_grades')
        .select()
        .eq('halaqa_id', halaqahId);

    final List<dynamic> remoteGrades = response as List<dynamic>;
    final surahs = QuranService.instance.surahs;

    for (final remote in remoteGrades) {
      // Find surah ID from name
      int surahId = 1;
      final match = surahs.where((s) => s.name == remote['surah']);
      if (match.isNotEmpty) {
        surahId = match.first.number;
      }

      final localGrade = HomeworkGrade(
        id: remote['id'],
        studentId: remote['student_id'],
        surahId: surahId,
        fromAyah: remote['from_ayah'],
        toAyah: remote['to_ayah'],
        date: DateTime.parse(remote['date']),
        gradeMark: remote['grade_mark'],
        mistakesCount: remote['mistakes_count'] ?? 0,
        isRevision: remote['is_revision'] ?? false,
        remark: remote['remark'],
        createdAt: DateTime.parse(remote['created_at']),
      );

      // Check if exists locally
      final localList = await _db.getStudentHomeworkGrades(localGrade.studentId);
      final exists = localList.any((g) => g.id == localGrade.id);
      if (!exists) {
        await _db.insertHomeworkGrade(localGrade);
      }
    }
  }

  // Sync Attendance: Push local, Pull remote
  Future<void> _syncAttendance(String centerId, String halaqahId) async {
    // 1. Fetch all local daily records
    final localRecords = await _db.getAllDailyRecords();

    // 2. Upload to Supabase
    for (final record in localRecords) {
      // Create a unique UUID from studentId and date for Supabase PRIMARY KEY
      final uniqueId = '${record.studentId}_${record.date.toIso8601String().split('T')[0]}';
      
      await client.from('attendance').upsert({
        'id': remoteUUID(uniqueId),
        'student_id': record.studentId,
        'center_id': centerId,
        'date': record.date.toIso8601String().split('T')[0],
        'status': record.attendance,
        'arrival_time': record.arrivalTime?.toIso8601String().split('T')[1],
        'absence_reason': record.absenceReason,
        'notes': record.notes,
      });
    }

    // 3. Download from Supabase
    final response = await client
        .from('attendance')
        .select()
        .eq('center_id', centerId);

    final List<dynamic> remoteAttendance = response as List<dynamic>;

    for (final remote in remoteAttendance) {
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

  // Sync Mushaf Progress: Push local, Pull remote
  Future<void> _syncMushafProgress(String centerId, String halaqahId) async {
    // 1. Fetch local mushaf progress
    final localProgressList = await _db.getAllMushafProgress();

    // 2. Upload to Supabase
    for (final progress in localProgressList) {
      final uniqueId = '${progress.studentId}_${progress.hizbNumber}_${progress.thumunNumber}';
      await client.from('mushaf_progress').upsert({
        'id': remoteUUID(uniqueId),
        'student_id': progress.studentId,
        'center_id': centerId,
        'hizb_number': progress.hizbNumber,
        'thumun_number': progress.thumunNumber,
        'average_grade': progress.averageGrade,
        'last_graded_date': progress.lastGradedDate?.toIso8601String().split('T')[0],
        'is_pre_memorized': progress.isPreMemorized,
      }, onConflict: 'student_id,hizb_number,thumun_number');
    }

    // 3. Download from Supabase
    final response = await client
        .from('mushaf_progress')
        .select()
        .eq('center_id', centerId);

    final List<dynamic> remoteProgressList = response as List<dynamic>;

    for (final remote in remoteProgressList) {
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
}
