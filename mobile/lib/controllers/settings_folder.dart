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
    try {
      final String? path = await Util.nativeCall('folderPicker');
      if (path != null && !folders.contains(path)) {
        folders.add(path);
        onUpdate(folders);
      }
    } catch (e) {
      Util.debug('onAddDirectoryTap: Error $e');
    }
  }

  onLongPressItem(int index) {
    Util.confirmDialog(Get.context!, () {
      folders.removeAt(index);
      onUpdate(folders);
    }, message: 'Delete path?');
  }
}
