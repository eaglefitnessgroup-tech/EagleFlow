import 'package:excel/excel.dart';

import '../../products/domain/product.dart';
import '../../products/domain/product_code.dart';
import '../domain/quick_quote_configuration.dart';
import 'quick_quote_xlsx_value_reader.dart';

class QuickQuoteConfigWorkbookService {
  QuickQuoteConfigWorkbookService({QuickQuoteXlsxValueReader? valueReader})
    : _valueReader = valueReader ?? QuickQuoteXlsxValueReader();

  static const String exportFilename =
      'EagleFlow_Quick_Quote_Budget_Automation_Master.xlsx';

  static const String profileSheet = 'Profile Summary';
  static const String allocationSheet = 'Automation Allocation';
  static const String strengthSheet = 'Strength Priority';
  static const String rulesSheet = 'Automation Rules';
  static const String roleMapSheet = 'Product Role Map';
  static const String sourceProductsSheet = 'Source Products';
  static const String verificationSheet = 'Verification';

  static const List<String> profileHeaders = [
    'Profile ID',
    'Brand',
    'Budget Range',
    'Budget Min',
    'Budget Max',
    'Budget Midpoint',
    'Estimated Total incl. VAT',
    'Variance vs Midpoint',
    'Range Status',
    'Total Unit Qty',
    'Cardio Qty',
    'Strength Qty',
  ];
  static const List<String> allocationHeaders = [
    'Profile ID',
    'Brand',
    'Budget Range',
    'Budget Min',
    'Budget Max',
    'Section Order',
    'Section',
    'Equipment Role',
    'Automation Role Key',
    'Product Code',
    'Product Name',
    'Product Brand',
    'Qty',
    'Unit Price AED',
    'Line Subtotal',
    'VAT %',
    'VAT Amount',
    'Line Total incl VAT',
    'Selection Mode',
    'Priority',
    'Review Flag',
    'Notes',
  ];
  static const List<String> strengthHeaders = [
    'Brand',
    'Area',
    'Priority',
    'Product Code',
    'Product Name',
    'Series Prefix',
    'Load Type',
    'Equipment Role',
    'Unit Price AED',
    'Automation Rule',
    'Source',
  ];
  static const List<String> rulesHeaders = [
    'Rule',
    'Premier',
    'Burnsport',
    'Automation Note',
  ];
  static const List<String> roleMapHeaders = [
    'Product Code',
    'Product Name',
    'Catalog Brand',
    'Category',
    'Automation Section',
    'Automation Role',
    'Role Key',
    'Unit Price AED',
    'Auto Eligible',
    'Notes',
  ];
  static const List<String> sourceProductHeaders = [
    'Product Code',
    'Product Name',
    'Category',
    'Brand',
    'Condition',
    'Selling Price',
    'Unit',
    'Min Stock Level',
    'Description / Notes',
    'VAT Applicable',
    'Active Product',
  ];
  static const List<String> verificationHeaders = [
    'Profile ID',
    'Expected Total incl VAT',
    'Budget Min',
    'Budget Max',
    'Expected Status',
    'Notes',
  ];

  static const List<String> _profileInputs = [
    'Profile ID',
    'Brand',
    'Budget Range',
    'Budget Min',
    'Budget Max',
  ];
  static const List<String> _allocationInputs = [
    'Profile ID',
    'Brand',
    'Budget Range',
    'Budget Min',
    'Budget Max',
    'Section Order',
    'Section',
    'Equipment Role',
    'Automation Role Key',
    'Product Code',
    'Qty',
    'Selection Mode',
    'Priority',
    'Review Flag',
    'Notes',
  ];
  static const List<String> _strengthInputs = [
    'Brand',
    'Area',
    'Priority',
    'Product Code',
    'Series Prefix',
    'Load Type',
    'Equipment Role',
    'Automation Rule',
  ];
  static const List<String> _roleMapInputs = [
    'Product Code',
    'Automation Section',
    'Automation Role',
    'Role Key',
    'Auto Eligible',
    'Notes',
  ];

  static const Set<String> _sections = {
    'cardio',
    'strength',
    'functional_multi',
    'benches',
    'free_weights',
  };
  static const Set<String> _strengthAreas = {
    'chest',
    'shoulder',
    'back',
    'arms',
    'core_abs',
    'legs',
    'glutes',
  };
  static const Set<String> _loadTypes = {'pin_loaded', 'plate_loaded'};
  static const Set<int> _approvedStationCounts = {4, 5, 8};
  static final Set<double> _requiredPlateWeights = {2.5, 5, 10, 20};

  final QuickQuoteXlsxValueReader _valueReader;

