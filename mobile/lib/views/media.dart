import 'package:dmedia/util.dart';
import 'package:get/get.dart';
import 'package:dmedia/controllers/media.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';

class MediaView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Get.put(MediaController());

    return Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(onPressed: () {}, icon: Icon(Icons.star_outline))
          ],
        ),
        bottomNavigationBar: Obx(() => BottomNavigationBar(
            currentIndex: c.tabIndex.value,
            onTap: c.onTabTapped,
            items: c.tabs
                .map((tab) => BottomNavigationBarItem(
                      icon: Icon(tab.icon),
                      label: tab.label,
                    ))
                .toList())),
        body: Obx(() => Stack(children: [
              GestureDetector(
                  child: c.media.isVideo
                      ? FutureBuilder<bool>(
                          key: Key('media_${c.media.id}'),
                          future: c.started(),
                          builder: (BuildContext context,
                              AsyncSnapshot<bool> snapshot) {
                            if (snapshot.data == true) {
                              return Stack(
                                alignment: Alignment.bottomCenter,
                                children: <Widget>[
                                  Center(
                                      child: AspectRatio(
                                    aspectRatio:
                                        c.videoController.value.aspectRatio,
                                    child: VideoPlayer(c.videoController),
                                  )),
                                  _ControlsOverlay(
                                      controller: c.videoController),
                                  VideoProgressIndicator(c.videoController,
                                      allowScrubbing: true),
                                ],
                              );
                            } else {
                              return Center(child: CircularProgressIndicator());
                            }
                          },
                        )
                      : Container(
                          alignment: Alignment.center,
                          child: InteractiveViewer(
                            panEnabled: false,
                            boundaryMargin: EdgeInsets.all(80),
                            minScale: 1,
                            maxScale: 2,
                            child: c.media.image(),
                          ),
                        ),
                  onHorizontalDragEnd: c.onItemSwipe),
              if (c.currentTab.key == 'details')
                Positioned.fill(
                    child: GestureDetector(
                        onTap: () => c.tabIndex(0),
                        child: Container(
                          decoration: new BoxDecoration(
                              border: new Border.all(color: Colors.transparent),
                              color: Colors.black87),
                          child: Center(
                              child: Column(
                            children: [
                              const Text('Details'),
                              if (!c.media.isLocal) Text('ID: ${c.media.id}'),
                              Text('Filename: ${c.media.name}'),
                              Text('Created: ${c.media.created}'),
                              Text('Content Type: ${c.media.ctype}'),
                              Text('Size: ${Util.formatBytes(c.media.size, 2)}')
                            ],
                          )),
                        )),
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 0)
            ])));
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
