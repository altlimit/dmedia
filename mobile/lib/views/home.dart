import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dmedia/controllers/home.dart';

class HomeView extends StatelessWidget {
  Widget getTabWidget(HomeController controller, String tabKey) {
    switch (tabKey) {
      case 'gallery':
        return Obx(() => SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 5.0,
                  crossAxisSpacing: 5.0),
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final media = controller.loadedMedia[index];
                  final item = media.isVideo
                      ? Stack(children: <Widget>[
                          Container(
                              alignment: Alignment.center,
                              child: media.image(size: 256)),
                          Align(
                            alignment: Alignment.center,
                            child: Icon(Icons.play_circle),
                          )
                        ])
                      : media.image(size: 256);
                  return InkWell(
                    child: Card(child: item),
                    onTap: () => controller.onMediaItemTap(index),
                  );
                },
                childCount: controller.loadedMedia.length,
              ),
            ));
      case 'albums':
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return Container(
                color: index.isOdd ? Colors.white : Colors.black12,
                height: 100.0,
                child: Center(
                  child: Text('$index', textScaleFactor: 5),
                ),
              );
            },
            childCount: 20,
          ),
        );
      case 'search':
        return SliverFixedExtentList(
          itemExtent: 50.0,
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return Container(
                alignment: Alignment.center,
                color: Colors.lightBlue[100 * (index % 9)],
                child: Text('list item $index'),
              );
            },
          ),
        );
    }
    return Center(
      child: Text('Tab Key: $tabKey not implemented'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.put(HomeController());

    return Scaffold(
        body: RefreshIndicator(
            key: controller.refreshIndicatorKey,
            onRefresh: controller.onPullRefresh,
            child: CustomScrollView(
              slivers: <Widget>[
                SliverAppBar(
                  actions: [
                    IconButton(
                      icon: Icon(Icons.account_circle),
                      onPressed: controller.accountIconTap,
                    ),
                    IconButton(
                      icon: Icon(Icons.settings),
                      onPressed: controller.settingsIconOnTap,
                    )
                  ],
                  leading: Obx(() =>
                      Icon(controller.tabs[controller.tabIndex.value].icon)),
                  floating: true,
                  flexibleSpace: FlexibleSpaceBar(
                      title: Obx(() => Text(
                          controller.tabs[controller.tabIndex.value].label))),
                ),
                Obx(() => getTabWidget(
                    controller, controller.tabs[controller.tabIndex.value].key))
              ],
            )),
        bottomNavigationBar: Obx(() => BottomNavigationBar(
            onTap: controller.onTabTapped,
            currentIndex: controller.tabIndex.value,
            items: controller.tabs
                .map((tab) => BottomNavigationBarItem(
                      icon: Icon(tab.icon),
                      label: tab.label,
                    ))
                .toList())));
  }
}