  QuickQuoteConfigImportResult parseAndValidate({
    required List<int> bytes,
    required String sourceFilename,
    required List<Product> products,
    QuickQuoteConfiguration? currentConfiguration,
  }) {
    if (!sourceFilename.toLowerCase().endsWith('.xlsx')) {
      throw const FormatException('Only .xlsx workbooks are supported.');
    }
    final workbook = _valueReader.read(bytes);
    final issues = <QuickQuoteConfigIssue>[];
    final productIndex = <String, List<Product>>{};
    for (final product in products) {
      productIndex
          .putIfAbsent(product.normalizedProductCode, () => [])
          .add(product);
    }
    final validBrands = products
        .map((product) => product.brand.trim().toLowerCase())
        .where((brand) => brand.isNotEmpty)
        .toSet();

    final rawProfiles = _readRows(
      workbook,
      profileSheet,
      _profileInputs,
      issues,
      stopAtFirstBlank: true,
    );
    final rawAllocations = _readRows(
      workbook,
      allocationSheet,
      _allocationInputs,
      issues,
    );
    final rawStrength = _readRows(
      workbook,
      strengthSheet,
      _strengthInputs,
      issues,
    );
    final rawRules = _readRows(workbook, rulesSheet, rulesHeaders, issues);
    final rawRoleMaps = _readRows(
      workbook,
      roleMapSheet,
      _roleMapInputs,
      issues,
    );

    final profiles = <QuickQuoteBudgetProfile>[];
    for (final row in rawProfiles) {
      final profileId = row.requiredText('Profile ID', issues);
      final brand = row.requiredText('Brand', issues);
      final budgetRange = row.requiredText('Budget Range', issues);
      final budgetMin = row.requiredDouble('Budget Min', issues);
      final budgetMax = row.requiredDouble('Budget Max', issues);
      if ([
        profileId,
        brand,
        budgetRange,
        budgetMin,
        budgetMax,
      ].any((value) => value == null)) {
        continue;
      }
      final parsedBudgetMin = budgetMin!;
      final parsedBudgetMax = budgetMax!;
      if (parsedBudgetMin < 0 || parsedBudgetMax < 0) {
        row.error(issues, 'Budget Min and Budget Max must not be negative.');
      }
      if (parsedBudgetMin > parsedBudgetMax) {
        row.error(
          issues,
          'Budget Min must be less than or equal to Budget Max.',
        );
      }
      if (!validBrands.contains(brand!.trim().toLowerCase())) {
        row.error(
          issues,
          'Brand "$brand" does not exist in the product catalog.',
        );
      }
      profiles.add(
        QuickQuoteBudgetProfile(
          profileId: profileId!,
          brand: brand,
          budgetRange: budgetRange!,
          budgetMin: parsedBudgetMin,
          budgetMax: parsedBudgetMax,
        ),
      );
    }

    final profilesById = {
      for (final profile in profiles) profile.profileId: profile,
    };
    final allocations = <QuickQuoteConfigAllocation>[];
    for (final row in rawAllocations) {
      final profileId = row.requiredText('Profile ID', issues);
      final brand = row.requiredText('Brand', issues);
      final budgetRange = row.requiredText('Budget Range', issues);
      final budgetMin = row.requiredDouble('Budget Min', issues);
      final budgetMax = row.requiredDouble('Budget Max', issues);
      final sectionOrder = row.requiredInt('Section Order', issues);
      final section = row.requiredToken('Section', issues);
      final equipmentRole = row.requiredText('Equipment Role', issues);
      final roleKey = row.requiredToken('Automation Role Key', issues);
      final productCode = row.requiredText('Product Code', issues);
      final quantity = row.requiredInt('Qty', issues);
      final selectionMode = row.requiredText('Selection Mode', issues);
      final priority = row.requiredInt('Priority', issues);
      final review = row.requiredBool('Review Flag', issues);
      if ([
        profileId,
        brand,
        budgetRange,
        budgetMin,
        budgetMax,
        sectionOrder,
        section,
        equipmentRole,
        roleKey,
        productCode,
        quantity,
        selectionMode,
        priority,
        review,
      ].any((value) => value == null)) {
        continue;
      }
      final profile = profilesById[profileId];
      if (profile == null) {
        row.error(issues, 'Profile ID "$profileId" does not exist.');
      } else {
        if (_token(profile.brand) != _token(brand!)) {
          row.error(issues, 'Allocation Brand does not match its profile.');
        }
        if (profile.budgetRange != budgetRange ||
            profile.budgetMin != budgetMin ||
            profile.budgetMax != budgetMax) {
          row.error(
            issues,
            'Allocation budget fields do not match its profile.',
          );
        }
      }
      if (!_sections.contains(section)) {
        row.error(issues, 'Section "${row.text('Section')}" is invalid.');
      }
      if (sectionOrder! <= 0) {
        row.error(issues, 'Section Order must be greater than zero.');
      }
      if (quantity! <= 0) {
        row.error(issues, 'Qty must be a whole number greater than zero.');
      }
      if (priority! <= 0) {
        row.error(issues, 'Priority must be a whole number greater than zero.');
      }
      final product = _resolveProduct(row, productCode!, productIndex, issues);
      allocations.add(
        QuickQuoteConfigAllocation(
          profileId: profileId!,
          sectionOrder: sectionOrder,
          section: row.text('Section'),
          equipmentRole: equipmentRole!,
          roleKey: roleKey!,
          productCode: normalizeProductCode(productCode),
          productId: product?.id,
          quantity: quantity,
          selectionMode: selectionMode!,
          priority: priority,
          reviewFlag: review!,
          notes: row.text('Notes'),
        ),
      );
      if (review) row.reviewWarning(issues);
    }

    final strengthPriorities = <QuickQuoteConfigStrengthPriority>[];
    for (final row in rawStrength) {
      final brand = row.requiredText('Brand', issues);
      final area = row.requiredToken('Area', issues);
      final priority = row.requiredInt('Priority', issues);
      final productCode = row.requiredText('Product Code', issues);
      final seriesPrefix = row.requiredText('Series Prefix', issues);
      final loadType = row.requiredToken('Load Type', issues);
      final equipmentRole = row.requiredText('Equipment Role', issues);
      final automationRule = row.requiredText('Automation Rule', issues);
      if ([
        brand,
        area,
        priority,
        productCode,
        seriesPrefix,
        loadType,
        equipmentRole,
        automationRule,
      ].any((value) => value == null)) {
        continue;
      }
      if (!validBrands.contains(brand!.trim().toLowerCase())) {
        row.error(
          issues,
          'Brand "$brand" does not exist in the product catalog.',
        );
      }
      if (!_strengthAreas.contains(area)) {
        row.error(issues, 'Area "${row.text('Area')}" is invalid.');
      }
      if (!_loadTypes.contains(loadType)) {
        row.error(issues, 'Load Type "${row.text('Load Type')}" is invalid.');
      }
      if (priority! <= 0) {
        row.error(issues, 'Priority must be a whole number greater than zero.');
      }
      final product = _resolveProduct(row, productCode!, productIndex, issues);
      strengthPriorities.add(
        QuickQuoteConfigStrengthPriority(
          brand: brand,
          strengthArea: row.text('Area'),
          priority: priority,
          productCode: normalizeProductCode(productCode),
          productId: product?.id,
          seriesPrefix: seriesPrefix!,
          loadType: row.text('Load Type'),
          equipmentRole: equipmentRole!,
          automationRule: automationRule!,
          source: row.text('Source'),
        ),
      );
    }

    final rules = <QuickQuoteConfigRule>[];
    for (final row in rawRules) {
      final rule = row.requiredText('Rule', issues);
      if (rule == null) continue;
      rules.add(
        QuickQuoteConfigRule(
          rule: rule,
          premier: row.text('Premier'),
          burnsport: row.text('Burnsport'),
          automationNote: row.text('Automation Note'),
        ),
      );
    }

    final roleMappings = <QuickQuoteConfigRoleMapping>[];
    for (final row in rawRoleMaps) {
      final productCode = row.requiredText('Product Code', issues);
      final section = row.requiredText('Automation Section', issues);
      final automationRole = row.requiredText('Automation Role', issues);
      final roleKey = row.requiredToken('Role Key', issues);
      final autoEligible = row.requiredToken('Auto Eligible', issues);
      if ([
        productCode,
        section,
        automationRole,
        roleKey,
        autoEligible,
      ].any((value) => value == null)) {
        continue;
      }
      if (!_sections.contains(_token(section!))) {
        row.error(issues, 'Automation Section "$section" is invalid.');
      }
      if (!{'yes', 'no', 'review'}.contains(autoEligible)) {
        row.error(issues, 'Auto Eligible must be Yes, No, or Review.');
      }
      final product = _resolveProduct(row, productCode!, productIndex, issues);
      roleMappings.add(
        QuickQuoteConfigRoleMapping(
          productCode: normalizeProductCode(productCode),
          productId: product?.id,
          productName: product?.name ?? row.text('Product Name'),
          catalogBrand: product?.brand ?? row.text('Catalog Brand'),
          category: product?.category ?? row.text('Category'),
          automationSection: section,
          automationRole: automationRole!,
          roleKey: roleKey!,
          unitPriceAed:
              product?.sellingPrice ??
              (double.tryParse(row.text('Unit Price AED')) ?? 0),
          autoEligible: _titleToken(autoEligible!),
          notes: row.text('Notes'),
        ),
      );
      if (autoEligible == 'review') row.reviewWarning(issues);
    }

    _validateProfiles(profiles, issues);
    _validateDuplicateRows(
      allocations,
      strengthPriorities,
      roleMappings,
      rules,
      issues,
    );
    _validateBusinessRules(
      profiles: profiles,
      allocations: allocations,
      roleMappings: roleMappings,
      products: products,
      issues: issues,
    );

    final configuration = QuickQuoteConfiguration(
      profiles: List.unmodifiable(profiles),
      allocations: List.unmodifiable(allocations),
      strengthPriorities: List.unmodifiable(strengthPriorities),
      roleMappings: List.unmodifiable(roleMappings),
      rules: List.unmodifiable(rules),
    );
    final errorCount = issues
        .where((issue) => issue.severity == QuickQuoteConfigIssueSeverity.error)
        .length;
    final warningCount = issues.length - errorCount;
    final summary = QuickQuoteConfigValidationSummary(
      profileCount: profiles.length,
      allocationCount: allocations.length,
      strengthPriorityCount: strengthPriorities.length,
      roleMappingCount: roleMappings.length,
      warningCount: warningCount,
      errorCount: errorCount,
    );
    return QuickQuoteConfigImportResult(
      sourceFilename: sourceFilename,
      configuration: configuration,
      issues: List.unmodifiable(issues),
      summary: summary,
      diff: calculateDiff(currentConfiguration, configuration),
    );
  }

