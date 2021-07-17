import 'package:dmedia/model.dart';
import 'package:dmedia/preference.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:convert';
import 'dart:ui';
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
    print('Native called background task: $task ->' + json.encode(inputData));
    print('Prefs: ' + Preference.getString(settingsAccounts, def: '')!);
    emit(task, {'Test': 123, 'ABC': 123});
    return Future.value(true);
  });
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
}
