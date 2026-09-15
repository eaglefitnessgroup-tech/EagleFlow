import 'package:file_picker/file_picker.dart';
import 'folder_picker_io.dart' if (dart.library.js_interop) 'folder_picker_web.dart';

/// Overridable in tests to avoid real folder-picker dialogs.
Map<String, List<int>>? mockFolderFilesForTesting;

/// Overridable in tests to avoid real file-picker dialogs for Excel/CSV.
/// The map must have exactly one entry: { filename: bytes }.
Map<String, List<int>>? mockExcelFileForTesting;

/// Opens an OS folder picker and returns a map of { filename → bytes } for
/// every file in the top-level of the selected directory.
/// Returns null if the user cancelled.
Future<Map<String, List<int>>?> pickFolderFiles() async {
  if (mockFolderFilesForTesting != null) {
    return mockFolderFilesForTesting;
  }
  return pickFolderFilesImpl();
}

/// Opens an OS file picker limited to .xlsx and .csv files.
/// Returns a single-entry map { filename → bytes }, or null if cancelled.
Future<Map<String, List<int>>?> pickExcelFile() async {
  if (mockExcelFileForTesting != null) {
    return mockExcelFileForTesting;
  }
  final result = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['xlsx', 'csv'],
  );
  if (result == null) return null;
  final bytes = await result.readAsBytes();
  return {result.name: bytes.toList()};
}
