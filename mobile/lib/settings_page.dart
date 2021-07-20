import 'package:flutter/material.dart';
import 'package:dmedia/model.dart';
import 'package:dmedia/preference.dart';
import 'package:dmedia/store.dart';
import 'dart:io';
import 'dart:convert';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPage createState() => _SettingsPage();
}

class _SettingsPage extends State<SettingsPage> with Store {
  late bool _isDarkMode;
  late AccountSettings _accountSettings;

  @override
  void initState() {
    super.initState();

    setState(() {
      _isDarkMode = Preference.getBool(settingsDarkMode);
      _accountSettings = AccountSettings(
          duration: 15,
          wifiEnabled: true,
          charging: false,
          idle: true,
          folders: []);
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> settingsWidgets = [
      SwitchListTile(
          title: const Text('Dark Mode'),
          subtitle: const Text('Set theme brightness to dark.'),
          value: _isDarkMode,
          onChanged: (bool value) {
            setState(() {
              _isDarkMode = value;
            });
            Preference.setBool(settingsDarkMode, value);
            myAppState!.updateTheme();
          }),
      ListTile(
        title: const Text('Sync Settings'),
        subtitle:
            const Text('Configure time, interval and other sync settings'),
        onTap: () async {},
      ),
      ListTile(
        title: const Text('Sync Folders'),
        subtitle: const Text('Add new directory to sync'),
        onTap: () async {
          await Util.chooseDirectory(
              context,
              (dir) => setState(() {
                    _accountSettings.folders.add(dir.path);
                  }));
        },
      ),
      Expanded(
          child: Padding(
        child: ListView.builder(
          itemCount: _accountSettings.folders.length,
          itemBuilder: (context, index) {
            var folder = _accountSettings.folders[index];
            return ListTile(
              title: Text(folder),
              onLongPress: () {
                Util.confirmDialog(
                    context,
                    () => setState(() {
                          _accountSettings.folders.removeAt(index);
                        }),
                    message: 'Are you sure you want to delete?');
              },
            );
          },
        ),
        padding: EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
      ))
    ];

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
