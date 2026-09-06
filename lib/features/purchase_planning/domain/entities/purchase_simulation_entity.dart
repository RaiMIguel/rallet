import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';
import 'package:rallet/shared/extensions/double_extension.dart';

class PurchaseSimulationOptionEntity {
  final DateTime date;
  final double balanceAfterPurchase;
  final double minimumBalanceAfterPurchase;
  final DateTime minimumBalanceDate;
  final bool safe;
  final DateTime? firstBillDueDate;
  final DateTime? lastBillDueDate;
  final double? cardAvailableBeforePurchase;
  final double? cardAvailableAfterPurchase;
  final bool cardLimitSafe;

  /// Primeiro dia em que o saldo projetado fica negativo. Quando preenchido,
  /// este cenário tende a gerar o mesmo alerta de saldo insuficiente do Radar.
  final DateTime? firstNegativeBalanceDate;
  final double? balanceAtFirstNegativeDate;

  /// Primeiro dia em que a compra ultrapassa o limite contratual do cartão.
  /// Este é o risco que gera o alerta principal de limite no Radar.
  final DateTime? firstCardLimitRiskDate;
  final double? cardLimitShortage;

  /// Primeiro dia em que apenas o limite de segurança pessoal é ultrapassado.
  /// Pode existir mesmo sem falta de limite contratual.
  final DateTime? firstCardSafetyRiskDate;
  final double? cardSafetyAmountOver;

  const PurchaseSimulationOptionEntity({
    required this.date,
    required this.balanceAfterPurchase,
    required this.minimumBalanceAfterPurchase,
    required this.minimumBalanceDate,
    required this.safe,
    this.firstBillDueDate,
    this.lastBillDueDate,
    this.cardAvailableBeforePurchase,
    this.cardAvailableAfterPurchase,
    this.cardLimitSafe = true,
    this.firstNegativeBalanceDate,
    this.balanceAtFirstNegativeDate,
    this.firstCardLimitRiskDate,
    this.cardLimitShortage,
    this.firstCardSafetyRiskDate,
    this.cardSafetyAmountOver,
  });

  bool get generatesRadarAlert =>
      firstNegativeBalanceDate != null || firstCardLimitRiskDate != null;

  bool get hasCardSafetyWarning => firstCardSafetyRiskDate != null;
}

class PurchaseSimulationEntity {
  final DateTime generatedAt;
  final DateTime horizonEnd;

  /// Fim do período atualmente configurado no Radar. A simulação pode ir além
  /// para enxergar todas as parcelas, mas um risco posterior a esta data ainda
  /// não aparecerá na tela do Radar até o horizonte ser ampliado.
  final DateTime radarHorizonEnd;
  final double purchaseAmount;
  final double totalCharged;
  final double reserveAmount;
  final DateTime desiredDate;
  final PlannedPurchasePaymentType paymentType;
  final int installmentCount;
  final String? creditCardDescription;
  final PurchaseSimulationOptionEntity desiredOption;
  final PurchaseSimulationOptionEntity todayOption;
  final PurchaseSimulationOptionEntity? recommendedOption;
  final double highestSafeAmount;
  final DateTime? highestSafeAmountDate;
  final List<PurchaseSimulationOptionEntity> alternatives;

  const PurchaseSimulationEntity({
    required this.generatedAt,
    required this.horizonEnd,
    required this.radarHorizonEnd,
    required this.purchaseAmount,
    required this.totalCharged,
    required this.reserveAmount,
    required this.desiredDate,
    required this.paymentType,
    required this.installmentCount,
    required this.creditCardDescription,
    required this.desiredOption,
    required this.todayOption,
    required this.recommendedOption,
    required this.highestSafeAmount,
    required this.highestSafeAmountDate,
    required this.alternatives,
  });

  bool get isCreditCard => paymentType != PlannedPurchasePaymentType.cash;
  bool get isInstallment => paymentType == PlannedPurchasePaymentType.creditCardInstallments;
  double get financialCost =>
      (totalCharged - purchaseAmount).clamp(0, double.infinity).toDouble().toRound(2);
  bool get canBuyToday => todayOption.safe;
  bool get desiredDateIsSafe => desiredOption.safe;
  bool get hasSafeDate => recommendedOption != null;
  bool riskDateIsInsideRadar(DateTime? date) =>
      date != null && !date.isAfter(radarHorizonEnd);

  bool get desiredGeneratesRadarAlert =>
      riskDateIsInsideRadar(desiredOption.firstNegativeBalanceDate) ||
      riskDateIsInsideRadar(desiredOption.firstCardLimitRiskDate);

  bool get desiredGeneratesRadarSafetyWarning =>
      riskDateIsInsideRadar(desiredOption.firstCardSafetyRiskDate);

  bool get recommendationDiffersFromDesired =>
      recommendedOption != null &&
      (recommendedOption!.date.year != desiredDate.year ||
          recommendedOption!.date.month != desiredDate.month ||
          recommendedOption!.date.day != desiredDate.day);

  double get desiredShortage =>
      (reserveAmount - desiredOption.minimumBalanceAfterPurchase)
          .clamp(0, double.infinity)
          .toDouble()
          .toRound(2);
}
