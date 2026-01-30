import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../utils/logger.dart';

/// Service for handling goal completion images
class GoalImageService {
  static final GoalImageService _instance = GoalImageService._internal();
  factory GoalImageService() => _instance;
  GoalImageService._internal();

  final ImagePicker _picker = ImagePicker();

  /// Pick image from camera
  Future<File?> pickFromCamera() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return null;
      return File(picked.path);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to pick image from camera', e, stackTrace);
      return null;
    }
  }

  /// Pick image from gallery
  Future<File?> pickFromGallery() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return null;
      return File(picked.path);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to pick image from gallery', e, stackTrace);
      return null;
    }
  }

  /// Save completion image permanently to app storage
  Future<String?> saveCompletionImage(String goalId, File image) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/goal_images');
      
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final ext = p.extension(image.path).isNotEmpty 
          ? p.extension(image.path) 
          : '.jpg';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savedPath = '${imagesDir.path}/${goalId}_$timestamp$ext';
      
      await image.copy(savedPath);
      AppLogger.info('Saved completion image to: $savedPath');
      return savedPath;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save completion image', e, stackTrace);
      return null;
    }
  }

  /// Delete completion image when goal is deleted
  Future<void> deleteImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;
    
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        AppLogger.info('Deleted completion image: $imagePath');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete image', e, stackTrace);
    }
  }

  /// Check if image file exists
  Future<bool> imageExists(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return false;
    return File(imagePath).exists();
  }

  /// Get the images directory path
  Future<String> getImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/goal_images';
  }
}
