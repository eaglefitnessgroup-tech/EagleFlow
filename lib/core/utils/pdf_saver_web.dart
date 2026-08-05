import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<String?> savePdf(Uint8List bytes, String filename) async {
  await FilePicker.saveFile(
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    bytes: bytes,
  );
  return 'Downloaded to browser';
}
