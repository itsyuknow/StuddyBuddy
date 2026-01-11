import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  static final ImagePicker _picker = ImagePicker();

  /// Pick image from gallery or camera
  /// Works on both mobile and web
  static Future<dynamic> pickImage({
    required ImageSource source,
    int maxWidth = 1920,
    int maxHeight = 1920,
    int imageQuality = 90,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );

      if (pickedFile == null) return null;

      if (kIsWeb) {
        // For web, return XFile directly
        return pickedFile;
      } else {
        // For mobile, return File
        return File(pickedFile.path);
      }
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  /// Get bytes from picked image (works on both web and mobile)
  static Future<List<int>?> getImageBytes(dynamic imageFile) async {
    try {
      if (imageFile == null) return null;

      if (kIsWeb) {
        // Web: XFile has readAsBytes
        return await (imageFile as XFile).readAsBytes();
      } else {
        // Mobile: File has readAsBytes
        return await (imageFile as File).readAsBytes();
      }
    } catch (e) {
      print('Error getting image bytes: $e');
      return null;
    }
  }

  /// Get file name from picked image
  static String getFileName(dynamic imageFile, String userId) {
    if (imageFile == null) {
      return '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    }

    if (kIsWeb) {
      return (imageFile as XFile).name;
    } else {
      return '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    }
  }
}