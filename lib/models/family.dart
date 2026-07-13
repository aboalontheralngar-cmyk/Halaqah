import 'package:uuid/uuid.dart';

class Family {
  final String id;
  String name;
  String? referenceName;
  String? notes;
  DateTime createdAt;
  DateTime updatedAt;

  Family({
    String? id,
    required this.name,
    this.referenceName,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get displayCode {
    final normalized = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final suffix = normalized.length >= 8
        ? normalized.substring(0, 8)
        : normalized.padRight(8, '0');
    return 'FAM-$suffix';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name.trim(),
        'reference_name': _nullable(referenceName),
        'notes': _nullable(notes),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Family.fromMap(Map<String, dynamic> map) => Family(
        id: map['id']?.toString(),
        name: map['name']?.toString() ?? '',
        referenceName: map['reference_name']?.toString(),
        notes: map['notes']?.toString(),
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
      );

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
