import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';
import 'package:rallet/shared/extensions/double_extension.dart';

enum CreditCardLimitPlanType {
  cashAdvance,
  plannedPurchase,
}

class CreditCardLimitPlanResult {
  final String id;
  final CreditCardLimitPlanType type;
  final String idCreditCard;
  final String description;
  final DateTime date;
  final double requiredAmount;
  final double availableBefore;
  final bool feasible;

  const CreditCardLimitPlanResult({
    required this.id,
    required this.type,
    required this.idCreditCard,
    required this.description,
    required this.date,
    required this.requiredAmount,
    required this.availableBefore,
    required this.feasible,
  });

  double get shortage =>
      (requiredAmount - availableBefore).clamp(0, double.infinity).toDouble().toRound(2);
}

class CreditCardLimitCardProjection {
  final String idCreditCard;
  final String cardDescription;
  final double amountLimit;
  final double? safetyLimit;
  final double currentUtilized;
  final double maximumProjectedUtilized;
  final DateTime maximumUtilizedDate;
  final Map<DateTime, double> utilizedByDate;
  final List<CreditCardLimitPlanResult> planResults;

  const CreditCardLimitCardProjection({
    required this.idCreditCard,
    required this.cardDescription,
    required this.amountLimit,
    required this.safetyLimit,
    required this.currentUtilized,
    required this.maximumProjectedUtilized,
    required this.maximumUtilizedDate,
    required this.utilizedByDate,
    required this.planResults,
  });

  double get minimumAvailable =>
      (amountLimit - maximumProjectedUtilized).toRound(2);

  double get effectiveSafetyLimit {
    final double? configured = safetyLimit;
    if (configured == null || configured <= 0) return amountLimit;
    return configured.clamp(0, amountLimit).toDouble();
  }

  double get maximumSafetyRatio => effectiveSafetyLimit <= 0
      ? 0
      : maximumProjectedUtilized / effectiveSafetyLimit;

  List<CreditCardLimitPlanResult> get infeasiblePlans =>
      planResults.where((plan) => !plan.feasible).toList();

