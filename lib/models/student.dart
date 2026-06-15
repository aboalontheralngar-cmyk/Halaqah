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
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        qrCode = qrCode ?? const Uuid().v4(),
        joinDate = joinDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

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
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
