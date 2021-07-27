import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dmedia/models.dart';
import 'package:dmedia/client.dart';
import 'package:dmedia/preference.dart';

class Util {
  static Map<int, Client> Clients = {};

  static void debug(Object msg) {
    if (!isRelease) print(msg);
  }

  static void showMessage(BuildContext context, String message) {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  static Function showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );

    return () => Navigator.pop(context);
  }

  static Future<void> runSingleInstance(String key, Function callback) async {
    var tmpPath = await getTemporaryDirectory();
    var lockPath = Directory(p.join(tmpPath.path, 'locks'));
    lockPath.create(recursive: true);
    var lockFile = File(p.join(lockPath.path, key + '.lock'));
    if (!(await lockFile.exists())) await lockFile.create();
    var raf = await lockFile.open(mode: FileMode.write);
    await raf.lock(FileLock.exclusive);
    callback();
    var f = await File(lockFile.path).open(mode: FileMode.write);
    await f.lock(FileLock.exclusive);
    await raf.close();
  }

  static Future<void> chooseDirectory(
      BuildContext context, Function(Directory) onSelect) async {
    if (await Permission.storage.request().isGranted) {
      var dirs = await getExternalStorageDirectories();
      if (dirs != null) {
        Function(String) dirSelector = (storagePath) async {
          var path = await FilesystemPicker.open(
            title: 'Select Folder',
            context: context,
            rootDirectory: Directory(storagePath),
            fsType: FilesystemType.folder,
            pickText: 'Choose Directory',
            folderIconColor: Colors.teal,
          );
          if (path != null) {
            var dir = Directory(path);
            print('Dir: ' +
                json.encode(
                    dir.listSync().map((d) => d.path.toString()).toList()));
            onSelect(dir);
          }
        };

        var storageOptions = dirs
            .map((d) => d.path.substring(0, d.path.indexOf('/Android/')))
            .toList();
        if (storageOptions.length == 1)
          await dirSelector(storageOptions[0]);
        else
          dialogList(context, "Select Storage", storageOptions,
              (_, selected) async {
            await dirSelector(selected);
          });
      }
    }
  }

  static String dateTimeToString(DateTime dt) {
    return dateTimeFormat.format(dt);
  }

  static DateTime StringToDateTime(String dt) {
    return dateTimeFormat.parse(dt);
  }

  static Future<Directory> getSyncDir(int internalId) async {
    final tmpDir = await getApplicationDocumentsDirectory();
    final dir =
        Directory(p.join(tmpDir.path, 'synced_' + internalId.toString()));
    // await dir.delete(recursive: true);
    await dir.create();
    return dir;
  }

  static Client getClient({int? internalId}) {
    if (internalId == null) internalId = getActiveAccountId();
    if (!Clients.containsKey(internalId)) {
      Clients[internalId] = Client(getAccount(internalId)!);
    }
    return Clients[internalId]!;
  }

  static Map<int, Account> getAccounts() {
    Map<String, dynamic> accounts =
        Preference.getJson(settingsAccounts, def: {});
    return accounts
        .map((key, value) => MapEntry(int.parse(key), Account.fromJson(value)));
  }

  static Account? getAccount(int internalId) {
    var accounts = getAccounts();
    return accounts[internalId];
  }

  static Account? getActiveAccount() {
    return getAccount(getActiveAccountId());
  }

  static int getActiveAccountId() {
    return Preference.getInt(settingsAccount, def: 0)!;
  }

  static void setActiveAccountId(int internalId) {
    Preference.setInt(settingsAccount, internalId);
  }

  static void delAccount(int internalId) {
    var accounts = getAccounts();
    if (accounts.containsKey(internalId)) accounts.remove(internalId);
    saveObjectPref(settingsAccounts, accounts);
  }

  static void saveObjectPref(String key, Map<int, dynamic> data) {
    Preference.setJson(key, data.map((k, v) => MapEntry(k.toString(), v)));
  }

  static int saveAccount(Account account, {int? internalId}) {
    var accounts = getAccounts();

    if (internalId == null) {
      internalId = Preference.getInt(settingsIdCounter, def: 1)!;
      Preference.setInt(settingsIdCounter, internalId + 1);
    }
    accounts[internalId] = account;
    saveObjectPref(settingsAccounts, accounts);
    return internalId;
  }

  static Map<int, AccountSettings> getAllAccountSettings() {
    Map<String, dynamic> result =
        Preference.getJson(settingsAccountSettings, def: {});
    return result.map((key, value) =>
        MapEntry(int.parse(key), AccountSettings.fromJson(value)));
  }

  static AccountSettings? getAccountSettings({int? internalId}) {
    if (internalId == null) internalId = getActiveAccountId();
    var settings = getAllAccountSettings();
    return settings[internalId];
  }

  static void delAccountSettings(int internalId) {
    var settings = getAllAccountSettings();
    if (settings.containsKey(internalId)) settings.remove(internalId);
    saveObjectPref(settingsAccountSettings, settings);
  }

  static void saveAccountSettings(AccountSettings accountSettings,
      {int? internalId}) {
    if (internalId == null) internalId = getActiveAccountId();
    var settings = getAllAccountSettings();
    settings[internalId] = accountSettings;
    saveObjectPref(settingsAccountSettings, settings);
  }

  static void confirmDialog(BuildContext context, Function() onConfirm,
      {String message = 'Are you sure?'}) {
    showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            content: new Text(message),
            actions: <Widget>[
              new ElevatedButton(
                child: new Text("No"),
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
              ),
              new ElevatedButton(
                child: new Text("Yes"),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onConfirm();
                },
              ),
            ],
          );
        });
  }

  static void inputDialog(
      BuildContext context, String title, Function(String) onValue,
      {String? hint, String? def, TextInputType? inputType}) async {
    final controller = TextEditingController(text: def != null ? def : "");
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: inputType,
            decoration: InputDecoration(hintText: hint),
          ),
          actions: <Widget>[
            ElevatedButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            ElevatedButton(
              child: Text('Ok'),
              onPressed: () {
                onValue(controller.text);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  static void dialogList(BuildContext context, String title,
      List<String> options, Function(int, String) onSelect) {
    List<Widget> dOptions = [];
    for (var i = 0; i < options.length; i++)
      dOptions.add(SimpleDialogOption(
          child: Text(options[i]),
          onPressed: () {
            Navigator.of(context).pop();
            onSelect(i, options[i]);
          }));
    SimpleDialog dialog = SimpleDialog(title: Text(title), children: dOptions);

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return dialog;
      },
    );
  }
}
