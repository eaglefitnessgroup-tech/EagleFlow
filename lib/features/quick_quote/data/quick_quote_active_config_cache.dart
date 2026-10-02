import '../domain/quick_quote_active_configuration.dart';

abstract interface class QuickQuoteActiveConfigCache {
  Future<QuickQuoteActiveConfiguration?> getConfiguration();

  Future<void> replaceConfiguration(
    QuickQuoteActiveConfiguration configuration, {
    bool Function()? canCommit,
  });
}
