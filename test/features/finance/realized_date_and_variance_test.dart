import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Data prevista x realizada', () {
    test('despesa preserva data prevista ao registrar data realizada', () {
      final expectedDate = DateTime(2026, 10, 10);
      final realizedDate = DateTime(2026, 10, 8);
      final expense = ExpenseEntity(
        id: 'expense-1',
        createdAt: DateTime(2026, 9, 1),
        deletedAt: null,
        description: 'Internet',
        amount: 100,
        date: expectedDate,
        paid: true,
        observation: null,
        idAccount: 'account-1',
        idCategory: 'category-1',
        idCreditCard: null,
        idCreditCardTransaction: null,
        realizedAt: realizedDate,
      );

      expect(expense.date, expectedDate);
      expect(expense.realizedAt, realizedDate);
    });

    test('diferença só existe quando confirmada como variação real', () {
      final expense = ExpenseEntity(
        id: 'expense-2',
        createdAt: DateTime(2026, 9, 1),
        deletedAt: null,
        description: 'Conta',
        amount: 50,
        date: DateTime(2026, 10, 10),
        paid: true,
        observation: null,
        idAccount: 'account-1',
        idCategory: 'category-1',
        idCreditCard: null,
        idCreditCardTransaction: null,
        expectedAmount: 100,
        trackVariance: false,
        varianceRegisteredAt: null,
      );
      expect(expense.varianceAmount, 0);

      expense.trackVariance = true;
      expense.varianceRegisteredAt = DateTime(2026, 10, 10);
      expect(expense.varianceAmount, 50);
    });

    test('receita usa o mesmo conceito sem inverter o sinal', () {
      final income = IncomeEntity(
        id: 'income-1',
        createdAt: DateTime(2026, 9, 1),
        deletedAt: null,
        description: 'Freelance',
        amount: 120,
        date: DateTime(2026, 10, 10),
        received: true,
        observation: null,
        idAccount: 'account-1',
        idCategory: 'category-1',
        expectedAmount: 100,
        trackVariance: true,
        varianceRegisteredAt: DateTime(2026, 10, 10),
      );
      expect(income.varianceAmount, 20);
    });
  });
}
