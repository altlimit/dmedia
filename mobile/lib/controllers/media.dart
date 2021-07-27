import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:dmedia/model.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:share_plus/share_plus.dart';

class MediaController extends GetxController {
  late Media media;
  VideoPlayerController? videoController;
  final List<TabElement> tabs = [
    TabElement('Share', Icons.share, 'share'),
    TabElement('Details', Icons.list, 'details'),
    TabElement('Delete', Icons.delete_outline, 'delete'),
  ];

  @override
  void onInit() {
    super.onInit();
    media = Get.arguments;

    if (media.isVideo) {
      final client = Util.getClient();

      videoController = VideoPlayerController.network(
          media.getPath(client: client),
          httpHeaders: client.headers);
      // videoController.addListener(() {});
    }
  }

  @override
  void dispose() {
    videoController?.dispose();
    super.dispose();
  }

  Future<bool> started() async {
    await videoController?.initialize();
    await videoController?.play();
    return true;
  }

  void onTabTapped(int index) async {
    final tab = tabs[index];
    if (tab.key == 'share') {
      var file = await DefaultCacheManager().getSingleFile(media.getPath());
      await Share.shareFiles([file.path]);
    }
  }
}