  List<int> export(QuickQuoteConfiguration configuration) {
    final workbook = Excel.createExcel();
    final profilesById = {
      for (final profile in configuration.profiles) profile.profileId: profile,
    };
    final mappingsByCode = {
      for (final mapping in configuration.roleMappings)
        mapping.productCode: mapping,
    };
    final mappingsByIdentity = {
      for (final mapping in configuration.roleMappings)
        _mappingIdentity(mapping.productCode, mapping.roleKey): mapping,
    };

    _writeCanonicalSheet(
      workbook,
      profileSheet,
      'EagleFlow Quick Quote — Budget Automation Master',
      profileHeaders,
      configuration.profiles.map((profile) {
        final rows = configuration.allocations
            .where((row) => row.profileId == profile.profileId)
            .toList();
        final total = _profileTotal(rows, mappingsByCode);
        final midpoint = (profile.budgetMin + profile.budgetMax) / 2;
        return [
          profile.profileId,
          profile.brand,
          profile.budgetRange,
          profile.budgetMin,
          profile.budgetMax,
          midpoint,
          total,
          total - midpoint,
          total >= profile.budgetMin && total <= profile.budgetMax
              ? 'WITHIN RANGE'
              : 'OUTSIDE RANGE',
          rows.fold<int>(0, (sum, row) => sum + row.quantity),
          rows
              .where((row) => _token(row.section) == 'cardio')
              .fold<int>(0, (sum, row) => sum + row.quantity),
          rows
              .where((row) => _token(row.section) == 'strength')
              .fold<int>(0, (sum, row) => sum + row.quantity),
        ];
      }),
      headerRow: 5,
      preHeaderRows: const [
        [],
        ['Main Full-Gym Ranges'],
        [],
      ],
    );

    _writeCanonicalSheet(
      workbook,
      allocationSheet,
      'Machine-readable product allocation by brand and budget range',
      allocationHeaders,
      configuration.allocations.map((row) {
        final profile = profilesById[row.profileId];
        final mapping =
            mappingsByIdentity[_mappingIdentity(row.productCode, row.roleKey)];
        final unitPrice = mapping?.unitPriceAed ?? 0;
        final subtotal = row.quantity * unitPrice;
        const vatRate = 0.05;
        final vat = subtotal * vatRate;
        return [
          row.profileId,
          profile?.brand ?? '',
          profile?.budgetRange ?? '',
          profile?.budgetMin ?? 0,
          profile?.budgetMax ?? 0,
          row.sectionOrder,
          row.section,
          row.equipmentRole,
          row.roleKey,
          row.productCode,
          mapping?.productName ?? '',
          mapping?.catalogBrand ?? '',
          row.quantity,
          unitPrice,
          subtotal,
          vatRate,
          vat,
          subtotal + vat,
          row.selectionMode,
          row.priority,
          row.reviewFlag ? 'Yes' : 'No',
          row.notes,
        ];
      }),
      headerRow: 2,
    );

    _writeCanonicalSheet(
      workbook,
      strengthSheet,
      'Strength movement priority — default products used by the budget profiles',
      strengthHeaders,
      configuration.strengthPriorities.map((row) {
        final mapping = mappingsByCode[row.productCode];
        return [
          row.brand,
          row.strengthArea,
          row.priority,
          row.productCode,
          mapping?.productName ?? '',
          row.seriesPrefix,
          row.loadType,
          row.equipmentRole,
          mapping?.unitPriceAed ?? 0,
          row.automationRule,
          row.source,
        ];
      }),
      headerRow: 3,
    );

    _writeCanonicalSheet(
      workbook,
      rulesSheet,
      'Locked Quick Quote automation rules',
      rulesHeaders,
      configuration.rules.map(
        (row) => [row.rule, row.premier, row.burnsport, row.automationNote],
      ),
      headerRow: 3,
    );

    _writeCanonicalSheet(
      workbook,
      roleMapSheet,
      'Automation product-role map — current catalog snapshot',
      roleMapHeaders,
      configuration.roleMappings.map(
        (row) => [
          row.productCode,
          row.productName,
          row.catalogBrand,
          row.category,
          row.automationSection,
          row.automationRole,
          row.roleKey,
          row.unitPriceAed,
          row.autoEligible,
          row.notes,
        ],
      ),
      headerRow: 3,
    );

    _writeCanonicalSheet(
      workbook,
      sourceProductsSheet,
      'Source snapshot — active products used by this configuration',
      sourceProductHeaders,
      configuration.roleMappings.map(
        (row) => [
          row.productCode,
          row.productName,
          row.category,
          row.catalogBrand,
          '',
          row.unitPriceAed,
          '',
          '',
          row.notes,
          'Yes',
          'Yes',
        ],
      ),
      headerRow: 3,
    );

    _writeCanonicalSheet(
      workbook,
      verificationSheet,
      'Automation verification — current configuration prices',
      verificationHeaders,
      configuration.profiles.map((profile) {
        final total = _profileTotal(
          configuration.allocations.where(
            (row) => row.profileId == profile.profileId,
          ),
          mappingsByCode,
        );
        return [
          profile.profileId,
          total,
          profile.budgetMin,
          profile.budgetMax,
          total >= profile.budgetMin && total <= profile.budgetMax
              ? 'WITHIN RANGE'
              : 'OUTSIDE RANGE',
          'Regenerated from the active normalized configuration.',
        ];
      }),
      headerRow: 3,
    );

    workbook.setDefaultSheet(profileSheet);
    if (workbook.tables.containsKey('Sheet1')) workbook.delete('Sheet1');
    final encoded = workbook.encode();
    if (encoded == null) {
      throw StateError(
        'Failed to generate Quick Quote configuration workbook.',
      );
    }
    return encoded;
  }

