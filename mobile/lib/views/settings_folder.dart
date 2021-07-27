import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dmedia/controllers/settings_folder.dart';

class SettingsFolderView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final SettingsFolderController controller =
        Get.put(SettingsFolderController());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Folders"),
      ),
      body: Column(
        children: [
          ListTile(
            title: Center(child: const Text('Add Directory')),
            onTap: controller.onAddDirectoryTap,
          ),
          Expanded(
            child: Obx(() => ListView.builder(
                  itemCount: controller.folders.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(controller.folders[index]),
                      onLongPress: () => controller.onLongPressItem(index),
                    );
                  },
                )),
          )
        ],
      ),
    );
  }
}
