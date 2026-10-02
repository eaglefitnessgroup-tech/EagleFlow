enum QuickQuoteMappingStatus {
  eligible('eligible'),
  manualExcluded('manual_excluded');

  const QuickQuoteMappingStatus(this.databaseValue);
  final String databaseValue;

  static QuickQuoteMappingStatus parse(Object? value) => switch (value) {
    'eligible' => QuickQuoteMappingStatus.eligible,
    'manual_excluded' => QuickQuoteMappingStatus.manualExcluded,
    _ => throw FormatException('Invalid Quick Quote mapping status: $value'),
  };
}

enum QuickQuoteSection {
  cardio('cardio'),
  strength('strength'),
  multifunction('multifunction'),
  dumbbell('dumbbell'),
  dumbbellRack('dumbbell_rack'),
  weightPlate('weight_plate'),
  bench('bench'),
  freeWeight('free_weight');

  const QuickQuoteSection(this.databaseValue);
  final String databaseValue;

  static QuickQuoteSection? parseNullable(Object? value) {
    if (value == null) return null;
    return switch (value) {
      'cardio' => QuickQuoteSection.cardio,
      'strength' => QuickQuoteSection.strength,
      'multifunction' => QuickQuoteSection.multifunction,
      'dumbbell' => QuickQuoteSection.dumbbell,
      'dumbbell_rack' => QuickQuoteSection.dumbbellRack,
      'weight_plate' => QuickQuoteSection.weightPlate,
      'bench' => QuickQuoteSection.bench,
      'free_weight' => QuickQuoteSection.freeWeight,
      _ => throw FormatException('Invalid Quick Quote section: $value'),
    };
  }
}

enum QuickQuoteStrengthArea {
  chest('chest'),
  back('back'),
  shoulder('shoulder'),
  legs('legs'),
  arms('arms'),
  glutes('glutes'),
  core('core');

  const QuickQuoteStrengthArea(this.databaseValue);
  final String databaseValue;

  static QuickQuoteStrengthArea? parseNullable(Object? value) {
    if (value == null) return null;
    return switch (value) {
      'chest' => QuickQuoteStrengthArea.chest,
      'back' => QuickQuoteStrengthArea.back,
      'shoulder' => QuickQuoteStrengthArea.shoulder,
      'legs' => QuickQuoteStrengthArea.legs,
      'arms' => QuickQuoteStrengthArea.arms,
      'glutes' => QuickQuoteStrengthArea.glutes,
      'core' => QuickQuoteStrengthArea.core,
      _ => throw FormatException('Invalid Quick Quote strength area: $value'),
    };
  }
}

enum QuickQuoteLoadType {
  pinLoaded('pin_loaded'),
  plateLoaded('plate_loaded');

  const QuickQuoteLoadType(this.databaseValue);
  final String databaseValue;

  static QuickQuoteLoadType? parseNullable(Object? value) {
    if (value == null) return null;
    return switch (value) {
      'pin_loaded' => QuickQuoteLoadType.pinLoaded,
      'plate_loaded' => QuickQuoteLoadType.plateLoaded,
      _ => throw FormatException('Invalid Quick Quote load type: $value'),
    };
  }
}

class QuickQuoteProductMapping {
  const QuickQuoteProductMapping({
    required this.productId,
    required this.status,
    required this.section,
    required this.roleKey,
    required this.strengthArea,
    required this.loadType,
    required this.movementKey,
    required this.familyKey,
    required this.plateWeightKg,
    required this.stationCount,
    required this.selectionPriority,
    required this.upgradePriority,
    required this.updatedAt,
  });

  factory QuickQuoteProductMapping.fromSupabaseRow(Map<String, dynamic> row) {
    final mapping = QuickQuoteProductMapping(
      productId: _requiredString(row['product_id'], 'product_id'),
      status: QuickQuoteMappingStatus.parse(row['status']),
      section: QuickQuoteSection.parseNullable(row['section']),
      roleKey: _optionalString(row['role_key'], 'role_key'),
      strengthArea: QuickQuoteStrengthArea.parseNullable(row['strength_area']),
      loadType: QuickQuoteLoadType.parseNullable(row['load_type']),
      movementKey: _optionalString(row['movement_key'], 'movement_key'),
      familyKey: _optionalString(row['family_key'], 'family_key'),
      plateWeightKg: _optionalDouble(row['plate_weight_kg'], 'plate_weight_kg'),
      stationCount: _optionalInt(row['station_count'], 'station_count'),
      selectionPriority: _requiredInt(
        row['selection_priority'],
        'selection_priority',
      ),
      upgradePriority: _requiredInt(
        row['upgrade_priority'],
        'upgrade_priority',
      ),
      updatedAt: _requiredDateTime(row['updated_at'], 'updated_at'),
    );
    mapping.validate();
    return mapping;
  }

