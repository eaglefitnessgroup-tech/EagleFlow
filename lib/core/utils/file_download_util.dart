// Cross-platform file download utility.
//
// On web: triggers a browser `<a download>` click.
// On Windows/desktop: saves to the system Downloads folder.
//
// Usage:
//   await FileDownloadUtil.save(bytes: bytes, filename: 'report.xlsx');

export 'file_download_util_stub.dart'
    if (dart.library.html) 'file_download_util_web.dart'
    if (dart.library.io) 'file_download_util_io.dart';
