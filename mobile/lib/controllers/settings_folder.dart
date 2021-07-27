import 'package:get/get.dart';
import 'package:dmedia/util.dart';

class SettingsFolderController extends GetxController {
  late RxList<String> folders;
  late Function(List<String>) onUpdate;

  @override
  void onInit() {
    super.onInit();

    folders = Get.arguments[0];
    onUpdate = Get.arguments[1];
  }

  onAddDirectoryTap() async {
    await Util.chooseDirectory(Get.context!, (dir) {
      if (!folders.contains(dir.path)) {
        folders.add(dir.path);
        onUpdate(folders);
      }
    });
  }

  onLongPressItem(int index) {
    Util.confirmDialog(Get.context!, () {
      folders.removeAt(index);
      onUpdate(folders);
    }, message: 'Delete path?');
  }
}
