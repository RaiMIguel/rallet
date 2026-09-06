import 'package:rallet/features/account/domain/entities/account_entity.dart';
import 'package:rallet/features/account/domain/use_cases/i_account_find.dart';
import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/card_cash_advance/domain/use_cases/i_card_cash_advance.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_find.dart';
import 'package:rallet/shared/presentation/commands/command.dart';
import 'package:flutter/foundation.dart';

class CardCashAdvanceDetailsViewModel extends ChangeNotifier {
  final ICardCashAdvance _cashAdvance;
  final IAccountFind _accountFind;
  final ICreditCardFind _creditCardFind;

  late final Command1<void, CardCashAdvancePlanEntity> load;
  late final Command0<CardCashAdvancePlanEntity> undoRealization;
  late final Command0<CardCashAdvancePlanEntity> repairLinkedTransaction;

  CardCashAdvanceDetailsViewModel({
    required ICardCashAdvance cashAdvance,
    required IAccountFind accountFind,
    required ICreditCardFind creditCardFind,
  })  : _cashAdvance = cashAdvance,
        _accountFind = accountFind,
        _creditCardFind = creditCardFind {
    load = Command1(_load);
    undoRealization = Command0(_undoRealization);
    repairLinkedTransaction = Command0(_repairLinkedTransaction);
  }

  late CardCashAdvancePlanEntity plan;
  AccountEntity? account;
  CreditCardEntity? creditCard;
  bool linkedTransactionMissing = false;

  Future<void> _load(CardCashAdvancePlanEntity value) async {
    plan = (await _cashAdvance.findById(value.id)) ?? value.clone();
    final values = await Future.wait<dynamic>([
      _accountFind.findById(plan.idAccount, deleted: true),
      _creditCardFind.findById(plan.idCreditCard),
    ]);
    account = values[0] as AccountEntity?;
    creditCard = values[1] as CreditCardEntity?;
    linkedTransactionMissing =
        await _cashAdvance.hasMissingLinkedTransaction(plan);
    notifyListeners();
  }


  Future<CardCashAdvancePlanEntity> _repairLinkedTransaction() async {
    final result = await _cashAdvance.repairMissingLinkedTransaction(plan);
    plan = result;
    linkedTransactionMissing = false;
    notifyListeners();
    return result;
  }

  Future<CardCashAdvancePlanEntity> _undoRealization() async {
    final result = await _cashAdvance.undoRealization(plan);
    plan = result;
    notifyListeners();
    return result;
  }
}
