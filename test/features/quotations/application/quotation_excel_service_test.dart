import 'package:eagleflow/features/quotations/application/quotation_calculator.dart';
import 'package:eagleflow/features/quotations/application/quotation_excel_service.dart';
import 'package:eagleflow/features/quotations/domain/customer_info.dart';
import 'package:eagleflow/features/quotations/domain/quotation.dart';
import 'package:eagleflow/features/quotations/domain/quotation_charges.dart';
import 'package:eagleflow/features/quotations/domain/quotation_line_item.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = QuotationExcelService();

  Quotation quotation({
    List<QuotationLineItem> items = const [],
    QuotationCharges charges = const QuotationCharges(),
    String customerNotes = 'Customer-facing note',
    String internalNotes = 'Private internal note',
  }) {
    return Quotation(
      id: 'quotation-id',
      quotationNumber: 'QT-1001',
      customerInfo: const CustomerInfo(
        name: 'Alex Customer',
        company: 'Acme LLC',
        phone: '+971500000000',
        email: 'alex@example.com',
        projectLocation: 'Dubai',
      ),
      salespersonId: 'sales-1',
      createdDate: DateTime(2026, 9, 17),
      modifiedDate: DateTime(2026, 9, 17),
      validUntil: DateTime(2026, 10, 2),
      expectedDelivery: DateTime(2026, 10, 15),
      lineItems: items,
      charges: charges,
      customerNotes: customerNotes,
      internalNotes: internalNotes,
    );
  }

  Excel workbookFor(Quotation value, {String? salespersonName}) {
    return Excel.decodeBytes(
      service.generateWorkbook(value, salespersonName: salespersonName),
    );
  }

  Sheet quotationSheet(Excel workbook) => workbook.tables['Quotation']!;

  int rowContaining(Sheet sheet, String label) {
    return sheet.rows.indexWhere(
      (row) => row.any((cell) {
        final value = cell?.value;
        return value is TextCellValue && value.value.toString() == label;
      }),
    );
  }

  CellValue? valueBeside(Sheet sheet, String label) {
    final rowIndex = rowContaining(sheet, label);
    expect(rowIndex, isNonNegative, reason: 'Missing row for $label');
    final row = sheet.rows[rowIndex];
    final columnIndex = row.indexWhere((cell) {
      final value = cell?.value;
      return value is TextCellValue && value.value.toString() == label;
    });
    return row[columnIndex + 1]?.value;
  }

  double numericValue(CellValue? value) {
    return switch (value) {
      DoubleCellValue(value: final number) => number,
      IntCellValue(value: final number) => number.toDouble(),
      _ => throw TestFailure('Expected numeric cell, got $value'),
    };
  }

  test('generates a customer-facing Quotation workbook', () {
    const item = QuotationLineItem(
      id: 'line-1',
      productCode: 'SKU-1',
      name: 'Treadmill',
      brand: 'Eagle',
      description: 'Commercial treadmill',
      unitPrice: 2500,
      quantity: 2,
    );
    final workbook = workbookFor(
      quotation(items: const [item]),
      salespersonName: 'Sam Sales',
    );
    final sheet = quotationSheet(workbook);

    expect(workbook.tables.keys, ['Quotation']);
    expect(valueBeside(sheet, 'Quotation No'), TextCellValue('QT-1001'));
    expect(valueBeside(sheet, 'Salesperson'), TextCellValue('Sam Sales'));
    expect(valueBeside(sheet, 'Customer'), TextCellValue('Alex Customer'));
    expect(valueBeside(sheet, 'Company'), TextCellValue('Acme LLC'));
    expect(valueBeside(sheet, 'Phone'), TextCellValue('+971500000000'));
    expect(valueBeside(sheet, 'Email'), TextCellValue('alex@example.com'));
    expect(valueBeside(sheet, 'Location'), TextCellValue('Dubai'));
    expect(valueBeside(sheet, 'Date'), isA<DateCellValue>());
    expect(valueBeside(sheet, 'Valid Until'), isA<DateCellValue>());
    expect(
      valueBeside(sheet, 'Customer Notes'),
      TextCellValue('Customer-facing note'),
    );
    expect(
      sheet.rows
          .expand((row) => row)
          .map((cell) => cell?.value)
          .whereType<TextCellValue>()
          .map((value) => value.value.toString()),
      isNot(contains('Private internal note')),
    );

    final headerRow = rowContaining(sheet, 'No.');
    expect(
      sheet.rows[headerRow].map((cell) => cell?.value.toString()).toList(),
      [
        'No.',
        'Product Code',
        'Product',
        'Brand',
        'Description',
        'Quantity',
        'Unit Price (AED)',
        'Discount %',
        'Gross Amount',
        'Discount Amount',
        'Net Amount',
        'VAT Applicable',
      ],
    );
    expect(sheet.rows[headerRow + 1][5]?.value, const IntCellValue(2));
    expect(numericValue(sheet.rows[headerRow + 1][6]?.value), 2500);
  });

  test('exports mixed taxable and exempt items with authoritative VAT', () {
    const items = [
      QuotationLineItem(
        id: 'taxable',
        name: 'Taxable',
        brand: 'Brand',
        unitPrice: 100,
        quantity: 1,
        isVatApplicable: true,
      ),
      QuotationLineItem(
        id: 'exempt',
        name: 'Exempt',
        brand: 'Brand',
        unitPrice: 200,
        quantity: 1,
        isVatApplicable: false,
      ),
    ];
    const charges = QuotationCharges(vatPercentage: 5);
    final sheet = quotationSheet(
      workbookFor(quotation(items: items, charges: charges)),
    );
    final headerRow = rowContaining(sheet, 'No.');

    expect(sheet.rows[headerRow + 1][11]?.value, TextCellValue('Yes'));
    expect(sheet.rows[headerRow + 2][11]?.value, TextCellValue('No'));
    expect(
      numericValue(valueBeside(sheet, 'VAT Amount')),
      QuotationCalculator.calculateVAT(items, charges),
    );
  });

  test('exports line discount as numeric gross, discount, and net amounts', () {
    const item = QuotationLineItem(
      id: 'discounted',
      name: 'Discounted item',
      brand: 'Brand',
      unitPrice: 125,
      quantity: 2,
      discount: 10,
    );
    final sheet = quotationSheet(workbookFor(quotation(items: const [item])));
    final itemRow = rowContaining(sheet, 'No.') + 1;

    expect(numericValue(sheet.rows[itemRow][7]?.value), 10);
    expect(numericValue(sheet.rows[itemRow][8]?.value), 250);
    expect(numericValue(sheet.rows[itemRow][9]?.value), 25);
    expect(
      numericValue(sheet.rows[itemRow][10]?.value),
      QuotationCalculator.calculateLineTotal(125, 2, 10),
    );
  });

  test('exports overall discount as a negative numeric total', () {
    const items = [
      QuotationLineItem(
        id: 'item',
        name: 'Item',
        brand: 'Brand',
        unitPrice: 100,
        quantity: 1,
      ),
    ];
    const charges = QuotationCharges(overallDiscount: 20);
    final sheet = quotationSheet(
      workbookFor(quotation(items: items, charges: charges)),
    );

    expect(numericValue(valueBeside(sheet, 'Overall Discount')), -20);
  });

  test('exports delivery, installation, and other charges as numbers', () {
    const charges = QuotationCharges(
      deliveryCharges: 15,
      installationCharges: 25,
      otherCharges: 5,
    );
    final sheet = quotationSheet(workbookFor(quotation(charges: charges)));

    expect(numericValue(valueBeside(sheet, 'Delivery Charges')), 15);
    expect(numericValue(valueBeside(sheet, 'Installation Charges')), 25);
    expect(numericValue(valueBeside(sheet, 'Other Charges')), 5);
  });

  test('grand total exactly matches QuotationCalculator', () {
    const items = [
      QuotationLineItem(
        id: 'taxable',
        name: 'Taxable',
        brand: 'Brand',
        unitPrice: 199.95,
        quantity: 2,
        discount: 7.5,
      ),
      QuotationLineItem(
        id: 'exempt',
        name: 'Exempt',
        brand: 'Brand',
        unitPrice: 80,
        quantity: 3,
        discount: 5,
        isVatApplicable: false,
      ),
    ];
    const charges = QuotationCharges(
      deliveryCharges: 35,
      installationCharges: 50,
      otherCharges: 12.5,
      overallDiscount: 40,
      vatPercentage: 5,
    );
    final sheet = quotationSheet(
      workbookFor(quotation(items: items, charges: charges)),
    );

    expect(
      numericValue(valueBeside(sheet, 'Grand Total')),
      QuotationCalculator.calculateGrandTotal(items, charges),
    );
  });
}
