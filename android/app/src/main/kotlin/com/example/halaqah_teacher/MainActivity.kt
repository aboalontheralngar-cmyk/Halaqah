package com.example.halaqah_teacher

import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.tahdir/sound"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playSuccess" -> {
                        playTone(ToneGenerator.TONE_PROP_ACK, 150)
                        result.success(null)
                    }
                    "playError" -> {
                        playTone(ToneGenerator.TONE_PROP_NACK, 300)
                        result.success(null)
                    }
                    "playWarning" -> {
                        playTone(ToneGenerator.TONE_PROP_PROMPT, 200)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun playTone(toneType: Int, durationMs: Int) {
        try {
            val toneGenerator = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100)
            toneGenerator.startTone(toneType, durationMs)
            android.os.Handler(mainLooper).postDelayed({
                toneGenerator.release()
            }, (durationMs + 50).toLong())
        } catch (e: Exception) {
            // Silently handle audio errors
        }
    }
}
