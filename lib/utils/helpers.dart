import 'package:flutter/widgets.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

class Helpers {
  static String formatHijriDate(DateTime date) {
    final hijri = HijriCalendar.fromDate(date);
    return '${hijri.hDay}/${hijri.hMonth}/${hijri.hYear}';
  }

  static String formatGregorianDate(DateTime date) {
    return DateFormat('yyyy/MM/dd').format(date);
  }

  static String formatTime(DateTime time, {String format = '12h', BuildContext? context}) {
    bool use24 = false;
    if (format == '24h') {
      use24 = true;
    } else if (format == 'device') {
      if (context != null) {
        use24 = MediaQuery.alwaysUse24HourFormatOf(context);
      }
    }
    
    if (use24) {
      return DateFormat('HH:mm').format(time);
    } else {
      final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
      final minute = time.minute.toString().padLeft(2, '0');
      final period = time.hour >= 12 ? 'م' : 'ص';
      return '$hour:$minute $period';
    }
  }

  static String getHijriMonthName(int month) {
    const months = [
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الثاني',
      'جمادى الأولى',
      'جمادى الآخرة',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة',
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }

  static String getFullHijriDate(DateTime date) {
    final hijri = HijriCalendar.fromDate(date);
    return '${hijri.hDay} ${getHijriMonthName(hijri.hMonth)} ${hijri.hYear}هـ';
  }

  static String getDayName(DateTime date) {
    const days = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return days[date.weekday - 1];
  }

  static int calculateLines(int ayahCount) {
    return (ayahCount / 2.5).ceil();
  }

  static double calculatePages(int ayahCount) {
    return ayahCount / 15 / 2.5;
  }

  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 30) {
      return formatHijriDate(date);
    } else if (diff.inDays > 0) {
      return 'منذ ${diff.inDays} يوم';
    } else if (diff.inHours > 0) {
      return 'منذ ${diff.inHours} ساعة';
    } else if (diff.inMinutes > 0) {
      return 'منذ ${diff.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  static List<DateTime> getWeekDays(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
  }

  static int getConsecutiveAbsenceDays(List<DateTime> absenceDates) {
    if (absenceDates.isEmpty) return 0;
    
    absenceDates.sort((a, b) => b.compareTo(a));
    int count = 1;
    
    for (int i = 1; i < absenceDates.length; i++) {
      final diff = absenceDates[i - 1].difference(absenceDates[i]).inDays;
      if (diff == 1) {
        count++;
      } else {
        break;
      }
    }
    
    return count;
  }

  static String getHijriMonth(DateTime date) {
    final hijri = HijriCalendar.fromDate(date);
    return '${getHijriMonthName(hijri.hMonth)} ${hijri.hYear}هـ';
  }
}

class GenderHelper {
  static String student(String gender) => gender == 'female' ? 'طالبة' : 'طالب';
  static String students(String gender) => gender == 'female' ? 'الطالبات' : 'الطلاب';
  static String addStudent(String gender) => gender == 'female' ? 'إضافة طالبة' : 'إضافة طالب';
  static String editStudent(String gender) => gender == 'female' ? 'تعديل طالبة' : 'تعديل طالب';
  static String studentName(String gender) => gender == 'female' ? 'اسم الطالبة' : 'اسم الطالب';
  static String studentPhone(String gender) => gender == 'female' ? 'رقم جوال الطالبة' : 'رقم جوال الطالب';
  static String siblingRelation(String gender) => gender == 'female' ? 'أخت لـ' : 'أخ لـ';
  
  static String present(String gender) => gender == 'female' ? 'حاضرة' : 'حاضر';
  static String absent(String gender) => gender == 'female' ? 'غائبة' : 'غائب';
  static String excused(String gender) => gender == 'female' ? 'مستأذنة' : 'مستأذن';
  static String arrivalWord(String gender) => gender == 'female' ? 'وصلت' : 'وصل';
  static String lateWord(String gender) => gender == 'female' ? 'متأخرة' : 'متأخر';
  static String remaining(String gender) => gender == 'female' ? 'متبقية' : 'متبقي';
}
