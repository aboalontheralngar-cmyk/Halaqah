import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/app.dart';
import 'services/database_service.dart';
import 'services/quran_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await QuranService.instance.initialize();
  
  // Load saved theme settings from DB
  final db = DatabaseService();
  try {
    final settings = await db.getSettings();
    themeNotifier.value = settings.theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
  } catch (e) {
    // Fail silently, default remains light
  }
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const HalaqahApp());
}
