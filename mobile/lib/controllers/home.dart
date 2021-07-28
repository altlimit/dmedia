import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:dmedia/models.dart';
import 'package:dmedia/background.dart';
import 'package:dmedia/util.dart';

class HomeController extends GetxController {
  final tabIndex = 0.obs;
  final loadedMedia = [].obs;
  final selectedIndex = 0.obs;
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
  }

  Future<void> loadMedia({bool reset = false}) async {
    if (reset) {
      page = 1;
      pages = null;
      loadedMedia.clear();
    }
    if (pages == null || page <= pages!) {
      final result = await Util.getClient().getMediaList(qs: {
        'p': page.toString(),
        'deleted': tabs[tabIndex.value].key == 'trash' ? '1' : '0'
      }, onPages: (foundPages) => pages = foundPages);
      loadedMedia.addAll(result);
      Util.debug('Added ${result.length}');
      page++;
    }
  }

  void onTabTapped(int index) async {
    tabIndex(index);
    await loadMedia(reset: true);
  }

  reload() {
    refreshIndicatorKey.currentState?.show();
  }

  deleteMedia() async {
    await Util.getClient()
        .deleteMedia([(loadedMedia[selectedIndex.value] as Media).id]);
    loadedMedia.removeAt(selectedIndex.value);
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
