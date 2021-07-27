import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:dmedia/models.dart';
import 'package:dmedia/background.dart';
import 'package:dmedia/util.dart';

class HomeController extends SuperController {
  final db = DBProvider();
  final tabIndex = 0.obs;
  final loadedMedia = [].obs;
  final selectedIndex = 0.obs;
  int page = 1;
  int? pages;
  final refreshIndicatorKey = new GlobalKey<RefreshIndicatorState>();
  final List<TabElement> tabs = [
    TabElement('Gallery', Icons.photo, 'gallery'),
    TabElement('Albums', Icons.photo_album, 'albums'),
    TabElement('Search', Icons.search, 'search'),
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
  }

  @override
  void onResumed() async {
    await db.syncMedia(Util.getActiveAccountId());
  }

  @override
  void onDetached() {
    print('onDetached called');
  }

  @override
  void onInactive() {
    print('onInative called');
  }

  @override
  void onPaused() {
    print('onPaused called');
  }

  Future<void> loadMedia() async {
    if (pages == null || page <= pages!) {
      final result = await db.getRecentMedia(Util.getActiveAccountId(),
          page: page,
          countPages: pages == null
              ? (totalPages) {
                  pages = totalPages;
                }
              : null);
      loadedMedia.addAll(result);
      Util.debug('Added ${result.length}');
      page++;
    }
  }

  void onTabTapped(int index) {
    tabIndex(index);
  }

  reload() {
    refreshIndicatorKey.currentState?.show();
  }

  deleteMedia(int index) async {
    await db.deleteMedia(
        Util.getActiveAccountId(), [(loadedMedia[index] as Media).id]);
    loadedMedia.removeAt(index);
  }

  Future<String> onPullRefresh() async {
    page = 1;
    pages = null;
    loadedMedia.clear();
    await db.syncMedia(Util.getActiveAccountId());
    await loadMedia();
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

  void settingsIconOnTap() {
    Get.toNamed('/settings');
  }

  onMediaItemTap(int index) {
    selectedIndex(index);
    print('index $index');
    Get.toNamed('/media');
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
