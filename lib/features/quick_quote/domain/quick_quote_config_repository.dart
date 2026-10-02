import 'quick_quote_configuration.dart';

abstract interface class QuickQuoteConfigRepository {
  Future<QuickQuoteConfiguration?> getActiveConfiguration();

  Future<List<QuickQuoteConfigVersion>> getVersionHistory();

  Future<QuickQuoteConfiguration> applyConfiguration({
    required String sourceFilename,
    required QuickQuoteConfiguration configuration,
    required QuickQuoteConfigValidationSummary validationSummary,
  });

  Future<QuickQuoteConfiguration> activateVersion(String versionId);
}

class QuickQuoteConfigRepositoryException implements Exception {
  const QuickQuoteConfigRepositoryException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