  QuickQuoteConfigDiff calculateDiff(
    QuickQuoteConfiguration? current,
    QuickQuoteConfiguration next,
  ) => QuickQuoteConfigDiff(
    profiles: _diffRows(
      current?.profiles ?? const [],
      next.profiles,
      (row) => row.identityKey,
      (row) => row.contentKey,
    ),
    allocations: _diffRows(
      current?.allocations ?? const [],
      next.allocations,
      (row) => row.identityKey,
      (row) => row.contentKey,
    ),
    strengthPriorities: _diffRows(
      current?.strengthPriorities ?? const [],
      next.strengthPriorities,
      (row) => row.identityKey,
      (row) => row.contentKey,
    ),
    roleMappings: _diffRows(
      current?.roleMappings ?? const [],
      next.roleMappings,
      (row) => row.identityKey,
      (row) => row.contentKey,
    ),
  );

  List<_WorkbookRow> _readRows(
    Map<String, List<List<String>>> workbook,
    String sheetName,
    List<String> requiredHeaders,
    List<QuickQuoteConfigIssue> issues, {
    bool stopAtFirstBlank = false,
  }) {
    final sheet = workbook[sheetName];
    if (sheet == null) {
      issues.add(
        QuickQuoteConfigIssue(
          severity: QuickQuoteConfigIssueSeverity.error,
          sheet: sheetName,
          message: 'Required sheet is missing.',
        ),
      );
      return const [];
    }
    final firstHeader = requiredHeaders.first.toLowerCase();
    final headerIndex = sheet.indexWhere(
      (row) => row.any((value) => value.trim().toLowerCase() == firstHeader),
    );
    if (headerIndex < 0) {
      for (final header in requiredHeaders) {
        issues.add(
          QuickQuoteConfigIssue(
            severity: QuickQuoteConfigIssueSeverity.error,
            sheet: sheetName,
            message: 'Required column "$header" is missing.',
          ),
        );
      }
      return const [];
    }
    final headers = sheet[headerIndex];
    final indexes = <String, int>{};
    for (var index = 0; index < headers.length; index++) {
      final key = headers[index].trim().toLowerCase();
      if (key.isNotEmpty) indexes[key] = index;
    }
    for (final header in requiredHeaders) {
      if (!indexes.containsKey(header.toLowerCase())) {
        issues.add(
          QuickQuoteConfigIssue(
            severity: QuickQuoteConfigIssueSeverity.error,
            sheet: sheetName,
            message: 'Required column "$header" is missing.',
          ),
        );
      }
    }
    if (requiredHeaders.any(
      (header) => !indexes.containsKey(header.toLowerCase()),
    )) {
      return const [];
    }

    final rows = <_WorkbookRow>[];
    for (var index = headerIndex + 1; index < sheet.length; index++) {
      final cells = sheet[index];
      final values = <String, String>{};
      var hasValue = false;
      for (final entry in indexes.entries) {
        final value = entry.value < cells.length
            ? cells[entry.value].trim()
            : '';
        values[headers[entry.value].trim()] = value;
        hasValue = hasValue || value.isNotEmpty;
      }
      if (hasValue) {
        rows.add(_WorkbookRow(sheetName, index + 1, values));
      } else if (stopAtFirstBlank && rows.isNotEmpty) {
        break;
      }
    }
    return rows;
  }

