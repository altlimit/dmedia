package com.example.dmedia

import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
  private val LOGTAG = "DMEDIA";
  private val CHANNEL = "org.altlimit.dmedia/native"

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
      call, result ->
      if (call.method == "nativeMethod") {
        log("Called: " + call.method)
      } else {
        result.notImplemented()
      }
    }
  }

  private fun log(message: String) {
    Log.d(LOGTAG, message);
  }
}
