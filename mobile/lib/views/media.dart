import 'package:get/get.dart';
import 'package:dmedia/controllers/media.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';

class MediaView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MediaController());

    return Scaffold(
      appBar: AppBar(
        actions: [IconButton(onPressed: () {}, icon: Icon(Icons.star_outline))],
      ),
      bottomNavigationBar: BottomNavigationBar(
          onTap: controller.onTabTapped,
          items: controller.tabs
              .map((tab) => BottomNavigationBarItem(
                    icon: Icon(tab.icon),
                    label: tab.label,
                  ))
              .toList()),
      body: controller.media.isVideo
          ? FutureBuilder<bool>(
              future: controller.started(),
              builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                if (snapshot.data == true) {
                  return Stack(
                    alignment: Alignment.bottomCenter,
                    children: <Widget>[
                      Center(
                          child: AspectRatio(
                        aspectRatio:
                            controller.videoController!.value.aspectRatio,
                        child: VideoPlayer(controller.videoController!),
                      )),
                      _ControlsOverlay(controller: controller.videoController!),
                      VideoProgressIndicator(controller.videoController!,
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
              child: controller.media.image(),
            ),
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
