import 'quick_quote_configuration.dart';

enum QuickQuoteActiveConfigSource { remote, cache }

class QuickQuoteActiveConfigLoadResult {
  const QuickQuoteActiveConfigLoadResult({
    required this.configuration,
    required this.source,
  });

  final QuickQuoteActiveConfiguration configuration;
  final QuickQuoteActiveConfigSource source;
}

class QuickQuoteActiveConfiguration {
  QuickQuoteActiveConfiguration({
    required this.versionId,
    required List<QuickQuoteBudgetProfile> profiles,
    required List<QuickQuoteConfigAllocation> allocations,
    required List<QuickQuoteConfigStrengthPriority> strengthPriorities,
    required List<QuickQuoteConfigRoleMapping> roleMappings,
    required List<QuickQuoteConfigRule> rules,
  }) : profiles = List.unmodifiable(profiles),
       allocations = List.unmodifiable(allocations),
       strengthPriorities = List.unmodifiable(strengthPriorities),
       roleMappings = List.unmodifiable(roleMappings),
       rules = List.unmodifiable(rules) {
    validate();
  }

  final String versionId;
  final List<QuickQuoteBudgetProfile> profiles;
  final List<QuickQuoteConfigAllocation> allocations;
  final List<QuickQuoteConfigStrengthPriority> strengthPriorities;
  final List<QuickQuoteConfigRoleMapping> roleMappings;
  final List<QuickQuoteConfigRule> rules;

  void validate() {
    if (versionId.trim().isEmpty) {
      throw const FormatException('Active configuration version is missing.');
    }
    if (profiles.isEmpty ||
        allocations.isEmpty ||
        strengthPriorities.isEmpty ||
        roleMappings.isEmpty ||
        rules.isEmpty) {
      throw const FormatException(
        'Active Quick Quote configuration is incomplete.',
      );
    }

    final profileIds = <String>{};
    final profilesByBrand = <String, List<QuickQuoteBudgetProfile>>{};
    for (final profile in profiles) {
      if (profile.profileId.trim().isEmpty ||
          profile.brand.trim().isEmpty ||
          !profile.budgetMin.isFinite ||
          !profile.budgetMax.isFinite ||
          profile.budgetMin < 0 ||
          profile.budgetMax < profile.budgetMin ||
          !profileIds.add(profile.profileId)) {
        throw const FormatException('Invalid Quick Quote budget profile.');
      }
      profilesByBrand.putIfAbsent(_token(profile.brand), () => []).add(profile);
    }
    for (final brandProfiles in profilesByBrand.values) {
      brandProfiles.sort(
        (left, right) => left.budgetMin.compareTo(right.budgetMin),
      );
      for (var index = 1; index < brandProfiles.length; index++) {
        if (brandProfiles[index].budgetMin <=
            brandProfiles[index - 1].budgetMax) {
          throw const FormatException(
            'Quick Quote budget profiles must not overlap.',
          );
        }
      }
    }

    final roleMappingKeys = <String>{};
    for (final mapping in roleMappings) {
      final productId = mapping.productId;
      if (mapping.productCode.trim().isEmpty ||
          productId == null ||
          productId.trim().isEmpty ||
          mapping.roleKey.trim().isEmpty ||
          !roleMappingKeys.add(
            _mappingKey(mapping.productCode, mapping.roleKey),
          )) {
        throw const FormatException(
          'Invalid Quick Quote product role mapping.',
        );
      }
    }

    final allocationsByProfile = <String, int>{};
    for (final allocation in allocations) {
      final productId = allocation.productId;
      if (!profileIds.contains(allocation.profileId) ||
          allocation.sectionOrder <= 0 ||
          allocation.priority <= 0 ||
          allocation.quantity <= 0 ||
          allocation.productCode.trim().isEmpty ||
          productId == null ||
          productId.trim().isEmpty ||
          !roleMappingKeys.contains(
            _mappingKey(allocation.productCode, allocation.roleKey),
          )) {
        throw const FormatException(
          'Invalid Quick Quote configuration allocation.',
        );
      }
      allocationsByProfile.update(
        allocation.profileId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    if (profileIds.any(
      (profileId) => !allocationsByProfile.containsKey(profileId),
    )) {
      throw const FormatException(
        'Every Quick Quote profile must contain allocations.',
      );
    }

    for (final priority in strengthPriorities) {
      final productId = priority.productId;
      if (priority.brand.trim().isEmpty ||
          priority.strengthArea.trim().isEmpty ||
          priority.priority <= 0 ||
          priority.productCode.trim().isEmpty ||
          productId == null ||
          productId.trim().isEmpty) {
        throw const FormatException('Invalid Quick Quote strength priority.');
      }
    }
  }

  QuickQuoteBudgetProfile? resolveProfile(String brand, double budget) {
    final matches = profiles
        .where(
          (profile) =>
              _token(profile.brand) == _token(brand) &&
              budget >= profile.budgetMin &&
              budget <= profile.budgetMax,
        )
        .toList(growable: false);
    if (matches.length > 1) {
      throw const FormatException(
        'Multiple active Quick Quote profiles match the selected budget.',
      );
    }
    return matches.singleOrNull;
  }

  List<QuickQuoteBudgetProfile> profilesForBrand(String brand) {
    final matches = profiles
        .where((profile) => _token(profile.brand) == _token(brand))
        .toList();
    matches.sort((left, right) => left.budgetMin.compareTo(right.budgetMin));
    return List.unmodifiable(matches);
  }

  Map<String, Object?> toCacheJson() => {
    'versionId': versionId,
    'profiles': profiles.map((row) => row.toPayload()).toList(),
    'allocations': allocations.map((row) => row.toPayload()).toList(),
    'strengthPriorities': strengthPriorities
        .map((row) => row.toPayload())
        .toList(),
    'roleMappings': roleMappings.map((row) => row.toPayload()).toList(),
    'rules': rules.map((row) => row.toPayload()).toList(),
  };

  factory QuickQuoteActiveConfiguration.fromCacheJson(
    Map<String, Object?> json,
  ) {
    List<Map<String, dynamic>> rows(String key) {
      final value = json[key];
      if (value is! List) {
        throw FormatException('Cached $key is missing.');
      }
      return value
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
    }

    return QuickQuoteActiveConfiguration(
      versionId: json['versionId'] as String? ?? '',
      profiles: rows(
        'profiles',
      ).map(QuickQuoteBudgetProfile.fromSupabase).toList(growable: false),
      allocations: rows(
        'allocations',
      ).map(QuickQuoteConfigAllocation.fromSupabase).toList(growable: false),
      strengthPriorities: rows('strengthPriorities')
          .map(QuickQuoteConfigStrengthPriority.fromSupabase)
          .toList(growable: false),
      roleMappings: rows(
        'roleMappings',
      ).map(QuickQuoteConfigRoleMapping.fromSupabase).toList(growable: false),
      rules: rows(
        'rules',
      ).map(QuickQuoteConfigRule.fromSupabase).toList(growable: false),
    );
  }
}

String _mappingKey(String productCode, String roleKey) =>
    '${productCode.trim().toUpperCase()}|${roleKey.trim().toLowerCase()}';

String _token(String value) => value.trim().toLowerCase();
