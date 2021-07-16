import 'package:flutter/material.dart';
import 'package:dmedia/model.dart';
import 'package:dmedia/preference.dart';
import 'package:dmedia/store.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPage createState() => _SettingsPage();
}

class _SettingsPage extends State<SettingsPage> with Store {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();

    setState(() {
      _isDarkMode = Preference.getBool(settingsDarkMode);
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> settingsWidgets = List<Widget>.empty();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: Column(
        children: settingsWidgets,
      ),
    );
  }
}
