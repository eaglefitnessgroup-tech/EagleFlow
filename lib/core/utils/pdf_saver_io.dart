import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<String?> savePdf(Uint8List bytes, String filename) async {
  final outputPath = await FilePicker.saveFile(
    dialogTitle: 'Save PDF',
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );
  if (outputPath != null) {
    final file = File(outputPath);
    await file.writeAsBytes(bytes);
    return outputPath;
  }
  return null;
}
