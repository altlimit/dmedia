import 'package:flutter/material.dart';
import 'package:dmedia/models.dart';
import 'package:dmedia/util.dart';
import 'package:dmedia/client.dart';
import 'package:dmedia/preference.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'dart:isolate';

const bgChannelName = 'org.altlimit.dmedia';

void callbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
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
          await Tasks.syncDirectories(
              inputData!['accountId'], (d) => emit(task, d));
          break;
        case taskDelete:
          await Tasks.deleteBackedUp(
              inputData!['accountId'], (d) => emit(task, d));
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
  static Future<void> syncDirectories(
      int accountId, Function(dynamic) emit) async {
    final account = Util.getAccount(accountId);
    final accountSettings = Util.getAccountSettings(internalId: accountId);
    Util.debug('${account} -> $accountSettings');
    if (accountSettings == null) {
      Workmanager().cancelByUniqueName(accountId.toString());
      return;
    }
    final syncedDir = (await Util.getSyncDir(accountId)).path;
    var uploaded = 0;
    var uploadedBytes = 0;
    var maxModified =
        accountSettings.lastSync == null ? 0 : accountSettings.lastSync!;
    if (account != null) {
      var client = Client(account);
      await client.init();
      for (var folder in accountSettings.folders) {
        Util.debug('Syncing ${accountId} / $folder');
        var dir = Directory(folder);
        final List<String> toUpload = [];
        await dir.list().forEach((file) async {
          final stat = await file.stat();
          final lastMod = stat.modified.millisecondsSinceEpoch;
          // skip backed up files
          if (accountSettings.lastSync != null &&
              accountSettings.lastSync! >= lastMod) return;
          toUpload.add(file.path);
          if (maxModified < lastMod) maxModified = lastMod;
        });
        for (final file in toUpload) {
          Util.debug('Uploading: $file');
          var fileSize = 0;
          var result = await client.upload(file, onStat: (stat) {
            fileSize = stat.size;
          }, onProgress: (progress, _, received, total) async {
            if (accountSettings.notify)
              await Util.showProgressNotify(
                  'taskProgress', 100, progress, accountId,
                  title: '${p.basename(file)}',
                  body:
                      '${Util.formatBytes(received, 2)}/${Util.formatBytes(total, 2)} - ${progress}%');
          });
          if (result != null && result is int) {
            final int id = result;
            uploadedBytes += fileSize;
            uploaded++;
            Util.debug('Uploaded: $id');
            if (accountSettings.delete) {
              if (!(await Util.deleteFile(file))) {
                Util.debug('FailedDelete: $file');
              }
            } else
              await File(p.join(syncedDir, '$id.txt')).writeAsString(file);
          } else {
            Util.debug('Skipped: $result');
          }
        }
      }
      if (accountSettings.lastSync == null ||
          accountSettings.lastSync != maxModified) {
        accountSettings.lastSync = maxModified;
        Util.saveAccountSettings(accountSettings, internalId: accountId);
      }
      if (accountSettings.notify && uploaded > 0) {
        await Future.delayed(Duration(seconds: 1));
        final notify = await Util.getLocalNotify();
        notify.show(
            account.id,
            'Sync Completed',
            '${account} synced $uploaded files (${Util.formatBytes(uploadedBytes, 2)})',
            NotificationDetails(
                android: AndroidNotificationDetails('syncDirectories',
                    'syncDirectories', 'Background process syncDirectories',
                    showWhen: true)));
      }
    }
    emit({'message': 'Sync completed'});
  }

  static Future<void> deleteBackedUp(
      int accountId, Function(dynamic) emit) async {
    final accountSettings = Util.getAccountSettings(internalId: accountId);
    if (accountSettings == null) {
      Workmanager().cancelByUniqueName(accountId.toString());
      return;
    }
    final syncedDir = (await Util.getSyncDir(accountId));
    var deleted = 0;
    var deletedBytes = 0;
    final files = await syncedDir.list().toList();
    for (final file in files) {
      final path = await File(file.path).readAsString();
      final mediaFile = File(path);
      Util.debug('Deleting ${file.path} -> $path');
      if (await mediaFile.exists()) {
        final stat = await mediaFile.stat();
        if (await Util.deleteFile(mediaFile.path)) {
          deleted++;
          deletedBytes += stat.size;
        } else
          Util.debug('DeleteFailed: $path');
      }
      await file.delete();
    }

    if (accountSettings.notify && deleted > 0) {
      final account = Util.getAccount(accountId);
      final notify = await Util.getLocalNotify();
      notify.show(
          accountId,
          'Delete Completed',
          '${account} deleted $deleted files (${Util.formatBytes(deletedBytes, 2)})',
          NotificationDetails(
              android: AndroidNotificationDetails(
                  'deleteTask', 'deleteTask', 'Background process deleteTask',
                  showWhen: true)));
    }
    emit({'message': 'Delete completed'});
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
      port.listen((dynamic data) {
        emit(data);
      });
    }
  }

  static void emit(dynamic data) {
    Map<String, dynamic> recv = data;
    if (recv.containsKey('task') &&
        callbacks.containsKey(recv['task']) &&
        recv.containsKey('data'))
      callbacks[recv['task']]!.values.forEach((cb) => cb(recv['data']));
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
      {bool isOnce = false,
      Constraints? constraints,
      Map<String, dynamic>? input}) async {
    await init();
    var wm = Workmanager();
    var m = isOnce ? wm.registerOneOffTask : wm.registerPeriodicTask;
    await wm.cancelByUniqueName(id);
    await m(id, taskName, constraints: constraints, inputData: input);
  }

  static Future cancelTask(String id) async {
    await Workmanager().cancelByUniqueName(id);
  }
}
