import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dmedia/controllers/home.dart';

class HomeView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Get.put(HomeController());

    return Scaffold(
        body: RefreshIndicator(
            key: c.refreshIndicatorKey,
            onRefresh: c.onPullRefresh,
            child: CustomScrollView(
              controller: c.scrollController,
              slivers: <Widget>[
                Obx(() => SliverAppBar(
                      actions: [
                        if (c.multiSelect.value) ...[
                          if (c.currentTab.key == 'trash')
                            IconButton(
                              icon: Icon(Icons.undo),
                              onPressed: c.restoreSelectedTap,
                            ),
                          if (c.currentTab.key == 'gallery')
                            IconButton(
                              icon: Icon(Icons.share),
                              onPressed: c.shareSelectedTap,
                            ),
                          IconButton(
                            icon: Icon(Icons.delete_outline),
                            onPressed: c.deleteSelectedTap,
                          )
                        ],
                        IconButton(
                          icon: Icon(Icons.account_circle),
                          onPressed: c.accountIconTap,
                        ),
                        IconButton(
                          icon: Icon(Icons.settings),
                          onPressed: c.settingsIconOnTap,
                        )
                      ],
                      leading: Obx(() => Icon(c.currentTab.icon)),
                      floating: true,
                      flexibleSpace: FlexibleSpaceBar(
                          title: Obx(() => Text(c.currentTab.label))),
                    )),
                Obx(() {
                  switch (c.currentTab.key) {
                    case 'gallery':
                    case 'trash':
                      return SliverGrid(
                        // todo this shouldn't be necessary but this works for now
                        key: Key('grid_${c.selectedIndexes.length}'),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                mainAxisSpacing: 5.0,
                                crossAxisSpacing: 5.0),
                        delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                            final media = c.loadedMedia[index];
                            var item = media.isVideo
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
                            if (c.multiSelect.value && c.isSelected(index))
                              item = Stack(children: [
                                Padding(
                                    padding: EdgeInsets.only(left: 5, right: 5),
                                    child: Container(
                                      child: item,
                                      alignment: Alignment.center,
                                    )),
                                Padding(
                                  padding: EdgeInsets.all(5),
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: Icon(Icons.check_circle),
                                  ),
                                )
                              ]);
                            return InkWell(
                              child: Card(child: item),
                              onTap: () => c.onMediaItemTap(index),
                              onLongPress: () => c.onMediaLongPress(index),
                            );
                          },
                          childCount: c.loadedMedia.length,
                        ),
                      );
                    case 'albums':
                      return SliverFillRemaining(
                        child:
                            Center(child: Text('Create and view albums here')),
                      );
                  }
                  return Center(child: const Text('...'));
                })
              ],
            )),
        bottomNavigationBar: Obx(() => BottomNavigationBar(
            onTap: c.onTabTapped,
            currentIndex: c.tabIndex.value,
            items: c.tabs
                .map((tab) => BottomNavigationBarItem(
                      icon: Icon(tab.icon),
                      label: tab.label,
                    ))
                .toList())));
  }
}
