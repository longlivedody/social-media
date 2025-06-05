// models/video_info.dart (if you haven't created it yet)
class VideoInfo {
  final String id;
  final String
  title; // You might display this somewhere or use it for analytics
  final String videoUrl;

  VideoInfo({required this.id, required this.title, required this.videoUrl});
}

final List<VideoInfo> sampleVideos = [
  VideoInfo(
    id: '1',
    title: 'Big Buck Bunny',
    videoUrl:
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
  ),
  VideoInfo(
    id: '2',
    title: 'Elephants Dream',
    videoUrl:
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
  ),
  VideoInfo(
    id: '3',
    title: 'For Bigger Blazes',
    videoUrl:
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
  ),
];
