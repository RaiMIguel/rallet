import 'package:flutter_test/flutter_test.dart';
import 'package:rallet/features/reports/domain/entities/reports_dashboard_entity.dart';

void main() {
  group('Caminho para o verde', () {
    test('dívida de 2000 + mês normal de 500 gera alvo de 2500', () {
      final report = ReportGreenPathEntity(
        calculatedAt: DateTime(2026, 9, 6),
        availableBalance: 0,
        openDebt: 2000,
        creditCardDebt: 1800,
        pendingExpenseDebt: 200,
        monthlyLivingCost: 500,
        monthlyIncome: 1000,
        incomeBasedOnRecurring: true,
        nonCardMonthlyCost: 500,
        nextMonthCardBill: 750,
        historyMonthsAnalyzed: 3,
      );

      expect(report.greenTarget, 2500);
      expect(report.amountMissing, 2500);
      expect(report.monthlyRecoveryCapacity, 500);
      expect(report.monthsToGreen, 5);
      expect(report.estimatedGreenMonth, DateTime(2027, 2, 1));
    });

    test('saldo atual reduz somente o que ainda falta para o alvo', () {
      final report = ReportGreenPathEntity(
        calculatedAt: DateTime(2026, 9, 6),
        availableBalance: 800,
        openDebt: 2000,
        creditCardDebt: 2000,
        pendingExpenseDebt: 0,
        monthlyLivingCost: 500,
        monthlyIncome: 1000,
        incomeBasedOnRecurring: true,
        nonCardMonthlyCost: 500,
        nextMonthCardBill: 300,
        historyMonthsAnalyzed: 3,
      );

      expect(report.greenTarget, 2500);
      expect(report.amountMissing, 1700);
      expect(report.monthsToGreen, 4);
    });

    test('sem sobra mensal não inventa prazo para ficar no verde', () {
      final report = ReportGreenPathEntity(
        calculatedAt: DateTime(2026, 9, 6),
        availableBalance: 100,
        openDebt: 2000,
        creditCardDebt: 2000,
        pendingExpenseDebt: 0,
        monthlyLivingCost: 1100,
        monthlyIncome: 1000,
        incomeBasedOnRecurring: true,
        nonCardMonthlyCost: 500,
        nextMonthCardBill: 700,
        historyMonthsAnalyzed: 3,
      );

      expect(report.monthlyRecoveryCapacity, -100);
      expect(report.monthsToGreen, isNull);
      expect(report.estimatedGreenMonth, isNull);
    });

    test('margem pessoal do cartão compara fatura com renda restante', () {
      final report = ReportGreenPathEntity(
        calculatedAt: DateTime(2026, 9, 6),
        availableBalance: 0,
        openDebt: 2000,
        creditCardDebt: 2000,
        pendingExpenseDebt: 0,
        monthlyLivingCost: 500,
        monthlyIncome: 1000,
        incomeBasedOnRecurring: true,
        nonCardMonthlyCost: 500,
        nextMonthCardBill: 750,
        historyMonthsAnalyzed: 3,
      );

      expect(report.sustainableCardCapacity, 500);
      expect(report.nextMonthCardExcess, 250);
    });
    test('projeção só considera normalização quando permanece verde no horizonte', () {
      final report = ReportGreenPathEntity(
        calculatedAt: DateTime(2026, 9, 6),
        availableBalance: 1000,
        openDebt: 800,
        creditCardDebt: 800,
        pendingExpenseDebt: 0,
        monthlyLivingCost: 500,
        monthlyIncome: 1500,
        incomeBasedOnRecurring: true,
        nonCardMonthlyCost: 500,
        nextMonthCardBill: 0,
        historyMonthsAnalyzed: 3,
        projectionMonths: 6,
        projection: [
          ReportGreenProjectionPoint(
            month: DateTime(2026, 9, 1),
            projectedBalance: 1600,
            remainingDebt: 800,
            requiredCoverage: 1300,
            netMovement: 600,
          ),
          ReportGreenProjectionPoint(
            month: DateTime(2026, 10, 1),
            projectedBalance: 900,
            remainingDebt: 600,
            requiredCoverage: 1100,
            netMovement: -700,
          ),
          ReportGreenProjectionPoint(
            month: DateTime(2026, 11, 1),
            projectedBalance: 1400,
            remainingDebt: 400,
            requiredCoverage: 900,
            netMovement: 500,
          ),
          ReportGreenProjectionPoint(
            month: DateTime(2026, 12, 1),
            projectedBalance: 1700,
            remainingDebt: 200,
            requiredCoverage: 700,
            netMovement: 300,
          ),
        ],
      );

      expect(report.estimatedGreenMonth, DateTime(2026, 11, 1));
      expect(report.monthsToGreen, 2);
    });

    test('não inventa normalização quando o fim do horizonte continua sem cobertura', () {
      final report = ReportGreenPathEntity(
        calculatedAt: DateTime(2026, 9, 6),
        availableBalance: 200,
        openDebt: 2000,
        creditCardDebt: 2000,
        pendingExpenseDebt: 0,
        monthlyLivingCost: 500,
        monthlyIncome: 1000,
        incomeBasedOnRecurring: true,
        nonCardMonthlyCost: 500,
        nextMonthCardBill: 700,
        historyMonthsAnalyzed: 3,
        projectionMonths: 6,
        projection: [
          ReportGreenProjectionPoint(
            month: DateTime(2026, 9, 1),
            projectedBalance: 300,
            remainingDebt: 1800,
            requiredCoverage: 2300,
            netMovement: 100,
          ),
          ReportGreenProjectionPoint(
            month: DateTime(2026, 10, 1),
            projectedBalance: 450,
            remainingDebt: 1600,
            requiredCoverage: 2100,
            netMovement: 150,
          ),
        ],
      );

      expect(report.estimatedGreenMonth, isNull);
      expect(report.monthsToGreen, isNull);
    });

  });
}
