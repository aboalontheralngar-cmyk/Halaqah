import 'package:flutter/material.dart';
import 'theme.dart';
import '../screens/home/home_screen.dart';

class HalaqahApp extends StatelessWidget {
  const HalaqahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حلقتي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      locale: const Locale('ar'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const HomeScreen(),
    );
  }
}