  Product? _resolveProduct(
    _WorkbookRow row,
    String rawCode,
    Map<String, List<Product>> productIndex,
    List<QuickQuoteConfigIssue> issues,
  ) {
    final code = normalizeProductCode(rawCode);
    final matches = productIndex[code] ?? const [];
    if (matches.isEmpty) {
      row.error(
        issues,
        'Product Code "$code" is unknown or refers to a deleted product.',
      );
      return null;
    }
    if (matches.length != 1) {
      row.error(issues, 'Product Code "$code" does not resolve uniquely.');
      return null;
    }
    final product = matches.single;
    if (!product.isActive) {
      row.error(issues, 'Product Code "$code" is inactive.');
    }
    if (!product.sellingPrice.isFinite || product.sellingPrice <= 0) {
      row.error(
        issues,
        'Product Code "$code" must have a positive selling price.',
      );
    }
    return product;
  }

  void _validateProfiles(
    List<QuickQuoteBudgetProfile> profiles,
    List<QuickQuoteConfigIssue> issues,
  ) {
    final ids = <String>{};
    for (final profile in profiles) {
      if (!ids.add(profile.profileId)) {
        _error(
          issues,
          profileSheet,
          'Duplicate Profile ID "${profile.profileId}".',
        );
      }
    }
    for (var left = 0; left < profiles.length; left++) {
      for (var right = left + 1; right < profiles.length; right++) {
        final a = profiles[left];
        final b = profiles[right];
        final sameBrand = _token(a.brand) == _token(b.brand);
        final overlaps =
            a.budgetMin <= b.budgetMax && b.budgetMin <= a.budgetMax;
        if (sameBrand && overlaps) {
          _error(
            issues,
            profileSheet,
            'Profiles "${a.profileId}" and "${b.profileId}" overlap for ${a.brand}.',
          );
        }
      }
    }
  }

