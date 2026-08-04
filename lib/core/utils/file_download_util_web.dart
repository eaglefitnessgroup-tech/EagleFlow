// Web implementation — triggers a browser anchor-download.
//
// Uses `package:web` + `dart:js_interop` (Dart 3 / Flutter 3.24+).
// The object URL is always revoked after the click to release memory.

import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

abstract class FileDownloadUtil {
  /// Triggers a browser file download for [bytes] with [filename].
  ///
  /// Creates a temporary Blob object URL, clicks an invisible anchor element,
  /// then immediately revokes the URL.
  static Future<void> save({
    required List<int> bytes,
    required String filename,
  }) async {
    final uint8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

    // Build a Blob from the raw bytes.
    final blob = web.Blob(
      [uint8.toJS].toJS,
      web.BlobPropertyBag(type: _mimeType(filename)),
    );

    // Create an object URL and revoke it after the click.
    final url = web.URL.createObjectURL(blob);
    try {
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = url;
      anchor.download = filename;
      anchor.style.display = 'none';

      web.document.body!.appendChild(anchor);
      anchor.click();
      web.document.body!.removeChild(anchor);
    } finally {
      // Revoke regardless of success or failure.
      web.URL.revokeObjectURL(url);
    }
  }

  static String _mimeType(String filename) {
    if (filename.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    } else if (filename.endsWith('.zip')) {
      return 'application/zip';
    } else if (filename.endsWith('.csv')) {
      return 'text/csv';
    }
    return 'application/octet-stream';
  }
}
