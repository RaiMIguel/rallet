import 'package:rallet/features/account/domain/entities/account_entity.dart';
import 'package:rallet/features/account/domain/use_cases/i_account_find.dart';
import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/card_cash_advance/domain/use_cases/i_card_cash_advance.dart';
import 'package:rallet/features/config/domain/use_cases/i_config_find.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/features/credit_card/domain/services/credit_card_limit_projection.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_bill_dates.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_find.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_transaction_save.dart';
import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';
import 'package:rallet/features/purchase_planning/domain/entities/purchase_simulation_entity.dart';
import 'package:rallet/features/purchase_planning/domain/repositories/i_purchase_planning_repository.dart';
import 'package:rallet/features/purchase_planning/domain/use_cases/i_purchase_planning.dart';
import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/entities/i_transaction_entity.dart';
import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_transaction_find.dart';
import 'package:rallet/shared/classes/constants.dart';
import 'package:rallet/shared/exceptions/exceptions.dart';
import 'package:rallet/shared/extensions/date_time_extension.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/presentation/notifiers/event_notifier.dart';

class PurchasePlanning implements IPurchasePlanning {
  final IPurchasePlanningRepository _repository;
  final IAccountFind _accountFind;
  final ITransactionFind _transactionFind;
  final ICreditCardFind _creditCardFind;
  final ICreditCardBillDates _billDates;
  final ICreditCardTransactionSave _creditCardTransactionSave;
  final ICardCashAdvance _cashAdvance;
  final IConfigFind _configFind;
  final EventNotifier _eventNotifier;

  PurchasePlanning({
    required IPurchasePlanningRepository repository,
    required IAccountFind accountFind,
    required ITransactionFind transactionFind,
    required ICreditCardFind creditCardFind,
    required ICreditCardBillDates billDates,
    required ICreditCardTransactionSave creditCardTransactionSave,
    required ICardCashAdvance cashAdvance,
    required IConfigFind configFind,
    required EventNotifier eventNotifier,
  })  : _repository = repository,
        _accountFind = accountFind,
        _transactionFind = transactionFind,
        _creditCardFind = creditCardFind,
        _billDates = billDates,
        _creditCardTransactionSave = creditCardTransactionSave,
        _cashAdvance = cashAdvance,
        _configFind = configFind,
        _eventNotifier = eventNotifier;

  @override
  Future<PlannedPurchaseEntity> save(PlannedPurchaseEntity entity) async {
    entity.description = entity.description.trim();
    entity.normalizeMoney();
    if (entity.description.isEmpty) {
      throw ValidationException('Informe a despesa que você pretende planejar.');
    }
    if (entity.amount <= 0) {
      throw ValidationException('O valor da despesa deve ser maior que zero.');
    }

    final DateTime today = _day(DateTime.now());
    entity.plannedDate = _day(entity.plannedDate);
    if (entity.plannedDate.isBefore(today)) {
      throw ValidationException('A data planejada não pode estar no passado.');
    }

    if (entity.idCategory == null) {
      throw ValidationException('Selecione a categoria da despesa planejada.');
    }
    if (!entity.isCreditCard && entity.idAccount == null) {
      throw ValidationException('Selecione a conta que pagará a despesa.');
    }

    if (entity.isCreditCard) {
      if (entity.idCreditCard == null) {
        throw ValidationException('Selecione o cartão da despesa.');
      }
      if (entity.totalCharged <= 0) {
        throw ValidationException('Informe o total que será cobrado no cartão.');
      }
      if (entity.paymentType == PlannedPurchasePaymentType.creditCardSingle) {
        entity.installmentCount = 1;
      } else if (entity.installmentCount < 2 || entity.installmentCount > 24) {
        throw ValidationException('Escolha entre 2 e 24 parcelas.');
      }

      final CreditCardEntity? card = await _creditCardFind.findById(entity.idCreditCard!);
      if (card == null) throw ValidationException('Cartão não encontrado.');
      if (entity.totalCharged > card.amountLimit) {
        throw ValidationException(
          'O total da despesa é maior que o limite total deste cartão.',
        );
      }
      entity.firstBillDueDate = _billDates
          .generateDates(
            closingDay: card.billClosingDay,
            dueDay: card.billDueDay,
            baseDate: entity.plannedDate,
          )
          .dueDate;
    }

    final saved = await _repository.save(entity);
    _eventNotifier.notify(EventType.purchasePlan);
    return saved;
  }

