import 'package:rallet/features/home/domain/entities/financial_radar_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compromisso de limite aparece no Radar sem mexer no caixa', () {
    final event = FinancialRadarEventEntity(
      id: 'plan-limit',
      description: 'Despesa planejada',
      date: DateTime(2026, 9, 15),
      amount: -570,
      type: FinancialRadarEventType.cardLimitCommitment,
      affectsCashFlow: false,
      warningMessage:
          'Limite insuficiente no cartão Nubank para esse compromisso nesse dia.',
    );

    expect(event.isPlanned, isTrue);
    expect(event.hasWarning, isTrue);
    expect(event.cashFlowAmount, 0);
    expect(event.isCharge, isFalse);
  });

  test('falta de limite contratual bloqueia Tudo sob controle', () {
    final alert = CreditCardSafetyAlertEntity(
      idCreditCard: 'card',
      cardDescription: 'Nubank',
      amountLimit: 1000,
      safetyLimit: 1000,
      utilized: 800,
      plannedAmount: 0,
      level: CreditCardSafetyAlertLevel.exceeded,
      riskDate: DateTime(2026, 9, 15),
      availableBeforeRisk: 200,
      requiredAmountAtRisk: 570,
      riskDescription: 'Crédito planejado',
      bankLimitExceeded: true,
    );

    final radar = FinancialRadarEntity(
      generatedAt: DateTime(2026, 9, 3),
      horizonEnd: DateTime(2027, 3, 3),
      currentBalance: 1000,
      minimumProjectedBalance: 500,
      minimumBalanceDate: DateTime(2026, 9, 3),
      alerts: const [],
      cardLimitAlerts: [alert],
      events: const [],
    );

    expect(radar.hasBlockingCardLimitAlert, isTrue);
    expect(radar.hasBlockingAlerts, isTrue);
    expect(radar.firstRiskDate, DateTime(2026, 9, 15));
  });
}
