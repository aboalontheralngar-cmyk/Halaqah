class AppConstants {
  static const String appName = 'حلقتي';
  static const String appVersion = '1.0.0';
  
  static const String encryptionKey = 'HalaqahApp2024SecretKey!';
  
  static const int defaultAbsenceDaysBeforeWarning = 2;
  static const int defaultAbsenceDaysBeforeExpulsion = 7;
  
  static const Map<String, int> defaultPoints = {
    'dailyMemorization': 5,
    'extraMemorization': 2,
    'earlyAttendance': 2,
    'revisionComplete': 3,
    'monthlyExamPass': 10,
    'goodAppearance': 1,
    'latePenalty': -2,
    'incompletePenalty': -3,
    'unexcusedAbsence': -5,
    'appearanceViolation': -3,
  };
}

class PlanType {
  static const String ayahs = 'ayahs';
  static const String lines = 'lines';
  static const String pages = 'pages';
  
  static String getLabel(String type) {
    switch (type) {
      case ayahs:
        return 'آيات';
      case lines:
        return 'أسطر';
      case pages:
        return 'صفحات';
      default:
        return type;
    }
  }
}

class AttendanceStatus {
  static const String present = 'present';
  static const String late = 'late';
  static const String absent = 'absent';
  static const String excused = 'excused';
  
  static String getLabel(String status) {
    switch (status) {
      case present:
        return 'حاضر';
      case late:
        return 'متأخر';
      case absent:
        return 'غائب';
      case excused:
        return 'معذور';
      default:
        return status;
    }
  }
}

class AbsenceReason {
  static const String sick = 'sick';
  static const String work = 'work';
  static const String noExcuse = 'no_excuse';
  static const String other = 'other';
  
  static String getLabel(String reason) {
    switch (reason) {
      case sick:
        return 'مرض';
      case work:
        return 'عمل/ظرف';
      case noExcuse:
        return 'بدون عذر';
      case other:
        return 'أخرى';
      default:
        return reason;
    }
  }
}

class StudentStatus {
  static const String active = 'active';
  static const String suspended = 'suspended';
  static const String expelled = 'expelled';
  static const String graduated = 'graduated';
  
  static String getLabel(String status) {
    switch (status) {
      case active:
        return 'نشط';
      case suspended:
        return 'موقوف';
      case expelled:
        return 'مفصول';
      case graduated:
        return 'متخرج';
      default:
        return status;
    }
  }
}

class BehaviorType {
  static const String positive = 'positive';
  static const String negative = 'negative';
  static const String appearance = 'appearance';
}

class QualityRating {
  static const int excellent = 4;
  static const int veryGood = 3;
  static const int good = 2;
  static const int acceptable = 1;
  
  static String getLabel(int rating) {
    switch (rating) {
      case excellent:
        return 'ممتاز';
      case veryGood:
        return 'جيد جداً';
      case good:
        return 'جيد';
      case acceptable:
        return 'مقبول';
      default:
        return 'غير محدد';
    }
  }
}