  void _validateDuplicateRows(
    List<QuickQuoteConfigAllocation> allocations,
    List<QuickQuoteConfigStrengthPriority> strength,
    List<QuickQuoteConfigRoleMapping> mappings,
    List<QuickQuoteConfigRule> rules,
    List<QuickQuoteConfigIssue> issues,
  ) {
    _conflicts(
      allocations,
      (row) => row.identityKey,
      (row) => row.contentKey,
      allocationSheet,
      'automation role key',
      issues,
    );
    _conflicts(
      strength,
      (row) => row.identityKey,
      (row) => row.contentKey,
      strengthSheet,
      'strength priority context',
      issues,
    );
    _conflicts(
      mappings,
      (row) => row.identityKey,
      (row) => row.contentKey,
      roleMapSheet,
      'Product Code mapping',
      issues,
    );
    _conflicts(
      rules,
      (row) => row.identityKey,
      (row) => row.contentKey,
      rulesSheet,
      'Rule',
      issues,
    );
  }

  void _validateBusinessRules({
    required List<QuickQuoteBudgetProfile> profiles,
    required List<QuickQuoteConfigAllocation> allocations,
    required List<QuickQuoteConfigRoleMapping> roleMappings,
    required List<Product> products,
    required List<QuickQuoteConfigIssue> issues,
  }) {
    final productsByCode = {
      for (final product in products) product.normalizedProductCode: product,
    };
    final mappingsByIdentity = {
      for (final mapping in roleMappings)
        _mappingIdentity(mapping.productCode, mapping.roleKey): mapping,
    };
    for (final row in allocations) {
      final mapping =
          mappingsByIdentity[_mappingIdentity(row.productCode, row.roleKey)];
      if (mapping == null) {
        _error(
          issues,
          allocationSheet,
          '${row.profileId}: ${row.productCode} has no Product Role Map row.',
        );
      } else {
        if (_token(mapping.autoEligible) == 'no') {
          _error(
            issues,
            allocationSheet,
            '${row.profileId}: ${row.productCode} is not Auto Eligible.',
          );
        }
      }
    }

    for (final profile in profiles) {
      final rows = allocations
          .where((row) => row.profileId == profile.profileId)
          .toList();
      _requireExactQuantity(
        profile,
        rows,
        'functional_multi_smith_machine',
        1,
        'Smith Machine',
        issues,
      );
      _requireExactQuantity(
        profile,
        rows,
        'functional_multi_functional_trainer',
        1,
        'Functional Trainer',
        issues,
      );
      final multiStations = rows
          .where(
            (row) =>
                RegExp(r'^functional_multi_\d+_station$').hasMatch(row.roleKey),
          )
          .toList();
      if (multiStations.length > 1 ||
          multiStations.fold<int>(0, (sum, row) => sum + row.quantity) > 1) {
        _profileError(
          issues,
          profile,
          'Only one Multi Station model is allowed.',
        );
      }
      for (final row in multiStations) {
        final match = RegExp(
          r'^functional_multi_(\d+)_station$',
        ).firstMatch(row.roleKey);
        final stationCount = int.tryParse(match?.group(1) ?? '');
        if (stationCount == null ||
            !_approvedStationCounts.contains(stationCount)) {
          _profileError(
            issues,
            profile,
            'Multi Station must be an approved 4, 5, or 8 Station model.',
          );
        }
      }
      _validateDumbbells(profile, rows, mappingsByIdentity, issues);
      _validateWeightPlates(
        profile,
        rows,
        mappingsByIdentity,
        productsByCode,
        issues,
      );
      _validateBarbells(
        profile,
        rows,
        mappingsByIdentity,
        productsByCode,
        issues,
      );
    }
  }

  void _validateDumbbells(
    QuickQuoteBudgetProfile profile,
    List<QuickQuoteConfigAllocation> rows,
    Map<String, QuickQuoteConfigRoleMapping> mappings,
    List<QuickQuoteConfigIssue> issues,
  ) {
    final sets = rows.where(
      (row) =>
          row.roleKey == 'free_weights_dumbbell_full_set_2_5_50kg' ||
          row.roleKey == 'free_weights_dumbbell_half_set_2_5_25kg',
    );
    if (sets.isEmpty) return;
    final families = <String>{};
    var expectedRacks = 0;
    for (final row in sets) {
      final family = _token(
        mappings[_mappingIdentity(row.productCode, row.roleKey)]
                ?.catalogBrand ??
            '',
      );
      if (family.isNotEmpty) families.add(family);
      expectedRacks +=
          row.quantity *
          (row.roleKey == 'free_weights_dumbbell_full_set_2_5_50kg' ? 2 : 1);
    }
    final racks = rows.where(
      (row) => row.roleKey == 'free_weights_dumbbell_rack',
    );
    final rackFamilies = <String>{};
    var rackQuantity = 0;
    for (final rack in racks) {
      final family = _token(
        mappings[_mappingIdentity(rack.productCode, rack.roleKey)]
                ?.catalogBrand ??
            '',
      );
      if (family.isNotEmpty) rackFamilies.add(family);
      rackQuantity += rack.quantity;
    }
    if (families.length != 1 ||
        rackFamilies.length != 1 ||
        families.singleOrNull != rackFamilies.singleOrNull ||
        families.singleOrNull != _token(profile.brand)) {
      _profileError(
        issues,
        profile,
        'Dumbbell sets and racks must use one matching Premier or Burnsport family.',
      );
    }
    if (rackQuantity != expectedRacks) {
      _profileError(
        issues,
        profile,
        'Dumbbell configuration requires exactly $expectedRacks matching rack(s), found $rackQuantity.',
      );
    }
  }

