import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:dmedia/model.dart';
import 'package:dmedia/background.dart';

class HomeController extends SuperController {
  final db = DBProvider();
  final tabIndex = 0.obs;
  final loadedMedia = [].obs;
  int page = 1;
  int? pages;
  final refreshIndicatorKey = new GlobalKey<RefreshIndicatorState>();
  final List<TabElement> tabs = [
    TabElement('Gallery', Icons.photo, 'gallery'),
    TabElement('Albums', Icons.photo_album, 'albums'),
    TabElement('Search', Icons.search, 'search'),
  ];

  @override
  void onInit() {
    super.onInit();

    if (Util.getActiveAccountId() == 0) {
      print('No Active account');
      Get.toNamed('/account');
      return;
    }

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
    print('onResumed called');
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
    final result = await db.getRecentMedia(Util.getActiveAccountId(),
        page: page,
        countPages: pages == null
            ? (totalPages) {
                pages = totalPages;
              }
            : null);
    if (page <= pages!) {
      loadedMedia.addAll(result);
      page++;
    }
  }

  void onTabTapped(int index) {
    tabIndex(index);
  }

  reload() {
    refreshIndicatorKey.currentState?.show();
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
    Get.toNamed('/media', arguments: loadedMedia[index]);
  }
}
