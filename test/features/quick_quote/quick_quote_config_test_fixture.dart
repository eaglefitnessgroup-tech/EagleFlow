import 'package:eagleflow/features/products/domain/product.dart';
import 'package:eagleflow/features/quick_quote/application/quick_quote_config_workbook_service.dart';
import 'package:excel/excel.dart';

List<Product> buildConfigProducts() {
  final now = DateTime(2026, 10, 2);
  Product product(
    String code, {
    String brand = 'Premier',
    bool active = true,
  }) => Product(
    id: 'id-$code',
    productCode: code,
    name: 'Product $code',
    category: 'Gym Equipment',
    brand: brand,
    sellingPrice: 1000,
    isActive: active,
    createdAt: now,
    updatedAt: now,
  );

  return [
    product('SMITH'),
    product('FT'),
    product('FT2'),
    product('MS4'),
    product('MS8'),
    product('PM1012'),
    product('PM1012-50'),
    product('PM0011C'),
    product('BRN-001-1', brand: 'Burnsport'),
    product('BRN-001-2', brand: 'Burnsport'),
    product('HM-2017', brand: 'Burnsport'),
    product('PLATE25'),
    product('PLATE5'),
    product('PLATE10'),
    product('PLATE20'),
    product('BPLATE20', brand: 'Burnsport'),
    product('BARSET'),
    product('PM0041'),
    product('HM-2023', brand: 'Burnsport'),
    product('STR'),
    product('INACTIVE', active: false),
  ];
}