  void _validateWeightPlates(
    QuickQuoteBudgetProfile profile,
    List<QuickQuoteConfigAllocation> rows,
    Map<String, QuickQuoteConfigRoleMapping> mappings,
    Map<String, Product> products,
    List<QuickQuoteConfigIssue> issues,
  ) {
    final plates = rows
        .where((row) => row.roleKey.contains('_weight_plate_'))
        .toList();
    if (plates.isEmpty) {
      if (profile.budgetMin >= 200000) {
        _profileError(
          issues,
          profile,
          'Profiles from AED 200,000 require one complete weight plate family.',
        );
      }
      return;
    }
    final families = <String>{};
    final weights = <double>{};
    final brands = <String>{};
    final quantities = <int>{};
    final pattern = RegExp(
      r'^free_weights_(tpu|pu)_weight_plate_(2_5|5|10|20)kg$',
    );
    for (final plate in plates) {
      final match = pattern.firstMatch(plate.roleKey);
      if (match == null) {
        _profileError(
          issues,
          profile,
          'Weight plate ${plate.productCode} has an invalid Role Key.',
        );
        continue;
      }
      families.add(match.group(1)!);
      weights.add(double.parse(match.group(2)!.replaceFirst('_', '.')));
      quantities.add(plate.quantity);
      final brand = products[plate.productCode]?.brand.trim().toLowerCase();
      if (brand != null) brands.add(brand);
      if (!mappings.containsKey(
        _mappingIdentity(plate.productCode, plate.roleKey),
      )) {
        _profileError(
          issues,
          profile,
          'Weight plate ${plate.productCode} does not match Product Role Map.',
        );
      }
    }
    if (families.length != 1 || brands.length != 1) {
      _profileError(
        issues,
        profile,
        'Weight plates must use one family and one brand.',
      );
    }
    if (!weights.containsAll(_requiredPlateWeights) || weights.length != 4) {
      _profileError(
        issues,
        profile,
        'Weight plates must contain one complete 2.5, 5, 10, and 20 kg family.',
      );
    }
    if (quantities.length != 1) {
      _profileError(
        issues,
        profile,
        'All weight plate sizes must use a consistent quantity.',
      );
    }
    if (brands.length == 1 && brands.single != profile.brand.toLowerCase()) {
      _profileError(
        issues,
        profile,
        'Weight plate brand must match the profile brand.',
      );
    }
    if (profile.budgetMin >= 200000 && families.length == 1) {
      final expected = _token(profile.brand) == 'premier' ? 'tpu' : 'pu';
      if (families.single != expected) {
        _profileError(
          issues,
          profile,
          '${profile.brand} profiles from AED 200,000 must use the ${expected.toUpperCase()} plate family.',
        );
      }
    }
  }

  void _validateBarbells(
    QuickQuoteBudgetProfile profile,
    List<QuickQuoteConfigAllocation> rows,
    Map<String, QuickQuoteConfigRoleMapping> mappings,
    Map<String, Product> products,
    List<QuickQuoteConfigIssue> issues,
  ) {
    final sets = rows
        .where((row) => row.roleKey == 'free_weights_barbell_set')
        .toList();
    if (sets.isEmpty) return;
    final racks = rows
        .where((row) => row.roleKey == 'free_weights_barbell_rack')
        .toList();
    final setQuantity = sets.fold<int>(0, (sum, row) => sum + row.quantity);
    final rackQuantity = racks.fold<int>(0, (sum, row) => sum + row.quantity);
    if (setQuantity != rackQuantity) {
      _profileError(
        issues,
        profile,
        'Each Barbell Set requires exactly one matching Barbell Rack.',
      );
    }
    for (final row in [...sets, ...racks]) {
      final brand = products[row.productCode]?.brand.trim().toLowerCase();
      final matches = brand == profile.brand.trim().toLowerCase();
      final reviewed =
          row.reviewFlag ||
          _token(
                mappings[_mappingIdentity(row.productCode, row.roleKey)]
                        ?.autoEligible ??
                    '',
              ) ==
              'review';
      if (!matches && !reviewed) {
        _profileError(
          issues,
          profile,
          '${row.equipmentRole} ${row.productCode} must match the profile brand or be explicitly marked Review.',
        );
      }
    }
  }

  void _requireExactQuantity(
    QuickQuoteBudgetProfile profile,
    List<QuickQuoteConfigAllocation> rows,
    String roleKey,
    int required,
    String label,
    List<QuickQuoteConfigIssue> issues,
  ) {
    final quantity = rows
        .where((row) => row.roleKey == roleKey)
        .fold<int>(0, (sum, row) => sum + row.quantity);
    if (quantity != required) {
      _profileError(
        issues,
        profile,
        '$label must be exactly Qty $required in a required full-gym profile.',
      );
    }
  }

  void _writeCanonicalSheet(
    Excel workbook,
    String name,
    String title,
    List<String> headers,
    Iterable<List<Object?>> rows, {
    required int headerRow,
    List<List<Object?>> preHeaderRows = const [],
  }) {
    final sheet = workbook[name];
    sheet.appendRow([TextCellValue(title)]);
    for (final row in preHeaderRows) {
      sheet.appendRow(row.map(_cellValue).toList());
    }
    while (sheet.maxRows < headerRow - 1) {
      sheet.appendRow([TextCellValue('')]);
    }
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    for (final row in rows) {
      sheet.appendRow(row.map(_cellValue).toList());
    }
  }

