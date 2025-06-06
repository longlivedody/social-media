import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class VideoPickerUtils {
  static const int _maxVideoDurationInSeconds = 60; // 1 minute
  static const int _maxVideoSizeInBytes = 50 * 1024 * 1024; // 50MB

  /// Shows a dialog to select video source (camera or gallery)
  static Future<ImageSource?> showVideoSourceDialog(
      BuildContext context) async {
    return showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Video Source',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Picks a video from the selected source and validates it
  static Future<File?> pickAndProcessVideo(BuildContext context) async {
    try {
      final ImageSource? source = await showVideoSourceDialog(context);
      if (source == null) return null;

      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: source,
        maxDuration: Duration(seconds: _maxVideoDurationInSeconds),
      );

      if (video == null) return null;

      final File videoFile = File(video.path);
      final int fileSize = await videoFile.length();

      if (fileSize > _maxVideoSizeInBytes) {
        if (!context.mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video size should be less than 50MB'),
            backgroundColor: Colors.red,
          ),
        );
        return null;
      }

      return videoFile;
    } catch (e) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking video: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }
}
