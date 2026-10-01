enum QuickQuoteVatBudgetMode { excludingVat, includingVat }

enum QuickQuoteCardioRole {
  treadmill('treadmill'),
  crossTrainer('cross_trainer'),
  recumbentBike('recumbent_bike'),
  uprightBike('upright_bike'),
  spinningBike('spinning_bike');

  const QuickQuoteCardioRole(this.mappingValue);

  final String mappingValue;

  static QuickQuoteCardioRole? tryParse(String? value) {
    for (final role in values) {
      if (role.mappingValue == value) return role;
    }
    return null;
  }
}

enum QuickQuoteMultifunctionRole {
  smithMachine('smith_machine'),
  functionalTrainer('functional_trainer'),
  multiStation('multi_station');

  const QuickQuoteMultifunctionRole(this.mappingValue);

  final String mappingValue;

  static QuickQuoteMultifunctionRole? tryParse(String? value) {
    for (final role in values) {
      if (role.mappingValue == value) return role;
    }
    return null;
  }
}

enum QuickQuoteDumbbellBundleKind { fullSet, optionalHalfSet }

const Set<String> approvedPremierPinSeriesPrefixes = {'APN', 'PXN', 'EPN'};

const Set<String> approvedPremierPlateSeriesPrefixes = {'APL', 'PXL'};

const List<double> quickQuoteRequiredPlateWeightsKg = [2.5, 5, 10, 20];
const List<int> quickQuotePlateQuantityTiers = [8, 12, 15];

const String quickQuoteDumbbellFullSetRole = 'dumbbell_full_set';
const String quickQuoteDumbbellHalfSetRole = 'dumbbell_half_set';
const String quickQuoteDumbbellRackRole = 'dumbbell_rack';
const String quickQuoteWeightPlateRole = 'weight_plate';

const String quickQuoteMultiStationExclusivityKey =
    'multifunction:multi_station';
const String quickQuoteWeightPlateBundleExclusivityKey =
    'weight_plate:family_and_tier';

bool isPremierBrand(String brand) => brand.trim().toLowerCase() == 'premier';

bool brandsMatch(String left, String right) =>
    left.trim().toLowerCase() == right.trim().toLowerCase();
