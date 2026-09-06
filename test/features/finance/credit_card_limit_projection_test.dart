import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/card_cash_advance/domain/enums/card_cash_advance_status_enum.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/features/credit_card/domain/services/credit_card_limit_projection.dart';
import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';
import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CreditCardEntity card({double utilized = 800}) => CreditCardEntity(
        id: 'card-1',
        createdAt: DateTime(2026, 9, 1),
        deletedAt: null,
        description: 'Cartão teste',
        amountLimit: 1000,
        safetyLimit: null,
        billClosingDay: 1,
        billDueDay: 10,
        brand: null,
        idAccount: null,
        descriptionAccount: '',
        financialInstitutionAccount: null,
        amountLimitUtilized: utilized,
      );

  CreditCardBillEntity bill(double amount, DateTime dueDate) {
    final tx = CreditCardTransactionEntity(
      id: 'bill-tx-${dueDate.month}',
      createdAt: DateTime(2026, 9, 1),
      deletedAt: null,
      description: 'Compra real',
      amount: amount,
      date: DateTime(2026, 9, 1),
      idCategory: 'category-1',
      idCreditCard: 'card-1',
      idCreditCardBill: 'bill-${dueDate.month}',
      observation: null,
    );
    return CreditCardBillEntity(
      id: 'bill-${dueDate.month}',
      createdAt: DateTime(2026, 9, 1),
      deletedAt: null,
      billClosingDate: dueDate.subtract(const Duration(days: 7)),
      billDueDate: dueDate,
      idCreditCard: 'card-1',
      transactions: [tx],
    );
  }

  CardCashAdvancePlanEntity cashPlan({
    required double charged,
    required DateTime date,
    required DateTime dueDate,
  }) =>
      CardCashAdvancePlanEntity(
        id: 'cash-1',
        createdAt: DateTime(2026, 9, 2),
        deletedAt: null,
        description: 'Crédito planejado',
        idAccount: 'account-1',
        idCreditCard: 'card-1',
        amountReceived: charged,
        amountCharged: charged,
        plannedDate: date,
        billDueDate: dueDate,
        status: CardCashAdvanceStatusEnum.planned,
        realizedAt: null,
        idStatement: null,
        idCreditCardTransaction: null,
      );

  group('Projeção temporal do limite do cartão', () {
    test('mantém crédito planejado no cenário e marca falta de limite', () {
      final result = CreditCardLimitProjection.calculate(
        today: DateTime(2026, 9, 1),
        horizonEnd: DateTime(2026, 10, 31),
        cards: [card()],
        bills: [bill(500, DateTime(2026, 9, 10))],
        cashAdvancePlans: [
          cashPlan(
            charged: 300,
            date: DateTime(2026, 9, 5),
            dueDate: DateTime(2026, 10, 10),
          ),
        ],
        plannedPurchases: const [],
      );

      final plan = result.cashAdvancePlans['cash-1']!;
      expect(plan.feasible, isFalse);
      expect(plan.availableBefore, 200);
      expect(plan.shortage, 100);
      expect(result.cards.single.maximumProjectedUtilized, 1100);
    });

    test('fatura paga antes do plano libera limite para a operação', () {
      final result = CreditCardLimitProjection.calculate(
        today: DateTime(2026, 9, 1),
        horizonEnd: DateTime(2026, 10, 31),
        cards: [card()],
        bills: [bill(500, DateTime(2026, 9, 10))],
        cashAdvancePlans: [
          cashPlan(
            charged: 600,
            date: DateTime(2026, 9, 11),
            dueDate: DateTime(2026, 10, 10),
          ),
        ],
        plannedPurchases: const [],
      );

      final plan = result.cashAdvancePlans['cash-1']!;
      expect(plan.feasible, isTrue);
      expect(plan.availableBefore, 700);
      expect(result.cards.single.utilizedByDate[DateTime(2026, 9, 11)], 900);
    });

    test('despesa planejada no cartão compromete o total e libera por parcela', () {
      final purchase = PlannedPurchaseEntity(
        id: 'purchase-1',
        createdAt: DateTime(2026, 9, 2),
        deletedAt: null,
        description: 'Notebook',
        amount: 600,
        plannedDate: DateTime(2026, 9, 5),
        paymentType: PlannedPurchasePaymentType.creditCardInstallments,
        idCreditCard: 'card-1',
        installmentCount: 3,
        totalCharged: 600,
        firstBillDueDate: DateTime(2026, 10, 10),
      );

      final result = CreditCardLimitProjection.calculate(
        today: DateTime(2026, 9, 1),
        horizonEnd: DateTime(2027, 1, 31),
        cards: [card(utilized: 0)],
        bills: const [],
        cashAdvancePlans: const [],
        plannedPurchases: [purchase],
      );

      expect(result.plannedPurchases['purchase-1']!.feasible, isTrue);
      expect(result.cards.single.utilizedByDate[DateTime(2026, 9, 5)], 600);
      expect(result.cards.single.utilizedByDate[DateTime(2026, 10, 10)], 400);
      expect(result.cards.single.utilizedByDate[DateTime(2026, 11, 10)], 200);
      expect(result.cards.single.utilizedByDate[DateTime(2026, 12, 10)], 0);
    });
  });

  group('Planejado x realizado', () {
    test('despesa menor que o esperado vira economia positiva', () {
      final expense = ExpenseEntity(
        id: 'expense-1',
        createdAt: DateTime(2026, 9, 1),
        deletedAt: null,
        description: 'Mercado',
        amount: 50,
        date: DateTime(2026, 9, 3),
        paid: true,
        observation: null,
        idAccount: 'account-1',
        idCategory: 'category-1',
        idCreditCard: null,
        idCreditCardTransaction: null,
        expectedAmount: 100,
        trackVariance: true,
        varianceRegisteredAt: DateTime(2026, 9, 3),
      );
      expect(expense.varianceAmount, 50);
    });



    test('flag antiga sem confirmação explícita não gera desvio', () {
      final expense = ExpenseEntity(
        id: 'expense-legacy',
        createdAt: DateTime(2026, 9, 1),
        deletedAt: null,
        description: 'Cadastro antigo',
        amount: 50,
        date: DateTime(2026, 9, 3),
        paid: true,
        observation: null,
        idAccount: 'account-1',
        idCategory: 'category-1',
        idCreditCard: null,
        idCreditCardTransaction: null,
        expectedAmount: 100,
        trackVariance: true,
      );
      expect(expense.varianceAmount, 0);
    });
    test('receita abaixo do esperado vira desvio negativo', () {
      final income = IncomeEntity(
        id: 'income-1',
        createdAt: DateTime(2026, 9, 1),
        deletedAt: null,
        description: 'Freela',
        amount: 1800,
        date: DateTime(2026, 9, 3),
        received: true,
        observation: null,
        idAccount: 'account-1',
        idCategory: 'category-1',
        expectedAmount: 2000,
        trackVariance: true,
        varianceRegisteredAt: DateTime(2026, 9, 3),
      );
      expect(income.varianceAmount, -200);
    });
  });
}
