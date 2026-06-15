import 'package:flutter/services.dart';

class SoundService {
  static const _channel = MethodChannel('com.tahdir/sound');

  static Future<void> playSuccess() async {
    try {
      await _channel.invokeMethod('playSuccess');
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static Future<void> playError() async {
    try {
      await _channel.invokeMethod('playError');
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  static Future<void> playWarning() async {
    try {
      await _channel.invokeMethod('playWarning');
      HapticFeedback.lightImpact();
    } catch (_) {}
  }
}
