import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/card_cash_advance/domain/enums/card_cash_advance_status_enum.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/features/home/domain/entities/home_monthly_economy_entity.dart';
import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';
import 'package:rallet/features/reports/domain/entities/report_financial_explanation_entity.dart';
import 'package:rallet/features/reports/domain/entities/reports_dashboard_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Auditoria financeira - crédito via cartão', () {
    test('R\$ 500 recebidos e R\$ 550 cobrados geram R\$ 50 de custo', () {
      final plan = CardCashAdvancePlanEntity(
        id: 'plan-1',
        createdAt: DateTime(2026, 9, 1),
        deletedAt: null,
        description: 'Cobertura',
        idAccount: 'account-1',
        idCreditCard: 'card-1',
        amountReceived: 500,
        amountCharged: 550,
        plannedDate: DateTime(2026, 9, 8),
        billDueDate: DateTime(2026, 10, 10),
        status: CardCashAdvanceStatusEnum.planned,
        realizedAt: null,
        idStatement: null,
        idCreditCardTransaction: null,
      );

      expect(plan.financialCost, 50.00);
      expect((plan.financialCost / plan.amountReceived) * 100, 10.00);
    });

    test('principal emprestado não aumenta receitas da economia mensal', () {
      const economy = HomeMonthlyEconomyEntity(
        incomes: 2000,
        expenses: 1650,
        regularExpenses: 1200,
        creditCardPurchases: 400,
        plannedFinancialCosts: 50,
      );

      expect(economy.incomes, 2000);
      expect(economy.financialCosts, 50);
      expect(economy.expenseCompositionTotal, 1650);
      expect(economy.isExpenseCompositionConsistent, isTrue);
      expect(economy.savings, 350);
    });


    test('compra planejada entra na composição sem alterar receitas', () {
      const economy = HomeMonthlyEconomyEntity(
        incomes: 2000,
        expenses: 1750,
        regularExpenses: 1200,
        creditCardPurchases: 400,
        plannedFinancialCosts: 50,
        plannedPurchases: 100,
      );

      expect(economy.incomes, 2000);
      expect(economy.plannedPurchases, 100);
      expect(economy.expenseCompositionTotal, 1750);
      expect(economy.isExpenseCompositionConsistent, isTrue);
      expect(economy.savings, 250);
    });

    test('resumo fecha despesas comuns + cartão + juros', () {
      final item = ReportFinancialCostItem(
        id: 'plan-1',
        description: 'Cobertura',
        amountReceived: 500,
        amountCharged: 550,
        financialCost: 50,
        billDueDate: DateTime(2026, 10, 10),
        planned: true,
      );

      final report = ReportsDashboardEntity(
        month: DateTime(2026, 10, 1),
        incomes: 2000,
        expenses: 1650,
        regularExpenses: 1200,
        creditCardPurchases: 400,
        realizedFinancialCosts: 0,
        plannedFinancialCosts: 50,
        creditCardExpenses: 450,
        cashCommitments: const ReportCashCommitmentComposition(
          pendingExpenses: 860,
          openBills: 1187.38,
          plannedCreditCharges: 0,
          plannedExpenses: 0,
        ),
        fixedExpenses: 800,
        variableExpenses: 850,
        previousMonthExpenses: 1500,
        expenseCategories: const [],
        evolution: const [],
        futureCommitments: const [],
        financialCostItems: [item],
        financialExplanation: ReportFinancialExplanationEntity(
          month: DateTime(2026, 10, 1),
          economicIncomes: 2000,
          economicExpenses: 1650,
          cashReceivable: 1850,
          cashPayable: 2047.38,
          economicIncomeItems: [
            ReportAuditItem(
              id: 'income-total',
              description: 'Receitas do mês',
              date: DateTime(2026, 10, 1),
              amount: 2000,
              reason: 'Teste',
              treatment: ReportAuditTreatment.economicIncome,
            ),
          ],
          economicExpenseItems: [
            ReportAuditItem(
              id: 'expense-total',
              description: 'Despesas do mês',
              date: DateTime(2026, 10, 1),
              amount: 1650,
              reason: 'Teste',
              treatment: ReportAuditTreatment.economicExpense,
            ),
          ],
          cashReceivableItems: [
            ReportAuditItem(
              id: 'receivable-total',
              description: 'A receber',
              date: DateTime(2026, 10, 1),
              amount: 1850,
              reason: 'Teste',
              treatment: ReportAuditTreatment.economicIncome,
            ),
          ],
          cashPayableItems: [
            ReportAuditItem(
              id: 'payable-total',
              description: 'A pagar',
              date: DateTime(2026, 10, 1),
              amount: 2047.38,
              reason: 'Teste',
              treatment: ReportAuditTreatment.cashOutflowNotNewExpense,
            ),
          ],
          nonEconomicItems: const [],
        ),
        greenPath: ReportGreenPathEntity(
          calculatedAt: DateTime(2026, 9, 6),
          availableBalance: 800,
          openDebt: 2000,
          creditCardDebt: 1800,
          pendingExpenseDebt: 200,
          monthlyLivingCost: 500,
          monthlyIncome: 1000,
          incomeBasedOnRecurring: true,
          nonCardMonthlyCost: 500,
          nextMonthCardBill: 750,
          historyMonthsAnalyzed: 3,
        ),
      );

      expect(report.financialCosts, 50);
      expect(report.expenseCompositionTotal, 1650);
      expect(report.isExpenseCompositionConsistent, isTrue);
      expect(report.financialCostItemsTotal, 50);
      expect(report.isFinancialCostCompositionConsistent, isTrue);
      expect(report.savings, 350);
      expect(report.cashCommitments.total, closeTo(2047.38, 0.001));
    });

    test('explicação financeira só confirma quando todos os totais fecham', () {
      final explanation = ReportFinancialExplanationEntity(
        month: DateTime(2026, 9, 1),
        economicIncomes: 1850,
        economicExpenses: 1710.38,
        cashReceivable: 1850,
        cashPayable: 2047.38,
        economicIncomeItems: [
          ReportAuditItem(
            id: 'i1',
            description: 'Receita',
            date: DateTime(2026, 9, 5),
            amount: 1850,
            reason: 'Teste',
            treatment: ReportAuditTreatment.economicIncome,
          ),
        ],
        economicExpenseItems: [
          ReportAuditItem(
            id: 'e1',
            description: 'Despesa',
            date: DateTime(2026, 9, 8),
            amount: 1710.38,
            reason: 'Teste',
            treatment: ReportAuditTreatment.economicExpense,
          ),
        ],
        cashReceivableItems: [
          ReportAuditItem(
            id: 'r1',
            description: 'A receber',
            date: DateTime(2026, 9, 10),
            amount: 1850,
            reason: 'Teste',
            treatment: ReportAuditTreatment.economicIncome,
          ),
        ],
        cashPayableItems: [
          ReportAuditItem(
            id: 'p1',
            description: 'A pagar',
            date: DateTime(2026, 9, 12),
            amount: 2047.38,
            reason: 'Teste',
            treatment: ReportAuditTreatment.cashOutflowNotNewExpense,
          ),
        ],
        nonEconomicItems: const [],
      );

      expect(explanation.savings, closeTo(139.62, .001));
      expect(explanation.cashPendingBalance, closeTo(-197.38, .001));
      expect(
        explanation.shouldExplainPositiveEconomyWithNegativePendingCash,
        isTrue,
      );
      expect(explanation.isFullyReconciled, isTrue);
    });

    test('explica quando pendentes parecem normais mas não batem com a economia', () {
      final explanation = ReportFinancialExplanationEntity(
        month: DateTime(2026, 9, 1),
        economicIncomes: 1800,
        economicExpenses: 1500,
        cashReceivable: 1600,
        cashPayable: 1500,
        economicIncomeItems: const [],
        economicExpenseItems: const [],
        cashReceivableItems: const [],
        cashPayableItems: const [],
        nonEconomicItems: const [],
      );

      expect(explanation.cashPendingBalance, 100);
      expect(explanation.savings, 300);
      expect(explanation.economyPendingDifference, 200);
      expect(
        explanation.shouldExplainPositiveEconomyWithNegativePendingCash,
        isFalse,
      );
      expect(explanation.shouldExplainEconomyVsPending, isTrue);
    });

    test('não mostra explicação extra quando pendentes e economia fecham', () {
      final explanation = ReportFinancialExplanationEntity(
        month: DateTime(2026, 9, 1),
        economicIncomes: 1600,
        economicExpenses: 1500,
        cashReceivable: 1600,
        cashPayable: 1500,
        economicIncomeItems: const [],
        economicExpenseItems: const [],
        cashReceivableItems: const [],
        cashPayableItems: const [],
        nonEconomicItems: const [],
      );

      expect(explanation.cashPendingBalance, 100);
      expect(explanation.savings, 100);
      expect(explanation.economyPendingDifference, 0);
      expect(explanation.shouldExplainEconomyVsPending, isFalse);
    });

  });


  group('Auditoria financeira - compra planejada parcelada', () {
    test('R\$ 1.200 em 6x sem juros fecha exatamente R\$ 1.200', () {
      final plan = PlannedPurchaseEntity(
        id: 'purchase-1',
        createdAt: DateTime(2026, 9, 2),
        deletedAt: null,
        description: 'TV',
        amount: 1200,
        plannedDate: DateTime(2026, 9, 8),
        paymentType: PlannedPurchasePaymentType.creditCardInstallments,
        idCreditCard: 'card-1',
        installmentCount: 6,
        totalCharged: 1200,
        firstBillDueDate: DateTime(2026, 10, 10),
      );

      expect(plan.installmentAmounts.length, 6);
      expect(plan.installmentAmounts.fold<double>(0, (a, b) => a + b), 1200);
      expect(plan.financialCost, 0);
    });

    test('R\$ 1.200 virando R\$ 1.350 separa R\$ 150 de custo', () {
      final plan = PlannedPurchaseEntity(
        id: 'purchase-2',
        createdAt: DateTime(2026, 9, 2),
        deletedAt: null,
        description: 'TV',
        amount: 1200,
        plannedDate: DateTime(2026, 9, 8),
        paymentType: PlannedPurchasePaymentType.creditCardInstallments,
        idCreditCard: 'card-1',
        installmentCount: 6,
        totalCharged: 1350,
        firstBillDueDate: DateTime(2026, 10, 10),
      );

      expect(plan.financialCost, 150);
      expect(plan.principalInstallmentAmounts.fold<double>(0, (a, b) => a + b), 1200);
      expect(plan.financialCostInstallmentAmounts.fold<double>(0, (a, b) => a + b), 150);
      expect(plan.installmentAmounts.fold<double>(0, (a, b) => a + b), 1350);
      expect(plan.amountDueInPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 31, 23, 59, 59)), 225);
      expect(plan.principalDueInPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 31, 23, 59, 59)), 200);
      expect(plan.financialCostDueInPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 31, 23, 59, 59)), 25);
    });

    test('parcelamento com centavos distribui sem perder nem criar centavo', () {
      final plan = PlannedPurchaseEntity(
        id: 'purchase-3',
        createdAt: DateTime(2026, 9, 2),
        deletedAt: null,
        description: 'Compra',
        amount: 100,
        plannedDate: DateTime(2026, 9, 8),
        paymentType: PlannedPurchasePaymentType.creditCardInstallments,
        idCreditCard: 'card-1',
        installmentCount: 3,
        totalCharged: 100,
        firstBillDueDate: DateTime(2026, 10, 10),
      );

      expect(plan.installmentAmounts, [33.34, 33.33, 33.33]);
      expect(plan.installmentAmounts.fold<double>(0, (a, b) => a + b), closeTo(100, .0001));
    });
  });

  test('fatura arredonda valores monetários em vez de truncar centavos', () {
    CreditCardTransactionEntity tx(String id, double amount) =>
        CreditCardTransactionEntity(
          id: id,
          createdAt: DateTime(2026, 9, 1),
          deletedAt: null,
          description: id,
          amount: amount,
          date: DateTime(2026, 9, 1),
          idCategory: 'category-1',
          idCreditCard: 'card-1',
          idCreditCardBill: 'bill-1',
          observation: null,
        );

    final bill = CreditCardBillEntity(
      id: 'bill-1',
      createdAt: DateTime(2026, 9, 1),
      deletedAt: null,
      billClosingDate: DateTime(2026, 9, 30),
      billDueDate: DateTime(2026, 10, 10),
      idCreditCard: 'card-1',
      transactions: [
        tx('a', .10),
        tx('b', .20),
        tx('payment', -.10),
      ],
    );

    expect(bill.billAmount, .20);
  });
}
