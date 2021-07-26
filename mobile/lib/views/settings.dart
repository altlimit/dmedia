import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dmedia/model.dart';
import 'package:dmedia/controllers/settings.dart';
import 'package:dmedia/store.dart';
import 'package:dmedia/background.dart';

class SettingsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final SettingsController controller = Get.put(SettingsController());

    List<Widget> settingsWidgets = [
      Center(child: const Text('Sync Settings')),
      ListTile(
        title: const Text('Manage Folders'),
        subtitle: const Text('Manage directories to sync'),
        trailing: Icon(Icons.arrow_right),
        onTap: controller.onManageFoldersTap,
      ),
      Obx(() => ListTile(
            title: const Text('Interval'),
            subtitle: Text('Sync directories every ' +
                controller.accountSettings.value.duration.toString() +
                ' minutes.'),
            trailing:
                Text(controller.accountSettings.value.duration.toString()),
            onTap: () async {
              Util.inputDialog(context, 'Sync Interval (Minutes)', (v) {
                controller.accountSettings.update((val) {
                  try {
                    val!.duration = int.parse(v);
                  } on Exception {
                    val!.duration = 15;
                  }
                  if (val.duration < 15) val.duration = 15;
                });
                controller.saveChanges();
              },
                  def: controller.accountSettings.value.duration.toString(),
                  inputType: TextInputType.number);
            },
          )),
      Obx(() => SwitchListTile(
          title: const Text('Wifi Only'),
          subtitle: const Text('Sync only when connected to wifi.'),
          value: controller.accountSettings.value.wifiEnabled,
          onChanged: (bool value) {
            controller.accountSettings.update((val) {
              val!.wifiEnabled = value;
            });
            controller.saveChanges();
          })),
      Obx(() => SwitchListTile(
          title: const Text('Charging Only'),
          subtitle: const Text('Sync only when connected to a charger.'),
          value: controller.accountSettings.value.charging,
          onChanged: (bool value) {
            controller.accountSettings.update((val) {
              val!.charging = value;
            });
            controller.saveChanges();
          })),
      Obx(() => SwitchListTile(
          title: const Text('Idle Only'),
          subtitle: const Text('Sync only when phone not in used.'),
          value: controller.accountSettings.value.idle,
          onChanged: (bool value) {
            controller.accountSettings.update((val) {
              val!.idle = value;
            });
            controller.saveChanges();
          })),
      Obx(() => SwitchListTile(
          title: const Text('Notifications'),
          subtitle: const Text('Get notified when media is synced.'),
          value: controller.accountSettings.value.notify,
          onChanged: (bool value) {
            controller.accountSettings.update((val) {
              val!.notify = value;
            });
            controller.saveChanges();
          })),
      Obx(() => SwitchListTile(
          title: const Text('Enable Schedule'),
          subtitle: Text('Runs sync every ' +
              controller.accountSettings.value.duration.toString() +
              ' minutes.'),
          value: controller.accountSettings.value.scheduled,
          onChanged: (bool value) {
            controller.accountSettings.update((val) {
              val!.scheduled = value;
            });
            controller.saveChanges();
          })),
      Obx(() => Visibility(
          child: ListTile(
            title: const Text('Run Sync'),
            subtitle: const Text('Run sync in background now.'),
            onTap: controller.onRunSyncTap,
          ),
          visible: !controller.accountSettings.value.scheduled)),
      ListTile(
        title: const Text('Delete Database'),
        subtitle: const Text('Forces full sync from server.'),
        trailing: Icon(Icons.sync),
        onTap: controller.onDeleteDbTap,
      ),
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
