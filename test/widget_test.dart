import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_app/core/formatters.dart';

void main() {
  test('formatage des montants', () {
    expect(fmtMoney(150000), '150 000 FCFA');
    expect(fmtMoney(0), '0 FCFA');
  });
}
