import 'package:flutter/material.dart';
import 'package:dmedia/preference.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const bool isRelease = bool.fromEnvironment("dart.vm.product");
const String settingsDarkMode = 'dark_mode';
const String settingsAccounts = 'accounts';
const String settingsAccount = 'account';

class Account {
  String serverUrl = "";
  String username = "";
  String password = "";
  bool admin = false;

  Account(
      {this.serverUrl = "",
      this.username = "",
      this.password = "",
      this.admin = false});

  Account.fromJson(Map<String, dynamic> json)
      : serverUrl = json['serverUrl'],
        username = json['username'],
        password = json['password'],
        admin = json['admin'];

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'username': username,
        'password': password,
        'admin': admin
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

  Future<String> init() async {
    headers = {
      "Authorization":
          base64Encode(utf8.encode('${account.username}:${account.password}'))
    };
    var urls = account.serverUrl.split("|");
    for (var i = 0; i < urls.length; i++) {
      if (selectedUrl.length == 0) {
        var response = await http.get(Uri.parse(urls[i] + '/status'));
        if (response.statusCode == 200) selectedUrl = urls[i];
      }
    }
    return selectedUrl;
  }

  Future<Map<String, dynamic>> auth() async {
    var response =
        await http.post(Uri.parse(selectedUrl + '/auth'), headers: headers);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return {};
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
