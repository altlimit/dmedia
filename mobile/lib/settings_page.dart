import 'package:flutter/material.dart';
import 'package:dmedia/model.dart';
import 'package:dmedia/preference.dart';
import 'package:dmedia/store.dart';
import 'package:dmedia/background.dart';

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
      var settings = Util.getAccountSettings();
      _accountSettings = settings != null
          ? settings
          : AccountSettings(
              duration: 15,
              wifiEnabled: true,
              charging: false,
              idle: true,
              notify: false,
              enabled: false,
              folders: []);
    });
  }

  void saveChanges() {
    Util.saveAccountSettings(_accountSettings);
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
      Center(child: const Text('Sync Settings')),
      ListTile(
        title: const Text('Manage Folders'),
        subtitle: const Text('Manage directories to sync'),
        trailing: Icon(Icons.arrow_right),
        onTap: () async {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      FolderSettingsPage(_accountSettings.folders, (folders) {
                        _accountSettings.folders = folders;
                        saveChanges();
                      })));
        },
      ),
      ListTile(
        title: const Text('Interval'),
        subtitle: Text('Sync directories every ' +
            _accountSettings.duration.toString() +
            ' minutes.'),
        trailing: Text(_accountSettings.duration.toString()),
        onTap: () async {
          Util.inputDialog(context, 'Sync Interval (Minutes)', (v) {
            setState(() {
              try {
                _accountSettings.duration = int.parse(v);
              } on Exception {
                _accountSettings.duration = 15;
              }
              if (_accountSettings.duration < 15)
                _accountSettings.duration = 15;
            });
            saveChanges();
          },
              def: _accountSettings.duration.toString(),
              inputType: TextInputType.number);
        },
      ),
      SwitchListTile(
          title: const Text('Wifi Only'),
          subtitle: const Text('Sync only when connected to wifi.'),
          value: _accountSettings.wifiEnabled,
          onChanged: (bool value) {
            setState(() {
              _accountSettings.wifiEnabled = value;
              saveChanges();
            });
          }),
      SwitchListTile(
          title: const Text('Charging Only'),
          subtitle: const Text('Sync only when connected to a charger.'),
          value: _accountSettings.charging,
          onChanged: (bool value) {
            setState(() {
              _accountSettings.charging = value;
              saveChanges();
            });
          }),
      SwitchListTile(
          title: const Text('Idle Only'),
          subtitle: const Text('Sync only when phone not in used.'),
          value: _accountSettings.idle,
          onChanged: (bool value) {
            setState(() {
              _accountSettings.idle = value;
              saveChanges();
            });
          }),
      SwitchListTile(
          title: const Text('Notifications'),
          subtitle: const Text('Get notified when media is synced.'),
          value: _accountSettings.notify,
          onChanged: (bool value) {
            setState(() {
              _accountSettings.notify = value;
              saveChanges();
            });
          }),
      SwitchListTile(
          title: const Text('Enable Schedule'),
          subtitle: Text('Runs sync every ' +
              _accountSettings.duration.toString() +
              ' minutes.'),
          value: _accountSettings.enabled,
          onChanged: (bool value) {
            setState(() {
              _accountSettings.enabled = value;
              saveChanges();
            });
          }),
      if (!_accountSettings.enabled) ...[
        ListTile(
          title: const Text('Run Sync'),
          subtitle: const Text('Run sync in background now.'),
          onTap: () async {
            await Bg.scheduleTask(
                Util.getActiveAccountId().toString(), taskSync,
                isOnce: true);
          },
        )
      ],
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        children: settingsWidgets,
      ),
    );
  }
}

class FolderSettingsPage extends StatefulWidget {
  List<String> folders;
  Function(List<String>) onUpdate;

  FolderSettingsPage(this.folders, this.onUpdate);

  @override
  _FolderSettingsPage createState() => _FolderSettingsPage();
}

class _FolderSettingsPage extends State<FolderSettingsPage> with Store {
  late List<String> _folders;
  late Function(List<String>) _onUpdate;

  @override
  void initState() {
    super.initState();

    _folders = widget.folders;
    _onUpdate = widget.onUpdate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Folders"),
      ),
      body: Column(
        children: [
          ListTile(
            title: Center(child: const Text('Add Directory')),
            onTap: () async {
              await Util.chooseDirectory(
                  context,
                  (dir) => setState(() {
                        if (!_folders.contains(dir.path)) {
                          _folders.add(dir.path);
                          _onUpdate(_folders);
                        }
                      }));
            },
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _folders.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_folders[index]),
                  onLongPress: () {
                    Util.confirmDialog(
                        context,
                        () => setState(() {
                              _folders.removeAt(index);
                              _onUpdate(_folders);
                            }),
                        message: 'Delete path?');
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
