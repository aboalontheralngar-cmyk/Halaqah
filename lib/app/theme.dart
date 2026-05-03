import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF00796B);
  static const Color primaryColorLight = Color(0xFF48A999);
  static const Color primaryColorDark = Color(0xFF004C40);
  static const Color accentColor = Color(0xFFFFB74D);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF388E3C);
  static const Color warningColor = Color(0xFFF57C00);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color surfaceColor = Colors.white;
  static const Color textPrimaryColor = Color(0xFF212121);
  static const Color textSecondaryColor = Color(0xFF757575);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      fontFamily: 'Tajawal',
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerTheme: const DividerThemeData(
        space: 1,
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
      ),
      fontFamily: 'Tajawal',
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class AppColors {
  static const Color present = Color(0xFF4CAF50);
  static const Color late = Color(0xFFFF9800);
  static const Color absent = Color(0xFFF44336);
  static const Color excused = Color(0xFF2196F3);
  
  static const Color excellent = Color(0xFF4CAF50);
  static const Color veryGood = Color(0xFF8BC34A);
  static const Color good = Color(0xFFFFEB3B);
  static const Color acceptable = Color(0xFFFF9800);
  static const Color weak = Color(0xFFF44336);

  static Color getAttendanceColor(String status) {
    switch (status) {
      case 'present':
        return present;
      case 'late':
        return late;
      case 'absent':
        return absent;
      case 'excused':
        return excused;
      default:
        return Colors.grey;
    }
  }

  static Color getScoreColor(int score) {
    if (score >= 90) return excellent;
    if (score >= 80) return veryGood;
    if (score >= 70) return good;
    if (score >= 60) return acceptable;
    return weak;
  }

  static Color getQualityColor(int rating) {
    switch (rating) {
      case 4:
        return excellent;
      case 3:
        return veryGood;
      case 2:
        return good;
      case 1:
        return acceptable;
      default:
        return Colors.grey;
    }
  }
}
