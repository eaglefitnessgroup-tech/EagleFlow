enum QuickQuoteConfigIssueSeverity { warning, error }

class QuickQuoteConfigIssue {
  const QuickQuoteConfigIssue({
    required this.severity,
    required this.message,
    this.sheet,
    this.row,
  });

  final QuickQuoteConfigIssueSeverity severity;
  final String message;
  final String? sheet;
  final int? row;

  String get location {
    if (sheet == null) return '';
    return row == null ? sheet! : '$sheet row $row';
  }
}

class QuickQuoteConfigValidationSummary {
  const QuickQuoteConfigValidationSummary({
    required this.profileCount,
    required this.allocationCount,
    required this.strengthPriorityCount,
    required this.roleMappingCount,
    required this.warningCount,
    required this.errorCount,
  });

  final int profileCount;
  final int allocationCount;
  final int strengthPriorityCount;
  final int roleMappingCount;
  final int warningCount;
  final int errorCount;

  bool get isValid => errorCount == 0;

  Map<String, dynamic> toJson() => {
    'profiles': profileCount,
    'allocations': allocationCount,
    'strength_priorities': strengthPriorityCount,
    'role_mappings': roleMappingCount,
    'warnings': warningCount,
    'errors': errorCount,
  };

  factory QuickQuoteConfigValidationSummary.fromJson(
    Map<String, dynamic>? json,
  ) => QuickQuoteConfigValidationSummary(
    profileCount: (json?['profiles'] as num?)?.toInt() ?? 0,
    allocationCount: (json?['allocations'] as num?)?.toInt() ?? 0,
    strengthPriorityCount: (json?['strength_priorities'] as num?)?.toInt() ?? 0,
    roleMappingCount: (json?['role_mappings'] as num?)?.toInt() ?? 0,
    warningCount: (json?['warnings'] as num?)?.toInt() ?? 0,
    errorCount: (json?['errors'] as num?)?.toInt() ?? 0,
  );
}

class QuickQuoteConfigVersion {
  const QuickQuoteConfigVersion({
    required this.id,
    required this.versionNumber,
    required this.sourceFilename,
    required this.createdAt,
    required this.createdBy,
    required this.isActive,
    required this.validationSummary,
    this.createdByName,
    this.activatedAt,
    this.activatedBy,
  });

  final String id;
  final int versionNumber;
  final String sourceFilename;
  final DateTime createdAt;
  final String createdBy;
  final String? createdByName;
  final DateTime? activatedAt;
  final String? activatedBy;
  final bool isActive;
  final QuickQuoteConfigValidationSummary validationSummary;

  factory QuickQuoteConfigVersion.fromSupabase(Map<String, dynamic> row) {
    final creator = row['created_by_user'];
    return QuickQuoteConfigVersion(
      id: row['id'] as String,
      versionNumber: (row['version_number'] as num).toInt(),
      sourceFilename: row['source_filename'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      createdBy: row['created_by'] as String,
      createdByName: creator is Map ? creator['name'] as String? : null,
      activatedAt: row['activated_at'] == null
          ? null
          : DateTime.parse(row['activated_at'] as String).toLocal(),
      activatedBy: row['activated_by'] as String?,
      isActive: row['is_active'] as bool? ?? false,
      validationSummary: QuickQuoteConfigValidationSummary.fromJson(
        row['validation_summary'] is Map
            ? Map<String, dynamic>.from(row['validation_summary'] as Map)
            : null,
      ),
    );
  }
}

class QuickQuoteBudgetProfile {
  const QuickQuoteBudgetProfile({
    required this.profileId,
    required this.brand,
    required this.budgetRange,
    required this.budgetMin,
    required this.budgetMax,
  });

  final String profileId;
  final String brand;
  final String budgetRange;
  final double budgetMin;
  final double budgetMax;

  String get identityKey => profileId;
  String get contentKey => [brand, budgetRange, budgetMin, budgetMax].join('|');

  Map<String, dynamic> toPayload() => {
    'profile_id': profileId,
    'brand': brand,
    'budget_range': budgetRange,
    'budget_min': budgetMin,
    'budget_max': budgetMax,
  };

  factory QuickQuoteBudgetProfile.fromSupabase(Map<String, dynamic> row) =>
      QuickQuoteBudgetProfile(
        profileId: row['profile_id'] as String,
        brand: row['brand'] as String,
        budgetRange: row['budget_range'] as String,
        budgetMin: (row['budget_min'] as num).toDouble(),
        budgetMax: (row['budget_max'] as num).toDouble(),
      );
}

class QuickQuoteConfigAllocation {
  const QuickQuoteConfigAllocation({
    required this.profileId,
    required this.sectionOrder,
    required this.section,
    required this.equipmentRole,
    required this.roleKey,
    required this.productCode,
    required this.productId,
    required this.quantity,
    required this.selectionMode,
    required this.priority,
    required this.reviewFlag,
    required this.notes,
  });

