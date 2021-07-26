import 'package:flutter/material.dart';
import 'package:dmedia/preference.dart';
import 'package:dmedia/model.dart';
import 'package:get/get.dart';
import 'package:dmedia/views/home.dart';
import 'package:dmedia/views/account.dart';
import 'package:dmedia/views/settings.dart';
import 'package:dmedia/views/settings_folder.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Preference.load();

  // runApp(MyApp(key: Store.myAppStateKey));
  runApp(GetMaterialApp(
    initialRoute: Util.getActiveAccountId() == 0 ? '/account' : '/home',
    getPages: [
      GetPage(name: '/home', page: () => HomeView()),
      GetPage(name: '/account', page: () => AccountView()),
      GetPage(name: '/settings', page: () => SettingsView()),
      GetPage(name: '/settings/folder', page: () => SettingsFolderView()),
    ],
  ));
}
