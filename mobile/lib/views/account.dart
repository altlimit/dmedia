import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:dmedia/models.dart';
import 'package:dmedia/controllers/account.dart';
import 'dart:convert';

class AccountView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AccountController controller = Get.put(AccountController());

    var children = <Widget>[
      Padding(
        padding:
            const EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 0),
        child: Obx(() => TextFormField(
              initialValue: controller.account.value.serverUrl,
              onChanged: (v) =>
                  controller.account.update((value) => value?.serverUrl = v),
              decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Server URL',
                  hintText: 'Enter full url like https://dmedia.altlimit.org'),
            )),
      ),
      Padding(
        padding:
            const EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 0),
        child: Obx(() => TextFormField(
              initialValue: controller.account.value.username,
              onChanged: (v) =>
                  controller.account.update((value) => value?.username = v),
              decoration: InputDecoration(
                errorText: controller.errors['username'],
                border: OutlineInputBorder(),
                labelText: 'Username',
              ),
            )),
      ),
      Padding(
        padding:
            const EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 0),
        child: Obx(() => TextFormField(
              initialValue: controller.account.value.password,
              onChanged: (v) =>
                  controller.account.update((value) => value?.password = v),
              obscureText: true,
              decoration: InputDecoration(
                  errorText: controller.errors['password'],
                  border: OutlineInputBorder(),
                  labelText: 'Password'),
            )),
      ),
    ];

    if (controller.isAdd) {
      children.add(Obx(() => Visibility(
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 15.0, right: 15.0, top: 15, bottom: 15),
              child: TextFormField(
                initialValue: controller.code.value,
                onChanged: controller.code,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  errorText: controller.errors['code'],
                  labelText: 'Code',
                ),
              ),
            ),
            visible: controller.isCreate.value,
          )));
    }

    children.add(Obx(() => Visibility(
          child: Padding(
            padding: const EdgeInsets.only(left: 15.0, right: 15.0, bottom: 0),
            child: controller.errors.containsKey('message')
                ? Text(controller.errors['message']!,
                    style: TextStyle(color: Colors.red))
                : null,
          ),
          visible: controller.errors.containsKey('message'),
        )));

    if (controller.isAdd)
      children.add(
        Padding(
          padding: const EdgeInsets.only(left: 15.0, right: 15.0),
          child: Obx(() => Switch(
                value: controller.isCreate.value,
                onChanged: controller.isCreate,
              )),
        ),
      );
    children.add(Obx(() => ElevatedButton(
          onPressed:
              controller.isValidAccount ? controller.onSaveAccountTap : null,
          child: Text(
            (controller.isAdd
                    ? (controller.isCreate.value ? 'Create' : 'Login')
                    : 'Save') +
                ' Account',
          ),
        )));
    if (controller.isActive)
      children.add(Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            "Active Account",
          )));
    else if (!controller.isAdd) {
      children.add(Padding(
          padding: EdgeInsets.only(top: 5),
          child: TextButton(
              style: TextButton.styleFrom(primary: Colors.blue),
              onPressed: controller.onSwitchAccountTap,
              child: Text(
                "Switch Account",
              ))));
      children.add(Padding(
          padding: EdgeInsets.only(top: 5),
          child: TextButton(
              style: TextButton.styleFrom(primary: Colors.red),
              onPressed: controller.onDeleteAccountTap,
              child: Text(
                "Delete Account",
              ))));
    }

    return Scaffold(
      appBar: AppBar(title: Text("Account Setup")),
      body: SingleChildScrollView(
        child: Column(
          children: children,
        ),
      ),
    );
  }
}
