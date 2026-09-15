import 'package:flutter_test/flutter_test.dart';
import 'package:eagleflow/features/quotations/presentation/preview/quotation_document_formatters.dart';

void main() {
  group('QuotationDocumentFormatters.formatSpecification', () {
    test('1 part - returns unchanged', () {
      final input = 'Only one part description';
      final result = QuotationDocumentFormatters.formatSpecification(input);
      expect(result, 'Only one part description');
    });

    test('2 parts - returns on the same line', () {
      final input = 'Part 1 | Part 2';
      final result = QuotationDocumentFormatters.formatSpecification(input);
      expect(result, 'Part 1 | Part 2');
    });

    test('3 parts - splits around midpoint (ceil of 3/2 = 2)', () {
      final input = '1410x680x450mm | Net Weight: 45kg | 10 years frame warranty';
      final result = QuotationDocumentFormatters.formatSpecification(input);
      expect(result, '1410x680x450mm | Net Weight: 45kg\n10 years frame warranty');
    });

    test('4 parts - splits around midpoint (4/2 = 2)', () {
      final input = 'A | B | C | D';
      final result = QuotationDocumentFormatters.formatSpecification(input);
      expect(result, 'A | B\nC | D');
    });

    test('Empty or null returns as is', () {
      expect(QuotationDocumentFormatters.formatSpecification(null), null);
      expect(QuotationDocumentFormatters.formatSpecification(''), '');
      expect(QuotationDocumentFormatters.formatSpecification('   '), '   ');
    });

    test('Long text parts are preserved properly', () {
      final input = 'Very long string part 1 that wraps | Very long string part 2 that wraps | Short 3';
      final result = QuotationDocumentFormatters.formatSpecification(input);
      expect(result, 'Very long string part 1 that wraps | Very long string part 2 that wraps\nShort 3');
    });

    test('Manual newline is preserved exactly without | splitting', () {
      final input = 'Part A | Part B\nPart C';
      final result = QuotationDocumentFormatters.formatSpecification(input);
      expect(result, 'Part A | Part B\nPart C');
      
      final input2 = 'Only one part but with\nmanual newline';
      final result2 = QuotationDocumentFormatters.formatSpecification(input2);
      expect(result2, 'Only one part but with\nmanual newline');
    });
  });
}