  double utilizedOn(DateTime date) =>
      utilizedByDate[_day(date)] ?? maximumProjectedUtilized;

  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class CreditCardLimitProjectionResult {
  final List<CreditCardLimitCardProjection> cards;
  final Map<String, CreditCardLimitPlanResult> cashAdvancePlans;
  final Map<String, CreditCardLimitPlanResult> plannedPurchases;

  const CreditCardLimitProjectionResult({
    required this.cards,
    required this.cashAdvancePlans,
    required this.plannedPurchases,
  });

  bool isCashAdvanceFeasible(String id) =>
      cashAdvancePlans[id]?.feasible ?? true;

  bool isPlannedPurchaseFeasible(String id) =>
      plannedPurchases[id]?.feasible ?? true;

  CreditCardLimitCardProjection? cardById(String id) {
    for (final card in cards) {
      if (card.idCreditCard == id) return card;
    }
    return null;
  }
}

class CreditCardLimitProjection {
  static CreditCardLimitProjectionResult calculate({
    required DateTime today,
    required DateTime horizonEnd,
    required List<CreditCardEntity> cards,
    required List<CreditCardBillEntity> bills,
    required List<CardCashAdvancePlanEntity> cashAdvancePlans,
    required List<PlannedPurchaseEntity> plannedPurchases,
    String? excludePlannedPurchaseId,
  }) {
    final DateTime start = _day(today);
    final DateTime end = _day(horizonEnd);
    final List<CreditCardLimitCardProjection> cardResults = [];
    final Map<String, CreditCardLimitPlanResult> cashResults = {};
    final Map<String, CreditCardLimitPlanResult> purchaseResults = {};

    DateTime projectionDate(DateTime date) {
      final DateTime normalized = _day(date);
      return normalized.isBefore(start) ? start : normalized;
    }

    for (final CreditCardEntity card in cards) {
      final Map<DateTime, double> releases = {};
      void addRelease(DateTime date, double amount) {
        final DateTime d = projectionDate(date);
        if (d.isAfter(end) || amount <= 0) return;
        releases[d] = ((releases[d] ?? 0) + amount.abs()).toRound(2);
      }

      // Dívida real já existente libera limite quando a respectiva fatura é
      // projetada como paga. A mesma data é usada pelo Radar para a saída de caixa.
      for (final CreditCardBillEntity bill in bills) {
        if (bill.idCreditCard != card.id || bill.billAmount <= 0) continue;
        addRelease(bill.billDueDate, bill.billAmount);
      }

      final List<_PlanCommitment> commitments = [];

      for (final CardCashAdvancePlanEntity plan in cashAdvancePlans) {
        if (plan.idCreditCard != card.id) continue;
        final DateTime date = projectionDate(plan.plannedDate);
        if (date.isAfter(end)) continue;
        commitments.add(
          _PlanCommitment(
            id: plan.id,
            type: CreditCardLimitPlanType.cashAdvance,
            description: plan.description.trim().isEmpty
                ? 'Crédito planejado'
                : plan.description.trim(),
            date: date,
            amount: plan.amountCharged.abs().toRound(2),
            releases: [
              _Release(
                date: projectionDate(plan.billDueDate),
                amount: plan.amountCharged.abs().toRound(2),
              ),
            ],
            createdAt: plan.createdAt,
          ),
        );
      }

      for (final PlannedPurchaseEntity purchase in plannedPurchases) {
        if (purchase.id == excludePlannedPurchaseId ||
            !purchase.isCreditCard ||
            purchase.idCreditCard != card.id) {
          continue;
        }
        final DateTime date = projectionDate(purchase.plannedDate);
        if (date.isAfter(end)) continue;
        commitments.add(
          _PlanCommitment(
            id: purchase.id,
            type: CreditCardLimitPlanType.plannedPurchase,
            description: purchase.description,
            date: date,
            amount: purchase.totalCharged.abs().toRound(2),
            releases: purchase.installmentSchedule
                .map(
                  (installment) => _Release(
                    date: projectionDate(installment.dueDate),
                    amount: installment.amount.abs().toRound(2),
                  ),
                )
                .toList(),
            createdAt: purchase.createdAt,
          ),
        );
      }

      commitments.sort((a, b) {
        final int byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        final DateTime aCreated = a.createdAt ?? DateTime(1970);
        final DateTime bCreated = b.createdAt ?? DateTime(1970);
        final int byCreated = aCreated.compareTo(bCreated);
        if (byCreated != 0) return byCreated;
        return a.id.compareTo(b.id);
      });

      final Map<DateTime, List<_PlanCommitment>> commitmentsByDay = {};
      for (final commitment in commitments) {
        commitmentsByDay.putIfAbsent(commitment.date, () => []).add(commitment);
      }

      double utilized = card.amountLimitUtilized
          .clamp(0, double.infinity)
          .toDouble()
          .toRound(2);
      double maximumUtilized = utilized;
      DateTime maximumDate = start;
      final Map<DateTime, double> utilizedByDate = {};
      final List<CreditCardLimitPlanResult> planResults = [];

      DateTime cursor = start;
      while (!cursor.isAfter(end)) {
        final double release = releases[cursor] ?? 0;
        if (release > 0) {
          utilized = (utilized - release)
              .clamp(0, double.infinity)
              .toDouble()
              .toRound(2);
        }

        for (final _PlanCommitment commitment
            in commitmentsByDay[cursor] ?? const <_PlanCommitment>[]) {
          final double availableBefore =
              (card.amountLimit - utilized).toRound(2);
          final bool feasible =
              commitment.amount <= availableBefore + 0.0001;

          final result = CreditCardLimitPlanResult(
            id: commitment.id,
            type: commitment.type,
            idCreditCard: card.id,
            description: commitment.description,
            date: cursor,
            requiredAmount: commitment.amount,
            availableBefore: availableBefore,
            feasible: feasible,
          );
          planResults.add(result);
          if (commitment.type == CreditCardLimitPlanType.cashAdvance) {
            cashResults[commitment.id] = result;
          } else {
            purchaseResults[commitment.id] = result;
          }

          // Mesmo quando não cabe no limite atual, mantemos o compromisso na
          // projeção. O Radar é um cenário do que o usuário pretende fazer: ele
          // deve avisar a falta de limite, não apagar o planejamento. Assim,
          // planos seguintes também enxergam o impacto acumulado desse cenário.
          utilized = (utilized + commitment.amount).toRound(2);
          for (final _Release item in commitment.releases) {
            if (item.date.isBefore(cursor) || item.date.isAfter(end)) continue;
            releases[item.date] =
                ((releases[item.date] ?? 0) + item.amount).toRound(2);
          }
        }

        if (utilized > maximumUtilized) {
          maximumUtilized = utilized;
          maximumDate = cursor;
        }

        utilizedByDate[cursor] = utilized;
        cursor = cursor.add(const Duration(days: 1));
      }

      cardResults.add(
        CreditCardLimitCardProjection(
          idCreditCard: card.id,
          cardDescription: card.description,
          amountLimit: card.amountLimit.toRound(2),
          safetyLimit: card.safetyLimit?.toRound(2),
          currentUtilized: card.amountLimitUtilized.toRound(2),
          maximumProjectedUtilized: maximumUtilized.toRound(2),
          maximumUtilizedDate: maximumDate,
          utilizedByDate: utilizedByDate,
          planResults: planResults,
        ),
      );
    }

    return CreditCardLimitProjectionResult(
      cards: cardResults,
      cashAdvancePlans: cashResults,
      plannedPurchases: purchaseResults,
    );
  }

  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class _PlanCommitment {
  final String id;
  final CreditCardLimitPlanType type;
  final String description;
  final DateTime date;
  final double amount;
  final List<_Release> releases;
  final DateTime? createdAt;

  const _PlanCommitment({
    required this.id,
    required this.type,
    required this.description,
    required this.date,
    required this.amount,
    required this.releases,
    required this.createdAt,
  });
}

class _Release {
  final DateTime date;
  final double amount;

  const _Release({required this.date, required this.amount});
}