  final String profileId;
  final int sectionOrder;
  final String section;
  final String equipmentRole;
  final String roleKey;
  final String productCode;
  final String? productId;
  final int quantity;
  final String selectionMode;
  final int priority;
  final bool reviewFlag;
  final String notes;

  String get identityKey => '$profileId|$roleKey|$priority';
  String get contentKey => [
    sectionOrder,
    section,
    equipmentRole,
    productCode,
    productId,
    quantity,
    selectionMode,
    priority,
    reviewFlag,
    notes,
  ].join('|');

  Map<String, dynamic> toPayload() => {
    'profile_id': profileId,
    'section_order': sectionOrder,
    'section': section,
    'equipment_role': equipmentRole,
    'role_key': roleKey,
    'product_code': productCode,
    'product_id': productId,
    'quantity': quantity,
    'selection_mode': selectionMode,
    'priority': priority,
    'review_flag': reviewFlag,
    'notes': notes,
  };

  factory QuickQuoteConfigAllocation.fromSupabase(Map<String, dynamic> row) =>
      QuickQuoteConfigAllocation(
        profileId: row['profile_id'] as String,
        sectionOrder: (row['section_order'] as num).toInt(),
        section: row['section'] as String,
        equipmentRole: row['equipment_role'] as String,
        roleKey: row['role_key'] as String,
        productCode: row['product_code'] as String,
        productId: row['product_id'] as String?,
        quantity: (row['quantity'] as num).toInt(),
        selectionMode: row['selection_mode'] as String,
        priority: (row['priority'] as num).toInt(),
        reviewFlag: row['review_flag'] as bool? ?? false,
        notes: row['notes'] as String? ?? '',
      );
}

class QuickQuoteConfigStrengthPriority {
  const QuickQuoteConfigStrengthPriority({
    required this.brand,
    required this.strengthArea,
    required this.priority,
    required this.productCode,
    required this.productId,
    required this.seriesPrefix,
    required this.loadType,
    required this.equipmentRole,
    required this.automationRule,
    required this.source,
  });

  final String brand;
  final String strengthArea;
  final int priority;
  final String productCode;
  final String? productId;
  final String seriesPrefix;
  final String loadType;
  final String equipmentRole;
  final String automationRule;
  final String source;

  String get identityKey => '$brand|$strengthArea|$loadType|$priority';
  String get contentKey => [
    productCode,
    productId,
    seriesPrefix,
    equipmentRole,
    automationRule,
    source,
  ].join('|');

  Map<String, dynamic> toPayload() => {
    'brand': brand,
    'strength_area': strengthArea,
    'priority': priority,
    'product_code': productCode,
    'product_id': productId,
    'series_prefix': seriesPrefix,
    'load_type': loadType,
    'equipment_role': equipmentRole,
    'automation_rule': automationRule,
    'source': source,
  };

  factory QuickQuoteConfigStrengthPriority.fromSupabase(
    Map<String, dynamic> row,
  ) => QuickQuoteConfigStrengthPriority(
    brand: row['brand'] as String,
    strengthArea: row['strength_area'] as String,
    priority: (row['priority'] as num).toInt(),
    productCode: row['product_code'] as String,
    productId: row['product_id'] as String?,
    seriesPrefix: row['series_prefix'] as String? ?? '',
    loadType: row['load_type'] as String,
    equipmentRole: row['equipment_role'] as String,
    automationRule: row['automation_rule'] as String? ?? '',
    source: row['source'] as String? ?? '',
  );
}

class QuickQuoteConfigRoleMapping {
  const QuickQuoteConfigRoleMapping({
    required this.productCode,
    required this.productId,
    required this.productName,
    required this.catalogBrand,
    required this.category,
    required this.automationSection,
    required this.automationRole,
    required this.roleKey,
    required this.unitPriceAed,
    required this.autoEligible,
    required this.notes,
  });

  final String productCode;
  final String? productId;
  final String productName;
  final String catalogBrand;
  final String category;
  final String automationSection;
  final String automationRole;
  final String roleKey;
  final double unitPriceAed;
  final String autoEligible;
  final String notes;

  String get identityKey => '$productCode|$roleKey';
  String get contentKey => [
    productId,
    productName,
    catalogBrand,
    category,
    automationSection,
    automationRole,
    roleKey,
    unitPriceAed,
    autoEligible,
    notes,
  ].join('|');

