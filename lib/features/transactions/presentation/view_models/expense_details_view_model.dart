import 'package:rallet/features/account/domain/entities/account_entity.dart';
import 'package:rallet/features/account/domain/use_cases/i_account_find.dart';
import 'package:rallet/features/category/domain/entities/category_entity.dart';
import 'package:rallet/features/category/domain/use_cases/i_category_find.dart';
import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/enums/recurrence_scope_enum.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_expense_delete.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_expense_find.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_expense_save.dart';
import 'package:rallet/shared/presentation/commands/command.dart';
import 'package:rallet/shared/presentation/ui/app_locale.dart';
import 'package:flutter/foundation.dart';

typedef SettleExpenseDetailsParams = ({
  double realizedAmount,
  bool trackVariance,
  DateTime realizedAt,
});

class ExpenseDetailsViewModel extends ChangeNotifier {
  final IExpenseFind _expenseFind;
  final IExpenseSave _expenseSave;
  final ICategoryFind _categoryFind;
  final IAccountFind _accountFind;
  final IExpenseDelete _expenseDelete;

  late final Command1<void, String> load;
  late final Command1<void, bool> savePaid;
  late final Command1<void, SettleExpenseDetailsParams> settle;
  late final Command1<void, RecurrenceScopeEnum> delete;

  ExpenseDetailsViewModel({
    required IExpenseFind expenseFind,
    required IExpenseSave expenseSave,
    required IExpenseDelete expenseDelete,
    required ICategoryFind categoryFind,
    required IAccountFind accountFind,
  })  : _expenseFind = expenseFind,
        _expenseSave = expenseSave,
        _expenseDelete = expenseDelete,
        _categoryFind = categoryFind,
        _accountFind = accountFind {
    load = Command1(_load);
    savePaid = Command1(_savePaid);
    settle = Command1(_settle);
    delete = Command1(_delete);
  }

  late ExpenseEntity _expense;

  ExpenseEntity get expense => _expense;

  late CategoryEntity _category;

  CategoryEntity get category => _category;

  late AccountEntity _account;

  AccountEntity get account => _account;

  Future<void> _load(String idExpense) async {
    _expense = await _expenseFind.findById(idExpense) ?? (throw Exception(R.strings.transactionNotFound));

    await Future.wait([
      _categoryFind.findById(_expense.idCategory!, deleted: true).then((value) => _category = value ?? (throw Exception(R.strings.categoryNotFound))),
      _accountFind.findById(_expense.idAccount!, deleted: true).then((value) => _account = value ?? (throw Exception(R.strings.accountNotFound))),
    ]);
  }

  Future<void> _delete(RecurrenceScopeEnum scope) async {
    await _expenseDelete.delete(
      _expense,
      recurrenceScope: scope,
      recurrenceReferenceDate: _expense.date,
    );
  }


  Future<void> _settle(SettleExpenseDetailsParams params) async {
    if (_expense.paid) return;
    final ExpenseEntity updated = _expense.clone();
    final double expected = _expense.amount.abs();
    updated.amount = params.realizedAmount;
    updated.paid = true;
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
    _expense = await _expenseSave.save(updated);
    notifyListeners();
  }

  Future<void> _savePaid(bool value) async {
    await _expenseSave.savePaid(paid: value, id: _expense.id);
    _expense = await _expenseFind.findById(_expense.id) ?? _expense;

    notifyListeners();
  }
}
