import 'package:rallet/features/account/domain/entities/account_entity.dart';
import 'package:rallet/features/account/domain/use_cases/i_account_find.dart';
import 'package:rallet/features/category/domain/entities/category_entity.dart';
import 'package:rallet/features/category/domain/use_cases/i_category_find.dart';
import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/domain/enums/recurrence_scope_enum.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_income_delete.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_income_find.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_income_save.dart';
import 'package:rallet/shared/presentation/commands/command.dart';
import 'package:rallet/shared/presentation/ui/app_locale.dart';
import 'package:flutter/foundation.dart';

typedef SettleIncomeDetailsParams = ({
  double realizedAmount,
  bool trackVariance,
  DateTime realizedAt,
});

class IncomeDetailsViewModel extends ChangeNotifier {
  final IIncomeFind _incomeFind;
  final IIncomeSave _incomeSave;
  final ICategoryFind _categoryFind;
  final IAccountFind _accountFind;
  final IIncomeDelete _incomeDelete;

  late final Command1<void, String> load;
  late final Command1<void, bool> saveReceived;
  late final Command1<void, SettleIncomeDetailsParams> settle;
  late final Command1<void, RecurrenceScopeEnum> delete;

  IncomeDetailsViewModel({
    required IIncomeFind incomeFind,
    required IIncomeSave incomeSave,
    required IIncomeDelete incomeDelete,
    required ICategoryFind categoryFind,
    required IAccountFind accountFind,
  })  : _incomeFind = incomeFind,
        _incomeSave = incomeSave,
        _incomeDelete = incomeDelete,
        _categoryFind = categoryFind,
        _accountFind = accountFind {
    load = Command1(_load);
    saveReceived = Command1(_saveReceived);
    settle = Command1(_settle);
    delete = Command1(_delete);
  }

  late IncomeEntity _income;

  IncomeEntity get income => _income;

  late CategoryEntity _category;

  CategoryEntity get category => _category;

  late AccountEntity _account;

  AccountEntity get account => _account;

  Future<void> _load(String idIncome) async {
    _income = await _incomeFind.findById(idIncome) ?? (throw Exception(R.strings.transactionNotFound));

    await Future.wait([
      _categoryFind.findById(_income.idCategory!, deleted: true).then((value) => _category = value ?? (throw Exception(R.strings.categoryNotFound))),
      _accountFind.findById(_income.idAccount!, deleted: true).then((value) => _account = value ?? (throw Exception(R.strings.accountNotFound))),
    ]);
  }

  Future<void> _delete(RecurrenceScopeEnum scope) async {
    await _incomeDelete.delete(
      _income,
      recurrenceScope: scope,
      recurrenceReferenceDate: _income.date,
    );
  }


  Future<void> _settle(SettleIncomeDetailsParams params) async {
    if (_income.received) return;
    final IncomeEntity updated = _income.clone();
    final double expected = _income.amount.abs();
    updated.amount = params.realizedAmount;
    updated.received = true;
    updated.realizedAt = params.realizedAt;
    if ((expected - params.realizedAmount).abs() > 0.004 &&
        params.trackVariance) {
      updated.expectedAmount = expected;
      updated.trackVariance = true;
      updated.varianceRegisteredAt = DateTime.now();
    } else {
      updated.expectedAmount = null;
      updated.trackVariance = false;
      updated.varianceRegisteredAt = null;
    }
    _income = await _incomeSave.save(updated);
    notifyListeners();
  }

  Future<void> _saveReceived(bool value) async {
    await _incomeSave.saveReceived(received: value, id: _income.id);
    _income = await _incomeFind.findById(_income.id) ?? _income;

    notifyListeners();
  }
}
