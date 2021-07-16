import 'package:flutter/material.dart';
import 'package:dmedia/my_app.dart';
import 'package:dmedia/preference.dart';
import 'package:dmedia/store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Preference.load();

  runApp(MyApp(key: Store.myAppStateKey));
}
