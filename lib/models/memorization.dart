import 'package:uuid/uuid.dart';

class MemorizationProgress {
  final String id;
  final String studentId;
  final int surahId;
  final int fromAyah;
  final int toAyah;
  final DateTime date;
  final int qualityRating;
  final bool isRevision;
  String? notes;
  DateTime createdAt;

  MemorizationProgress({
    String? id,
    required this.studentId,
    required this.surahId,
    required this.fromAyah,
    required this.toAyah,
    required this.date,
    this.qualityRating = 3,
    this.isRevision = false,
    this.notes,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  int get ayahCount => toAyah - fromAyah + 1;

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'surah_id': surahId,
        'from_ayah': fromAyah,
        'to_ayah': toAyah,
        'date': date.toIso8601String().split('T')[0],
        'quality_rating': qualityRating,
        'is_revision': isRevision ? 1 : 0,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory MemorizationProgress.fromMap(Map<String, dynamic> map) =>
      MemorizationProgress(
        id: map['id'],
        studentId: map['student_id'],
        surahId: map['surah_id'],
        fromAyah: map['from_ayah'],
        toAyah: map['to_ayah'],
        date: DateTime.parse(map['date']),
        qualityRating: map['quality_rating'] ?? 3,
        isRevision: map['is_revision'] == 1,
        notes: map['notes'],
        createdAt: DateTime.parse(map['created_at']),
      );
}

class StudentMemorization {
  final String studentId;
  final Map<int, List<int>> memorizedAyahs;

  StudentMemorization({
    required this.studentId,
    Map<int, List<int>>? memorizedAyahs,
  }) : memorizedAyahs = memorizedAyahs ?? {};

  void addMemorization(int surahId, int fromAyah, int toAyah) {
    if (!memorizedAyahs.containsKey(surahId)) {
      memorizedAyahs[surahId] = [];
    }
    for (int i = fromAyah; i <= toAyah; i++) {
      if (!memorizedAyahs[surahId]!.contains(i)) {
        memorizedAyahs[surahId]!.add(i);
      }
    }
    memorizedAyahs[surahId]!.sort();
  }

  bool isAyahMemorized(int surahId, int ayah) {
    return memorizedAyahs[surahId]?.contains(ayah) ?? false;
  }

  bool isSurahMemorized(int surahId, int totalAyahs) {
    return memorizedAyahs[surahId]?.length == totalAyahs;
  }

  int getTotalMemorizedAyahs() {
    return memorizedAyahs.values.fold(0, (sum, ayahs) => sum + ayahs.length);
  }

  List<int> getMemorizedSurahs() {
    return memorizedAyahs.keys.toList();
  }

  double getSurahProgress(int surahId, int totalAyahs) {
    if (!memorizedAyahs.containsKey(surahId)) return 0;
    return memorizedAyahs[surahId]!.length / totalAyahs;
  }
}
