import 'package:flutter/foundation.dart';

import '../../../core/supabase/supabase_service.dart';
import '../domain/quick_quote_config_repository.dart';
import '../domain/quick_quote_configuration.dart';

class SupabaseQuickQuoteConfigRepository implements QuickQuoteConfigRepository {
  SupabaseQuickQuoteConfigRepository(this.supabase);

  final SupabaseService supabase;

  @override
  Future<QuickQuoteConfiguration?> getActiveConfiguration() async {
    _requireClient();
    try {
      final row = await fetchActiveVersion();
      if (row == null) return null;
      return _loadConfiguration(row);
    } catch (error) {
      throw QuickQuoteConfigRepositoryException(
        'Unable to load the active Quick Quote configuration.',
        error,
      );
    }
  }

  @override
  Future<List<QuickQuoteConfigVersion>> getVersionHistory() async {
    _requireClient();
    try {
      final rows = await fetchVersionHistory();
      return rows
          .map(
            (row) => QuickQuoteConfigVersion.fromSupabase(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } catch (error) {
      throw QuickQuoteConfigRepositoryException(
        'Unable to load Quick Quote configuration history.',
        error,
      );
    }
  }

  @override
  Future<QuickQuoteConfiguration> applyConfiguration({
    required String sourceFilename,
    required QuickQuoteConfiguration configuration,
    required QuickQuoteConfigValidationSummary validationSummary,
  }) async {
    _requireClient();
    try {
      final result = await callApplyConfiguration(
        sourceFilename: sourceFilename,
        validationSummary: validationSummary.toJson(),
        payload: configuration.toPayload(),
      );
      final versionId = _rpcVersionId(result);
      final versionRow = await fetchVersionById(versionId);
      if (versionRow == null) {
        throw StateError('The created configuration version was not found.');
      }
      return _loadConfiguration(versionRow);
    } catch (error) {
      throw QuickQuoteConfigRepositoryException(
        'The Quick Quote configuration could not be applied.',
        error,
      );
    }
  }

  @override
  Future<QuickQuoteConfiguration> activateVersion(String versionId) async {
    _requireClient();
    try {
      final result = await callActivateVersion(versionId);
      final activeId = _rpcVersionId(result);
      final versionRow = await fetchVersionById(activeId);
      if (versionRow == null) {
        throw StateError('The activated configuration version was not found.');
      }
      return _loadConfiguration(versionRow);
    } catch (error) {
      throw QuickQuoteConfigRepositoryException(
        'The selected Quick Quote configuration could not be activated.',
        error,
      );
    }
  }

  Future<QuickQuoteConfiguration> _loadConfiguration(
    Map<String, dynamic> versionRow,
  ) async {
    final version = QuickQuoteConfigVersion.fromSupabase(versionRow);
    final rows = await Future.wait([
      fetchChildRows('quick_quote_budget_profiles', version.id),
      fetchChildRows('quick_quote_config_allocations', version.id),
      fetchChildRows('quick_quote_config_strength_priorities', version.id),
      fetchChildRows('quick_quote_config_role_mappings', version.id),
      fetchChildRows('quick_quote_config_rules', version.id),
    ]);
    return QuickQuoteConfiguration(
      version: version,
      profiles: rows[0]
          .map(
            (row) => QuickQuoteBudgetProfile.fromSupabase(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false),
      allocations: rows[1]
          .map(
            (row) => QuickQuoteConfigAllocation.fromSupabase(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false),
      strengthPriorities: rows[2]
          .map(
            (row) => QuickQuoteConfigStrengthPriority.fromSupabase(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false),
      roleMappings: rows[3]
          .map(
            (row) => QuickQuoteConfigRoleMapping.fromSupabase(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false),
      rules: rows[4]
          .map(
            (row) => QuickQuoteConfigRule.fromSupabase(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  String _rpcVersionId(dynamic result) {
    if (result is String) return result;
    if (result is Map && result['id'] is String) return result['id'] as String;
    if (result is List && result.isNotEmpty && result.first is Map) {
      final id = (result.first as Map)['id'];
      if (id is String) return id;
    }
    throw const FormatException('Configuration RPC returned no version ID.');
  }

  void _requireClient() {
    if (!hasClient) {
      throw const QuickQuoteConfigRepositoryException(
        'Supabase is unavailable. Configuration management requires an online connection.',
      );
    }
  }

  @visibleForTesting
  bool get hasClient => supabase.client != null;

  @visibleForTesting
  Future<Map<String, dynamic>?> fetchActiveVersion() async {
    final row = await supabase.client!
        .from('quick_quote_config_versions')
        .select()
        .eq('is_active', true)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  @visibleForTesting
  Future<List<dynamic>> fetchVersionHistory() async => await supabase.client!
      .from('quick_quote_config_versions')
      .select()
      .order('version_number', ascending: false);

  @visibleForTesting
  Future<Map<String, dynamic>?> fetchVersionById(String versionId) async {
    final row = await supabase.client!
        .from('quick_quote_config_versions')
        .select()
        .eq('id', versionId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  @visibleForTesting
  Future<List<dynamic>> fetchChildRows(String table, String versionId) async =>
      await supabase.client!
          .from(table)
          .select()
          .eq('config_version_id', versionId)
          .order('sort_order');

  @visibleForTesting
  Future<dynamic> callApplyConfiguration({
    required String sourceFilename,
    required Map<String, dynamic> validationSummary,
    required Map<String, dynamic> payload,
  }) => supabase.client!.rpc(
    'apply_quick_quote_config',
    params: {
      'p_source_filename': sourceFilename,
      'p_validation_summary': validationSummary,
      'p_payload': payload,
    },
  );

  @visibleForTesting
  Future<dynamic> callActivateVersion(String versionId) => supabase.client!.rpc(
    'activate_quick_quote_config_version',
    params: {'p_version_id': versionId},
  );
}
