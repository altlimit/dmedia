import 'package:flutter/material.dart';
import 'package:dmedia/my_app.dart';

mixin Store {
  static final myAppStateKey = GlobalKey<MyAppState>();

  MyAppState? get myAppState {
    return myAppStateKey.currentState;
  }
}
