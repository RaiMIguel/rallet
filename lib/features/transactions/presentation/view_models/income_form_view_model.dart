import 'package:rallet/features/account/domain/entities/account_entity.dart';
import 'package:rallet/features/account/domain/use_cases/i_account_find.dart';
import 'package:rallet/features/category/domain/entities/category_entity.dart';
import 'package:rallet/features/category/domain/enums/category_type_enum.dart';
import 'package:rallet/features/category/domain/use_cases/i_category_find.dart';
import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/domain/entities/transaction_by_text_entity.dart';
import 'package:rallet/features/transactions/domain/enums/recurrence_scope_enum.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_income_delete.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_income_find.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_income_save.dart';
import 'package:rallet/features/transactions/helpers/factories/income_factory.dart';
import 'package:rallet/shared/presentation/commands/command.dart';
import 'package:flutter/foundation.dart';

class IncomeFormViewModel extends ChangeNotifier {
  final ICategoryFind _categoryFind;
  final IAccountFind _accountFind;
  final IIncomeSave _incomeSave;

  late final Command1<void, IncomeEntity?> init;
  late final Command1<IncomeEntity, IncomeEntity> save;
  late final Command1<void, RecurrenceScopeEnum> delete;
  late final Command1<List<TransactionByTextEntity>, String> findByText;

  IncomeFormViewModel({
    required IIncomeSave incomeSave,
    required IIncomeDelete incomeDelete,
    required IIncomeFind incomeFind,
    required ICategoryFind categoryFind,
    required IAccountFind accountFind,
  })  : _categoryFind = categoryFind,
        _accountFind = accountFind,
        _incomeSave = incomeSave {
    init = Command1(_init);
    save = Command1(_save);
    delete = Command1((scope) => incomeDelete.delete(
          _income,
          recurrenceScope: scope,
          recurrenceReferenceDate: _recurrenceReferenceDate ?? _income.date,
        ));
    findByText = Command1(incomeFind.findByText);
  }

  bool get isLoading => save.running || delete.running;

  IncomeEntity _income = IncomeFactory.newEntity();
  double? _originalAmount;

  DateTime? _recurrenceReferenceDate;
  RecurrenceScopeEnum _recurrenceScope = RecurrenceScopeEnum.single;

  bool get isEditingRecurrence => income.recurrenceId != null;

  bool get isStoppingRecurrence =>
      income.recurrenceId != null && !income.recurring;

  void setRecurrenceScope(RecurrenceScopeEnum value) {
    _recurrenceScope = value;
  }

  IncomeEntity get income => _income;

  List<CategoryEntity> _categories = [];

  List<AccountEntity> _accounts = [];

  List<CategoryEntity> get categories => _categories;

  List<AccountEntity> get accounts => _accounts;

  Future<void> _init(IncomeEntity? income) async {
    await Future.wait([
      _categoryFind.findAll(type: CategoryTypeEnum.income, deleted: true).then((value) => _categories = value),
      _accountFind.findAll(deleted: true).then((value) => _accounts = value),
    ]);

    if (income != null) {
      _recurrenceReferenceDate = income.date;
      _recurrenceScope = RecurrenceScopeEnum.single;
      _originalAmount = income.amount;
      _income = income.clone();
    } else {
      _originalAmount = null;
      final AccountEntity? account = _accounts.where((account) => account.deletedAt == null).singleOrNull;
      if (account != null) _income.idAccount = account.id;
    }
  }

  Future<IncomeEntity> _save(IncomeEntity entity) async {
    final IncomeEntity result = await _incomeSave.save(
      entity,
      recurrenceScope: _recurrenceScope,
      recurrenceReferenceDate: _recurrenceReferenceDate,
    );
    _income = result;
    _recurrenceReferenceDate = result.date;
    _recurrenceScope = RecurrenceScopeEnum.single;
    return result;
  }


  bool get isEditingExisting => _originalAmount != null;

  bool get amountChanged =>
      _originalAmount != null &&
      (_originalAmount! - income.amount).abs() > 0.004;

  double get originalAmount => _originalAmount ?? income.amount;

  double get variancePreview => income.amount - originalAmount;

  void markAmountAsCorrection() {
    income.expectedAmount = null;
    income.trackVariance = false;
    income.varianceRegisteredAt = null;
  }

  void markAmountAsRealizedVariance() {
    if (_originalAmount == null) return;
    // Se vier de uma versão anterior sem confirmação explícita, a referência
    // correta passa a ser o valor imediatamente anterior a esta alteração.
    if (income.varianceRegisteredAt == null) {
      income.expectedAmount = _originalAmount;
    } else {
      income.expectedAmount ??= _originalAmount;
    }
    income.trackVariance = true;
    income.varianceRegisteredAt ??= DateTime.now();
  }

  void setIdCategory(String value) {
    income.idCategory = value;
    notifyListeners();
  }

  void setIdAccount(String value) {
    income.idAccount = value;
    notifyListeners();
  }

  void setDate(DateTime value) {
    income.date = value;
    notifyListeners();
  }

  void setRecurring(bool value) {
    income.recurring = value;
    notifyListeners();
  }

  void setReceived(bool value) {
    if (value && !income.received) {
      income.realizedAt = DateTime.now();
    } else if (!value) {
      income.realizedAt = null;
    }
    income.received = value;
    notifyListeners();
  }
}
