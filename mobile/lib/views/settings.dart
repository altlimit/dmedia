import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dmedia/util.dart';
import 'package:dmedia/controllers/settings.dart';

class SettingsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final SettingsController controller = Get.put(SettingsController());

    List<Widget> settingsWidgets = [
      ListTile(
        title: const Text('Manage Folders'),
        subtitle: const Text('Manage directories to sync'),
        trailing: Icon(Icons.arrow_right),
        onTap: controller.onManageFoldersTap,
      ),
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
          title: const Text('Delete Media'),
          subtitle:
              const Text('Deletes the media file after a succesful sync.'),
          value: controller.accountSettings.value.delete,
          onChanged: (bool value) {
            controller.accountSettings.update((val) {
              val!.delete = value;
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
            controller.scheduleSync(value);
          })),
      Obx(() => Visibility(
          child: ListTile(
            title: const Text('Run Sync'),
            subtitle: const Text('Run sync in background now.'),
            onTap: controller.onRunSyncTap,
          ),
          visible: !controller.accountSettings.value.scheduled)),
      ListTile(
        title: const Text('Delete Backed Up Media'),
        subtitle: const Text('Deletes all backed up media files.'),
        onTap: controller.onRunDeleteTap,
      ),
      ListTile(
        title: Text('About D-Media'),
        onTap: controller.onAboutTap,
        subtitle: GetBuilder<SettingsController>(
            builder: (_) => controller.packageInfo != null
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
