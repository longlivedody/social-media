import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';

import '../../models/video_model.dart';

class ReelsScreen extends StatefulWidget {
  final List<VideoInfo> videos;

  const ReelsScreen({super.key, required this.videos});

  @override
  ReelsScreenState createState() => ReelsScreenState();
}

String _formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return "${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}";
  } else {
    return "${twoDigits(minutes)}:${twoDigits(seconds)}";
  }
}

late PageController _pageController;
Map<int, VideoPlayerController> _videoControllers = {};
Map<int, Future<void>> _initializeVideoPlayerFutures = {};
int _currentPage = 0;

class ReelsScreenState extends State<ReelsScreen> {
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeAndPlay(0);
  }

  void _initializeAndPlay(int index) {
    if (widget.videos.isEmpty || index < 0 || index >= widget.videos.length) {
      return;
    }

    if (_videoControllers.containsKey(_currentPage) && _currentPage != index) {
      _videoControllers[_currentPage]?.removeListener(_onControllerUpdate);
      _videoControllers[_currentPage]?.pause();
    }

    final videoUrl = widget.videos[index].videoUrl;

    _videoControllers[index]?.dispose();

    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _videoControllers[index] = controller;

    controller.addListener(_onControllerUpdate);

    _initializeVideoPlayerFutures[index] = controller
        .initialize()
        .then((_) {
          if (mounted) {
            setState(() {});
            if (_currentPage == index) {
              controller.play();
              controller.setLooping(true);
            }
          }
        })
        .catchError((error) {
          debugPrint("Error initializing video at index $index: $error");
          if (mounted) {
            setState(() {});
          }
        });
  }

  void _onControllerUpdate() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoControllers.forEach((index, controller) {
      controller.removeListener(
        _onControllerUpdate,
      ); // Important: remove listeners
      controller.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return const Center(child: Text("No videos to display."));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.videos.length,
        onPageChanged: (index) {
          // Pause previous video
          final previousPageIndex = _currentPage;
          _videoControllers[previousPageIndex]?.pause();

          setState(() {
            _currentPage = index;
          });

          if (!_videoControllers.containsKey(index) ||
              !_videoControllers[index]!.value.isInitialized) {
            _initializeAndPlay(index);
          } else {
            _videoControllers[index]?.play();
            _videoControllers[index]?.setLooping(true);
          }
        },
        itemBuilder: (context, index) {
          return FutureBuilder(
            future: _initializeVideoPlayerFutures[index],
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  _videoControllers[index] != null &&
                  _videoControllers[index]!.value.isInitialized) {
                final controller = _videoControllers[index]!;
                // Get duration and position
                final Duration duration = controller.value.duration;
                final Duration position = controller.value.position;

                return Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (controller.value.isPlaying) {
                          controller.pause();
                        } else {
                          controller.play();
                        }
                      },
                      child: SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.fill,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: controller.value.size.width,
                            height: controller.value.size.height,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      ),
                    ),

                    VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      padding: const EdgeInsets.all(16.0),
                      colors: const VideoProgressColors(
                        playedColor: Colors.red,
                        bufferedColor: Colors.grey,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                    Positioned(
                      bottom: 40,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              shadows: <Shadow>[
                                Shadow(
                                  offset: Offset(0.0, 1.0),
                                  blurRadius: 3.0,
                                  color: Color.fromARGB(150, 0, 0, 0),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              shadows: <Shadow>[
                                Shadow(
                                  offset: Offset(0.0, 1.0),
                                  blurRadius: 3.0,
                                  color: Color.fromARGB(150, 0, 0, 0),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!controller.value.isPlaying)
                      Center(
                        child: IconButton(
                          icon: Icon(
                            controller.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            color: Colors.white.withAlpha(70),
                            size: 60,
                          ),
                          onPressed: () {
                            if (controller.value.isPlaying) {
                              controller.pause();
                            } else {
                              controller.play();
                            }
                          },
                        ),
                      ),
                  ],
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Error loading video",
                        style: TextStyle(color: Colors.red),
                      ),
                      Text(
                        widget.videos[index].title,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                return Shimmer.fromColors(
                  baseColor: Colors.grey[700]!,
                  highlightColor: Colors.grey[500]!,
                  child: Container(color: Colors.black),
                );
              }
            },
          );
        },
      ),
    );
  }
}
