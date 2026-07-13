import 'package:uuid/uuid.dart';

class Student {
  final String id;
  String name;
  String phone;
  String guardianPhone;
  String qrCode;
  String planType;
  int planAmount;
  int totalMemorized;
  DateTime joinDate;
  String status;
  String? photoPath;
  String? notes;
  String? familyId;
  String memorizationDirection; // 'desc' or 'asc'
  int? preMemorizedStartSurah;
  int? preMemorizedStartAyah;
  int? preMemorizedEndSurah;
  int? preMemorizedEndAyah;
  DateTime createdAt;
  DateTime updatedAt;

  Student({
    String? id,
    required this.name,
    this.phone = '',
    this.guardianPhone = '',
    String? qrCode,
    this.planType = 'ayahs',
    this.planAmount = 5,
    this.totalMemorized = 0,
    DateTime? joinDate,
    this.status = 'active',
    this.photoPath,
    this.notes,
    this.familyId,
    this.memorizationDirection = 'desc',
    this.preMemorizedStartSurah,
    this.preMemorizedStartAyah,
    this.preMemorizedEndSurah,
    this.preMemorizedEndAyah,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        qrCode = qrCode ?? const Uuid().v4(),
        joinDate = joinDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// رمز قصير ثابت وآمن للعرض في التقارير والبحث اليدوي.
  ///
  /// لا نعرض معرّف قاعدة البيانات الكامل، ونشتق الرمز من QR العشوائي حتى
  /// يبقى ثابتًا عند النسخ الاحتياطي والمزامنة بين الأجهزة.
  String get displayCode {
    final normalized = qrCode
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    final suffix = normalized.length >= 8
        ? normalized.substring(0, 8)
        : normalized.padRight(8, '0');
    return 'HAL-$suffix';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'guardian_phone': guardianPhone,
        'qr_code': qrCode,
        'plan_type': planType,
        'plan_amount': planAmount,
        'total_memorized': totalMemorized,
        'join_date': joinDate.toIso8601String(),
        'status': status,
        'photo_path': photoPath,
        'notes': notes,
        'family_id': familyId,
        'memorization_direction': memorizationDirection,
        'pre_memorized_start_surah': preMemorizedStartSurah,
        'pre_memorized_start_ayah': preMemorizedStartAyah,
        'pre_memorized_end_surah': preMemorizedEndSurah,
        'pre_memorized_end_ayah': preMemorizedEndAyah,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Student.fromMap(Map<String, dynamic> map) => Student(
        id: map['id'],
        name: map['name'],
        phone: map['phone'] ?? '',
        guardianPhone: map['guardian_phone'] ?? '',
        qrCode: map['qr_code'],
        planType: map['plan_type'] ?? 'ayahs',
        planAmount: map['plan_amount'] ?? 5,
        totalMemorized: map['total_memorized'] ?? 0,
        joinDate: DateTime.parse(map['join_date']),
        status: map['status'] ?? 'active',
        photoPath: map['photo_path'],
        notes: map['notes'],
        familyId: map['family_id']?.toString(),
        memorizationDirection: map['memorization_direction'] ?? 'desc',
        preMemorizedStartSurah: map['pre_memorized_start_surah'],
        preMemorizedStartAyah: map['pre_memorized_start_ayah'],
        preMemorizedEndSurah: map['pre_memorized_end_surah'],
        preMemorizedEndAyah: map['pre_memorized_end_ayah'],
        createdAt: DateTime.parse(map['created_at']),
        updatedAt: DateTime.parse(map['updated_at']),
      );

  Student copyWith({
    String? name,
    String? phone,
    String? guardianPhone,
    String? planType,
    int? planAmount,
    int? totalMemorized,
    String? status,
    String? photoPath,
    String? notes,
    String? familyId,
    String? memorizationDirection,
    int? preMemorizedStartSurah,
    int? preMemorizedStartAyah,
    int? preMemorizedEndSurah,
    int? preMemorizedEndAyah,
    bool clearPreMemorized = false,
    bool clearFamily = false,
  }) {
    return Student(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      qrCode: qrCode,
      planType: planType ?? this.planType,
      planAmount: planAmount ?? this.planAmount,
      totalMemorized: totalMemorized ?? this.totalMemorized,
      joinDate: joinDate,
      status: status ?? this.status,
      photoPath: photoPath ?? this.photoPath,
      notes: notes ?? this.notes,
      familyId: clearFamily ? null : (familyId ?? this.familyId),
      memorizationDirection: memorizationDirection ?? this.memorizationDirection,
      preMemorizedStartSurah: clearPreMemorized ? null : (preMemorizedStartSurah ?? this.preMemorizedStartSurah),
      preMemorizedStartAyah: clearPreMemorized ? null : (preMemorizedStartAyah ?? this.preMemorizedStartAyah),
      preMemorizedEndSurah: clearPreMemorized ? null : (preMemorizedEndSurah ?? this.preMemorizedEndSurah),
      preMemorizedEndAyah: clearPreMemorized ? null : (preMemorizedEndAyah ?? this.preMemorizedEndAyah),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Student && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
