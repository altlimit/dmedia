package com.example.dmedia

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import android.os.Bundle
import android.content.Intent
import android.util.Log
import java.io.File
import android.provider.DocumentsContract;
import com.anggrayudi.storage.SimpleStorageHelper
import com.anggrayudi.storage.file.DocumentFileCompat
import com.anggrayudi.storage.file.getAbsolutePath


class MainActivity: FlutterActivity() {
  private val REQUEST_CODE_STORAGE_ACCESS = 1
  private val CHANNEL = "org.altlimit.dmedia"
  private val LOGTAG = "DMEDIA";

  private lateinit var storageHelper: SimpleStorageHelper
  private var storageResult: MethodChannel.Result? = null;

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
        
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
      call, result ->
      if (call.method == "removeFile") {
        val path: String? = call.argument("path");
        if (path != null)
          result.success(removeFile(path));
        else
          result.error("path error", "path not provided", null);
      } else if (call.method == "folderPicker") {
        if (storageResult != null)
          storageResult?.success(null);
        storageResult = null;
        storageHelper.openFolderPicker();        
        storageResult = result;
      } else {
        result.notImplemented()
      }
    }
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    storageHelper = SimpleStorageHelper(this, REQUEST_CODE_STORAGE_ACCESS, savedInstanceState)
    storageHelper.onFolderSelected = { _, folder ->
      storageResult?.success(folder.getAbsolutePath(getApplicationContext()));
      storageResult = null;
    }
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent) {
    super.onActivityResult(requestCode, resultCode, data)
    storageHelper.storage.onActivityResult(requestCode, resultCode, data)
  }

  override fun onSaveInstanceState(outState: Bundle) {
      storageHelper.onSaveInstanceState(outState)
      super.onSaveInstanceState(outState)
  }

  override fun onRestoreInstanceState(savedInstanceState: Bundle) {
      super.onRestoreInstanceState(savedInstanceState)
      storageHelper.onRestoreInstanceState(savedInstanceState)
  }

  override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    storageHelper.onRequestPermissionsResult(requestCode, permissions, grantResults)
  }  

  private fun removeFile(path: String): Boolean {
    val context = getApplicationContext();
    val file = DocumentFileCompat.fromFullPath(context, path, requiresWriteAccess = true);
    if (file != null) {
      return file.delete();
    }
    return false;
  }

  private fun log(message: String) {
    Log.d(LOGTAG, message);
  }
}