  factory QuickQuoteProductMapping.fromCacheJson(Map<String, Object?> json) {
    final mapping = QuickQuoteProductMapping(
      productId: _requiredString(json['productId'], 'productId'),
      status: QuickQuoteMappingStatus.parse(json['status']),
      section: QuickQuoteSection.parseNullable(json['section']),
      roleKey: _optionalString(json['roleKey'], 'roleKey'),
      strengthArea: QuickQuoteStrengthArea.parseNullable(json['strengthArea']),
      loadType: QuickQuoteLoadType.parseNullable(json['loadType']),
      movementKey: _optionalString(json['movementKey'], 'movementKey'),
      familyKey: _optionalString(json['familyKey'], 'familyKey'),
      plateWeightKg: _optionalDouble(json['plateWeightKg'], 'plateWeightKg'),
      stationCount: _optionalInt(json['stationCount'], 'stationCount'),
      selectionPriority: _requiredInt(
        json['selectionPriority'],
        'selectionPriority',
      ),
      upgradePriority: _requiredInt(json['upgradePriority'], 'upgradePriority'),
      updatedAt: _requiredDateTime(json['updatedAt'], 'updatedAt'),
    );
    mapping.validate();
    return mapping;
  }

  final String productId;
  final QuickQuoteMappingStatus status;
  final QuickQuoteSection? section;
  final String? roleKey;
  final QuickQuoteStrengthArea? strengthArea;
  final QuickQuoteLoadType? loadType;
  final String? movementKey;
  final String? familyKey;
  final double? plateWeightKg;
  final int? stationCount;
  final int selectionPriority;
  final int upgradePriority;
  final DateTime updatedAt;

  bool get isEligible => status == QuickQuoteMappingStatus.eligible;

  void validate() {
    if (productId.trim().isEmpty) {
      throw const FormatException('productId must not be empty');
    }
    if (selectionPriority < 0 || upgradePriority < 0) {
      throw const FormatException(
        'Quick Quote priorities must be non-negative',
      );
    }
    if (stationCount != null && stationCount! <= 0) {
      throw const FormatException('stationCount must be positive');
    }
    if (plateWeightKg != null && plateWeightKg! <= 0) {
      throw const FormatException('plateWeightKg must be positive');
    }
    if (strengthArea != null && section != QuickQuoteSection.strength) {
      throw const FormatException(
        'strengthArea is only valid for strength mappings',
      );
    }
    if (loadType != null && section != QuickQuoteSection.strength) {
      throw const FormatException(
        'loadType is only valid for strength mappings',
      );
    }
    if (plateWeightKg != null && section != QuickQuoteSection.weightPlate) {
      throw const FormatException(
        'plateWeightKg is only valid for weight plate mappings',
      );
    }
    if (stationCount != null &&
        (section != QuickQuoteSection.multifunction ||
            roleKey != 'multi_station')) {
      throw const FormatException(
        'stationCount is only valid for multifunction multi-station mappings',
      );
    }
    if (!isEligible) return;
    if (section == null || roleKey == null) {
      throw const FormatException(
        'Eligible mappings require section and roleKey',
      );
    }
  }

  Map<String, Object?> toCacheJson() {
    validate();
    return <String, Object?>{
      'productId': productId,
      'status': status.databaseValue,
      'section': section?.databaseValue,
      'roleKey': roleKey,
      'strengthArea': strengthArea?.databaseValue,
      'loadType': loadType?.databaseValue,
      'movementKey': movementKey,
      'familyKey': familyKey,
      'plateWeightKg': plateWeightKg,
      'stationCount': stationCount,
      'selectionPriority': selectionPriority,
      'upgradePriority': upgradePriority,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }
}

String _requiredString(Object? value, String field) {
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('$field must be a non-empty string');
}

String? _optionalString(Object? value, String field) {
  if (value == null) return null;
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('$field must be null or a non-empty string');
}

int _requiredInt(Object? value, String field) {
  final parsed = _optionalInt(value, field);
  if (parsed != null) return parsed;
  throw FormatException('$field is required');
}

int? _optionalInt(Object? value, String field) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('$field must be an integer');
}

double? _optionalDouble(Object? value, String field) {
  if (value == null) return null;
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('$field must be numeric');
}

DateTime _requiredDateTime(Object? value, String field) {
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('$field must be a valid timestamp');
}
