import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:json_path/json_path.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as hp;
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart' as wm;

import 'package:dmedia/db_migrate.dart';
import 'package:dmedia/preference.dart';

const bool isRelease = bool.fromEnvironment("dart.vm.product");
const String settingsDarkMode = 'dark_mode';
const String settingsAccounts = 'accounts';
const String settingsAccount = 'account';
const String settingsAccountSettings = 'account_settings';
const String settingsIdCounter = 'id_ctr';
const String taskSync = 'sync';

final dateTimeFormat = DateFormat("yyyy-MM-dd HH:mm:ss");
final dateFormat = DateFormat("yyyy-MM-dd");

class Account {
  int id;
  String serverUrl;
  String username;
  String password;
  bool admin;

  Account(
      {this.id = 0,
      this.serverUrl = "",
      this.username = "",
      this.password = "",
      this.admin = false});

  Account.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        serverUrl = json['serverUrl'],
        username = json['username'],
        password = json['password'],
        admin = json['admin'];

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'username': username,
        'password': password,
        'admin': admin,
        'id': id
      };

  @override
  String toString() {
    return username + "@" + serverUrl;
  }
}

class AccountSettings {
  int duration;
  bool wifiEnabled;
  bool charging;
  bool idle;
  bool notify;
  bool scheduled;
  List<String> folders;

  AccountSettings({
    required this.duration,
    required this.wifiEnabled,
    required this.charging,
    required this.idle,
    required this.notify,
    required this.scheduled,
    required this.folders,
  });

  wm.Constraints getConstraints() {
    return wm.Constraints(
        networkType:
            wifiEnabled ? wm.NetworkType.unmetered : wm.NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: charging,
        requiresDeviceIdle: idle,
        requiresStorageNotLow: false);
  }

  Map<String, dynamic> toMap() {
    return {
      'duration': duration,
      'wifiEnabled': wifiEnabled,
      'charging': charging,
      'idle': idle,
      'notify': notify,
      'scheduled': scheduled,
      'folders': folders,
    };
  }

  factory AccountSettings.fromMap(Map<String, dynamic> map) {
    return AccountSettings(
      duration: map['duration'],
      wifiEnabled: map['wifiEnabled'],
      charging: map['charging'],
      idle: map['idle'],
      notify: map['notify'],
      scheduled: map['scheduled'],
      folders: List<String>.from(map['folders']),
    );
  }

  String toJson() => json.encode(toMap());

  factory AccountSettings.fromJson(String source) =>
      AccountSettings.fromMap(json.decode(source));
}

class Media {
  int id;
  String name;
  bool public;
  String checksum;
  String ctype;
  DateTime created;
  DateTime modified;
  int size;
  dynamic meta;
  Media({
    required this.id,
    required this.name,
    required this.public,
    required this.checksum,
    required this.ctype,
    required this.created,
    required this.modified,
    required this.size,
    required this.meta,
  });

  bool isVideo() {
    return ctype.startsWith('video/');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'public': public,
      'checksum': checksum,
      'ctype': ctype,
      'created': Util.dateTimeToString(created),
      'modified': Util.dateTimeToString(modified),
      'size': size,
      'meta': json.encode(meta),
    };
  }

  factory Media.fromMap(Map<String, dynamic> map) {
    return Media(
      id: map['id'],
      name: map['name'],
      public: map['public'] == 1,
      checksum: map['checksum'],
      ctype: map['ctype'],
      created: Util.StringToDateTime(map['created']),
      modified: Util.StringToDateTime(map['modified']),
      size: map['size'],
      meta: json.decode(map['meta']),
    );
  }

  String toJson() => json.encode(toMap());

  factory Media.fromJson(String source) => Media.fromMap(json.decode(source));

  @override
  String toString() {
    return 'Media(id: $id, name: $name, public: $public, checksum: $checksum, ctype: $ctype, created: $created, modified: $modified, size: $size, meta: $meta)';
  }

  String getPath({Client? client}) {
    if (client == null) client = Util.getClient();
    return '${client.selectedUrl}/${client.account.id}/' +
        dateFormat.format(created) +
        '/$id/$name';
  }

  Widget image({Client? client, int? size}) {
    if (client == null) client = Util.getClient();
    return CachedNetworkImage(
      fit: size != null ? BoxFit.cover : null,
      key: Key('thumb_' + id.toString()),
      httpHeaders: client.headers,
      imageUrl: getPath(client: client) +
          (size != null ? '?size=' + size.toString() : ''),
      progressIndicatorBuilder: (context, url, downloadProgress) =>
          CircularProgressIndicator(value: downloadProgress.progress),
      errorWidget: (context, url, error) => Icon(Icons.error),
    );
  }
}

class Client {
  Account account;
  String selectedUrl = "";
  late Map<String, String> headers;

