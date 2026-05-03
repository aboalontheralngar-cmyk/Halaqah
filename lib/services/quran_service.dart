import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/ayah.dart';

class QuranService {
  static QuranService? _instance;
  static QuranService get instance => _instance ??= QuranService._();
  
  QuranService._();

  List<Surah> _surahs = [];
  bool _isLoaded = false;

  Future<void> initialize() async {
    if (_isLoaded) return;
    
    final jsonString = await rootBundle.loadString('assets/quran_data.json');
    final data = json.decode(jsonString);
    
    _surahs = (data['surahs'] as List)
        .map((s) => Surah.fromJson(s))
        .toList();
    
    _isLoaded = true;
  }

  List<Surah> get surahs => _surahs;

  Surah? getSurah(int number) {
    if (number < 1 || number > 114) return null;
    return _surahs.firstWhere((s) => s.number == number, orElse: () => _surahs[0]);
  }

  String getSurahName(int number) {
    return getSurah(number)?.name ?? '';
  }

  int getSurahAyahCount(int number) {
    return getSurah(number)?.totalAyahs ?? 0;
  }

  Ayah? getAyah(int surahNumber, int ayahNumber) {
    return getSurah(surahNumber)?.getAyah(ayahNumber);
  }

  String getAyahText(int surahNumber, int ayahNumber) {
    return getAyah(surahNumber, ayahNumber)?.text ?? '';
  }

  List<Ayah> getAyahRange(int surahNumber, int fromAyah, int toAyah) {
    return getSurah(surahNumber)?.getAyahRange(fromAyah, toAyah) ?? [];
  }

  double calculateLines(int surahNumber, int fromAyah, int toAyah) {
    return getSurah(surahNumber)?.calculateLines(fromAyah, toAyah) ?? 0;
  }

  List<Surah> getSurahsByJuz(int juz) {
    return _surahs.where((s) => s.juzStart == juz || 
        s.ayahs.any((a) => a.juz == juz)).toList();
  }

  List<Ayah> getAyahsByPage(int page) {
    List<Ayah> result = [];
    for (final surah in _surahs) {
      result.addAll(surah.ayahs.where((a) => a.page == page));
    }
    return result;
  }

  List<Ayah> getAyahsByJuz(int juz) {
    List<Ayah> result = [];
    for (final surah in _surahs) {
      result.addAll(surah.ayahs.where((a) => a.juz == juz));
    }
    return result;
  }

  Map<String, dynamic> generateExamRange({
    required int surahNumber,
    required int fromAyah,
    required int toAyah,
    int questionCount = 5,
  }) {
    final ayahs = getAyahRange(surahNumber, fromAyah, toAyah);
    if (ayahs.isEmpty) return {};
    
    final shuffled = List<Ayah>.from(ayahs)..shuffle();
    final selected = shuffled.take(questionCount).toList();
    
    return {
      'surah': getSurahName(surahNumber),
      'range': '$fromAyah - $toAyah',
      'total_lines': calculateLines(surahNumber, fromAyah, toAyah),
      'questions': selected.map((a) => {
        'ayah_number': a.number,
        'start_text': a.text.split(' ').take(3).join(' '),
        'full_text': a.text,
        'difficulty': a.difficulty,
      }).toList(),
    };
  }

  Map<String, dynamic> generateMonthlyPlan({
    required int startSurah,
    required int startAyah,
    required double dailyLines,
    required int daysInMonth,
  }) {
    List<Map<String, dynamic>> dailyPlan = [];
    int currentSurah = startSurah;
    int currentAyah = startAyah;
    
    for (int day = 1; day <= daysInMonth; day++) {
      double linesForDay = 0;
      int dayStartSurah = currentSurah;
      int dayStartAyah = currentAyah;
      int dayEndSurah = currentSurah;
      int dayEndAyah = currentAyah;
      
      while (linesForDay < dailyLines && currentSurah <= 114) {
        final surah = getSurah(currentSurah);
        if (surah == null) break;
        
        final ayah = surah.getAyah(currentAyah);
        if (ayah == null) {
          currentSurah++;
          currentAyah = 1;
          continue;
        }
        
        linesForDay += ayah.lines;
        dayEndSurah = currentSurah;
        dayEndAyah = currentAyah;
        
        currentAyah++;
        if (currentAyah > surah.totalAyahs) {
          currentSurah++;
          currentAyah = 1;
        }
      }
      
      dailyPlan.add({
        'day': day,
        'from_surah': dayStartSurah,
        'from_surah_name': getSurahName(dayStartSurah),
        'from_ayah': dayStartAyah,
        'to_surah': dayEndSurah,
        'to_surah_name': getSurahName(dayEndSurah),
        'to_ayah': dayEndAyah,
        'lines': linesForDay.toStringAsFixed(1),
      });
      
      if (currentSurah > 114) break;
    }
    
    return {
      'start': '${getSurahName(startSurah)} : $startAyah',
      'end': '${getSurahName(currentSurah > 114 ? 114 : currentSurah)} : ${currentAyah - 1}',
      'daily_target': dailyLines,
      'plan': dailyPlan,
    };
  }

  Map<String, dynamic> generateYearlyPlan({
    required int startSurah,
    required int startAyah,
    required double dailyLines,
    required int daysPerWeek,
  }) {
    List<Map<String, dynamic>> monthlyPlan = [];
    int currentSurah = startSurah;
    int currentAyah = startAyah;
    
    final hijriMonths = [
      'محرم', 'صفر', 'ربيع الأول', 'ربيع الثاني',
      'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان',
      'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'
    ];
    
    for (int month = 0; month < 12; month++) {
      int monthStartSurah = currentSurah;
      int monthStartAyah = currentAyah;
      double monthLines = 0;
      int daysInMonth = (month == 8) ? 25 : 26;
      int workDays = (daysInMonth * daysPerWeek / 7).round();
      
      for (int day = 0; day < workDays && currentSurah <= 114; day++) {
        double linesForDay = 0;
        while (linesForDay < dailyLines && currentSurah <= 114) {
          final surah = getSurah(currentSurah);
          if (surah == null) break;
          
          final ayah = surah.getAyah(currentAyah);
          if (ayah == null) {
            currentSurah++;
            currentAyah = 1;
            continue;
          }
          
          linesForDay += ayah.lines;
          monthLines += ayah.lines;
          currentAyah++;
          
          if (currentAyah > surah.totalAyahs) {
            currentSurah++;
            currentAyah = 1;
          }
        }
      }
      
      monthlyPlan.add({
        'month': hijriMonths[month],
        'from_surah': getSurahName(monthStartSurah),
        'from_ayah': monthStartAyah,
        'to_surah': getSurahName(currentSurah > 114 ? 114 : currentSurah),
        'to_ayah': currentAyah > 1 ? currentAyah - 1 : 1,
        'total_lines': monthLines.toStringAsFixed(0),
        'work_days': workDays,
      });
      
      if (currentSurah > 114) break;
    }
    
    return {
      'start': '${getSurahName(startSurah)} : $startAyah',
      'daily_target': dailyLines,
      'days_per_week': daysPerWeek,
      'plan': monthlyPlan,
    };
  }
}
