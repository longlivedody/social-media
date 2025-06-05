import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class ImagePickerUtils {
  static const int _maxImageWidth = 1200;
  static const int _maxImageHeight = 1200;
  static const int _maxImageSizeInBytes = 5 * 1024 * 1024; // 5MB

  /// Shows a dialog to select image source (camera or gallery)
  static Future<ImageSource?> showImageSourceDialog(
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
                'Select Image Source',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Picks an image from the selected source and handles resizing if needed
  static Future<File?> pickAndProcessImage(BuildContext context) async {
    try {
      final ImageSource? source = await showImageSourceDialog(context);
      if (source == null) return null;

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: _maxImageWidth.toDouble(),
        maxHeight: _maxImageHeight.toDouble(),
        imageQuality: 85,
      );

      if (image == null) return null;

      final File imageFile = File(image.path);
      final int fileSize = await imageFile.length();

      if (fileSize > _maxImageSizeInBytes) {
        if (!context.mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image size should be less than 5MB'),
            backgroundColor: Colors.red,
          ),
        );
        return null;
      }

      return await resizeImageIfNeeded(imageFile);
    } catch (e) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  /// Resizes the image if it exceeds the maximum dimensions
  static Future<File> resizeImageIfNeeded(File imageFile) async {
    final Uint8List bytes = await imageFile.readAsBytes();
    final img.Image? originalImage = img.decodeImage(bytes);

    if (originalImage == null) return imageFile;

    if (originalImage.width <= _maxImageWidth &&
        originalImage.height <= _maxImageHeight) {
      return imageFile;
    }

    final img.Image resizedImage = img.copyResize(
      originalImage,
      width: _maxImageWidth,
      height: _maxImageHeight,
      interpolation: img.Interpolation.linear,
    );

    final Uint8List resizedBytes = img.encodeJpg(resizedImage, quality: 85);
    final String tempPath = imageFile.path.replaceAll('.jpg', '_resized.jpg');
    final File resizedFile = File(tempPath);
    await resizedFile.writeAsBytes(resizedBytes);

    return resizedFile;
  }

  /// Converts a File to base64 string
  static String getBase64Image(File imageFile) {
    final bytes = imageFile.readAsBytesSync();
    return base64Encode(bytes);
  }
}
