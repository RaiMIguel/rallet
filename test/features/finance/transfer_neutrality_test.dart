import 'package:rallet/features/transactions/domain/entities/transactions_by_period_entity.dart';
import 'package:rallet/features/transactions/domain/entities/transfer_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transferência entre contas não vira receita nem despesa', () {
    final transfer = TransferEntity(
      id: 'transfer-1',
      createdAt: DateTime(2026, 9, 1),
      deletedAt: null,
      amount: 500,
      date: DateTime(2026, 9, 3),
      idAccountFrom: 'account-a',
      idAccountTo: 'account-b',
    );

    final period = TransactionsByPeriodEntity(transactions: [transfer]);

    expect(period.amountsIncome, 0);
    expect(period.amountsExpense, 0);
    expect(period.balance, 0);
  });
}
