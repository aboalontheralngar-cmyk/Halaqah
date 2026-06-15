import 'dart:io';
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

  final SupabaseClient client = Supabase.instance.client;
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
      final response = await client
          .from('center_members')
          .select('center_id, halaqah_id, role, user_id')
          .eq('email', email)
          .maybeSingle();
          
      if (response != null && response['user_id'] == null) {
        await client
            .from('center_members')
            .update({'user_id': currentUser.id})
            .eq('email', email);
      }
      
      return response;
    } catch (e) {
      print('Error getting teacher info: $e');
      return null;
    }
  }

  // Synchronize SQLite and Supabase
  Future<void> synchronizeData() async {
    if (!isAuthenticated) return;

    try {
      final info = await getTeacherInfo();
      if (info == null) return;

      final String centerId = info['center_id'];
      final String? halaqahId = info['halaqah_id'];

      if (halaqahId == null) {
        print('No halaqah assigned to teacher');
        return;
      }

      await _syncStudents(centerId, halaqahId);
      await _syncHomeworkGrades(centerId, halaqahId);
      await _syncAttendance(centerId, halaqahId);
      await _syncMushafProgress(centerId, halaqahId);

      print('Supabase synchronization completed successfully!');
    } catch (e) {
      print('Error during Supabase synchronization: $e');
    }
  }

  // Sync Students: Pull from Supabase and save to local
  Future<void> _syncStudents(String centerId, String halaqahId) async {
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
        'halaqa_id': halaqahId,
        'date': record.date.toIso8601String().split('T')[0],
        'status': record.attendance,
        'arrival_time': record.arrivalTime,
        'absence_reason': record.absenceReason,
        'notes': record.notes,
      });
    }

    // 3. Download from Supabase
    final response = await client
        .from('attendance')
        .select()
        .eq('halaqa_id', halaqahId);

    final List<dynamic> remoteAttendance = response as List<dynamic>;

    for (final remote in remoteAttendance) {
      final localRecord = DailyRecord(
        studentId: remote['student_id'],
        date: DateTime.parse(remote['date']),
        attendance: remote['status'] ?? 'absent',
        arrivalTime: remote['arrival_time'],
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
      await client.from('mushaf_progress').upsert({
        'id': progress.id,
        'student_id': progress.studentId,
        'center_id': centerId,
        'hizb_number': progress.hizbNumber,
        'thumun_number': progress.thumunNumber,
        'average_grade': progress.averageGrade,
        'last_graded_date': progress.lastGradedDate,
        'is_pre_memorized': progress.isPreMemorized,
      });
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
        lastGradedDate: remote['last_graded_date'],
        isPreMemorized: remote['is_pre_memorized'] ?? false,
      );

      await _db.insertOrUpdateMushafProgress(localProgress);
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