  Map<String, dynamic> toPayload() => {
    'product_code': productCode,
    'product_id': productId,
    'product_name': productName,
    'catalog_brand': catalogBrand,
    'category': category,
    'automation_section': automationSection,
    'automation_role': automationRole,
    'role_key': roleKey,
    'unit_price_aed': unitPriceAed,
    'auto_eligible': autoEligible,
    'notes': notes,
  };

  factory QuickQuoteConfigRoleMapping.fromSupabase(Map<String, dynamic> row) =>
      QuickQuoteConfigRoleMapping(
        productCode: row['product_code'] as String,
        productId: row['product_id'] as String?,
        productName: row['product_name'] as String,
        catalogBrand: row['catalog_brand'] as String,
        category: row['category'] as String,
        automationSection: row['automation_section'] as String,
        automationRole: row['automation_role'] as String,
        roleKey: row['role_key'] as String,
        unitPriceAed: (row['unit_price_aed'] as num).toDouble(),
        autoEligible: row['auto_eligible'] as String,
        notes: row['notes'] as String? ?? '',
      );
}

class QuickQuoteConfigRule {
  const QuickQuoteConfigRule({
    required this.rule,
    required this.premier,
    required this.burnsport,
    required this.automationNote,
  });

  final String rule;
  final String premier;
  final String burnsport;
  final String automationNote;

  String get identityKey => rule;
  String get contentKey => [premier, burnsport, automationNote].join('|');

  Map<String, dynamic> toPayload() => {
    'rule': rule,
    'premier': premier,
    'burnsport': burnsport,
    'automation_note': automationNote,
  };

  factory QuickQuoteConfigRule.fromSupabase(Map<String, dynamic> row) =>
      QuickQuoteConfigRule(
        rule: row['rule'] as String,
        premier: row['premier'] as String? ?? '',
        burnsport: row['burnsport'] as String? ?? '',
        automationNote: row['automation_note'] as String? ?? '',
      );
}

class QuickQuoteConfiguration {
  const QuickQuoteConfiguration({
    required this.profiles,
    required this.allocations,
    required this.strengthPriorities,
    required this.roleMappings,
    required this.rules,
    this.version,
  });

  final List<QuickQuoteBudgetProfile> profiles;
  final List<QuickQuoteConfigAllocation> allocations;
  final List<QuickQuoteConfigStrengthPriority> strengthPriorities;
  final List<QuickQuoteConfigRoleMapping> roleMappings;
  final List<QuickQuoteConfigRule> rules;
  final QuickQuoteConfigVersion? version;

  Map<String, dynamic> toPayload() => {
    'profiles': profiles.map((row) => row.toPayload()).toList(),
    'allocations': allocations.map((row) => row.toPayload()).toList(),
    'strength_priorities': strengthPriorities
        .map((row) => row.toPayload())
        .toList(),
    'role_mappings': roleMappings.map((row) => row.toPayload()).toList(),
    'rules': rules.map((row) => row.toPayload()).toList(),
  };
}

class QuickQuoteConfigDiffCount {
  const QuickQuoteConfigDiffCount({
    required this.added,
    required this.changed,
    required this.removed,
    this.details = const [],
  });

  final int added;
  final int changed;
  final int removed;
  final List<String> details;
}

class QuickQuoteConfigDiff {
  const QuickQuoteConfigDiff({
    required this.profiles,
    required this.allocations,
    required this.strengthPriorities,
    required this.roleMappings,
  });

  final QuickQuoteConfigDiffCount profiles;
  final QuickQuoteConfigDiffCount allocations;
  final QuickQuoteConfigDiffCount strengthPriorities;
  final QuickQuoteConfigDiffCount roleMappings;
}

class QuickQuoteConfigImportResult {
  const QuickQuoteConfigImportResult({
    required this.sourceFilename,
    required this.configuration,
    required this.issues,
    required this.summary,
    required this.diff,
  });

  final String sourceFilename;
  final QuickQuoteConfiguration configuration;
  final List<QuickQuoteConfigIssue> issues;
  final QuickQuoteConfigValidationSummary summary;
  final QuickQuoteConfigDiff diff;

  bool get canApply => summary.isValid;
  Iterable<QuickQuoteConfigIssue> get errors => issues.where(
    (issue) => issue.severity == QuickQuoteConfigIssueSeverity.error,
  );
  Iterable<QuickQuoteConfigIssue> get warnings => issues.where(
    (issue) => issue.severity == QuickQuoteConfigIssueSeverity.warning,
  );
}
