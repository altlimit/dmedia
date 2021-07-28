import 'package:dmedia/controllers/home.dart';
import 'package:get/get.dart';
import 'package:dmedia/models.dart';
import 'package:dmedia/util.dart';
import 'package:dmedia/background.dart';

class SettingsController extends GetxController {
  late Rx<AccountSettings> accountSettings;

  @override
  void onInit() {
    super.onInit();

    var settings = Util.getAccountSettings();
    accountSettings = settings != null
        ? settings.obs
        : AccountSettings(
            duration: 15,
            wifiEnabled: true,
            charging: false,
            idle: true,
            notify: false,
            scheduled: false,
            folders: []).obs;
  }

  void saveChanges() {
    Util.saveAccountSettings(accountSettings());
  }

  onRunSyncTap() async {
    await Bg.scheduleTask(Util.getActiveAccountId().toString(), taskSync,
        isOnce: true);
  }

  onManageFoldersTap() async {
    Get.toNamed('/settings/folder', arguments: [
      accountSettings.value.folders.obs,
      (folders) {
        accountSettings.update((val) => val!.folders = folders);
        saveChanges();
      }
    ]);
  }
}
