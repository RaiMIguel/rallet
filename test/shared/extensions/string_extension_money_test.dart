import 'package:rallet/shared/extensions/string_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StringExtension.moneyToDouble', () {
    test('interpreta centavos com virgula', () {
      expect('1,73'.moneyToDouble(), 1.73);
      expect('0,01'.moneyToDouble(), 0.01);
      expect('0,10'.moneyToDouble(), 0.10);
      expect('10,99'.moneyToDouble(), 10.99);
      expect('100,05'.moneyToDouble(), 100.05);
    });

    test('interpreta ponto decimal sem inflar o valor', () {
      expect('1.73'.moneyToDouble(), 1.73);
      expect('1234.56'.moneyToDouble(), 1234.56);
    });

    test('interpreta formato brasileiro com milhar', () {
      expect('1.000,50'.moneyToDouble(), 1000.50);
      expect('1.234,56'.moneyToDouble(), 1234.56);
      expect('R\$ 1.234,56'.moneyToDouble(), 1234.56);
    });

    test('normaliza o retorno em centavos', () {
      expect('1,735'.moneyToDouble(), 1.74);
    });
  });
}
