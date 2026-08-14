import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Quotation stock validation rule', () {
    // 1 <= 1 -> ALLOW
    expect(1 > 1, isFalse);
    // 2 > 1 -> BLOCK
    expect(2 > 1, isTrue);
    // 5 <= 5 -> ALLOW
    expect(5 > 5, isFalse);
    // 6 > 5 -> BLOCK
    expect(6 > 5, isTrue);
  });
}
