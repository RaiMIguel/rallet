import 'package:collection/collection.dart';
import 'package:rallet/features/account/domain/entities/account_entity.dart';
import 'package:rallet/features/account/domain/use_cases/i_account_find.dart';
import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/card_cash_advance/domain/enums/card_cash_advance_status_enum.dart';
import 'package:rallet/features/card_cash_advance/domain/use_cases/i_card_cash_advance.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_bill_dates.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_find.dart';
import 'package:rallet/shared/presentation/commands/command.dart';
import 'package:flutter/foundation.dart';

class CardCashAdvanceFormViewModel extends ChangeNotifier {
  final ICardCashAdvance _cashAdvance;
  final IAccountFind _accountFind;
  final ICreditCardFind _creditCardFind;
  final ICreditCardBillDates _billDates;

  late final Command1<CardCashAdvancePlanEntity, CardCashAdvancePlanEntity> save;
  late final Command1<CardCashAdvancePlanEntity, CardCashAdvancePlanEntity> realize;
  late final Command1<void, CardCashAdvancePlanEntity> cancel;

  CardCashAdvanceFormViewModel({
    required ICardCashAdvance cashAdvance,
    required IAccountFind accountFind,
    required ICreditCardFind creditCardFind,
    required ICreditCardBillDates billDates,
  })  : _cashAdvance = cashAdvance,
        _accountFind = accountFind,
        _creditCardFind = creditCardFind,
        _billDates = billDates {
    save = Command1(_cashAdvance.savePlan);
    realize = Command1(_cashAdvance.realize);
    cancel = Command1(_cashAdvance.cancel);
  }

  List<AccountEntity> accounts = [];
  List<CreditCardEntity> creditCards = [];
  List<CardCashAdvancePlanEntity> plannedOperations = [];

  late CardCashAdvancePlanEntity plan;

  bool get isLoading => save.running || realize.running || cancel.running;

  Future<void> load({
    CardCashAdvancePlanEntity? existing,
    double? suggestedAmount,
    String? preferredCreditCardId,
    String? preferredAccountId,
  }) async {
    final values = await Future.wait<dynamic>([
      _accountFind.findAll(),
      _creditCardFind.findAll(),
      _cashAdvance.findPlanned(),
    ]);
    accounts = (values[0] as List).cast<AccountEntity>();
    creditCards = (values[1] as List).cast<CreditCardEntity>();
    plannedOperations = (values[2] as List).cast<CardCashAdvancePlanEntity>();

    plan = existing?.clone() ??
        CardCashAdvancePlanEntity(
          id: null,
          createdAt: null,
          deletedAt: null,
          description: 'Crédito via cartão',
          idAccount: '',
          idCreditCard: '',
          amountReceived: suggestedAmount ?? 0,
          amountCharged: suggestedAmount ?? 0,
          plannedDate: DateTime.now(),
          billDueDate: DateTime.now(),
          status: CardCashAdvanceStatusEnum.planned,
          realizedAt: null,
          idStatement: null,
          idCreditCardTransaction: null,
        );

    if (plan.idAccount.isEmpty && preferredAccountId != null &&
        accounts.any((account) => account.id == preferredAccountId)) {
      plan.idAccount = preferredAccountId;
    }
    if (plan.idAccount.isEmpty && accounts.isNotEmpty) {
      final included =
          accounts.where((account) => account.includeTotalBalance).toList();
      if (included.isNotEmpty) plan.idAccount = included.first.id;
    }

    if (plan.idCreditCard.isEmpty && preferredCreditCardId != null &&
        creditCards.any((card) => card.id == preferredCreditCardId)) {
      plan.idCreditCard = preferredCreditCardId;
    }
    if (plan.idCreditCard.isEmpty && creditCards.isNotEmpty) {
      plan.idCreditCard = creditCards.first.id;
    }
    recalculateBillDueDate();
    notifyListeners();
  }

  AccountEntity? get selectedAccount => accounts.where((item) => item.id == plan.idAccount).firstOrNull;
  CreditCardEntity? get selectedCreditCard => creditCards.where((item) => item.id == plan.idCreditCard).firstOrNull;

  double get otherPlansAmountForSelectedCard {
    final card = selectedCreditCard;
    if (card == null) return 0;

    return plannedOperations
        .where(
          (item) =>
              item.idCreditCard == card.id &&
              item.id != plan.id &&
              item.isPlanned,
        )
        .fold(0.0, (total, item) => total + item.amountCharged);
  }

  double get plannedCardAvailable {
    final card = selectedCreditCard;
    if (card == null) return 0;
    return card.amountLimit -
        card.amountLimitUtilized -
        otherPlansAmountForSelectedCard -
        plan.amountCharged;
  }

  double get projectedCardUtilized {
    final card = selectedCreditCard;
    if (card == null) return 0;
    return card.amountLimitUtilized +
        otherPlansAmountForSelectedCard +
        plan.amountCharged;
  }

  void setAccount(String id) {
    plan.idAccount = id;
    notifyListeners();
  }

  void setCreditCard(String id) {
    plan.idCreditCard = id;
    recalculateBillDueDate();
    notifyListeners();
  }

  void setPlannedDate(DateTime date) {
    plan.plannedDate = date;
    recalculateBillDueDate();
    notifyListeners();
  }

  void setAmounts({double? received, double? charged}) {
    if (received != null) plan.amountReceived = received;
    if (charged != null) plan.amountCharged = charged;
    notifyListeners();
  }

  void recalculateBillDueDate() {
    final card = selectedCreditCard;
    if (card == null) return;
    final dates = _billDates.generateDates(
      closingDay: card.billClosingDay,
      dueDay: card.billDueDay,
      baseDate: plan.plannedDate,
    );
    plan.billDueDate = dates.dueDate;
  }
}
