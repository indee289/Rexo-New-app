import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Shared plumbing for the PDF, Excel, and backup writers.
class ExportFiles {
  ExportFiles._();

  static Future<Directory> dir() async {
    final base = await getApplicationDocumentsDirectory();
    final out = Directory(p.join(base.path, 'exports'));
    if (!out.existsSync()) out.createSync(recursive: true);
    return out;
  }

  static Future<File> write(String filename, List<int> bytes) async {
    final out = await dir();
    final file = File(p.join(out.path, filename));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> share(File file, {String? subject}) async {
    await Share.shareXFiles([XFile(file.path)], subject: subject);
  }
}
