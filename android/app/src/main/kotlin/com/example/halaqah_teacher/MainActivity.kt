package com.example.halaqah_teacher

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val exchangeChannel = "halaqah/offline_exchange"
    private val pickExchangeFileRequest = 4107
    private var pendingPickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            exchangeChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickHalaqahFile" -> openExchangeFilePicker(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun openExchangeFilePicker(result: MethodChannel.Result) {
        if (pendingPickerResult != null) {
            result.error("picker_busy", "File picker is already open", null)
            return
        }
        pendingPickerResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/octet-stream"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("application/octet-stream", "application/json", "*/*")
            )
        }
        startActivityForResult(intent, pickExchangeFileRequest)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickExchangeFileRequest) return
        val result = pendingPickerResult ?: return
        pendingPickerResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }
        try {
            val source = data.data!!
            val target = File(
                cacheDir,
                "halaqah_exchange_${System.currentTimeMillis()}.halaqah"
            )
            contentResolver.openInputStream(source).use { input ->
                requireNotNull(input) { "Unable to open selected file" }
                target.outputStream().use { output -> input.copyTo(output) }
            }
            result.success(target.absolutePath)
        } catch (error: Exception) {
            result.error("pick_failed", error.message, null)
        }
    }
}
