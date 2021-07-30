import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:workmanager/workmanager.dart' as wm;

import 'package:dmedia/client.dart';
import 'package:dmedia/util.dart';

const bool isRelease = bool.fromEnvironment("dart.vm.product");
const String settingsDarkMode = 'dark_mode';
const String settingsAccounts = 'accounts';
const String settingsAccount = 'account';
const String settingsAccountSettings = 'account_settings';
const String settingsIdCounter = 'id_ctr';
const String taskSync = 'sync';
const String taskDelete = 'delete';

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
  bool delete;
  int? lastSync;
  List<String> folders;

  AccountSettings(
      {required this.duration,
      required this.wifiEnabled,
      required this.charging,
      required this.idle,
      required this.notify,
      required this.delete,
      required this.scheduled,
      required this.folders,
      this.lastSync});

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
      'delete': delete,
      'lastSync': lastSync,
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
      delete: map['delete'],
      lastSync: map['lastSync'],
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
  DateTime? deleted;
  int size;
  dynamic meta;
  Media(
      {required this.id,
      required this.name,
      required this.public,
      required this.checksum,
      required this.ctype,
      required this.created,
      required this.modified,
      required this.size,
      required this.meta,
      this.deleted});

  bool get isVideo {
    return ctype.startsWith('video/');
  }

  bool get isDeleted {
    return deleted != null;
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
      'deleted': deleted != null ? Util.dateTimeToString(deleted!) : null,
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
      deleted:
          map['deleted'] != null ? Util.StringToDateTime(map['deleted']) : null,
      size: map['size'],
      meta: map['meta'],
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
      progressIndicatorBuilder: size != null
          ? null
          : (context, url, downloadProgress) =>
              CircularProgressIndicator(value: downloadProgress.progress),
      errorWidget: (context, url, error) => Icon(Icons.error),
    );
  }
}
