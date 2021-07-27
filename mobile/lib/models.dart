import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart' as wm;
import 'package:dmedia/util.dart';
import 'package:dmedia/client.dart';
import 'package:dmedia/db_migrate.dart';

const bool isRelease = bool.fromEnvironment("dart.vm.product");
const String settingsDarkMode = 'dark_mode';
const String settingsAccounts = 'accounts';
const String settingsAccount = 'account';
const String settingsAccountSettings = 'account_settings';
const String settingsIdCounter = 'id_ctr';
const String taskSync = 'sync';

final dateTimeFormat = DateFormat("yyyy-MM-dd HH:mm:ss");
final dateFormat = DateFormat("yyyy-MM-dd");

class TabElement {
  String label;
  IconData icon;
  String key;

  TabElement(this.label, this.icon, this.key);
}

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

  bool get isVideo {
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
    return '${client!.selectedUrl}/${client.account.id}/' +
        dateFormat.format(created) +
        '/$id/$name';
  }

  Widget image({Client? client, int? size}) {
    if (client == null) client = Util.getClient();
    return CachedNetworkImage(
      fit: size != null ? BoxFit.cover : null,
      key: Key('thumb_' + id.toString()),
      httpHeaders: client!.headers,
      imageUrl: getPath(client: client) +
          (size != null ? '?size=' + size.toString() : ''),
      progressIndicatorBuilder: (context, url, downloadProgress) =>
          CircularProgressIndicator(value: downloadProgress.progress),
      errorWidget: (context, url, error) => Icon(Icons.error),
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
