import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:dmedia/model.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class MediaScreen extends StatefulWidget {
  const MediaScreen({
    Key? key,
    @required this.media,
  }) : super(key: key);

  final Media? media;

  _MediaScreenState createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  late Media _media;
  VideoPlayerController? _controller;
  final List<TabElement> _tabs = [
    TabElement('Share', Icons.share, 'share'),
    TabElement('Details', Icons.list, 'details'),
    TabElement('Delete', Icons.delete_outline, 'delete'),
  ];

  @override
  void initState() {
    super.initState();
    _media = widget.media!;

    if (_media.isVideo) {
      final client = Util.getClient();

      _controller = VideoPlayerController.network(
          _media.getPath(client: client),
          httpHeaders: client.headers);
      // _controller.addListener(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<bool> started() async {
    await _controller?.initialize();
    await _controller?.play();
    return true;
  }

  void onTabTapped(int index) async {
    final tab = _tabs[index];
    if (tab.key == 'share') {
      var file = await DefaultCacheManager().getSingleFile(_media.getPath());
      await Share.shareFiles([file.path]);
    }
  }

  @override
  Widget build(BuildContext context) {
    late Widget body;
    if (_media.isVideo)
      body = FutureBuilder<bool>(
        future: started(),
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.data == true) {
            return Stack(
              alignment: Alignment.bottomCenter,
              children: <Widget>[
                Center(
                    child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                )),
                _ControlsOverlay(controller: _controller!),
                VideoProgressIndicator(_controller!, allowScrubbing: true),
              ],
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      );
    else
      body = Container(
        alignment: Alignment.center,
        child: _media.image(),
      );
    return Scaffold(
      appBar: AppBar(
        actions: [IconButton(onPressed: () {}, icon: Icon(Icons.star_outline))],
      ),
      bottomNavigationBar: BottomNavigationBar(
          onTap: onTabTapped,
          items: _tabs
              .map((tab) => BottomNavigationBarItem(
                    icon: Icon(tab.icon),
                    label: tab.label,
                  ))
              .toList()),
      body: body,
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({Key? key, required this.controller})
      : super(key: key);

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        AnimatedSwitcher(
          duration: Duration(milliseconds: 50),
          reverseDuration: Duration(milliseconds: 200),
          child: controller.value.isPlaying
              ? SizedBox.shrink()
              : Container(
                  child: Center(
                    child: Icon(
                      Icons.play_arrow,
                      size: 100.0,
                    ),
                  ),
                ),
        ),
        GestureDetector(
          onTap: () {
            controller.value.isPlaying ? controller.pause() : controller.play();
          },
        ),
      ],
    );
  }
}
