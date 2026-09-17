import 'package:excel/excel.dart';

import '../domain/quotation.dart';
import 'quotation_calculator.dart';

class QuotationExcelService {
  static const _sheetName = 'Quotation';
  static const _currencyFormat = '#,##0.00';
  static const _percentageFormat = '0.00';
  static final _navy = ExcelColor.fromHexString('FF0F172A');
  static final _slate = ExcelColor.fromHexString('FF334155');
  static final _lightFill = ExcelColor.fromHexString('FFF1F5F9');
  static final _border = ExcelColor.fromHexString('FFCBD5E1');

  List<int> generateWorkbook(Quotation quotation, {String? salespersonName}) {
    final excel = Excel.createExcel();
    final sheet = excel[_sheetName];
    excel.setDefaultSheet(_sheetName);
    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: _navy,
      fontFamily: getFontFamily(FontFamily.Arial),
      verticalAlign: VerticalAlign.Center,
    );
    final metadataLabelStyle = CellStyle(
      bold: true,
      fontColorHex: _slate,
      backgroundColorHex: _lightFill,
      fontFamily: getFontFamily(FontFamily.Arial),
      verticalAlign: VerticalAlign.Center,
    );
    final metadataValueStyle = CellStyle(
      fontColorHex: _slate,
      fontFamily: getFontFamily(FontFamily.Arial),
      verticalAlign: VerticalAlign.Center,
    );
    final dateStyle = metadataValueStyle.copyWith(
      numberFormat: const CustomDateTimeNumFormat(formatCode: 'dd mmm yyyy'),
    );
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: _navy,
      fontFamily: getFontFamily(FontFamily.Arial),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      bottomBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: _border,
      ),
    );
    final textStyle = CellStyle(
      fontColorHex: _slate,
      fontFamily: getFontFamily(FontFamily.Arial),
      verticalAlign: VerticalAlign.Top,
      textWrapping: TextWrapping.WrapText,
      bottomBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: _border,
      ),
    );
    final integerStyle = textStyle.copyWith(
      horizontalAlignVal: HorizontalAlign.Right,
      numberFormat: const CustomNumericNumFormat(formatCode: '#,##0'),
    );
    final currencyStyle = textStyle.copyWith(
      horizontalAlignVal: HorizontalAlign.Right,
      numberFormat: const CustomNumericNumFormat(formatCode: _currencyFormat),
    );
    final percentageStyle = textStyle.copyWith(
      horizontalAlignVal: HorizontalAlign.Right,
      numberFormat: const CustomNumericNumFormat(formatCode: _percentageFormat),
    );
    final totalLabelStyle = CellStyle(
      bold: true,
      fontColorHex: _slate,
      backgroundColorHex: _lightFill,
      fontFamily: getFontFamily(FontFamily.Arial),
      horizontalAlign: HorizontalAlign.Right,
    );
    final totalValueStyle = totalLabelStyle.copyWith(
      numberFormat: const CustomNumericNumFormat(formatCode: _currencyFormat),
    );
    final grandTotalLabelStyle = totalLabelStyle.copyWith(
      fontColorHexVal: ExcelColor.white,
      backgroundColorHexVal: _navy,
    );
    final grandTotalValueStyle = grandTotalLabelStyle.copyWith(
      numberFormat: const CustomNumericNumFormat(formatCode: _currencyFormat),
    );

    sheet.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByString('L1'),
      customValue: TextCellValue('Quotation ${quotation.quotationNumber}'),
    );
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;

    final salesperson = salespersonName?.trim();
    final metadata = <(String, CellValue, CellStyle)>[
      (
        'Quotation No',
        TextCellValue(quotation.quotationNumber),
        metadataValueStyle,
      ),
      ('Date', DateCellValue.fromDateTime(quotation.createdDate), dateStyle),
      (
        'Valid Until',
        DateCellValue.fromDateTime(quotation.validUntil),
        dateStyle,
      ),
      (
        'Salesperson',
        TextCellValue(
          salesperson != null && salesperson.isNotEmpty
              ? salesperson
              : quotation.salespersonId,
        ),
        metadataValueStyle,
      ),
      (
        'Customer',
        TextCellValue(quotation.customerInfo.name),
        metadataValueStyle,
      ),
      (
        'Company',
        TextCellValue(quotation.customerInfo.company),
        metadataValueStyle,
      ),
      (
        'Phone',
        TextCellValue(quotation.customerInfo.phone),
        metadataValueStyle,
      ),
      (
        'Email',
        TextCellValue(quotation.customerInfo.email),
        metadataValueStyle,
      ),
      (
        'Location',
        TextCellValue(quotation.customerInfo.projectLocation),
        metadataValueStyle,
      ),
    ];

    for (var index = 0; index < metadata.length; index++) {
      final row = index + 2;
      final entry = metadata[index];
      _setCell(sheet, row, 0, TextCellValue(entry.$1), metadataLabelStyle);
      _setCell(sheet, row, 1, entry.$2, entry.$3);
    }

    const headers = [
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
    ];
    const headerRow = 12;
    for (var column = 0; column < headers.length; column++) {
      _setCell(
        sheet,
        headerRow,
        column,
        TextCellValue(headers[column]),
        headerStyle,
      );
    }

    for (var index = 0; index < quotation.lineItems.length; index++) {
      final item = quotation.lineItems[index];
      final row = headerRow + index + 1;
      final grossAmount = item.unitPrice * item.quantity;
      final netAmount = QuotationCalculator.calculateLineTotal(
        item.unitPrice,
        item.quantity,
        item.discount,
      );
      final discountAmount = grossAmount - netAmount;

      final values = <(CellValue, CellStyle)>[
        (IntCellValue(index + 1), integerStyle),
        (TextCellValue(item.productCode ?? ''), textStyle),
        (TextCellValue(item.name), textStyle),
        (TextCellValue(item.brand), textStyle),
        (TextCellValue(item.description ?? ''), textStyle),
        (IntCellValue(item.quantity), integerStyle),
        (DoubleCellValue(item.unitPrice), currencyStyle),
        (DoubleCellValue(item.discount), percentageStyle),
        (DoubleCellValue(grossAmount), currencyStyle),
        (DoubleCellValue(discountAmount), currencyStyle),
        (DoubleCellValue(netAmount), currencyStyle),
        (
          TextCellValue(item.isVatApplicable ? 'Yes' : 'No'),
          textStyle.copyWith(horizontalAlignVal: HorizontalAlign.Center),
        ),
      ];

      for (var column = 0; column < values.length; column++) {
        _setCell(sheet, row, column, values[column].$1, values[column].$2);
      }
    }

    final subtotal = QuotationCalculator.calculateSubtotal(quotation.lineItems);
    final vat = QuotationCalculator.calculateVAT(
      quotation.lineItems,
      quotation.charges,
    );
    final grandTotal = QuotationCalculator.calculateGrandTotal(
      quotation.lineItems,
      quotation.charges,
    );
    final totals = <(String, double, CellStyle)>[
      ('Subtotal', subtotal, totalValueStyle),
      ('Delivery Charges', quotation.charges.deliveryCharges, totalValueStyle),
      (
        'Installation Charges',
        quotation.charges.installationCharges,
        totalValueStyle,
      ),
      ('Other Charges', quotation.charges.otherCharges, totalValueStyle),
      ('Overall Discount', -quotation.charges.overallDiscount, totalValueStyle),
      (
        'VAT %',
        quotation.charges.vatPercentage,
        totalLabelStyle.copyWith(
          horizontalAlignVal: HorizontalAlign.Right,
          numberFormat: const CustomNumericNumFormat(
            formatCode: _percentageFormat,
          ),
        ),
      ),
      ('VAT Amount', vat, totalValueStyle),
      ('Grand Total', grandTotal, grandTotalValueStyle),
    ];
    final totalsStartRow = headerRow + quotation.lineItems.length + 2;
    for (var index = 0; index < totals.length; index++) {
      final row = totalsStartRow + index;
      final entry = totals[index];
      final isGrandTotal = entry.$1 == 'Grand Total';
      _setCell(
        sheet,
        row,
        10,
        TextCellValue(entry.$1),
        isGrandTotal ? grandTotalLabelStyle : totalLabelStyle,
      );
      _setCell(sheet, row, 11, DoubleCellValue(entry.$2), entry.$3);
    }

    final notesRow = totalsStartRow + totals.length + 2;
    _setCell(
      sheet,
      notesRow,
      0,
      TextCellValue('Customer Notes'),
      metadataLabelStyle,
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: notesRow),
      CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: notesRow),
      customValue: TextCellValue(quotation.customerNotes),
    );
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: notesRow))
        .cellStyle = metadataValueStyle.copyWith(
      textWrappingVal: TextWrapping.WrapText,
    );

    const columnWidths = [
      7.0,
      16.0,
      24.0,
      15.0,
      30.0,
      11.0,
      17.0,
      13.0,
      17.0,
      18.0,
      17.0,
      15.0,
    ];
    for (var column = 0; column < columnWidths.length; column++) {
      sheet.setColumnWidth(column, columnWidths[column]);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Failed to generate quotation workbook.');
    }
    return bytes;
  }

  void _setCell(
    Sheet sheet,
    int row,
    int column,
    CellValue value,
    CellStyle style,
  ) {
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
      value,
      cellStyle: style,
    );
  }
}
