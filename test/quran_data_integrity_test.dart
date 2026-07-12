import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/models/ayah.dart';

void main() {
  test('Quran data exposes exactly 6236 numbered ayahs', () async {
    final raw = await File('assets/quran_data.json').readAsString();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final rawSurahs = data['surahs'] as List<dynamic>;
    final surahs = rawSurahs
        .map((value) => Surah.fromJson(value as Map<String, dynamic>))
        .toList();

    expect(surahs, hasLength(114));
    expect(data['total_ayahs'], 6236);
    expect(
      surahs.fold<int>(0, (sum, surah) => sum + surah.totalAyahs),
      6236,
    );

    final basmalaRows = surahs
        .expand((surah) => surah.ayahs)
        .where((ayah) => ayah.number == 0)
        .length;
    expect(basmalaRows, 112);

    final alBaqarah = surahs.firstWhere((surah) => surah.number == 2);
    expect(alBaqarah.totalAyahs, 286);
    expect(alBaqarah.getAyah(286)?.number, 286);
    expect(alBaqarah.getAyah(287), isNull);
  });
}
