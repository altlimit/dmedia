import 'package:dmedia/models.dart';
import 'package:dmedia/util.dart';
import 'package:dmedia/client.dart';
import 'package:dmedia/preference.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'dart:isolate';

const bgChannelName = 'org.altlimit.dmedia';

void callbackDispatcher() {
  final sendPort = IsolateNameServer.lookupPortByName(bgChannelName);

  var emit = (String task, dynamic data) {
    if (sendPort != null) {
      sendPort.send({'task': task, 'data': data});
    }
  };

  Workmanager().executeTask((task, inputData) async {
    await Preference.load();
    var success = true;
    Util.debug('Background task: $task ->' + json.encode(inputData));
    try {
      switch (task) {
        case taskSync:
          await Tasks.syncDirectories((d) => emit(task, d));
          break;
      }
    } on Exception catch (e) {
      success = false;
      Util.debug('FailedTask: ' + e.toString());
    }
    return success;
  });
}

class Tasks {
  static Future<void> syncDirectories(Function(dynamic) emit) async {
    for (var entry in Util.getAllAccountSettings().entries) {
      var account = Util.getAccount(entry.key);
      if (account != null) {
        var client = Client(account);
        for (var folder in entry.value.folders) {
          Util.debug('Syncing ${entry.key} / $folder');
          var dir = Directory(folder);
          var files = await dir.list().toList();
          for (var file in files) {
            var id = await client.upload(file.path);
            if (id > 0) {
              Util.debug('Uploaded: $file -> $id');
              await file.delete();
            }
          }
        }
      }
    }
    emit({'message': 'Sync completed'});
  }
}

class Bg {
  static bool isListening = false;
  static bool isInitialized = false;
  static Map<String, Map<String, Function(dynamic)>> callbacks = {};

  static Future<void> init() async {
    if (isInitialized) return;
    isInitialized = true;
    await Workmanager()
        .initialize(callbackDispatcher, isInDebugMode: !isRelease);
  }

  static void listen() {
    if (isListening) return;
    var port = ReceivePort();
    if (IsolateNameServer.registerPortWithName(port.sendPort, bgChannelName)) {
      isListening = true;
      port.listen((dynamic data) async {
        Map<String, dynamic> recv = data;
        if (recv.containsKey('task') &&
            callbacks.containsKey(recv['task']) &&
            recv.containsKey('data'))
          callbacks[recv['task']]!.values.forEach((cb) => cb(recv['data']));
      });
    }
  }

  static void on(String taskName, String name, Function(dynamic) cb) {
    listen();
    if (!callbacks.containsKey(taskName)) callbacks[taskName] = {};
    callbacks[taskName]![name] = cb;
  }

  static void off(String taskName, {String? name}) {
    if (callbacks.containsKey(taskName)) {
      if (name == null)
        callbacks.remove(taskName);
      else if (callbacks[taskName]!.containsKey(name))
        callbacks[taskName]!.remove(name);
    }
  }

  static Future<Workmanager> manager() async {
    await init();
    return Workmanager();
  }

  static Future<void> scheduleTask(String id, String taskName,
      {bool isOnce = false, Constraints? constraints}) async {
    await init();
    var wm = Workmanager();
    var m = isOnce ? wm.registerOneOffTask : wm.registerPeriodicTask;
    await wm.cancelByUniqueName(id);
    await m(id, taskName, constraints: constraints);
  }
}