  Client(this.account) {
    headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Basic ' +
          base64Encode(utf8.encode('${account.username}:${account.password}'))
    };
  }

  Future<void> init() async {
    if (selectedUrl.length == 0) {
      var urls = account.serverUrl.split("|");
      for (var i = 0; i < urls.length; i++) {
        if (selectedUrl.length == 0) {
          var resp = await http
              .get(Uri.parse(urls[i] + '/status'))
              .timeout(Duration(seconds: 1));
          if (resp.statusCode == 200) {
            selectedUrl = urls[i];
            break;
          }
        }
      }
    }
  }

  Future<dynamic> request(String path, {dynamic data, String? method}) async {
    http.Response resp;
    try {
      await init();
      var uri = Uri.parse(selectedUrl + path);
      if (data != null) {
        if (!isRelease) print('Payload: ' + json.encode(data));
        var m = method == 'PUT' ? http.put : http.post;
        resp = await m(uri, body: json.encode(data), headers: headers);
      } else {
        resp = await http.get(uri, headers: headers);
      }
      if (resp.statusCode != 200 || !isRelease) print('response: ' + resp.body);
      return resp.body.length > 0 ? json.decode(resp.body) : null;
    } on SocketException {
      print('Not connected to internet');
      return {'error': 'connection failed'};
    } on TimeoutException {
      print('Not connected to internet');
      return {'error': 'connection timeout'};
    } on FormatException {
      return {'error': 'unexpected response'};
    } on Exception catch (e) {
      print('Error: ' + e.toString());
      return {'error': e.toString()};
    }
  }

  Future<dynamic> upload(String path) async {
    try {
      await init();
      final uri = Uri.parse(selectedUrl + '/api/upload');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);
      final stat = await FileStat.stat(path);
      request.fields['fallbackDate'] = Util.dateTimeToString(stat.modified);
      var cType = lookupMimeType(path);
      if (cType != null &&
          (cType.startsWith('image/') || cType.startsWith('video/'))) {
        request.files.add(http.MultipartFile.fromBytes(
            'file', await File.fromUri(Uri.parse(path)).readAsBytes(),
            filename: p.basename(path),
            contentType: hp.MediaType.parse(cType)));

        var response = await request.send();
        if (response.statusCode == 200) {
          return json.decode(await response.stream.bytesToString());
        } else if (!isRelease) {
          print('Response: ' + await response.stream.bytesToString());
        }
      }
      return null;
    } catch (e) {
      print('Error: ' + e.toString());
      return null;
    }
  }

  Map<String, String>? checkError(Map<String, dynamic>? data) {
    if (data != null &&
        data.containsKey('error') &&
        data.containsKey('params') &&
        data['error'] == 'validation') {
      return (data['params'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
    }
    return data != null && data.containsKey('error')
        ? {'message': data['error']}
        : null;
  }
}

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

class DBProvider {
  static final DBProvider _instance = new DBProvider.internal();

  factory DBProvider() => _instance;
  DBProvider.internal();

  static Map<int, Database> _dbs = {};

  Future<void> clearDbs({int? internalId}) async {
    final dbPath = await getDatabasesPath();
    for (final db in _dbs.entries.toList()) {
      if (internalId == null || internalId == db.key) {
        db.value.close();
        _dbs.remove(db.key);
      }
    }
    for (final file in await Directory(dbPath).list().toList()) {
      if (internalId == null || file.path.endsWith('account_$internalId.db')) {
        await file.delete();
      }
    }
  }

  Future<Database> open(int internalId) async {
    if (!_dbs.containsKey(internalId)) {
      var path = await getDatabasesPath();
      var dbPath = p.join(path, 'account_$internalId.db');
      _dbs[internalId] =
          await openDatabase(dbPath, version: dbMigrations.length,
              onCreate: (Database db, int version) async {
        for (var i = 0; i < version; i++) await db.execute(dbMigrations[i]);
      }, onUpgrade: (Database db, oldVersion, newVersion) async {
        for (var i = oldVersion; i < newVersion; i++)
          await db.execute(dbMigrations[i]);
      });
    }
    return _dbs[internalId]!;
  }

  Future<void> upsertMedia(int internalId, List<dynamic> rows) async {
    final db = await open(internalId);
    final batch = db.batch();
    for (final r in rows) {
      final row = r as Map<String, dynamic>;
      row['public'] = row['public'] == true ? 1 : 0;
      row['meta'] = row['meta'] != null ? json.encode(row['meta']) : null;
      batch.insert('media', row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit();
  }

  Future<void> syncMedia(int internalId) async {
    final db = await open(internalId);
    final client = await Util.getClient(internalId: Util.getActiveAccountId());
    var rows = await db.rawQuery('SELECT MAX(modified) as lastMod FROM media');
    var lastMod = rows[0]['lastMod'] == null
        ? ''
        : '?mod=' + (rows[0]['lastMod'] as String);
    Map<String, dynamic> response =
        await client.request('/api/media' + lastMod);
    if (response['result'] != null) {
      final pages = response['pages'] as int;
      await upsertMedia(internalId, response['result']);
      if (pages > 1) {
        for (var page = 2; page <= pages; page++) {
          response = await client.request('/api/media' + lastMod);
          if (response['result'] != null)
            await upsertMedia(internalId, response['result']);
        }
      }
    }
  }

  Future<List<Media>> getRecentMedia(int internalId,
      {int page = 1, int limit = 50, Function(int)? countPages}) async {
    final db = await open(internalId);
    final List<Media> result = [];
    final offset = (limit * page) - limit;
    var rows = await db.rawQuery("""SELECT * 
    FROM media
    ORDER BY created DESC
    LIMIT $limit
    OFFSET $offset""");
    for (final row in rows) {
      final media = Media.fromMap(row);
      result.add(media);
      print('${media.id} -> ' + Util.dateTimeToString(media.created));
      // Util.debug(
      //     JsonPath(r'$.exif.ApertureValue[0]').read(media.meta).single.value);
    }

    if (countPages != null) {
      rows = await db.rawQuery('SELECT COUNT(1) FROM media');
      var pages = (rows[0]['COUNT(1)'] as int) / limit;
      if (pages <= 0) {
        pages = 1;
      }
      countPages(pages.ceil());
    }

    return result;
  }
}
