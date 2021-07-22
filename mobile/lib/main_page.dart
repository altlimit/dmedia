import 'package:flutter/material.dart';
import 'package:dmedia/model.dart';
import 'package:dmedia/account_page.dart';
import 'package:dmedia/store.dart';
import 'package:dmedia/preference.dart';
import 'package:dmedia/background.dart';
import 'dart:convert';
import 'package:video_player/video_player.dart';

class MainPage extends StatefulWidget {
  MainPage({Key? key}) : super(key: key);

  @override
  MainPageState createState() => MainPageState();
}

class TabElement {
  String label;
  IconData icon;
  String key;

  TabElement(this.label, this.icon, this.key);
}

class MainPageState extends State<MainPage> with Store, WidgetsBindingObserver {
  final _db = DBProvider();
  int _tabIndex = 0;
  BuildContext? _buildContext;
  List<Media> _loadedMedia = [];
  int _page = 1;
  int? _pages;
  final _refreshIndicatorKey = new GlobalKey<RefreshIndicatorState>();
  final List<TabElement> _tabs = [
    TabElement('Gallery', Icons.photo, 'gallery'),
    TabElement('Albums', Icons.photo_album, 'albums'),
    TabElement('Search', Icons.search, 'search'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addObserver(this);
    Bg.on(taskSync, 'message', (d) async {
      if (_buildContext != null) {
        var data = d as Map<String, String>;
        if (data.containsKey('message'))
          Util.showMessage(context, data['message']!);
      }
      _refreshIndicatorKey.currentState?.show();
    });

    WidgetsBinding.instance!.addPostFrameCallback((Duration duration) async {
      _refreshIndicatorKey.currentState?.show();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);

    Bg.off(taskSync, name: 'message');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    Util.debug('State: $state');
    if (state == AppLifecycleState.resumed)
      await _db.syncMedia(Util.getActiveAccountId());
  }

  Future<void> loadMedia() async {
    final result = await _db.getRecentMedia(Util.getActiveAccountId(),
        page: _page,
        countPages: _pages == null
            ? (pages) {
                _pages = pages;
              }
            : null);
    if (_page <= _pages!) {
      setState(() {
        _loadedMedia.addAll(result);
      });
      _page++;
    }
  }

  void onTabTapped(int index) {
    setState(() {
      _tabIndex = index;
    });
  }

  reload() {
    _refreshIndicatorKey.currentState?.show();
  }

  Widget getTabWidget(String tabKey) {
    switch (tabKey) {
      case 'gallery':
        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              final media = _loadedMedia[index];
              final widget = media.isVideo()
                  ? Stack(children: <Widget>[
                      Container(
                          alignment: Alignment.center,
                          child: media.image(size: 256)),
                      Align(
                        alignment: Alignment.center,
                        child: Icon(Icons.play_circle),
                      )
                    ])
                  : Container(
                      alignment: Alignment.center,
                      child: media.image(size: 256),
                    );
              return InkWell(
                child: widget,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => media.isVideo()
                          ? VideoScreen(
                              media: media,
                            )
                          : ImageScreen(
                              media: media,
                            ),
                    ),
                  );
                },
              );
            },
            childCount: _loadedMedia.length,
          ),
        );
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
    _buildContext = context;

    return Scaffold(
        body: RefreshIndicator(
            key: _refreshIndicatorKey,
            onRefresh: () async {
              _page = 1;
              _pages = null;
              _loadedMedia.clear();
              await _db.syncMedia(Util.getActiveAccountId());
              await loadMedia();
              return Future.value('done');
            },
            child: CustomScrollView(
              slivers: <Widget>[
                SliverAppBar(
                  actions: [
                    IconButton(
                      icon: Icon(Icons.account_circle),
                      onPressed: () async {
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
                          Navigator.pushNamed(context, '/account');
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
                        Util.dialogList(
                            context, "Select Account", accountOptions,
                            (index, selected) {
                          if (selected != "Add New") {
                            selectedId = accountIds[index];
                          }
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      AccountPage(internalId: selectedId)));
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.settings),
                      onPressed: () {
                        Navigator.pushNamed(context, '/settings');
                      },
                    )
                  ],
                  leading: Icon(_tabs[_tabIndex].icon),
                  floating: true,
                  flexibleSpace:
                      FlexibleSpaceBar(title: Text(_tabs[_tabIndex].label)),
                ),
                getTabWidget(_tabs[_tabIndex].key)
              ],
            )),
        bottomNavigationBar: BottomNavigationBar(
            onTap: onTabTapped,
            currentIndex: _tabIndex,
            items: _tabs
                .map((tab) => BottomNavigationBarItem(
                      icon: Icon(tab.icon),
                      label: tab.label,
                    ))
                .toList()));
  }
}

class ImageScreen extends StatelessWidget {
  const ImageScreen({
    Key? key,
    @required this.media,
  }) : super(key: key);

  final Media? media;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: media!.image(),
    );
  }
}

class VideoScreen extends StatefulWidget {
  const VideoScreen({
    Key? key,
    @required this.media,
  }) : super(key: key);

  final Media? media;

  @override
  _VideoScreenState createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late VideoPlayerController _controller;
  bool initialized = false;

  @override
  void initState() {
    _initVideo();
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _initVideo() {
    final media = widget.media!;
    final client = Util.getClient();
    _controller = VideoPlayerController.network(media.getPath(client: client),
        httpHeaders: client.headers)
      ..setLooping(false)
      ..initialize().then((_) => setState(() => initialized = true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: initialized
          // If the video is initialized, display it
          ? Scaffold(
              body: Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  // Use the VideoPlayer widget to display the video.
                  child: VideoPlayer(_controller),
                ),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  // Wrap the play or pause in a call to `setState`. This ensures the
                  // correct icon is shown.
                  setState(() {
                    // If the video is playing, pause it.
                    if (_controller.value.isPlaying) {
                      _controller.pause();
                    } else {
                      // If the video is paused, play it.
                      _controller.play();
                    }
                  });
                },
                // Display the correct icon depending on the state of the player.
                child: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
              ),
            )
          // If the video is not yet initialized, display a spinner
          : Center(child: CircularProgressIndicator()),
    );
  }
}
