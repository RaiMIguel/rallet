import 'package:collection/collection.dart';
import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/card_cash_advance/domain/use_cases/i_card_cash_advance.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_bill_find.dart' show ICreditCardBillFind;
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_find.dart';
import 'package:rallet/shared/extensions/date_time_extension.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/presentation/commands/command.dart';
import 'package:flutter/foundation.dart';

typedef BillsFindParams = ({DateTime date, String? idCreditCard});

class CreditCardsDetailsViewModel extends ChangeNotifier {
  final ICreditCardFind _creditCardFind;
  final ICreditCardBillFind _creditCardBillFind;
  final ICardCashAdvance _cashAdvance;

  late final Command1<void, String?> load;
  late final Command1<List<CreditCardBillEntity>, BillsFindParams> billsFind;

  CreditCardsDetailsViewModel({
    required ICreditCardFind creditCardFind,
    required ICreditCardBillFind creditCardBillFind,
    required ICardCashAdvance cashAdvance,
  })  : _creditCardFind = creditCardFind,
        _creditCardBillFind = creditCardBillFind,
        _cashAdvance = cashAdvance {
    load = Command1(_load);
    billsFind = Command1(_billsFind);
  }

  CreditCardEntity? _creditCardSelected;
  CreditCardEntity? get creditCardSelected => _creditCardSelected;

  List<CardCashAdvancePlanEntity> _plannedOperations = [];
  List<CardCashAdvancePlanEntity> get plannedOperations => _plannedOperations;

  double get plannedAmountForSelectedCard {
    final card = _creditCardSelected;
    if (card == null) return 0;

    return _plannedOperations
        .where((plan) => plan.idCreditCard == card.id)
        .fold(0.0, (total, plan) => total + plan.amountCharged)
        .toRound(2);
  }

  double get projectedUtilized =>
      ((_creditCardSelected?.amountLimitUtilized ?? 0) +
              plannedAmountForSelectedCard)
          .toRound(2);

  void setCreditCardSelected(CreditCardEntity? value) {
    _creditCardSelected = value;

    if (_creditCardSelected == null) {
      billsFind.clearResult();
    } else {
      billsFind.execute((
        date: DateTime.now().getInitialMonth().subtractMonths(1),
        idCreditCard: _creditCardSelected!.id,
      ));
    }

    notifyListeners();
  }

  List<CreditCardEntity> _creditCards = [];
  List<CreditCardEntity> get creditCards => _creditCards;

  void setCreditCards(List<CreditCardEntity> value) {
    _creditCards = value;
    notifyListeners();
  }

  Future<void> _load(String? idCreditCard) async {
    final values = await Future.wait<dynamic>([
      _creditCardFind.findAll(),
      _cashAdvance.findPlanned(),
    ]);

    _creditCards = (values[0] as List).cast<CreditCardEntity>();
    _plannedOperations =
        (values[1] as List).cast<CardCashAdvancePlanEntity>();

    setCreditCardSelected(
      _creditCards.firstWhereOrNull(
            (creditCard) => creditCard.id == idCreditCard,
          ) ??
          _creditCards.firstOrNull,
    );
  }

  Future<List<CreditCardBillEntity>> _billsFind(
    BillsFindParams params,
  ) async =>
      params.idCreditCard == null
          ? []
          : await _creditCardBillFind.findAllAfterDate(
              date: params.date,
              idCreditCard: params.idCreditCard!,
            );

  Future<void> refreshCreditCard() async {
    if (_creditCardSelected == null) return;

    final values = await Future.wait<dynamic>([
      _creditCardFind.findById(_creditCardSelected!.id),
      _cashAdvance.findPlanned(),
    ]);

    final CreditCardEntity? refreshed = values[0] as CreditCardEntity?;
    _plannedOperations =
        (values[1] as List).cast<CardCashAdvancePlanEntity>();

    if (refreshed != null) {
      _creditCardSelected = refreshed;
      final int index =
          _creditCards.indexWhere((e) => e.id == refreshed.id);
      if (index >= 0) _creditCards[index] = refreshed;
    }

    notifyListeners();
  }
}
