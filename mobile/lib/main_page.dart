import 'package:flutter/material.dart';
import 'package:dmedia/model.dart';
import 'package:dmedia/login_page.dart';
import 'package:dmedia/store.dart';

class MainPage extends StatefulWidget {
  @override
  _MainPage createState() => _MainPage();
}

class _MainPage extends State<MainPage> with Store {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> settingsWidgets = List<Widget>.empty();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Recent"),
        actions: [
          IconButton(
            icon: Icon(Icons.account_circle),
            onPressed: () {
              var accounts = Util.getAccounts();
              if (accounts.length == 0) {
                Navigator.pushNamed(context, '/login');
                return;
              }
              var accountOptions = accounts.map((a) => a.toString()).toList();
              accountOptions.add("Add New");
              String? account;
              Util.dialogList(context, "Select Account", accountOptions,
                  (selected) {
                if (selected != "Add New") {
                  account = selected;
                }
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => LoginPage(account: account)));
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          )
        ],
      ),
      body: Column(
        children: settingsWidgets,
      ),
    );
  }
}
