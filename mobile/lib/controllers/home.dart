import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:dmedia/models.dart';
import 'package:dmedia/background.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dmedia/util.dart';

class HomeController extends GetxController {
  late StreamSubscription intentSub;
  final tabIndex = 0.obs;
  final loadedMedia = [].obs;
  final selectedIndex = 0.obs;
  final selectedIndexes = {}.obs;
  final multiSelect = false.obs;
  int page = 1;
  int? pages;
  final refreshIndicatorKey = new GlobalKey<RefreshIndicatorState>();
  final List<TabElement> tabs = [
    TabElement('Gallery', Icons.photo, 'gallery'),
    // TabElement('Albums', Icons.photo_album, 'albums'),
    TabElement('Trash', Icons.delete_outline, 'trash'),
  ];
  late ScrollController scrollController;

  @override
  void onInit() {
    super.onInit();

    scrollController = ScrollController();
    scrollController.addListener(() async {
      if (scrollController.offset >=
              scrollController.position.maxScrollExtent &&
          !scrollController.position.outOfRange) {
        await loadMedia();
      }
      // if (scrollController.offset <=
      //         scrollController.position.minScrollExtent &&
      //     !scrollController.position.outOfRange) {
      //   print('top');
      // }
    });

    Bg.on(taskSync, 'message', (d) async {
      var data = d as Map<String, String>;
      if (data.containsKey('message'))
        Util.showMessage(Get.context!, data['message']!);
      refreshIndicatorKey.currentState?.show();
    });

    WidgetsBinding.instance!.addPostFrameCallback((Duration duration) async {
      refreshIndicatorKey.currentState?.show();
    });

    intentSub = ReceiveSharingIntent.getMediaStream().listen(
        (List<SharedMediaFile> value) async {
      await Util.uploadShared(value.map((f) => f.path).toList());
      if (currentTab.key == 'gallery') await onPullRefresh();
    }, onError: (err) {
      Util.debug("getIntentDataStream error: $err");
    });

    // For sharing images coming from outside the app while the app is closed
    ReceiveSharingIntent.getInitialMedia()
        .then((List<SharedMediaFile> value) async {
      await Util.uploadShared(value.map((f) => f.path).toList());
      if (currentTab.key == 'gallery') await onPullRefresh();
    });
  }

  @override
  void dispose() {
    intentSub.cancel();
    super.dispose();
  }

  TabElement get currentTab {
    return tabs[tabIndex.value];
  }

  bool get inTrash {
    return tabs[tabIndex.value].key == 'trash';
  }

  Future<void> loadMedia({bool reset = false}) async {
    if (reset) {
      page = 1;
      pages = null;
      loadedMedia.clear();
    }
    if (pages == null || page <= pages!) {
      final result = await Util.getClient().getMediaList(
          qs: {'p': page.toString(), 'deleted': inTrash ? '1' : '0'},
          onPages: (foundPages) => pages = foundPages);

      if (loadedMedia.length == 0 && !inTrash) {
        loadedMedia.addAll(await Util.localMedia());
      }

      loadedMedia.addAll(result);
      Util.debug('Added ${result.length}');
      page++;
    }
  }

  void onTabTapped(int index) async {
    tabIndex(index);
    await loadMedia(reset: true);
    multiSelect(false);
    selectedIndexes.clear();
  }

  reload() {
    refreshIndicatorKey.currentState?.show();
  }

  deleteMedia() async {
    final List<int> indexes = multiSelect.value
        ? selectedIndexes.keys.map((k) => k as int).toList()
        : [selectedIndex.value];
    final List<int> ids = [];
    for (var i = 0; i < indexes.length; i++) {
      final Media m = loadedMedia[indexes[i]];
      if (m.isLocal)
        await File(m.getPath()).delete();
      else
        ids.add(m.id);
    }
    await Util.getClient().deleteMedia(ids);
    indexes.forEach((i) {
      loadedMedia.removeAt(i);
    });
    multiSelect(false);
    selectedIndexes.clear();
  }

  restoreMedia() async {
    final List<int> indexes = multiSelect.value
        ? selectedIndexes.keys.map((k) => k as int).toList()
        : [selectedIndex.value];
    await Util.getClient().restoreMedia(
        indexes.map((i) => (loadedMedia[i] as Media).id).toList());
    indexes.forEach((i) {
      loadedMedia.removeAt(i);
    });
    multiSelect(false);
    selectedIndexes.clear();
  }

  Future<String> onPullRefresh() async {
    await loadMedia(reset: true);
    return Future.value('done');
  }

  Future<void> accountIconTap() async {
    // Preference.clear();
    // Tasks.syncDirectories((m) => print(m));
    // Util.runSingleInstance('test', () {
    //   print('Called');
    // });
    // Preference.clear();
    // await Bg.manager()
    //   ..registerOneOffTask('1000', taskSync,
    //       inputData: {'test': 1235},
    //       initialDelay: Duration(seconds: 2));
    var accounts = Util.getAccounts();
    if (accounts.length == 0) {
      Get.toNamed('/account');
      return;
    }
    List<int> accountIds = [];
    List<String> accountOptions = [];
    for (var key in accounts.keys) {
      accountIds.add(key);
      accountOptions.add(accounts[key].toString());
    }
    accountOptions.add("Add New");
    int? selectedId;
    Util.dialogList(Get.context!, "Select Account", accountOptions,
        (index, selected) {
      if (selected != "Add New") {
        selectedId = accountIds[index];
      }
      Get.toNamed('/account', arguments: selectedId);
    });
  }

  Future shareSelectedTap() async {
    final done = Util.showLoading(Get.context!);
    final files =
        await Future.wait<String>(selectedIndexes.keys.map((index) async {
      final Media media = loadedMedia[index];
      return media.getSharePath();
    }));
    done();
    await Share.shareFiles(files);
    multiSelect(false);
    selectedIndexes.clear();
  }

  deleteSelectedTap() {
    Util.confirmDialog(Get.context!, () {
      deleteMedia();
    }, message: 'Delete all selected media?');
  }

  restoreSelectedTap() {
    Util.confirmDialog(Get.context!, () {
      restoreMedia();
    }, message: 'Restore all selected media?');
  }

  void settingsIconOnTap() {
    Get.toNamed('/settings');
  }

  onMediaItemTap(int index) {
    if (multiSelect.value) {
      toggleSelected(index);
      return;
    }
    selectedIndex(index);
    Get.toNamed('/media');
  }

  onMediaLongPress(int index) {
    multiSelect(true);
    toggleSelected(index);

    Util.debug('MultiSelect: $multiSelect');
  }

  toggleSelected(int index) {
    if (selectedIndexes.containsKey(index))
      selectedIndexes.remove(index);
    else
      selectedIndexes.addAll({index: true});
    if (selectedIndexes.length == 0 && multiSelect.value) multiSelect(false);
  }

  bool isSelected(int index) {
    return selectedIndexes.containsKey(index);
  }

  Media get selectedMedia {
    return loadedMedia[selectedIndex.value];
  }

  nextMedia() {
    if (selectedIndex.value < loadedMedia.length - 1)
      selectedIndex(selectedIndex.value + 1);
    print('index $selectedIndex');
  }

  prevMedia() {
    if (selectedIndex.value > 0) selectedIndex(selectedIndex.value - 1);
    print('index $selectedIndex');
  }
}
