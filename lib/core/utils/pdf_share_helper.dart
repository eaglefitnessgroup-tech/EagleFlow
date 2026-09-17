import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

typedef PdfShareInvoker = Future<ShareResult> Function(ShareParams params);

/// Shares an in-memory PDF through the platform share sheet.
///
/// Browser download fallback is deliberately disabled so callers can handle
/// unsupported file sharing separately from an explicit export action.
class PdfShareHelper {
  PdfShareHelper({PdfShareInvoker? share})
    : _share = share ?? SharePlus.instance.share;

  final PdfShareInvoker _share;

  Future<ShareResult> sharePdf({
    required Uint8List bytes,
    required String filename,
  }) {
    return _share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
        fileNameOverrides: [filename],
        downloadFallbackEnabled: false,
      ),
    );
  }
}
