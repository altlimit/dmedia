package org.altlimit.saf

import androidx.annotation.NonNull

import android.app.Activity;
import android.content.Context;
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry;

import android.util.Log
import android.os.Bundle
import android.content.Intent
import com.anggrayudi.storage.SimpleStorageHelper
import com.anggrayudi.storage.file.DocumentFileCompat
import com.anggrayudi.storage.file.getAbsolutePath


/** SafPlugin */
class SafPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener,
  ActivityPluginBinding.OnSaveInstanceStateListener {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private val REQUEST_CODE_STORAGE_ACCESS = 1
  private lateinit var channel : MethodChannel
  private lateinit var storageHelper: SimpleStorageHelper
  private lateinit var context: Context
  private lateinit var activity: Activity
  private lateinit var activityBinding: ActivityPluginBinding 
  private var storageResult: MethodChannel.Result? = null;

  private val LOGTAG = "SAF";

  private fun log(message: String) {
    Log.d(LOGTAG, message);
  }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "saf")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
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

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onDetachedFromActivity() {
    activityBinding.removeActivityResultListener(this);
    activityBinding.removeOnSaveStateListener(this);
}

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
      activity = binding.getActivity();
      activityBinding = binding
      storageHelper = SimpleStorageHelper(activity, REQUEST_CODE_STORAGE_ACCESS, null)
      storageHelper.onFolderSelected = { _, folder ->
        storageResult?.success(folder.getAbsolutePath(context));
        storageResult = null;
      }

      binding.addActivityResultListener(this);
      binding.addOnSaveStateListener(this);
    }

  override fun onDetachedFromActivityForConfigChanges() {
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent): Boolean {
    // super.onActivityResult(requestCode, resultCode, data)
    storageHelper.storage.onActivityResult(requestCode, resultCode, data)
    return true
  }

  override fun onSaveInstanceState(outState: Bundle) {
      storageHelper.onSaveInstanceState(outState)
      // super.onSaveInstanceState(outState)
  }

  override fun onRestoreInstanceState(savedInstanceState: Bundle?) {
      // super.onRestoreInstanceState(savedInstanceState)
      if (savedInstanceState != null)
        storageHelper.onRestoreInstanceState(savedInstanceState)
  }
  
  private fun removeFile(path: String): Boolean {
    val file = DocumentFileCompat.fromFullPath(context, path, requiresWriteAccess = true);
    if (file != null) {
      return file.delete();
    }
    return false;
  }  
}
