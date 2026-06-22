import 'package:adhan/adhan.dart';
import 'package:hijri/hijri_calendar.dart';
import '../models/settings.dart';

class CityCoordinates {
  final String name;
  final double latitude;
  final double longitude;
  final String defaultMethod;

  const CityCoordinates({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.defaultMethod = 'umm_al_qura',
  });
}

class ClassTimes {
  final DateTime start;
  final DateTime end;
  final bool isRamadan;
  final String? calculationSource; // 'fixed' or description of relative prayer

  ClassTimes({
    required this.start,
    required this.end,
    required this.isRamadan,
    this.calculationSource,
  });
}

class PrayerTimeHelper {
  // Database of pre-configured countries and cities
  static const Map<String, Map<String, CityCoordinates>> countriesData = {
    'YE': {
      'صنعاء': CityCoordinates(name: 'صنعاء', latitude: 15.3694, longitude: 44.1910, defaultMethod: 'umm_al_qura'),
      'عدن': CityCoordinates(name: 'عدن', latitude: 12.7855, longitude: 45.0186, defaultMethod: 'umm_al_qura'),
      'تعز': CityCoordinates(name: 'تعز', latitude: 13.5795, longitude: 44.0160, defaultMethod: 'umm_al_qura'),
      'المكلا': CityCoordinates(name: 'المكلا', latitude: 14.5422, longitude: 49.1242, defaultMethod: 'umm_al_qura'),
      'الحديدة': CityCoordinates(name: 'الحديدة', latitude: 14.7979, longitude: 42.9530, defaultMethod: 'umm_al_qura'),
      'إب': CityCoordinates(name: 'إب', latitude: 13.9716, longitude: 44.1811, defaultMethod: 'umm_al_qura'),
      'سيئون': CityCoordinates(name: 'سيئون', latitude: 15.9430, longitude: 48.7887, defaultMethod: 'umm_al_qura'),
      'صعدة': CityCoordinates(name: 'صعدة', latitude: 16.9402, longitude: 43.7639, defaultMethod: 'umm_al_qura'),
      'عتق': CityCoordinates(name: 'عتق', latitude: 14.5377, longitude: 46.8307, defaultMethod: 'umm_al_qura'),
      'دوعن': CityCoordinates(name: 'دوعن', latitude: 15.0167, longitude: 48.2500, defaultMethod: 'umm_al_qura'),
      'حجة': CityCoordinates(name: 'حجة', latitude: 15.6923, longitude: 43.6014, defaultMethod: 'umm_al_qura'),
    },
    'SA': {
      'الرياض': CityCoordinates(name: 'الرياض', latitude: 24.7136, longitude: 46.6753, defaultMethod: 'umm_al_qura'),
      'مكة المكرمة': CityCoordinates(name: 'مكة المكرمة', latitude: 21.3891, longitude: 39.8579, defaultMethod: 'umm_al_qura'),
      'المدينة المنورة': CityCoordinates(name: 'المدينة المنورة', latitude: 24.5247, longitude: 39.5692, defaultMethod: 'umm_al_qura'),
      'جدة': CityCoordinates(name: 'جدة', latitude: 21.5433, longitude: 39.1728, defaultMethod: 'umm_al_qura'),
      'الدمام': CityCoordinates(name: 'الدمام', latitude: 26.4207, longitude: 50.0888, defaultMethod: 'umm_al_qura'),
    },
    'EG': {
      'القاهرة': CityCoordinates(name: 'القاهرة', latitude: 30.0444, longitude: 31.2357, defaultMethod: 'egyptian'),
      'الإسكندرية': CityCoordinates(name: 'الإسكندرية', latitude: 31.2001, longitude: 29.9187, defaultMethod: 'egyptian'),
    },
    'AE': {
      'دبي': CityCoordinates(name: 'دبي', latitude: 25.2048, longitude: 55.2708, defaultMethod: 'gulf'),
      'أبوظبي': CityCoordinates(name: 'أبوظبي', latitude: 24.4539, longitude: 54.3773, defaultMethod: 'gulf'),
    },
    'JO': {
      'عمان': CityCoordinates(name: 'عمان', latitude: 31.9522, longitude: 35.8376, defaultMethod: 'umm_al_qura'),
    },
    'PS': {
      'القدس': CityCoordinates(name: 'القدس', latitude: 31.7683, longitude: 35.2137, defaultMethod: 'egyptian'),
      'غزة': CityCoordinates(name: 'غزة', latitude: 31.5000, longitude: 34.4667, defaultMethod: 'egyptian'),
    },
    'KW': {
      'الكويت': CityCoordinates(name: 'الكويت', latitude: 29.3759, longitude: 47.9774, defaultMethod: 'kuwait'),
    },
    'QA': {
      'الدوحة': CityCoordinates(name: 'الدوحة', latitude: 25.2854, longitude: 51.5310, defaultMethod: 'qatar'),
    },
  };

  static Map<String, String> getSupportedCountries() {
    return {
      'YE': 'اليمن',
      'SA': 'المملكة العربية السعودية',
      'EG': 'مصر',
      'AE': 'الإمارات العربية المتحدة',
      'JO': 'الأردن',
      'PS': 'فلسطين',
      'KW': 'الكويت',
      'QA': 'قطر',
    };
  }

  static Map<String, String> getCalculationMethods() {
    return {
      'umm_al_qura': 'تقويم أم القرى (مكة)',
      'egyptian': 'الهيئة المصرية العامة للمساحة',
      'karachi': 'جامعة العلوم الإسلامية بكراتشي',
      'muslim_world_league': 'رابطة العالم الإسلامي',
      'gulf': 'منطقة الخليج العربي',
      'kuwait': 'الكويت',
      'qatar': 'قطر',
    };
  }

