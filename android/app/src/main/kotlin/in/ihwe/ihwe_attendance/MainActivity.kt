package `in`.ihwe.ihwe_attendance

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val fileChannel = "ihwe_attendance/files"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, fileChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveToDownloads") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    result.error("UNSUPPORTED_ANDROID", "Public Downloads requires Android 10 or newer.", null)
                    return@setMethodCallHandler
                }
                val filename = call.argument<String>("filename")
                val bytes = call.argument<ByteArray>("bytes")
                if (filename.isNullOrBlank() || bytes == null || bytes.isEmpty()) {
                    result.error("INVALID_FILE", "The exported Excel file is empty.", null)
                    return@setMethodCallHandler
                }
                try {
                    val values = ContentValues().apply {
                        put(MediaStore.Downloads.DISPLAY_NAME, filename)
                        put(MediaStore.Downloads.MIME_TYPE, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
                        put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/IHWE Attendance")
                        put(MediaStore.Downloads.IS_PENDING, 1)
                    }
                    val resolver = applicationContext.contentResolver
                    val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                        ?: throw IllegalStateException("Android could not create the download file.")
                    resolver.openOutputStream(uri)?.use { output -> output.write(bytes) }
                        ?: throw IllegalStateException("Android could not open the download file.")
                    values.clear()
                    values.put(MediaStore.Downloads.IS_PENDING, 0)
                    resolver.update(uri, values, null, null)
                    result.success("Downloads/IHWE Attendance/$filename")
                } catch (error: Exception) {
                    result.error("SAVE_FAILED", error.message ?: "Excel download failed.", null)
                }
            }
    }
}
