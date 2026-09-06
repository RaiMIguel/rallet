import 'package:collection/collection.dart';
import 'package:rallet/features/category/domain/entities/category_entity.dart';
import 'package:rallet/features/category/domain/enums/category_type_enum.dart';
import 'package:rallet/features/category/domain/use_cases/i_category_find.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/features/credit_card/domain/enums/installment_scope_enum.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_find.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_transaction_delete.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_transaction_find.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_transaction_save.dart';
import 'package:rallet/features/credit_card/helpers/factories/credit_card_transaction_factory.dart';
import 'package:rallet/features/transactions/domain/entities/transaction_by_text_entity.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_expense_find.dart';
import 'package:rallet/shared/presentation/commands/command.dart';
import 'package:flutter/foundation.dart';

class CreditCardExpenseFormViewModel extends ChangeNotifier {
  final ICategoryFind _categoryFind;
  final ICreditCardFind _creditCardFind;
  final ICreditCardTransactionFind _creditCardTransactionFind;
  final ICreditCardTransactionSave _creditCardTransactionSave;

  late final Command1<List<TransactionByTextEntity>, String> findByText;
  late final Command1<void, CreditCardTransactionEntity> delete;
  late final Command1<CreditCardTransactionEntity, CreditCardTransactionEntity> save;
  late final Command1<void, CreditCardTransactionEntity?> load;

  CreditCardExpenseFormViewModel({
    required ICreditCardTransactionSave creditCardTransactionSave,
    required ICreditCardTransactionDelete creditCardTransactionDelete,
    required ICreditCardTransactionFind creditCardTransactionFind,
    required IExpenseFind expenseFind,
    required ICategoryFind categoryFind,
    required ICreditCardFind creditCardFind,
  })  : _categoryFind = categoryFind,
        _creditCardFind = creditCardFind,
        _creditCardTransactionFind = creditCardTransactionFind,
        _creditCardTransactionSave = creditCardTransactionSave {
    findByText = Command1(expenseFind.findByText);
    delete = Command1(creditCardTransactionDelete.delete);
    save = Command1(_save);
    load = Command1(_load);
  }

  bool get isLoading => save.running || delete.running || load.running;

  List<CategoryEntity> _categories = [];

  List<CategoryEntity> get categories => List.unmodifiable(_categories);

  void setCategories(List<CategoryEntity> categories) => _categories = categories;

  List<CreditCardEntity> _creditCards = [];

  List<CreditCardEntity> get creditCards => List.unmodifiable(_creditCards);

  void setCreditCards(List<CreditCardEntity> creditCards) => _creditCards = creditCards;

  CreditCardTransactionEntity _creditCardExpense = CreditCardTransactionFactory.newEntity();

  CreditCardTransactionEntity get creditCardExpense => _creditCardExpense;

  List<CreditCardTransactionEntity> _installments = [];
  List<CreditCardTransactionEntity> get installments => List.unmodifiable(_installments);

  bool _installmentPurchase = false;
  int _installmentCount = 2;
  InstallmentScopeEnum _installmentScope = InstallmentScopeEnum.single;

  bool get installmentPurchase => _installmentPurchase;
  int get installmentCount => _installmentCount;

  bool get canConfigureInstallments => _creditCardExpense.isNew;
  bool get isExistingInstallmentPurchase => !_creditCardExpense.isNew && _installments.length > 1;

  int get currentInstallmentNumber =>
      _creditCardExpense.installmentNumber ?? _parseInstallmentNumber(_creditCardExpense.description) ?? 1;

  int get totalInstallments =>
      _creditCardExpense.installmentCount ?? _parseInstallmentCount(_creditCardExpense.description) ?? _installments.length.clamp(1, 24).toInt();

  void setInstallmentPurchase(bool value) {
    if (!canConfigureInstallments) return;
    _installmentPurchase = value;
    notifyListeners();
  }

  void setInstallmentCount(int value) {
    if (!canConfigureInstallments) return;
    _installmentCount = value.clamp(2, 24).toInt();
    notifyListeners();
  }

  void setInstallmentScope(InstallmentScopeEnum scope) {
    _installmentScope = scope;
  }

  Future<void> _load(CreditCardTransactionEntity? initialValue) async {
    if (initialValue != null) {
      _creditCardExpense = initialValue.clone();
      _installments = await _creditCardTransactionFind.findInstallments(initialValue);

      final CreditCardTransactionEntity? current =
          _installments.firstWhereOrNull((item) => item.id == initialValue.id);
      if (current != null) {
        _creditCardExpense.installmentGroupId = current.installmentGroupId;
        _creditCardExpense.installmentNumber =
            current.installmentNumber ?? _parseInstallmentNumber(current.description);
        _creditCardExpense.installmentCount =
            current.installmentCount ?? _parseInstallmentCount(current.description);
      }
    } else {
      _installments = [];
    }

    await Future.wait([
      _categoryFind.findAll(type: CategoryTypeEnum.expense, deleted: true).then((value) => _categories = value),
      _creditCardFind.findAll().then((value) => _creditCards = value),
    ]);

    if (initialValue == null) {
      final CreditCardEntity? creditCard = _creditCards
          .where((creditCard) => creditCard.deletedAt == null)
          .singleOrNull;
      if (creditCard != null) _creditCardExpense.idCreditCard = creditCard.id;
    }
  }

  Future<CreditCardTransactionEntity> _save(CreditCardTransactionEntity entity) async {
    final CreditCardTransactionEntity result =
        await _creditCardTransactionSave.save(
      entity,
      installmentCount: _installmentPurchase ? _installmentCount : 1,
      installmentScope: _installmentScope,
    );

    _creditCardExpense = result;
    return result;
  }

  int? _parseInstallmentNumber(String description) {
    final match = RegExp(r'\((\d+)\/(\d+)\)\s*$').firstMatch(description.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  int? _parseInstallmentCount(String description) {
    final match = RegExp(r'\((\d+)\/(\d+)\)\s*$').firstMatch(description.trim());
    return match == null ? null : int.tryParse(match.group(2)!);
  }

  void setCategory(String idCategory) {
    _creditCardExpense.idCategory = idCategory;
    notifyListeners();
  }

  void setCreditCard(String idCreditCard) {
    _creditCardExpense.idCreditCard = idCreditCard;
    notifyListeners();
  }

  void setDate(DateTime date) {
    _creditCardExpense.date = date;
    notifyListeners();
  }
}
