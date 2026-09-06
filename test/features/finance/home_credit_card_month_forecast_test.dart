import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/features/home/domain/entities/home_credit_card_month_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('previsão da fatura soma somente valor já conhecido + planejamentos', () {
    final card = CreditCardEntity(
      id: 'card-1',
      createdAt: DateTime(2026, 9, 1),
      deletedAt: null,
      description: 'Cartão',
      amountLimit: 2000,
      billClosingDay: 3,
      billDueDay: 10,
      brand: null,
      idAccount: 'account-1',
      descriptionAccount: 'Conta',
      financialInstitutionAccount: null,
      amountLimitUtilized: 0,
    );

    final item = HomeCreditCardMonthEntity(
      creditCard: card,
      bill: null,
      billAmount: 700.10,
      plannedAmount: 300.25,
    );

    expect(item.forecastAmount, 1000.35);
  });
}
