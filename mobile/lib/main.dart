import 'package:flutter/material.dart';
import 'package:dmedia/preference.dart';
import 'package:dmedia/util.dart';
import 'package:get/get.dart';
import 'package:dmedia/views/home.dart';
import 'package:dmedia/views/account.dart';
import 'package:dmedia/views/settings.dart';
import 'package:dmedia/views/settings_folder.dart';
import 'package:dmedia/views/media.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Preference.load();

  runApp(GetMaterialApp(
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
    themeMode: ThemeMode.system,
    initialRoute: Util.getActiveAccountId() == 0 ? '/account' : '/home',
    getPages: [
      GetPage(name: '/home', page: () => HomeView()),
      GetPage(name: '/account', page: () => AccountView()),
      GetPage(name: '/settings', page: () => SettingsView()),
      GetPage(name: '/settings/folder', page: () => SettingsFolderView()),
      GetPage(name: '/media', page: () => MediaView()),
    ],
  ));
}
