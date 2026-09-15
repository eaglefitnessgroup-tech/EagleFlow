import 'dart:io';
import 'package:file_picker/file_picker.dart';

Future<Map<String, List<int>>?> pickFolderFilesImpl() async {
  final path = await FilePicker.getDirectoryPath();
  if (path == null) return null;
  final dir = Directory(path);
  final files = dir.listSync(recursive: false).whereType<File>();
  final result = <String, List<int>>{};
  for (final f in files) {
    result[f.path.split(Platform.pathSeparator).last] = f.readAsBytesSync();
  }
  return result;
}
