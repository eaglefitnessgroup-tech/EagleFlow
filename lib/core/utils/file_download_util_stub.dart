// Stub — should never be reached; web or IO impl is always chosen.

abstract class FileDownloadUtil {
  /// Saves [bytes] with the given [filename].
  ///
  /// Throws [UnsupportedError] if the platform is unrecognised.
  static Future<void> save({
    required List<int> bytes,
    required String filename,
  }) async {
    throw UnsupportedError(
      'FileDownloadUtil.save is not supported on this platform.',
    );
  }
}
