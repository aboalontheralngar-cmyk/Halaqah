import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryLight = Color(0xFF0D9488); // Teal 600
  static const Color primaryDark = Color(0xFF14B8A6);  // Teal 500
  
  static const Color accentLight = Color(0xFFF43F5E);  // Rose 500
  static const Color accentDark = Color(0xFFFB7185);   // Rose 400

  // Background and Surfaces
  static const Color bgLight = Color(0xFFF8FAFC);      // Slate 50
  static const Color bgDark = Color(0xFF0F172A);       // Slate 900
  
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1E293B);     // Slate 800

  // Text Colors
  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate 900
  static const Color textSecondaryLight = Color(0xFF475569); // Slate 600
  static const Color textPrimaryDark = Color(0xFFF8FAFC);   // Slate 50
  static const Color textSecondaryDark = Color(0xFF94A3B8);  // Slate 400

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryLight,
      scaffoldBackgroundColor: bgLight,
      colorScheme: const ColorScheme.light(
        primary: primaryLight,
        secondary: Color(0xFF0F766E),
        tertiary: accentLight,
        background: bgLight,
        surface: cardLight,
        error: Color(0xFFEF4444),
      ),
      textTheme: GoogleFonts.tajawalTextTheme(
        ThemeData.light().textTheme.copyWith(
          titleLarge: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(color: textPrimaryLight),
          bodyMedium: TextStyle(color: textSecondaryLight),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: bgLight,
        foregroundColor: textPrimaryLight,
        iconTheme: const IconThemeData(color: textPrimaryLight),
        titleTextStyle: GoogleFonts.tajawal(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimaryLight,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1), // Slate 200
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.tajawal(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryLight,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryLight,
        unselectedItemColor: Color(0xFF64748B), // Slate 500
        backgroundColor: cardLight,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: const TextStyle(fontSize: 12),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryDark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryDark,
        secondary: Color(0xFF2DD4BF),
        tertiary: accentDark,
        background: bgDark,
        surface: cardDark,
        error: Color(0xFFF87171),
      ),
      textTheme: GoogleFonts.tajawalTextTheme(
        ThemeData.dark().textTheme.copyWith(
          titleLarge: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(color: textPrimaryDark),
          bodyMedium: TextStyle(color: textSecondaryDark),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: bgDark,
        foregroundColor: textPrimaryDark,
        iconTheme: const IconThemeData(color: textPrimaryDark),
        titleTextStyle: GoogleFonts.tajawal(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF334155), width: 1), // Slate 700
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: bgDark,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.tajawal(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF475569), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryDark, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryDark,
        foregroundColor: bgDark,
        elevation: 4,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryDark,
        unselectedItemColor: Color(0xFF64748B),
        backgroundColor: cardDark,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: const Color(0xFF1E293B),
        labelStyle: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class AppColors {
  static const Color present = Color(0xFF10B981);    // Emerald 500
  static const Color late = Color(0xFFF59E0B);       // Amber 500
  static const Color absent = Color(0xFFEF4444);     // Red 500
  static const Color excused = Color(0xFF3B82F6);    // Blue 500
  
  static const Color excellent = Color(0xFF10B981);
  static const Color veryGood = Color(0xFF84CC16);   // Lime 500
  static const Color good = Color(0xFFEAB308);       // Yellow 500
  static const Color acceptable = Color(0xFFF97316); // Orange 500
  static const Color weak = Color(0xFFEF4444);

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
