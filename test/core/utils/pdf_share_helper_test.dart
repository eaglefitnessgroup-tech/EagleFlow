import 'dart:typed_data';

import 'package:eagleflow/core/utils/pdf_share_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  test('shares PDF bytes with its MIME type and filename override', () async {
    final bytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
    ShareParams? capturedParams;
    final helper = PdfShareHelper(
      share: (params) async {
        capturedParams = params;
        return const ShareResult('test', ShareResultStatus.success);
      },
    );

    final result = await helper.sharePdf(
      bytes: bytes,
      filename: 'quotation.pdf',
    );

    expect(result.status, ShareResultStatus.success);
    expect(capturedParams, isNotNull);
    expect(capturedParams!.downloadFallbackEnabled, isFalse);
    expect(capturedParams!.fileNameOverrides, ['quotation.pdf']);
    expect(capturedParams!.files, hasLength(1));
    expect(capturedParams!.files!.single.mimeType, 'application/pdf');
    expect(await capturedParams!.files!.single.readAsBytes(), bytes);
  });
}
