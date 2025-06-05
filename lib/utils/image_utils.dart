import 'dart:convert';
import 'package:flutter/material.dart';

class ImageUtils {
  static bool isBase64Image(String imageString) {
    try {
      // Check if the string starts with data:image
      if (imageString.startsWith('data:image')) {
        return true;
      }
      // Try to decode the string as base64
      base64Decode(imageString);
      return true;
    } catch (e) {
      return false;
    }
  }

  static ImageProvider getImageProvider(String imageString) {
    if (isBase64Image(imageString)) {
      // If it's a data URL, extract the base64 part
      if (imageString.startsWith('data:image')) {
        final parts = imageString.split(',');
        if (parts.length == 2) {
          return MemoryImage(base64Decode(parts[1]));
        }
      }
      // If it's a plain base64 string
      return MemoryImage(base64Decode(imageString));
    }
    // If it's a network URL
    return NetworkImage(imageString);
  }
}
