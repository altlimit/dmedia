import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dmedia/preference.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const bool isRelease = bool.fromEnvironment("dart.vm.product");
const String settingsDarkMode = 'dark_mode';
const String settingsAccounts = 'accounts';
const String settingsAccount = 'account';
const String taskSync = 'sync';

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
        'id': id,
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
  static Map<String, Client> Clients = <String, Client>{};

  static Client getClient(String account) {
    if (!Clients.containsKey(account)) {
      Clients[account] = Client(getAccount(account)!);
    }
    return Clients[account]!;
  }

  static List<Account> getAccounts() {
    List<dynamic> accounts =
        jsonDecode(Preference.getString(settingsAccounts, def: '[]')!);

    return List<Account>.from(accounts.map((a) => Account.fromJson(a)));
  }

  static Account? getAccount(String account) {
    var accounts = getAccounts().where((a) => a.toString() == account).toList();
    return accounts.length == 0 ? null : accounts[0];
  }

  static int saveAccount(Account account,
      {bool delete = false, String acct = ""}) {
    var accounts = getAccounts();
    var index = -1;
    for (var i = 0; i < accounts.length; i++) {
      if (accounts[i].toString() == acct) {
        index = i;
        break;
      }
    }
    if (delete) {
      if (index != -1) accounts.removeAt(index);
    } else if (index != -1) {
      accounts[index] = account;
    } else {
      accounts.add(account);
    }
    Preference.setString(settingsAccounts, jsonEncode(accounts));
    return accounts.length - 1;
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
      List<String> options, Function(String) onSelect) {
    // set up the SimpleDialog
    SimpleDialog dialog = SimpleDialog(
      title: Text(title),
      children: options
          .map((o) => SimpleDialogOption(
                child: Text(o),
                onPressed: () {
                  Navigator.of(context).pop();
                  onSelect(o);
                },
              ))
          .toList(),
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return dialog;
      },
    );
  }
}
