import 'package:flutter/material.dart';
import 'package:dmedia/model.dart';
import 'package:dmedia/preference.dart';
import 'package:dmedia/store.dart';
import 'dart:convert';

class LoginPage extends StatefulWidget {
  final String? account;

  LoginPage({this.account});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with Store {
  Account _account = Account();
  bool _isAdd = false;
  String _currentAccount = "";
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      var a = Util.getAccount(widget.account!);
      if (a != null) {
        _account = a;
        _currentAccount = _account.toString();
        _isActive = _currentAccount == myAppState!.currentAccount();
      }
    } else {
      _isAdd = true;
    }
  }

  bool isValidAccount() {
    return _account.serverUrl.length > 0 &&
        _account.username.length > 0 &&
        _account.password.length > 0;
  }

  @override
  Widget build(BuildContext context) {
    var children = <Widget>[
      Padding(
        padding:
            const EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 0),
        child: TextFormField(
          initialValue: _account.serverUrl,
          onChanged: (v) => setState(() {
            _account.serverUrl = v;
          }),
          decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Server URL',
              hintText: 'Enter full url like https://dmedia.altlimit.org'),
        ),
      ),
      Padding(
        padding:
            const EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 0),
        child: TextFormField(
          initialValue: _account.username,
          onChanged: (v) => setState(() {
            _account.username = v;
          }),
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Username',
          ),
        ),
      ),
      Padding(
        padding:
            const EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 15),
        child: TextFormField(
          initialValue: _account.password,
          onChanged: (v) => setState(() {
            _account.password = v;
          }),
          obscureText: true,
          decoration: InputDecoration(
              border: OutlineInputBorder(), labelText: 'Password'),
        ),
      ),
      ElevatedButton(
        onPressed: isValidAccount()
            ? () async {
                // test connections
                var client = Client(_account);
                var result = await client.init();
                print("Url: " + result.toString());
                var auth = await client.auth();
                print("Auth: " + json.encode(auth));
                Util.saveAccount(_account, acct: _currentAccount);
                if (_isAdd ||
                    _isActive && _account.toString() != _currentAccount) {
                  Preference.setString(settingsAccount, _account.toString());
                  myAppState!.updateAccount();
                }
                Navigator.of(context).pop();
              }
            : null,
        child: Text(
          _isAdd ? 'Add Account' : 'Save Account',
        ),
      ),
    ];
    if (_isActive)
      children.add(Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            "Active Account",
          )));
    else if (!_isAdd) {
      children.add(Padding(
          padding: EdgeInsets.only(top: 5),
          child: TextButton(
              style: TextButton.styleFrom(primary: Colors.blue),
              onPressed: () {
                Preference.setString(settingsAccount, _account.toString());
                myAppState!.updateAccount();
                Navigator.of(context).pop();
              },
              child: Text(
                "Switch Account",
              ))));
      children.add(Padding(
          padding: EdgeInsets.only(top: 5),
          child: TextButton(
              style: TextButton.styleFrom(primary: Colors.red),
              onPressed: () {
                Util.confirmDialog(context, () {
                  Util.saveAccount(_account,
                      delete: true, acct: _currentAccount);
                  Navigator.of(context).pop();
                });
              },
              child: Text(
                "Delete Account",
              ))));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("D-Media Account Setup"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: children,
        ),
      ),
    );
  }
}
