// IO (Windows / macOS / Linux) implementation.
//
// Saves the file to the system Downloads folder obtained via path_provider.
// Falls back to the application documents directory if Downloads is unavailable.

import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract class FileDownloadUtil {
  /// Saves [bytes] as [filename] in the user's Downloads folder.
  ///
  /// Throws if the write fails.
  static Future<void> save({
    required List<int> bytes,
    required String filename,
  }) async {
    final dir = await _resolveDownloadsDir();
    final safeName = _safeName(filename);
    final dest = File(p.join(dir.path, safeName));
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    await dest.writeAsBytes(data, flush: true);
  }

  static Future<Directory> _resolveDownloadsDir() async {
    // getDownloadsDirectory() is available on Windows / macOS / Linux.
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;
    // Fallback: app documents directory.
    return getApplicationDocumentsDirectory();
  }

  /// Strips any path separators so the name is always a plain filename.
  static String _safeName(String name) =>
      p.basename(name).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}