  @override
  Future<void> delete(PlannedPurchaseEntity entity) async {
    await _repository.delete(entity);
    _eventNotifier.notify(EventType.purchasePlan);
  }

  @override
  Future<List<PlannedPurchaseEntity>> findAll() => _repository.findAll();

  @override
  Future<void> realizeCreditCardPurchase(PlannedPurchaseEntity entity) async {
    if (!entity.isCreditCard || entity.idCreditCard == null) {
      throw ValidationException('Este planejamento não é uma despesa no cartão.');
    }
    if (entity.isNew) entity = await save(entity);

    await _creditCardTransactionSave.save(
      CreditCardTransactionEntity(
        id: null,
        createdAt: null,
        deletedAt: null,
        description: entity.description,
        amount: entity.totalCharged,
        date: DateTime.now(),
        idCategory: entity.idCategory ?? categoryOthersUuidExpense,
        idCreditCard: entity.idCreditCard!,
        idCreditCardBill: null,
        observation: [
          if (entity.observation != null && entity.observation!.trim().isNotEmpty)
            entity.observation!.trim(),
          if (entity.financialCost > 0)
            'Despesa originada de planejamento. Preço-base: ${entity.amount.toStringAsFixed(2)} | total parcelado: ${entity.totalCharged.toStringAsFixed(2)} | custo: ${entity.financialCost.toStringAsFixed(2)}'
          else
            'Despesa originada de planejamento do Rallet',
        ].join(' • '),
        installmentGroupId: null,
        installmentNumber: null,
        installmentCount: null,
        cashAdvancePlanId: null,
        cashAdvancePrincipal: null,
        plannedPurchaseId: entity.id,
        plannedPurchasePrincipal: entity.principalCharged,
      ),
      installmentCount: entity.installmentCount,
    );

    await _repository.delete(entity);
    _eventNotifier.notify(EventType.purchasePlan);
    _eventNotifier.notify(EventType.creditCard);
  }

