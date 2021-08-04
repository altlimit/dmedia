import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dmedia/util.dart';
import 'package:dmedia/controllers/settings.dart';

class SettingsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Get.put(SettingsController());

    List<Widget> settingsWidgets = [
      ListTile(
        title: const Text('Manage Folders'),
        subtitle: const Text('Manage directories to sync'),
        trailing: Icon(Icons.arrow_right),
        onTap: c.onManageFoldersTap,
      ),
      Obx(() => SwitchListTile(
          title: const Text('Wifi Only'),
          subtitle: const Text('Sync only when connected to wifi.'),
          value: c.accountSettings.value.wifiEnabled,
          onChanged: (bool value) {
            c.accountSettings.update((val) {
              val!.wifiEnabled = value;
            });
            c.saveChanges();
          })),
      Obx(() => SwitchListTile(
          title: const Text('Charging Only'),
          subtitle: const Text('Sync only when connected to a charger.'),
          value: c.accountSettings.value.charging,
          onChanged: (bool value) {
            c.accountSettings.update((val) {
              val!.charging = value;
            });
            c.saveChanges();
          })),
      Obx(() => SwitchListTile(
          title: const Text('Idle Only'),
          subtitle: const Text('Sync only when phone not in used.'),
          value: c.accountSettings.value.idle,
          onChanged: (bool value) {
            c.accountSettings.update((val) {
              val!.idle = value;
            });
            c.saveChanges();
          })),
      Obx(() => SwitchListTile(
          title: const Text('Delete Media'),
          subtitle:
              const Text('Deletes the media file after a succesful sync.'),
          value: c.accountSettings.value.delete,
          onChanged: (bool value) {
            c.accountSettings.update((val) {
              val!.delete = value;
            });
            c.saveChanges();
          })),
      Obx(() => SwitchListTile(
          title: const Text('Notifications'),
          subtitle: const Text('Get notified when media is synced.'),
          value: c.accountSettings.value.notify,
          onChanged: (bool value) {
            c.accountSettings.update((val) {
              val!.notify = value;
            });
            c.saveChanges();
          })),
      Obx(() => ListTile(
            title: const Text('Interval'),
            subtitle: Text('Sync directories every ' +
                c.accountSettings.value.duration.toString() +
                ' minutes.'),
            trailing: Text(c.accountSettings.value.duration.toString()),
            onTap: () async {
              Util.inputDialog(context, 'Sync Interval (Minutes)', (v) {
                c.accountSettings.update((val) {
                  try {
                    val!.duration = int.parse(v);
                  } on Exception {
                    val!.duration = 15;
                  }
                  if (val.duration < 15) val.duration = 15;
                });
                c.saveChanges();
              },
                  def: c.accountSettings.value.duration.toString(),
                  inputType: TextInputType.number);
            },
          )),
      Obx(() => SwitchListTile(
          title: const Text('Enable Schedule'),
          subtitle: Text('Runs sync every ' +
              c.accountSettings.value.duration.toString() +
              ' minutes.'),
          value: c.accountSettings.value.scheduled,
          onChanged: (bool value) {
            c.accountSettings.update((val) {
              val!.scheduled = value;
            });
            c.saveChanges();
            c.scheduleSync(value);
          })),
      Obx(() => Visibility(
          child: ListTile(
            title: const Text('Run Sync'),
            subtitle: const Text('Run sync in background now.'),
            onTap: c.onRunSyncTap,
          ),
          visible: !c.accountSettings.value.scheduled)),
      ListTile(
        title: const Text('Delete Backed Up Media'),
        subtitle: const Text('Deletes all backed up media files.'),
        onTap: c.onRunDeleteTap,
      ),
      ListTile(
        title: const Text('Local Upload'),
        subtitle: Text(
            'Place your media files under /data/${Util.getActiveAccount()!.id}/upload/* on your server.'),
        onTap: c.onLocalUpload,
      ),
      ListTile(
        title: Text('About D-Media'),
        onTap: c.onAboutTap,
        subtitle: GetBuilder<SettingsController>(
            builder: (_) => c.packageInfo != null
                ? Text(_.packageInfo!.version +
                    ' BULD:' +
                    _.packageInfo!.buildNumber +
                    ' PKG:' +
                    _.packageInfo!.packageName)
                : Text('')),
      )
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
