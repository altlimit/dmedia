import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import 'package:dmedia/preference.dart';
import 'package:dmedia/db_migrate.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

const bool isRelease = bool.fromEnvironment("dart.vm.product");
const String settingsDarkMode = 'dark_mode';
const String settingsAccounts = 'accounts';
const String settingsAccount = 'account';
const String settingsIdCounter = 'id_ctr';
const String taskSync = 'sync';

var dateTimeFormat = DateFormat("yyyy-MM-dd HH:mm:ss");

class Account {
  int id = 0;
  String serverUrl = "";
  String username = "";
  String password = "";
  bool admin = false;

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

class Client {
  Account account;
  String selectedUrl = "";
  Map<String, String> headers = {};

  Client(this.account);

  Future<dynamic> request(String path, {dynamic data, String? method}) async {
    headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Basic ' +
          base64Encode(utf8.encode('${account.username}:${account.password}'))
    };
    http.Response resp;
    try {
      if (selectedUrl.length == 0) {
        var urls = account.serverUrl.split("|");
        for (var i = 0; i < urls.length; i++) {
          if (selectedUrl.length == 0) {
            resp = await http
                .get(Uri.parse(urls[i] + '/status'))
                .timeout(Duration(seconds: 1));
            if (resp.statusCode == 200) {
              selectedUrl = urls[i];
              break;
            }
          }
        }
      }
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

  static String dateTimeToString(DateTime dt) {
    return dateTimeFormat.format(dt);
  }

  static Client getClient(int internalId) {
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
  }

  static int saveAccount(Account account, {int? internalId}) {
    var accounts = getAccounts();

    if (internalId == null) {
      internalId = Preference.getInt(settingsIdCounter, def: 1)!;
      Preference.setInt(settingsIdCounter, internalId + 1);
    }
    accounts[internalId] = account;
    Preference.setJson(
        settingsAccounts, accounts.map((k, v) => MapEntry(k.toString(), v)));
    return internalId;
  }

  static void confirmDialog(BuildContext context, Function() onConfirm) {
    showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            content: new Text("Are you sure?"),
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

  Future<void> test(int internalId) async {
    var db = await open(internalId);
    var rows = await db.rawQuery('SELECT * FROM media');
    print('Rows: ' + json.encode(rows));
  }
}
