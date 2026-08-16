import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> pickImage({
    required ImageSource source,
    int imageQuality = 75,
    double maxWidth = 1024,
    double maxHeight = 1024,
  }) async {
    try {
      return await _picker.pickImage(
        source: source,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
    } catch (e) {
      debugPrint("ImagePicker Error: $e");
      return null;
    }
  }

  /// Handles Android MainActivity destruction during camera/gallery pick
  static Future<XFile?> checkLostData() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty) return null;
      if (response.file != null) {
        return response.file;
      } else if (response.exception != null) {
        debugPrint("ImagePicker LostData Exception: ${response.exception}");
      }
    } catch (e) {
      debugPrint("ImagePicker checkLostData error: $e");
    }
    return null;
  }
}