  @override
  Future<PurchaseSimulationEntity> simulate({
    required double amount,
    required DateTime desiredDate,
    double reserveAmount = 0,
    PlannedPurchasePaymentType paymentType = PlannedPurchasePaymentType.cash,
    String? idCreditCard,
    String? idAccount,
    int installmentCount = 1,
    double? totalCharged,
    String? editingPlanId,
  }) async {
    amount = amount.abs().toRound(2);
    reserveAmount = reserveAmount.abs().toRound(2);
    final double chargedTotal = (totalCharged ?? amount).abs().toRound(2);
    if (amount <= 0) {
      throw ValidationException('Informe um valor maior que zero para simular.');
    }

    final bool isCreditCard = paymentType != PlannedPurchasePaymentType.cash;
    if (isCreditCard && idCreditCard == null) {
      throw ValidationException('Selecione o cartão para analisar a despesa.');
    }
    installmentCount = paymentType == PlannedPurchasePaymentType.creditCardInstallments
        ? installmentCount.clamp(2, 24).toInt()
        : 1;

    final DateTime now = DateTime.now();
    final DateTime today = _day(now);
    final int radarMonths = _configFind.findRadarMonths();
    final int extensionMonths = isCreditCard ? installmentCount : 0;
    final DateTime horizonEnd = DateTime(
      today.year,
      today.month + radarMonths + extensionMonths,
      0,
      23,
      59,
      59,
      999,
    );
    final DateTime recommendationEnd = DateTime(
      today.year,
      today.month + radarMonths,
      0,
      23,
      59,
      59,
      999,
    );

    desiredDate = _day(desiredDate);
    if (desiredDate.isBefore(today)) desiredDate = today;
    if (desiredDate.isAfter(recommendationEnd)) desiredDate = _day(recommendationEnd);

    final results = await Future.wait<dynamic>([
      _accountFind.findAccountsBalance(),
      _accountFind.findAll(deleted: true),
      _transactionFind.findUnpaidUnreceived(),
      _creditCardFind.findBillsByPeriod(DateTime(1970), horizonEnd),
      _creditCardFind.findAll(),
      _cashAdvance.findPlanned(),
      _repository.findAll(),
    ]);

    final double currentBalance = (results[0] as double).toRound(2);
    final List<AccountEntity> accounts = (results[1] as List).cast<AccountEntity>();
    final List<ITransactionEntity> pending = (results[2] as List).cast<ITransactionEntity>();
    final List<CreditCardBillEntity> bills = (results[3] as List).cast<CreditCardBillEntity>();
    final List<CreditCardEntity> cards = (results[4] as List).cast<CreditCardEntity>();
    final List<CardCashAdvancePlanEntity> cashPlans =
        (results[5] as List).cast<CardCashAdvancePlanEntity>();
    final List<PlannedPurchaseEntity> purchasePlans =
        (results[6] as List).cast<PlannedPurchaseEntity>();

    CreditCardEntity? selectedCard;
    if (isCreditCard) {
      for (final card in cards) {
        if (card.id == idCreditCard) {
          selectedCard = card;
          break;
        }
      }
      if (selectedCard == null) throw ValidationException('Cartão não encontrado.');
      if (chargedTotal > selectedCard.amountLimit) {
        throw ValidationException('O total da despesa é maior que o limite total do cartão.');
      }
    }

    final Set<String> includedAccounts = accounts
        .where((account) => account.includeTotalBalance)
        .map((account) => account.id)
        .toSet();

    // Mesma linha temporal de limite usada pelo Radar. Isso evita que a
    // simulação de uma nova despesa conte como caixa um crédito planejado que
    // não seria possível por falta de limite na data prevista.
    final CreditCardLimitProjectionResult baseLimitProjection =
        CreditCardLimitProjection.calculate(
      today: today,
      horizonEnd: horizonEnd,
      cards: cards,
      bills: bills,
      cashAdvancePlans: cashPlans,
      plannedPurchases: purchasePlans,
      excludePlannedPurchaseId: editingPlanId,
    );

    final Map<DateTime, double> baseEvents = {};
    void add(DateTime date, double value) {
      final DateTime projectedDate = _projectionDate(date, today);
      if (projectedDate.isAfter(horizonEnd)) return;
      baseEvents[projectedDate] = ((baseEvents[projectedDate] ?? 0) + value).toRound(2);
    }

    for (final transaction in pending) {
      if (transaction is IncomeEntity && !transaction.received) {
        if (transaction.idAccount != null && !includedAccounts.contains(transaction.idAccount)) continue;
        add(transaction.date, transaction.amount);
      } else if (transaction is ExpenseEntity && !transaction.paid && transaction.idCreditCard == null) {
        if (transaction.idAccount != null && !includedAccounts.contains(transaction.idAccount)) continue;
        add(transaction.date, -transaction.amount.abs());
      }
    }

    for (final bill in bills) {
      if (bill.billAmount > 0) add(bill.billDueDate, -bill.billAmount.abs());
    }

    for (final plan in cashPlans) {
      if (!baseLimitProjection.isCashAdvanceFeasible(plan.id)) continue;
      if (includedAccounts.contains(plan.idAccount)) {
        add(plan.plannedDate, plan.amountReceived);
      }
      add(plan.billDueDate, -plan.amountCharged.abs());
    }

    for (final plan in purchasePlans) {
      if (editingPlanId != null && plan.id == editingPlanId) continue;
      if (plan.isCreditCard) {
        if (!baseLimitProjection.isPlannedPurchaseFeasible(plan.id)) continue;
        for (final installment in plan.installmentSchedule) {
          add(installment.dueDate, -installment.amount);
        }
      } else {
        // Só afeta o saldo consolidado quando a conta escolhida participa dele.
        if (plan.idAccount == null || includedAccounts.contains(plan.idAccount)) {
          add(plan.plannedDate, -plan.amount.abs());
        }
      }
    }

    final Map<DateTime, double> baseBalanceAtEndOfDay = {};
    double baseRunning = currentBalance;
    DateTime cursor = today;
    while (!cursor.isAfter(horizonEnd)) {
      baseRunning = (baseRunning + (baseEvents[cursor] ?? 0)).toRound(2);
      baseBalanceAtEndOfDay[cursor] = baseRunning;
      cursor = cursor.add(const Duration(days: 1));
    }

    final CreditCardLimitCardProjection? selectedCardProjection =
        selectedCard == null ? null : baseLimitProjection.cardById(selectedCard.id);


    List<double> splitInstallments(double total, int count) {
      final int cents = (total * 100).round();
      final int base = cents ~/ count;
      int remainder = cents - (base * count);
      return List.generate(count, (_) {
        final value = base + (remainder > 0 ? 1 : 0);
        if (remainder > 0) remainder--;
        return value / 100.0;
      });
    }

    PurchaseSimulationOptionEntity evaluate(DateTime date) {
      date = _day(date);
      final Map<DateTime, double> candidateEvents = {};
      DateTime? firstDue;
      DateTime? lastDue;
      double? cardAvailableBefore;
      double? cardAvailableAfter;
      bool cardLimitSafe = true;
      DateTime? firstCardLimitRiskDate;
      double? cardLimitShortage;
      DateTime? firstCardSafetyRiskDate;
      double? cardSafetyAmountOver;

      if (selectedCard == null) {
        if (idAccount == null || includedAccounts.contains(idAccount)) {
          candidateEvents[date] = -amount;
        }
      } else {
        final due = _billDates.generateDates(
          closingDay: selectedCard.billClosingDay,
          dueDay: selectedCard.billDueDay,
          baseDate: date,
        ).dueDate;
        firstDue = due;
        final values = splitInstallments(chargedTotal, installmentCount);
        final Map<DateTime, double> candidateLimitReleases = {};
        for (int i = 0; i < values.length; i++) {
          final d = due.addMonths(i);
          final normalizedDue = _day(d);
          candidateEvents[normalizedDue] =
              ((candidateEvents[normalizedDue] ?? 0) - values[i]).toRound(2);
          candidateLimitReleases[normalizedDue] =
              ((candidateLimitReleases[normalizedDue] ?? 0) + values[i]).toRound(2);
          lastDue = d;
        }

        final bool hasSafetyLimit =
            selectedCard.safetyLimit != null && selectedCard.safetyLimit! > 0;
        final double safetyCeiling = !hasSafetyLimit
            ? selectedCard.amountLimit
            : selectedCard.safetyLimit!
                .clamp(0, selectedCard.amountLimit)
                .toDouble();

        double candidateOutstanding = 0;
        DateTime limitScan = today;
        while (!limitScan.isAfter(horizonEnd)) {
          // Pagamentos previstos da própria compra liberam o limite antes dos
          // novos compromissos do dia, seguindo a mesma ordem do Radar.
          candidateOutstanding = (candidateOutstanding -
                  (candidateLimitReleases[limitScan] ?? 0))
              .clamp(0, double.infinity)
              .toDouble()
              .toRound(2);

          final double baselineUtilized = selectedCardProjection
                  ?.utilizedByDate[limitScan] ??
              selectedCard.amountLimitUtilized;

          if (limitScan == date) {
            cardAvailableBefore =
                (selectedCard.amountLimit - baselineUtilized).toRound(2);
            candidateOutstanding =
                (candidateOutstanding + chargedTotal).toRound(2);
          }

          final double projectedUtilized =
              (baselineUtilized + candidateOutstanding).toRound(2);

          if (limitScan == date) {
            cardAvailableAfter =
                (selectedCard.amountLimit - projectedUtilized).toRound(2);
          }

          if (!limitScan.isBefore(date)) {
            if (projectedUtilized > selectedCard.amountLimit + 0.0001 &&
                firstCardLimitRiskDate == null) {
              firstCardLimitRiskDate = limitScan;
              cardLimitShortage =
                  (projectedUtilized - selectedCard.amountLimit).toRound(2);
            }
            if (hasSafetyLimit &&
                projectedUtilized > safetyCeiling + 0.0001 &&
                firstCardSafetyRiskDate == null) {
              firstCardSafetyRiskDate = limitScan;
              cardSafetyAmountOver =
                  (projectedUtilized - safetyCeiling).toRound(2);
            }
            if (projectedUtilized > selectedCard.amountLimit + 0.0001 ||
                projectedUtilized > safetyCeiling + 0.0001) {
              cardLimitSafe = false;
            }
          }
          limitScan = limitScan.add(const Duration(days: 1));
        }
      }

      double running = currentBalance;
      double balanceOnPurchaseDate = currentBalance;
      double minimum = double.infinity;
      DateTime minimumDate = date;
      DateTime? firstNegativeBalanceDate;
      double? balanceAtFirstNegativeDate;
      DateTime scan = today;
      while (!scan.isAfter(horizonEnd)) {
        running = (running + (baseEvents[scan] ?? 0) + (candidateEvents[scan] ?? 0)).toRound(2);
        if (scan == date) balanceOnPurchaseDate = running;
        if (!scan.isBefore(date) &&
            running < -0.0001 &&
            firstNegativeBalanceDate == null) {
          firstNegativeBalanceDate = scan;
          balanceAtFirstNegativeDate = running;
        }
        if (!scan.isBefore(date) && running < minimum) {
          minimum = running;
          minimumDate = scan;
        }
        scan = scan.add(const Duration(days: 1));
      }
      if (minimum == double.infinity) minimum = balanceOnPurchaseDate;

      final bool cashFlowSafe = minimum + 0.0001 >= reserveAmount;
      return PurchaseSimulationOptionEntity(
        date: date,
        balanceAfterPurchase: balanceOnPurchaseDate.toRound(2),
        minimumBalanceAfterPurchase: minimum.toRound(2),
        minimumBalanceDate: minimumDate,
        safe: cashFlowSafe && cardLimitSafe,
        firstBillDueDate: firstDue,
        lastBillDueDate: lastDue,
        cardAvailableBeforePurchase: cardAvailableBefore,
        cardAvailableAfterPurchase: cardAvailableAfter,
        cardLimitSafe: cardLimitSafe,
        firstNegativeBalanceDate: firstNegativeBalanceDate,
        balanceAtFirstNegativeDate: balanceAtFirstNegativeDate,
        firstCardLimitRiskDate: firstCardLimitRiskDate,
        cardLimitShortage: cardLimitShortage,
        firstCardSafetyRiskDate: firstCardSafetyRiskDate,
        cardSafetyAmountOver: cardSafetyAmountOver,
      );
    }

    final todayOption = evaluate(today);
    final desiredOption = evaluate(desiredDate);
    PurchaseSimulationOptionEntity? recommended;
    double highestSafeAmount = 0;
    DateTime? highestSafeAmountDate;
    final List<PurchaseSimulationOptionEntity> safeAlternatives = [];

    cursor = today;
    DateTime? lastAlternativeDate;
    while (!cursor.isAfter(recommendationEnd)) {
      final option = evaluate(cursor);
      recommended ??= option.safe ? option : null;

      if (!isCreditCard) {
        double minimumBase = double.infinity;
        DateTime scan = cursor;
        while (!scan.isAfter(horizonEnd)) {
          final double baseBalance = baseBalanceAtEndOfDay[scan] ?? currentBalance;
          if (baseBalance < minimumBase) minimumBase = baseBalance;
          scan = scan.add(const Duration(days: 1));
        }
        final double safeAmount =
            (minimumBase - reserveAmount).clamp(0, double.infinity).toDouble().toRound(2);
        if (safeAmount > highestSafeAmount) {
          highestSafeAmount = safeAmount;
          highestSafeAmountDate = cursor;
        }
      }

      if (safeAlternatives.length < 4 &&
          option.safe &&
          (lastAlternativeDate == null || cursor.difference(lastAlternativeDate).inDays >= 7)) {
        safeAlternatives.add(option);
        lastAlternativeDate = cursor;
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    final alternatives = [
      todayOption,
      desiredOption,
      if (recommended != null) recommended,
      ...safeAlternatives,
    ];
    final seen = <String>{};
    final uniqueAlternatives = alternatives.where((option) {
      final key = '${option.date.year}-${option.date.month}-${option.date.day}';
      return seen.add(key);
    }).take(5).toList();

    return PurchaseSimulationEntity(
      generatedAt: now,
      horizonEnd: horizonEnd,
      radarHorizonEnd: recommendationEnd,
      purchaseAmount: amount,
      totalCharged: chargedTotal,
      reserveAmount: reserveAmount,
      desiredDate: desiredDate,
      paymentType: paymentType,
      installmentCount: installmentCount,
      creditCardDescription: selectedCard?.description,
      desiredOption: desiredOption,
      todayOption: todayOption,
      recommendedOption: recommended,
      highestSafeAmount: highestSafeAmount,
      highestSafeAmountDate: highestSafeAmountDate,
      alternatives: uniqueAlternatives,
    );
  }

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime _projectionDate(DateTime date, DateTime today) {
    final normalized = _day(date);
    return normalized.isBefore(today) ? today : normalized;
  }
}
