import 'dart:io';

import 'package:dmedia/controllers/home.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:dmedia/models.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dmedia/util.dart';

class MediaController extends GetxController {
  final tabIndex = 0.obs;
  final videoPlayers = {}.obs;
  final List<TabElement> defaultTabs = [
    TabElement('Share', Icons.share, 'share'),
    TabElement('Details', Icons.list, 'details'),
    TabElement('Delete', Icons.delete_outline, 'delete'),
  ];
  final List<TabElement> trashTabs = [
    TabElement('Restore', Icons.undo, 'restore'),
    TabElement('Details', Icons.list, 'details'),
    TabElement('Delete Permanently', Icons.delete_outline, 'delete'),
  ];

  @override
  void onClose() {
    super.onClose();
    videoPlayers.values.forEach((val) {
      val.dispose();
    });
  }

  List<TabElement> get tabs {
    return media.isDeleted ? trashTabs : defaultTabs;
  }

  Media get media {
    return Get.find<HomeController>().selectedMedia;
  }

  VideoPlayerController get videoController {
    return videoPlayers[media.id]!;
  }

  Future<bool> started() async {
    if (media.isVideo && !videoPlayers.containsKey(media.id)) {
      final client = Util.getClient();

      videoPlayers[media.id] = media.isLocal
          ? VideoPlayerController.file(File(media.getPath()))
          : VideoPlayerController.network(media.getPath(client: client),
              httpHeaders: client.headers);
      // videoController.addListener(() {});
      await videoPlayers[media.id]?.initialize();
    }
    await videoPlayers[media.id]?.play();
    return true;
  }

  TabElement get currentTab {
    return tabs[tabIndex.value];
  }

  void onTabTapped(int index) async {
    tabIndex(index);
    final tab = currentTab;
    print('${tab.key}');
    if (tab.key == 'share') {
      final done = Util.showLoading(Get.context!);
      final sharePath = await media.getSharePath();
      done();
      await Share.shareFiles([sharePath]);
    } else if (tab.key == 'delete') {
      Util.confirmDialog(Get.context!, () async {
        Get.find<HomeController>().deleteMedia();
        Get.back();
      }, message: media.isLocal ? 'Permanently delete file?' : 'Are you sure?');
    } else if (tab.key == 'restore') {
      Util.confirmDialog(Get.context!, () async {
        Get.find<HomeController>().restoreMedia();
        Get.back();
      });
    }
  }

  onItemSwipe(details) {
    final hCtrl = Get.find<HomeController>();
    if (details.primaryVelocity != 0) videoPlayers[media.id]?.pause();
    if (details.primaryVelocity > 0)
      hCtrl.prevMedia();
    else if (details.primaryVelocity < 0) hCtrl.nextMedia();

    // if (details.primaryVelocity != 0) initVideoController();
  }
}
