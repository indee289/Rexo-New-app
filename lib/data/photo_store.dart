import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Item photos live on the device only. They are never uploaded, and the synced
/// Sheet has no photo column.
///
/// Paths are stored relative to the app documents directory so a restored
/// backup or an OS-reassigned sandbox path does not break every image.
class PhotoStore {
  PhotoStore._();

  static String? _baseDir;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _baseDir = dir.path;
    final photos = Directory(p.join(dir.path, 'photos'));
    if (!photos.existsSync()) {
      photos.createSync(recursive: true);
    }
  }

  static String get baseDir => _baseDir ?? '';

  /// Absolute path for a stored relative path, or null when there is none.
  static String? resolve(String? relative) {
    if (relative == null || relative.isEmpty || _baseDir == null) return null;
    return p.join(_baseDir!, relative);
  }

  static File? file(String? relative) {
    final abs = resolve(relative);
    if (abs == null) return null;
    final f = File(abs);
    return f.existsSync() ? f : null;
  }

  /// Picks and downscales a photo, returning its relative path.
  static Future<String?> pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked == null) return null;
    if (_baseDir == null) await init();

    final name = 'item_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final relative = p.join('photos', name);
    await File(picked.path).copy(p.join(_baseDir!, relative));
    return relative;
  }

  static Future<void> delete(String? relative) async {
    final abs = resolve(relative);
    if (abs == null) return;
    final f = File(abs);
    if (f.existsSync()) {
      try {
        await f.delete();
      } on FileSystemException {
        // A photo that cannot be removed is not worth failing an edit over.
      }
    }
  }
}
