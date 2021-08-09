import 'dart:async';

import 'package:flutter/services.dart';

class Saf {
  static const MethodChannel _channel = const MethodChannel('saf');

  static Future<String?> openFolderPicker() async {
    final String? path = await _channel.invokeMethod('folderPicker');
    return path;
  }

  static Future<bool> deleteFile(String path) async {
    return await _channel.invokeMethod('removeFile', {'path': path});
  }
}
