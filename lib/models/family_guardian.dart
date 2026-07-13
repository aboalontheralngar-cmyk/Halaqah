import 'package:uuid/uuid.dart';

class FamilyGuardian {
  final String id;
  final String familyId;
  String name;
  String phone;
  String? email;
  String relationship;
  bool isPrimary;
  String? notes;
  DateTime createdAt;
  DateTime updatedAt;

  FamilyGuardian({
    String? id,
    required this.familyId,
    required this.name,
    required this.phone,
    this.email,
    this.relationship = 'father',
    this.isPrimary = false,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  static const relationships = <String>{
    'father',
    'mother',
    'brother',
    'grandfather',
    'uncle',
    'guardian',
    'other',
  };

  String get relationshipLabel => switch (relationship) {
        'father' => 'الأب',
        'mother' => 'الأم',
        'brother' => 'الأخ',
        'grandfather' => 'الجد',
        'uncle' => 'العم/الخال',
        'guardian' => 'ولي أمر',
        _ => 'صلة أخرى',
      };

  Map<String, dynamic> toMap() => {
        'id': id,
        'family_id': familyId,
        'name': name.trim(),
        'phone': phone.trim(),
        'email': _nullable(email),
        'relationship': relationships.contains(relationship)
            ? relationship
            : 'other',
        'is_primary': isPrimary ? 1 : 0,
        'notes': _nullable(notes),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory FamilyGuardian.fromMap(Map<String, dynamic> map) => FamilyGuardian(
        id: map['id']?.toString(),
        familyId: map['family_id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        phone: map['phone']?.toString() ?? '',
        email: map['email']?.toString(),
        relationship: map['relationship']?.toString() ?? 'guardian',
        isPrimary: map['is_primary'] == true || map['is_primary'] == 1,
        notes: map['notes']?.toString(),
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
      );

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