  double _profileTotal(
    Iterable<QuickQuoteConfigAllocation> allocations,
    Map<String, QuickQuoteConfigRoleMapping> mappings,
  ) => allocations.fold<double>(0, (sum, row) {
    final unitPrice = mappings[row.productCode]?.unitPriceAed ?? 0;
    return sum + row.quantity * unitPrice * 1.05;
  });

  CellValue _cellValue(Object? value) => switch (value) {
    int value => IntCellValue(value),
    double value => DoubleCellValue(value),
    null => TextCellValue(''),
    _ => TextCellValue(value.toString()),
  };

  QuickQuoteConfigDiffCount _diffRows<T>(
    List<T> current,
    List<T> next,
    String Function(T row) identity,
    String Function(T row) content,
  ) {
    final before = {for (final row in current) identity(row): content(row)};
    final after = {for (final row in next) identity(row): content(row)};
    final added = after.keys.where((key) => !before.containsKey(key)).toList();
    final removed = before.keys
        .where((key) => !after.containsKey(key))
        .toList();
    final changed = after.keys
        .where((key) => before.containsKey(key) && before[key] != after[key])
        .toList();
    return QuickQuoteConfigDiffCount(
      added: added.length,
      changed: changed.length,
      removed: removed.length,
      details: [
        ...added.map((key) => 'Added: $key'),
        ...changed.map((key) => 'Changed: $key'),
        ...removed.map((key) => 'Removed: $key'),
      ],
    );
  }

  void _conflicts<T>(
    List<T> rows,
    String Function(T row) identity,
    String Function(T row) content,
    String sheet,
    String label,
    List<QuickQuoteConfigIssue> issues,
  ) {
    final seen = <String, String>{};
    for (final row in rows) {
      final key = identity(row);
      final previous = seen[key];
      if (previous != null && previous != content(row)) {
        _error(issues, sheet, 'Duplicate conflicting $label "$key".');
      } else {
        seen[key] = content(row);
      }
    }
  }

  void _profileError(
    List<QuickQuoteConfigIssue> issues,
    QuickQuoteBudgetProfile profile,
    String message,
  ) => _error(issues, allocationSheet, '${profile.profileId}: $message');

  void _error(
    List<QuickQuoteConfigIssue> issues,
    String sheet,
    String message,
  ) => issues.add(
    QuickQuoteConfigIssue(
      severity: QuickQuoteConfigIssueSeverity.error,
      sheet: sheet,
      message: message,
    ),
  );

  static String _token(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  static String _mappingIdentity(String productCode, String roleKey) =>
      '${normalizeProductCode(productCode)}|${_token(roleKey)}';

  static String _titleToken(String value) => switch (value) {
    'yes' => 'Yes',
    'no' => 'No',
    'review' => 'Review',
    _ => value,
  };

  static bool? _parseBool(String value) => switch (value.trim().toLowerCase()) {
    'yes' || 'true' || '1' || 'y' => true,
    'no' || 'false' || '0' || 'n' => false,
    _ => null,
  };
}

class _WorkbookRow {
  const _WorkbookRow(this.sheet, this.rowNumber, this.values);

  final String sheet;
  final int rowNumber;
  final Map<String, String> values;

  String text(String column) => values[column]?.trim() ?? '';

  String? requiredText(String column, List<QuickQuoteConfigIssue> issues) {
    final value = text(column);
    if (value.isEmpty) {
      error(issues, '$column is required.');
      return null;
    }
    return value;
  }

  String? requiredToken(String column, List<QuickQuoteConfigIssue> issues) {
    final value = requiredText(column, issues);
    return value == null ? null : QuickQuoteConfigWorkbookService._token(value);
  }

  double? requiredDouble(String column, List<QuickQuoteConfigIssue> issues) {
    final value = requiredText(column, issues);
    if (value == null) return null;
    final parsed = double.tryParse(value.replaceAll(',', ''));
    if (parsed == null || !parsed.isFinite) {
      error(issues, '$column must be a valid number.');
      return null;
    }
    return parsed;
  }

  int? requiredInt(String column, List<QuickQuoteConfigIssue> issues) {
    final value = requiredText(column, issues);
    if (value == null) return null;
    final parsed = double.tryParse(value.replaceAll(',', ''));
    if (parsed == null ||
        !parsed.isFinite ||
        parsed != parsed.roundToDouble()) {
      error(issues, '$column must be a valid whole number.');
      return null;
    }
    return parsed.toInt();
  }

  bool? requiredBool(String column, List<QuickQuoteConfigIssue> issues) {
    final value = requiredText(column, issues);
    if (value == null) return null;
    final parsed = QuickQuoteConfigWorkbookService._parseBool(value);
    if (parsed == null) {
      error(issues, '$column must be Yes or No.');
      return null;
    }
    return parsed;
  }

  void error(List<QuickQuoteConfigIssue> issues, String message) {
    issues.add(
      QuickQuoteConfigIssue(
        severity: QuickQuoteConfigIssueSeverity.error,
        sheet: sheet,
        row: rowNumber,
        message: message,
      ),
    );
  }

  void reviewWarning(List<QuickQuoteConfigIssue> issues) {
    issues.add(
      QuickQuoteConfigIssue(
        severity: QuickQuoteConfigIssueSeverity.warning,
        sheet: sheet,
        row: rowNumber,
        message: 'Review row requires explicit admin review before Apply.',
      ),
    );
  }
}
