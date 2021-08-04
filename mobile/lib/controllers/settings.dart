import 'package:get/get.dart';
import 'package:dmedia/models.dart';
import 'package:dmedia/util.dart';
import 'package:dmedia/background.dart';
import 'package:package_info/package_info.dart';

class SettingsController extends GetxController {
  late Rx<AccountSettings> accountSettings;
  PackageInfo? packageInfo;

  @override
  void onInit() async {
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
            delete: true,
            folders: []).obs;
    packageInfo = await PackageInfo.fromPlatform();
    update();
  }

  void saveChanges() {
    Util.saveAccountSettings(accountSettings.value);
  }

  onRunSyncTap() async {
    await Bg.scheduleTask(
        "manual" + Util.getActiveAccountId().toString(), taskSync,
        isOnce: true, input: {'accountId': Util.getActiveAccountId()});
  }

  onRunDeleteTap() async {
    await Bg.scheduleTask(
        "manual" + Util.getActiveAccountId().toString(), taskDelete,
        isOnce: true, input: {'accountId': Util.getActiveAccountId()});
  }

  onLocalUpload() {
    Util.confirmDialog(Get.context!, () async {
      await Util.getClient().request('/api/upload/dir', data: {});
    }, message: 'Upload media in upload folder?');
  }

  scheduleSync(bool enabled) async {
    if (enabled)
      await Bg.scheduleTask(Util.getActiveAccountId().toString(), taskSync,
          constraints: accountSettings.value.getConstraints(),
          input: {'accountId': Util.getActiveAccountId()});
    else
      await Bg.cancelTask(Util.getActiveAccountId().toString());
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

  onAboutTap() async {
    Util.debug('Test ${accountSettings.value.lastSync}');
  }
}