Excel buildValidConfigWorkbook() {
  final workbook = Excel.createExcel();

  void write(
    String name,
    String title,
    List<String> headers,
    int headerRow,
    List<List<Object?>> rows,
  ) {
    final sheet = workbook[name];
    sheet.appendRow([TextCellValue(title)]);
    while (sheet.maxRows < headerRow - 1) {
      sheet.appendRow([TextCellValue('')]);
    }
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    for (final row in rows) {
      sheet.appendRow(row.map(_cellValue).toList());
    }
  }

  write(
    QuickQuoteConfigWorkbookService.profileSheet,
    'EagleFlow Quick Quote — Budget Automation Master',
    QuickQuoteConfigWorkbookService.profileHeaders,
    5,
    [
      [
        'P200',
        'Premier',
        '200K-299K',
        200000,
        299999,
        249999.5,
        0,
        0,
        'WITHIN RANGE',
        0,
        0,
        0,
      ],
    ],
  );
  write(
    QuickQuoteConfigWorkbookService.allocationSheet,
    'Machine-readable product allocation by brand and budget range',
    QuickQuoteConfigWorkbookService.allocationHeaders,
    2,
    [
      _allocation(
        'Strength',
        'Smith Machine',
        'functional_multi_smith_machine',
        'SMITH',
      ),
      _allocation(
        'Functional / Multi',
        'Functional Trainer',
        'functional_multi_functional_trainer',
        'FT',
      ),
      _allocation(
        'Functional / Multi',
        '4 Station',
        'functional_multi_4_station',
        'MS4',
      ),
      _allocation(
        'Free Weights',
        'Dumbbell Full Set 2.5–50kg',
        'free_weights_dumbbell_full_set_2_5_50kg',
        'PM1012-50',
      ),
      _allocation(
        'Free Weights',
        'Dumbbell Rack',
        'free_weights_dumbbell_rack',
        'PM0011C',
        quantity: 2,
      ),
      _allocation(
        'Free Weights',
        'TPU Weight Plate 2.5kg',
        'free_weights_tpu_weight_plate_2_5kg',
        'PLATE25',
        quantity: 8,
      ),
      _allocation(
        'Free Weights',
        'TPU Weight Plate 5kg',
        'free_weights_tpu_weight_plate_5kg',
        'PLATE5',
        quantity: 8,
      ),
      _allocation(
        'Free Weights',
        'TPU Weight Plate 10kg',
        'free_weights_tpu_weight_plate_10kg',
        'PLATE10',
        quantity: 8,
      ),
      _allocation(
        'Free Weights',
        'TPU Weight Plate 20kg',
        'free_weights_tpu_weight_plate_20kg',
        'PLATE20',
        quantity: 8,
      ),
      _allocation(
        'Free Weights',
        'Barbell Set',
        'free_weights_barbell_set',
        'BARSET',
      ),
      _allocation(
        'Free Weights',
        'Barbell Rack',
        'free_weights_barbell_rack',
        'PM0041',
      ),
    ],
  );
  write(
    QuickQuoteConfigWorkbookService.strengthSheet,
    'Strength movement priority — default products used by the budget profiles',
    QuickQuoteConfigWorkbookService.strengthHeaders,
    3,
    [
      [
        'Premier',
        'Chest',
        1,
        'STR',
        'Product STR',
        'APN',
        'Pin Loaded',
        'Chest',
        1000,
        'Preserve area and movement.',
        'Canonical fixture',
      ],
    ],
  );
  write(
    QuickQuoteConfigWorkbookService.rulesSheet,
    'Locked Quick Quote automation rules',
    QuickQuoteConfigWorkbookService.rulesHeaders,
    3,
    [
      [
        'Main full-gym range',
        'AED 200K–299K',
        'AED 350K–449K',
        'Use the matching brand profile.',
      ],
    ],
  );
  write(
    QuickQuoteConfigWorkbookService.roleMapSheet,
    'Automation product-role map — current catalog snapshot',
    QuickQuoteConfigWorkbookService.roleMapHeaders,
    3,
    [
      _role(
        'SMITH',
        'Strength',
        'Smith Machine',
        'functional_multi_smith_machine',
      ),
      _role(
        'FT',
        'Functional / Multi',
        'Functional Trainer',
        'functional_multi_functional_trainer',
      ),
      _role(
        'MS4',
        'Functional / Multi',
        '4 Station',
        'functional_multi_4_station',
      ),
      _role(
        'PM1012-50',
        'Free Weights',
        'Dumbbell Full Set 2.5–50kg',
        'free_weights_dumbbell_full_set_2_5_50kg',
      ),
      _role(
        'PM0011C',
        'Free Weights',
        'Dumbbell Rack',
        'free_weights_dumbbell_rack',
      ),
      _role(
        'PLATE25',
        'Free Weights',
        'TPU Weight Plate 2.5kg',
        'free_weights_tpu_weight_plate_2_5kg',
      ),
      _role(
        'PLATE5',
        'Free Weights',
        'TPU Weight Plate 5kg',
        'free_weights_tpu_weight_plate_5kg',
      ),
      _role(
        'PLATE10',
        'Free Weights',
        'TPU Weight Plate 10kg',
        'free_weights_tpu_weight_plate_10kg',
      ),
      _role(
        'PLATE20',
        'Free Weights',
        'TPU Weight Plate 20kg',
        'free_weights_tpu_weight_plate_20kg',
      ),
      _role(
        'BARSET',
        'Free Weights',
        'Barbell Set',
        'free_weights_barbell_set',
      ),
      _role(
        'PM0041',
        'Free Weights',
        'Barbell Rack',
        'free_weights_barbell_rack',
      ),
      _role('STR', 'Strength', 'Chest', 'strength_chest'),
    ],
  );
  if (workbook.tables.containsKey('Sheet1')) workbook.delete('Sheet1');
  workbook.setDefaultSheet(QuickQuoteConfigWorkbookService.profileSheet);
  return workbook;
}

List<Object?> _allocation(
  String section,
  String role,
  String roleKey,
  String code, {
  int quantity = 1,
  String review = 'No',
  String notes = '',
}) => [
  'P200',
  'Premier',
  '200K-299K',
  200000,
  299999,
  1,
  section,
  role,
  roleKey,
  code,
  'Product $code',
  code.startsWith('HM-') ? 'Burnsport' : 'Premier',
  quantity,
  1000,
  quantity * 1000,
  0.05,
  quantity * 50,
  quantity * 1050,
  'Fixed role',
  1,
  review,
  notes,
];

List<Object?> _role(
  String code,
  String section,
  String role,
  String roleKey, {
  String brand = 'Premier',
  String eligible = 'Yes',
  String notes = '',
}) => [
  code,
  'Product $code',
  brand,
  'Gym Equipment',
  section,
  role,
  roleKey,
  1000,
  eligible,
  notes,
];

CellValue _cellValue(Object? value) => switch (value) {
  int value => IntCellValue(value),
  double value => DoubleCellValue(value),
  _ => TextCellValue(value?.toString() ?? ''),
};

List<int> encodeWorkbook(Excel workbook) => workbook.encode()!;

void setWorkbookCell(
  Excel workbook,
  String sheet,
  String address,
  CellValue value,
) {
  workbook[sheet].cell(CellIndex.indexByString(address)).value = value;
}
