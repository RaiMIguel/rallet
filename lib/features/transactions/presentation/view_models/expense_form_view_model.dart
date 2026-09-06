import 'package:rallet/features/account/domain/entities/account_entity.dart';
import 'package:rallet/features/account/domain/use_cases/i_account_find.dart';
import 'package:rallet/features/category/domain/entities/category_entity.dart';
import 'package:rallet/features/category/domain/enums/category_type_enum.dart';
import 'package:rallet/features/category/domain/use_cases/i_category_find.dart';
import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/entities/transaction_by_text_entity.dart';
import 'package:rallet/features/transactions/domain/enums/recurrence_scope_enum.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_expense_delete.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_expense_find.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_expense_save.dart';
import 'package:rallet/features/transactions/helpers/factories/expense_factory.dart';
import 'package:rallet/shared/presentation/commands/command.dart';
import 'package:flutter/foundation.dart';

class ExpenseFormViewModel extends ChangeNotifier {
  final ICategoryFind _categoryFind;
  final IAccountFind _accountFind;
  final IExpenseSave _expenseSave;

  late final Command1<void, ExpenseEntity?> init;
  late final Command1<ExpenseEntity, ExpenseEntity> save;
  late final Command1<List<TransactionByTextEntity>, String> findByText;

  ExpenseFormViewModel({
    required IExpenseSave expenseSave,
    required IExpenseDelete expenseDelete,
    required IExpenseFind expenseFind,
    required ICategoryFind categoryFind,
    required IAccountFind accountFind,
  })  : _categoryFind = categoryFind,
        _accountFind = accountFind,
        _expenseSave = expenseSave {
    init = Command1(_init);
    save = Command1(_save);
    findByText = Command1(expenseFind.findByText);
  }

  ExpenseEntity _expense = ExpenseFactory.newEntity();
  double? _originalAmount;

  DateTime? _recurrenceReferenceDate;
  RecurrenceScopeEnum _recurrenceScope = RecurrenceScopeEnum.single;

  bool get isEditingRecurrence => expense.recurrenceId != null;

  bool get isStoppingRecurrence =>
      expense.recurrenceId != null && !expense.recurring;

  void setRecurrenceScope(RecurrenceScopeEnum value) {
    _recurrenceScope = value;
  }

  ExpenseEntity get expense => _expense;

  List<CategoryEntity> _categories = [];

  List<AccountEntity> _accounts = [];

  List<CategoryEntity> get categories => _categories;

  List<AccountEntity> get accounts => _accounts;

  Future<void> _init(ExpenseEntity? expense) async {
    await Future.wait([
      _categoryFind.findAll(type: CategoryTypeEnum.expense, deleted: true).then((value) => _categories = value),
      _accountFind.findAll(deleted: true).then((value) => _accounts = value),
    ]);

    if (expense != null) {
      _recurrenceReferenceDate = expense.date;
      _recurrenceScope = RecurrenceScopeEnum.single;
      _originalAmount = expense.amount.abs();
      _expense = expense.clone();
    } else {
      _originalAmount = null;
      final AccountEntity? account = _accounts.where((account) => account.deletedAt == null).singleOrNull;
      if (account != null) _expense.idAccount = account.id;
    }
  }

  Future<ExpenseEntity> _save(ExpenseEntity entity) async {
    final ExpenseEntity result = await _expenseSave.save(
      entity,
      recurrenceScope: _recurrenceScope,
      recurrenceReferenceDate: _recurrenceReferenceDate,
    );
    _expense = result;
    _recurrenceReferenceDate = result.date;
    _recurrenceScope = RecurrenceScopeEnum.single;
    return result;
  }


  bool get isEditingExisting => _originalAmount != null;

  bool get amountChanged =>
      _originalAmount != null &&
      (_originalAmount! - expense.amount.abs()).abs() > 0.004;

  double get originalAmount => _originalAmount ?? expense.amount.abs();

  double get variancePreview =>
      originalAmount - expense.amount.abs();

  void markAmountAsCorrection() {
    expense.expectedAmount = null;
    expense.trackVariance = false;
    expense.varianceRegisteredAt = null;
  }

  void markAmountAsRealizedVariance() {
    if (_originalAmount == null) return;
    // Se vier de uma versão anterior sem confirmação explícita, a referência
    // correta passa a ser o valor imediatamente anterior a esta alteração.
    if (expense.varianceRegisteredAt == null) {
      expense.expectedAmount = _originalAmount;
    } else {
      expense.expectedAmount ??= _originalAmount;
    }
    expense.trackVariance = true;
    expense.varianceRegisteredAt ??= DateTime.now();
  }

  void setIdCategory(String value) {
    expense.idCategory = value;
    notifyListeners();
  }

  void setIdAccount(String value) {
    expense.idAccount = value;
    notifyListeners();
  }

  void setDate(DateTime value) {
    expense.date = value;
    notifyListeners();
  }

  void setRecurring(bool value) {
    expense.recurring = value;
    notifyListeners();
  }

  void setPaid(bool value) {
    if (value && !expense.paid) {
      expense.realizedAt = DateTime.now();
    } else if (!value) {
      expense.realizedAt = null;
    }
    expense.paid = value;
    notifyListeners();
  }
}
