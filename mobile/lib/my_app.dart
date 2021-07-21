import 'package:flutter/material.dart';
import 'package:dmedia/store.dart';
import 'package:dmedia/model.dart';
import 'package:dmedia/preference.dart';
import 'package:dmedia/settings_page.dart';
import 'package:dmedia/account_page.dart';
import 'package:dmedia/main_page.dart';
import 'package:dmedia/background.dart';

class MyApp extends StatefulWidget {
  MyApp({Key? key}) : super(key: key);
  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> with Store {
  late bool _isDarkMode;
  late Account? _selectedAccount;

  @override
  void initState() {
    super.initState();
    updateTheme();
    updateAccount();
  }

  updateTheme() {
    setState(() {
      _isDarkMode = Preference.getBool(settingsDarkMode);
    });
  }

  updateAccount() {
    setState(() {
      _selectedAccount = Util.getActiveAccount();
    });
  }

  Account? currentAccount() {
    return _selectedAccount;
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'D-Media',
        theme: ThemeData(
            primarySwatch: Colors.blueGrey,
            brightness: _isDarkMode ? Brightness.dark : Brightness.light),
        initialRoute: _selectedAccount == null ? '/account' : '/home',
        routes: {
          '/home': (context) => MainPage(),
          '/account': (context) => AccountPage(),
          '/settings': (context) => SettingsPage(),
        });
  }
}