  static CalculationParameters _getParams(String method) {
    switch (method) {
      case 'egyptian':
        return CalculationMethod.egyptian.getParameters();
      case 'karachi':
        return CalculationMethod.karachi.getParameters();
      case 'muslim_world_league':
        return CalculationMethod.muslim_world_league.getParameters();
      case 'gulf':
        return CalculationMethod.dubai.getParameters();
      case 'kuwait':
        return CalculationMethod.kuwait.getParameters();
      case 'qatar':
        return CalculationMethod.qatar.getParameters();
      case 'umm_al_qura':
      default:
        return CalculationMethod.umm_al_qura.getParameters();
    }
  }

  static String getPrayerLabel(String prayer) {
    switch (prayer) {
      case 'fajr': return 'الفجر';
      case 'dhuhr': return 'الظهر';
      case 'asr': return 'العصر';
      case 'maghrib': return 'المغرب';
      case 'isha': return 'العشاء';
      default: return prayer;
    }
  }

  static ClassTimes calculateClassTimes(HalaqahSettings settings, DateTime date) {
    // 1. Determine if this date falls in Ramadan
    final hijriDate = HijriCalendar.fromDate(date);
    final isRamadan = settings.isRamadanMode || hijriDate.hMonth == 9;

    // Determine type of timing to use: Ramadan vs Regular
    final currentTimingType = isRamadan
        ? (settings.ramadanTimingType == 'same' ? settings.timingType : settings.ramadanTimingType)
        : settings.timingType;

    // Handle fixed timing
    if (currentTimingType == 'fixed') {
      final startTimeStr = isRamadan ? settings.ramadanStartTime : settings.normalStartTime;
      final endTimeStr = isRamadan ? settings.ramadanEndTime : settings.normalEndTime;

      final startParts = startTimeStr.split(':');
      final endParts = endTimeStr.split(':');

      final startHour = startParts.isNotEmpty ? (int.tryParse(startParts[0]) ?? 16) : 16;
      final startMin = startParts.length > 1 ? (int.tryParse(startParts[1]) ?? 0) : 0;

      final endHour = endParts.isNotEmpty ? (int.tryParse(endParts[0]) ?? 18) : 18;
      final endMin = endParts.length > 1 ? (int.tryParse(endParts[1]) ?? 0) : 0;

      return ClassTimes(
        start: DateTime(date.year, date.month, date.day, startHour, startMin),
        end: DateTime(date.year, date.month, date.day, endHour, endMin),
        isRamadan: isRamadan,
        calculationSource: 'وقت ثابت',
      );
    }

    // Handle relative (prayer-relative) timing
    double latitude = 15.3694; // Sana'a default
    double longitude = 44.1910;
    String method = 'umm_al_qura';

    // Get coordinates from country and city database
    final countryCities = countriesData[settings.country];
    if (countryCities != null && countryCities.containsKey(settings.city)) {
      final cityData = countryCities[settings.city]!;
      latitude = cityData.latitude;
      longitude = cityData.longitude;
      method = settings.calculationMethod;
    } else if (settings.customLatitude != null && settings.customLongitude != null) {
      latitude = settings.customLatitude!;
      longitude = settings.customLongitude!;
      method = settings.calculationMethod;
    }

    try {
      final coordinates = Coordinates(latitude, longitude);
      final dateComponents = DateComponents(date.year, date.month, date.day);
      final params = _getParams(method);
      final prayerTimes = PrayerTimes(coordinates, dateComponents, params);

      // Determine which prayer and offset to use
      final relativePrayer = isRamadan ? settings.ramadanRelativeStartPrayer : settings.relativeStartPrayer;
      final relativeOffset = isRamadan ? settings.ramadanRelativeStartOffset : settings.relativeStartOffset;
      final duration = isRamadan ? settings.ramadanClassDurationMinutes : settings.classDurationMinutes;

      DateTime prayerTimeUtc;
      switch (relativePrayer) {
        case 'fajr':
          prayerTimeUtc = prayerTimes.fajr;
          break;
        case 'dhuhr':
          prayerTimeUtc = prayerTimes.dhuhr;
          break;
        case 'asr':
          prayerTimeUtc = prayerTimes.asr;
          break;
        case 'maghrib':
          prayerTimeUtc = prayerTimes.maghrib;
          break;
        case 'isha':
          prayerTimeUtc = prayerTimes.isha;
          break;
        default:
          prayerTimeUtc = prayerTimes.asr;
      }

      // Convert from UTC to Local time
      final prayerTimeLocal = prayerTimeUtc.toLocal();

      // Apply offset
      final classStart = prayerTimeLocal.add(Duration(minutes: relativeOffset));
      final classEnd = classStart.add(Duration(minutes: duration));

      final offsetSign = relativeOffset >= 0 ? '+' : '';
      final sourceLabel = 'نسبةً إلى صلاة ${getPrayerLabel(relativePrayer)} ($offsetSign$relativeOffset د)';

      return ClassTimes(
        start: classStart,
        end: classEnd,
        isRamadan: isRamadan,
        calculationSource: sourceLabel,
      );
    } catch (e) {
      // Fallback in case of calculation error
      final fallbackHour = isRamadan ? 21 : 16;
      final fallbackDuration = isRamadan ? 90 : 120;
      final classStart = DateTime(date.year, date.month, date.day, fallbackHour, 0);
      return ClassTimes(
        start: classStart,
        end: classStart.add(Duration(minutes: fallbackDuration)),
        isRamadan: isRamadan,
        calculationSource: 'خطأ في الحساب (توقيت افتراضي)',
      );
    }
  }
}
