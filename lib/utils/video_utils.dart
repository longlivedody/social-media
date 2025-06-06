import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class VideoUtils {
  static bool isBase64Video(String videoString) {
    try {
      // Check if the string starts with data:video
      if (videoString.startsWith('data:video')) {
        return true;
      }
      // Try to decode the string as base64
      base64Decode(videoString);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String> _saveBase64ToFile(String base64String) async {
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final file = File('${tempDir.path}/$fileName');

      // Decode base64 string
      List<int> bytes;
      if (base64String.startsWith('data:video')) {
        final parts = base64String.split(',');
        if (parts.length == 2) {
          bytes = base64Decode(parts[1]);
        } else {
          throw Exception('Invalid data URL format');
        }
      } else {
        bytes = base64Decode(base64String);
      }

      // Write to file
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      throw Exception('Failed to save base64 video: $e');
    }
  }

  static Future<VideoPlayerController> getVideoController(
      String videoString) async {
    try {
      if (isBase64Video(videoString)) {
        // Save base64 to temporary file and get the file path
        final filePath = await _saveBase64ToFile(videoString);
        // Create controller from file
        return VideoPlayerController.file(File(filePath));
      }
      // If it's a network URL
      return VideoPlayerController.networkUrl(Uri.parse(videoString));
    } catch (e) {
      throw Exception('Failed to create video controller: $e');
    }
  }
}
