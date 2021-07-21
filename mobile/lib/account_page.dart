import 'package:flutter/material.dart';
import 'package:dmedia/model.dart';
import 'package:dmedia/preference.dart';
import 'package:dmedia/store.dart';
import 'dart:convert';

class AccountPage extends StatefulWidget {
  final int? internalId;

  AccountPage({this.internalId});

  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> with Store {
  Account _account = Account();
  bool _isAdd = false;
  Account? _currentAccount;
  bool _isActive = false;
  String _code = "";
  Map<String, String> _errors = {};
  bool _isCreate = false;
  int? _internalId;
  late bool _isFirstAccount = false;

  @override
  void initState() {
    super.initState();
    _isFirstAccount = myAppState!.currentAccount() == null;
    _internalId = widget.internalId;
    if (_internalId != null) {
      var a = Util.getAccount(_internalId!);
      if (a != null) {
        _account = a;
        _isActive = Util.getActiveAccountId() == _internalId;
        _currentAccount = Account.fromJson(_account.toJson());
      }
    } else {
      _isAdd = true;
      if (!isRelease) _account.serverUrl = 'http://192.168.1.70:5454';
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
            errorText: _errors['username'],
            border: OutlineInputBorder(),
            labelText: 'Username',
          ),
        ),
      ),
      Padding(
        padding:
            const EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 0),
        child: TextFormField(
          initialValue: _account.password,
          onChanged: (v) => setState(() {
            _account.password = v;
          }),
          obscureText: true,
          decoration: InputDecoration(
              errorText: _errors['password'],
              border: OutlineInputBorder(),
              labelText: 'Password'),
        ),
      ),
    ];

    if (_isAdd) {
      if (_isCreate)
        children.add(Padding(
          padding: const EdgeInsets.only(
              left: 15.0, right: 15.0, top: 15, bottom: 15),
          child: TextFormField(
            initialValue: _code,
            onChanged: (v) => setState(() {
              _code = v;
            }),
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              errorText: _errors['code'],
              labelText: 'Code',
            ),
          ),
        ));
    }

    if (_errors.containsKey('message'))
      children.add(Padding(
        padding: const EdgeInsets.only(left: 15.0, right: 15.0, bottom: 0),
        child: Text(_errors['message']!, style: TextStyle(color: Colors.red)),
      ));

    if (_isAdd)
      children.add(
        Padding(
          padding: const EdgeInsets.only(left: 15.0, right: 15.0),
          child: Switch(
            value: _isCreate,
            onChanged: (v) {
              setState(() {
                _isCreate = v;
              });
            },
          ),
        ),
      );
    children.add(ElevatedButton(
      onPressed: isValidAccount()
          ? () async {
              var doneLoading = Util.showLoading(context);
              setState(() {
                _errors.clear();
              });
              // test connections
              var client = Client(_account);
              Map<String, dynamic>? result;
              if (_isCreate)
                result = await client.request('/api/users?code=' + _code,
                    data: {
                      'username': _account.username,
                      'password': _account.password,
                      'active': true
                    });
              else if (_isAdd)
                result = await client.request('/api/auth');
              else // is update
              {
                client = Client(_currentAccount!);
                result =
                    await client.request('/api/users/' + _account.id.toString(),
                        data: {
                          'username': _account.username,
                          'password': _account.password,
                          'admin': _account.admin,
                          'active': true
                        },
                        method: 'PUT');
              }
              doneLoading();
              setState(() {
                var err = client.checkError(result);
                if (err != null) {
                  _errors = err;
                } else if (!(result!['active'] as bool)) {
                  _errors['message'] = 'inactive account';
                }
              });
              if (_errors.length > 0) return;

              _account.admin = result!['admin'] as bool;
              _account.id = result['id'];
              var newActiveId =
                  Util.saveAccount(_account, internalId: _internalId);
              if (_isAdd) {
                Util.setActiveAccountId(newActiveId);
                myAppState!.updateAccount();
              }
              if (_isFirstAccount)
                Navigator.of(context).pushReplacementNamed('/home');
              else
                Navigator.of(context).pop();
            }
          : null,
      child: Text(
        (_isAdd ? (_isCreate ? 'Create' : 'Login') : 'Save') + ' Account',
      ),
    ));
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
                Util.setActiveAccountId(_internalId!);
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
                  Util.delAccount(_internalId!);
                  Navigator.of(context).pop();
                });
              },
              child: Text(
                "Delete Account",
              ))));
    }

    return Scaffold(
      appBar: AppBar(title: Text("Account Setup")),
      body: SingleChildScrollView(
        child: Column(
          children: children,
        ),
      ),
    );
  }
}
