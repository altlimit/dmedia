package com.example.dmedia

import android.util.Log
import android.content.Intent
import android.content.ClipData
import android.os.Bundle
import androidx.annotation.NonNull
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
  private val LOGTAG = "DMEDIA"
  private val CHANNEL = "org.altlimit.dmedia/native"
  private var intentAction: String? = null

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
      call, result ->
      when (call.method) {
        "getIntentAction" -> 
          result.success(intentAction)            
        "setResult" -> {
          val path: String? = call.argument("path")
          val paths: Array<String>? = call.argument("paths")
          if (path != null || paths != null) {
              try {
                  val intent = Intent()
                  val context = getApplicationContext();
                  val provider = context.getPackageName() + ".provider"
                  if (paths != null) {
                    val clipData = ClipData.newRawUri(null, FileProvider.getUriForFile(context, provider, File(path)))
                    for (i in 1 until paths.size)
                      clipData.addItem(ClipData.Item(FileProvider.getUriForFile(context, provider, File(paths[i]))))
                    intent.setClipData(clipData)
                  } else
                    intent.setData(FileProvider.getUriForFile(context, provider, File(path)))                  
                  intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                  setResult(RESULT_OK, intent)
              } catch (e: Exception) {
                  result.error("failed", "Error: $e", null)
                  setResult(RESULT_CANCELED)
              }
              finish()
          }                
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
  }

  override fun onCreate(bundle: Bundle?) {
    super.onCreate(bundle)
    updateIntentAction(getIntent())
    log("onCreate: IntentAction $intentAction")
  }

  override fun onNewIntent(intent: Intent) {
      super.onNewIntent(intent)
      updateIntentAction(intent)
      log("onNewIntent: IntentAction $intentAction")
  }  

  private fun updateIntentAction(intent: Intent) {
    val intent = getIntent()
    intentAction = intent.getAction()
    if (intent.getBooleanExtra(Intent.EXTRA_ALLOW_MULTIPLE, false))
      intentAction += "|MULTIPLE"
    if (intentAction != null && intent.getType() != null)
      intentAction += "|" + intent.getType();
  }

  private fun log(message: String) {
    Log.d(LOGTAG, message)
  }
}
