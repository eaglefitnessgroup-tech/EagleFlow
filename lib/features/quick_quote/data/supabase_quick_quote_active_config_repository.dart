import 'package:flutter/foundation.dart';

import '../../../core/supabase/supabase_service.dart';
import '../domain/quick_quote_active_configuration.dart';
import '../domain/quick_quote_active_config_repository.dart';
import '../domain/quick_quote_configuration.dart';
import 'quick_quote_active_config_cache.dart';

class SupabaseQuickQuoteActiveConfigRepository
    implements QuickQuoteActiveConfigRepository {
  SupabaseQuickQuoteActiveConfigRepository({
    required this.supabase,
    required this.localCache,
    required this.sessionIdProvider,
  });

  final SupabaseService supabase;
  final QuickQuoteActiveConfigCache localCache;
  final String? Function() sessionIdProvider;

  @override
  Future<QuickQuoteActiveConfigLoadResult> loadActiveConfiguration() async {
    final sessionId = sessionIdProvider();
    if (sessionId == null || sessionId.trim().isEmpty) {
      throw const QuickQuoteActiveConfigUnavailableException(
        'Quick Quote automation configuration is not available. Please sign in again.',
      );
    }

    try {
      _requireClient();
      final versionId = await fetchActiveVersionId();
      _ensureCurrentSession(sessionId);
      if (versionId == null) {
        throw const _NoActiveQuickQuoteConfiguration();
      }
      final configuration = await _loadRemote(versionId);
      configuration.validate();
      _ensureCurrentSession(sessionId);
      await localCache.replaceConfiguration(
        configuration,
        canCommit: () => sessionIdProvider() == sessionId,
      );
      _ensureCurrentSession(sessionId);
      return QuickQuoteActiveConfigLoadResult(
        configuration: configuration,
        source: QuickQuoteActiveConfigSource.remote,
      );
    } on QuickQuoteActiveConfigStaleSessionException {
      rethrow;
    } on _NoActiveQuickQuoteConfiguration {
      throw const QuickQuoteActiveConfigUnavailableException(
        'Quick Quote automation configuration is not available. Please contact an administrator.',
      );
    } catch (remoteError) {
      _ensureCurrentSession(sessionId);
      try {
        final cached = await localCache.getConfiguration();
        _ensureCurrentSession(sessionId);
        if (cached != null) {
          cached.validate();
          return QuickQuoteActiveConfigLoadResult(
            configuration: cached,
            source: QuickQuoteActiveConfigSource.cache,
          );
        }
      } on QuickQuoteActiveConfigStaleSessionException {
        rethrow;
      } catch (_) {
        // Invalid cache data is treated as unavailable and is never returned.
      }
      throw QuickQuoteActiveConfigUnavailableException(
        'Quick Quote automation configuration is not available. Please contact an administrator.',
        remoteError,
      );
    }
  }

  Future<QuickQuoteActiveConfiguration> _loadRemote(String versionId) async {
    final rows = await Future.wait([
      fetchChildRows('quick_quote_budget_profiles', versionId),
      fetchChildRows('quick_quote_config_allocations', versionId),
      fetchChildRows('quick_quote_config_strength_priorities', versionId),
      fetchChildRows('quick_quote_config_role_mappings', versionId),
      fetchChildRows('quick_quote_config_rules', versionId),
    ]);
    return QuickQuoteActiveConfiguration(
      versionId: versionId,
      profiles: _parse(rows[0], QuickQuoteBudgetProfile.fromSupabase),
      allocations: _parse(rows[1], QuickQuoteConfigAllocation.fromSupabase),
      strengthPriorities: _parse(
        rows[2],
        QuickQuoteConfigStrengthPriority.fromSupabase,
      ),
      roleMappings: _parse(rows[3], QuickQuoteConfigRoleMapping.fromSupabase),
      rules: _parse(rows[4], QuickQuoteConfigRule.fromSupabase),
    );
  }

  List<T> _parse<T>(
    List<dynamic> rows,
    T Function(Map<String, dynamic>) parser,
  ) => rows
      .map((row) => parser(Map<String, dynamic>.from(row as Map)))
      .toList(growable: false);

  void _requireClient() {
    if (!hasClient) {
      throw StateError('Supabase is unavailable.');
    }
  }

  void _ensureCurrentSession(String sessionId) {
    if (sessionIdProvider() != sessionId) {
      throw const QuickQuoteActiveConfigStaleSessionException();
    }
  }

  @visibleForTesting
  bool get hasClient => supabase.client != null;

  @visibleForTesting
  Future<String?> fetchActiveVersionId() async {
    final row = await supabase.client!
        .from('quick_quote_config_versions')
        .select('id')
        .eq('is_active', true)
        .maybeSingle();
    return row?['id'] as String?;
  }

  @visibleForTesting
  Future<List<dynamic>> fetchChildRows(String table, String versionId) async =>
      await supabase.client!
          .from(table)
          .select()
          .eq('config_version_id', versionId)
          .order('sort_order');
}

class _NoActiveQuickQuoteConfiguration implements Exception {
  const _NoActiveQuickQuoteConfiguration();
}
