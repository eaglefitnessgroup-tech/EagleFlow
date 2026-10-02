import 'quick_quote_active_configuration.dart';

abstract interface class QuickQuoteActiveConfigRepository {
  Future<QuickQuoteActiveConfigLoadResult> loadActiveConfiguration();
}

class QuickQuoteActiveConfigUnavailableException implements Exception {
  const QuickQuoteActiveConfigUnavailableException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class QuickQuoteActiveConfigStaleSessionException implements Exception {
  const QuickQuoteActiveConfigStaleSessionException();

  @override
  String toString() => 'The authenticated session changed while loading.';
}
