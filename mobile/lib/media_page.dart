import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:dmedia/model.dart';

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
  bool _initialized = false;
  bool _startedPlaying = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();

    final media = widget.media!;
    final client = Util.getClient();

    _controller = VideoPlayerController.network(media.getPath(client: client),
        httpHeaders: client.headers);
    // _controller.addListener(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> started() async {
    await _controller.initialize();
    await _controller.play();
    _startedPlaying = true;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<bool>(
        future: started(),
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.data == true) {
            return Stack(
              alignment: Alignment.bottomCenter,
              children: <Widget>[
                Center(
                    child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )),
                _ControlsOverlay(controller: _controller),
                VideoProgressIndicator(_controller, allowScrubbing: true),
              ],
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
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
