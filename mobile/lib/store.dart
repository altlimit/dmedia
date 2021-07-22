import 'package:flutter/material.dart';
import 'package:dmedia/my_app.dart';
import 'package:dmedia/main_page.dart';

mixin Store {
  static final myAppStateKey = GlobalKey<MyAppState>();
  static final mainPageStateKey = GlobalKey<MainPageState>();

  MyAppState? get myAppState {
    return myAppStateKey.currentState;
  }

  MainPageState? get mainPageState {
    return mainPageStateKey.currentState;
  }
}
