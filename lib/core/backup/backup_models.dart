import 'dart:convert';
import 'package:crypto/crypto.dart';

class BackupMetadata {
  final int schemaVersion;
  final String createdAt;
  final String appVersion;
  final Map<String, int> recordCounts;
  final String checksum;

  BackupMetadata({
    required this.schemaVersion,
    required this.createdAt,
    required this.appVersion,
    required this.recordCounts,
    required this.checksum,
  });

  factory BackupMetadata.fromJson(Map<String, dynamic> json) {
    return BackupMetadata(
      schemaVersion: json['schemaVersion'] as int,
      createdAt: json['createdAt'] as String,
      appVersion: json['appVersion'] as String,
      recordCounts: Map<String, int>.from(json['recordCounts'] as Map),
      checksum: json['checksum'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'createdAt': createdAt,
      'appVersion': appVersion,
      'recordCounts': recordCounts,
      'checksum': checksum,
    };
  }

  /// Verifies if the computed checksum of the payload matches the stored checksum.
  static String computeChecksum(String rawPayload) {
    final bytes = utf8.encode(rawPayload);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  bool verifyChecksum(String rawPayload) {
    return computeChecksum(rawPayload) == checksum;
  }
}

class BackupResult {
  final bool isSuccess;
  final String? filePath;
  final String? errorMessage;

  BackupResult.success(this.filePath) : isSuccess = true, errorMessage = null;

  BackupResult.failure(this.errorMessage) : isSuccess = false, filePath = null;
}

class RestorePreview {
  final bool isValid;
  final String? errorMessage;
  final int schemaVersion;
  final Map<String, int> recordCounts;
  final String? rawPayload;
  final Map<String, dynamic>? parsedPayload;

  RestorePreview({
    required this.isValid,
    this.errorMessage,
    this.schemaVersion = 0,
    this.recordCounts = const {},
    this.rawPayload,
    this.parsedPayload,
  });

  factory RestorePreview.success(
    int schemaVersion,
    Map<String, int> recordCounts,
    String rawPayload,
    Map<String, dynamic> parsedPayload,
  ) {
    return RestorePreview(
      isValid: true,
      schemaVersion: schemaVersion,
      recordCounts: recordCounts,
      rawPayload: rawPayload,
      parsedPayload: parsedPayload,
    );
  }

  factory RestorePreview.failure(String message) {
    return RestorePreview(isValid: false, errorMessage: message);
  }
}

class RestoreResult {
  final bool isSuccess;
  final String? errorMessage;

  RestoreResult.success() : isSuccess = true, errorMessage = null;

  RestoreResult.failure(this.errorMessage) : isSuccess = false;
}
