import 'package:dmedia/controllers/home.dart';
import 'package:get/get.dart';

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:dmedia/model.dart';
import 'package:dmedia/preference.dart';
import 'package:dmedia/background.dart';

class SettingsController extends GetxController {
  late bool isDarkMode;
  late Rx<AccountSettings> accountSettings;
  final db = DBProvider();

  @override
  void onInit() {
    super.onInit();

    isDarkMode = Preference.getBool(settingsDarkMode);
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

  onDeleteDbTap() async {
    Util.confirmDialog(Get.context!, () async {
      await db.clearDbs(internalId: Util.getActiveAccountId());
      Get.find<HomeController>().onPullRefresh();
    });
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
