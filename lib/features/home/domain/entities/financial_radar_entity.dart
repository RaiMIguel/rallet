import 'package:rallet/features/credit_card/domain/entities/credit_card_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';

enum FinancialRadarEventType {
  income,
  expense,
  creditCardBill,
  plannedCashAdvanceIncome,
  plannedCashAdvanceCharge,
  plannedPurchase,
  cardLimitCommitment,
}

class FinancialRadarBillOrigin {
  final CreditCardBillEntity bill;
  final CreditCardEntity? creditCard;

  const FinancialRadarBillOrigin({required this.bill, required this.creditCard});
}

class FinancialRadarEventEntity {
  final String id;
  final String description;
  final DateTime date;
  final double amount;
  final FinancialRadarEventType type;

  /// Objeto que originou o evento. É somente uma referência de navegação; o
  /// Radar nunca cria uma segunda movimentação para representar a mesma coisa.
  final Object? origin;

  /// Aviso específico daquele ponto da linha do tempo.
  final String? warningMessage;
  final String? warningDetails;

  /// Alguns itens existem apenas para explicar uma restrição de limite na
  /// linha do tempo. Eles mostram o compromisso, mas não alteram o caixa.
  final bool affectsCashFlow;

  const FinancialRadarEventEntity({
    required this.id,
    required this.description,
    required this.date,
    required this.amount,
    required this.type,
    this.origin,
    this.warningMessage,
    this.warningDetails,
    this.affectsCashFlow = true,
  });

  bool get isIncome =>
      type == FinancialRadarEventType.income ||
      type == FinancialRadarEventType.plannedCashAdvanceIncome;

  bool get isCharge => affectsCashFlow && !isIncome;
  double get cashFlowAmount => affectsCashFlow ? amount : 0;

  bool get isPlanned =>
      type == FinancialRadarEventType.plannedCashAdvanceIncome ||
      type == FinancialRadarEventType.plannedCashAdvanceCharge ||
      type == FinancialRadarEventType.plannedPurchase ||
      type == FinancialRadarEventType.cardLimitCommitment;

  bool get isPending => !isPlanned;
  bool get hasWarning => warningMessage != null;

  FinancialRadarEventEntity copyWith({
    String? warningMessage,
    String? warningDetails,
  }) =>
      FinancialRadarEventEntity(
        id: id,
        description: description,
        date: date,
        amount: amount,
        type: type,
        origin: origin,
        warningMessage: warningMessage ?? this.warningMessage,
        warningDetails: warningDetails ?? this.warningDetails,
        affectsCashFlow: affectsCashFlow,
      );
}

class FinancialAlertEntity {
  final DateTime periodStart;
  final DateTime riskStartDate;
  final DateTime worstDate;
  final DateTime? recoveryDate;
  final double shortage;
  final double lowestBalance;
  final List<FinancialRadarEventEntity> events;

  const FinancialAlertEntity({
    required this.periodStart,
    required this.riskStartDate,
    required this.worstDate,
    required this.recoveryDate,
    required this.shortage,
    required this.lowestBalance,
    required this.events,
  });

  int get chargesCount => events.where((event) => event.isCharge).length;

  double get chargesAmount => events
      .where((event) => event.isCharge)
      .fold(0.0, (total, event) => total + event.amount.abs());

  double get incomesAmount => events
      .where((event) => event.isIncome)
      .fold(0.0, (total, event) => total + event.amount);
}

enum CreditCardSafetyAlertLevel {
  attention,
  critical,
  exceeded,
}

class CreditCardSafetyAlertEntity {
  final String idCreditCard;
  final String cardDescription;
  final double amountLimit;
  final double safetyLimit;
  final double utilized;
  final double plannedAmount;
  final CreditCardSafetyAlertLevel level;

  /// Data em que o maior uso projetado ou a falta de limite acontece.
  final DateTime? riskDate;

  /// Capacidade disponível imediatamente antes do evento que não coube.
  final double? availableBeforeRisk;

  /// Limite exigido pelo evento que não coube.
  final double? requiredAmountAtRisk;

  /// Descrição do planejamento responsável pelo risco de limite.
  final String? riskDescription;

  /// Verdadeiro quando o limite contratual do banco é insuficiente.
  final bool bankLimitExceeded;

  const CreditCardSafetyAlertEntity({
    required this.idCreditCard,
    required this.cardDescription,
    required this.amountLimit,
    required this.safetyLimit,
    required this.utilized,
    required this.plannedAmount,
    required this.level,
    this.riskDate,
    this.availableBeforeRisk,
    this.requiredAmountAtRisk,
    this.riskDescription,
    this.bankLimitExceeded = false,
  });

  double get projectedUtilized => utilized + plannedAmount;
  double get safetyRatio => safetyLimit <= 0 ? 0 : projectedUtilized / safetyLimit;
  double get availableReal => amountLimit - utilized;
  double get availableAfterPlans => amountLimit - projectedUtilized;
  double get amountOverSafety =>
      (projectedUtilized - safetyLimit).clamp(0, double.infinity).toDouble();
  double get bankShortage => ((requiredAmountAtRisk ?? 0) -
          (availableBeforeRisk ?? 0))
      .clamp(0, double.infinity)
      .toDouble();
}

class FinancialRadarEntity {
  final DateTime generatedAt;
  final DateTime horizonEnd;
  final double currentBalance;
  final double minimumProjectedBalance;
  final DateTime minimumBalanceDate;
  final List<FinancialAlertEntity> alerts;
  final List<CreditCardSafetyAlertEntity> cardLimitAlerts;
  final List<FinancialRadarEventEntity> events;
  final List<PlannedPurchaseEntity> plannedPurchases;

  const FinancialRadarEntity({
    required this.generatedAt,
    required this.horizonEnd,
    required this.currentBalance,
    required this.minimumProjectedBalance,
    required this.minimumBalanceDate,
    required this.alerts,
    required this.cardLimitAlerts,
    required this.events,
    this.plannedPurchases = const [],
  });

  int get totalAlerts => alerts.length + cardLimitAlerts.length;
  bool get hasAlerts => totalAlerts > 0;
  bool get hasCashFlowAlerts => alerts.isNotEmpty;
  List<CreditCardSafetyAlertEntity> get blockingCardLimitAlerts =>
      cardLimitAlerts.where((alert) => alert.bankLimitExceeded).toList();
  List<CreditCardSafetyAlertEntity> get safetyOnlyCardAlerts =>
      cardLimitAlerts.where((alert) => !alert.bankLimitExceeded).toList();
  bool get hasBlockingCardLimitAlert => blockingCardLimitAlerts.isNotEmpty;
  bool get hasBlockingAlerts => hasCashFlowAlerts || hasBlockingCardLimitAlert;

  DateTime? get firstRiskDate {
    final List<DateTime> dates = [
      ...alerts.map((alert) => alert.riskStartDate),
      ...blockingCardLimitAlerts
          .map((alert) => alert.riskDate)
          .whereType<DateTime>(),
    ]..sort();
    return dates.isEmpty ? null : dates.first;
  }
}
