import 'package:rallet/features/account/domain/use_cases/i_account_find.dart';
import 'package:rallet/features/category/domain/entities/category_entity.dart';
import 'package:rallet/features/category/domain/use_cases/i_category_find.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/features/credit_card/domain/enums/installment_scope_enum.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_find.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_transaction_delete.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_transaction_find.dart';
import 'package:rallet/shared/presentation/commands/command.dart';
import 'package:rallet/shared/presentation/ui/app_locale.dart';
import 'package:flutter/foundation.dart';

class CreditCardExpenseDetailsViewModel extends ChangeNotifier {
  final ICreditCardTransactionFind _creditCardExpenseFind;
  final ICategoryFind _categoryFind;
  final ICreditCardFind _creditCardFind;

  late final Command1<void, String> load;
  late final Command1<void, bool> savePaid;
  late final Command1<void, CreditCardTransactionEntity> delete;
  late final Command1<void, ({CreditCardTransactionEntity entity, InstallmentScopeEnum scope})> deleteInstallments;

  CreditCardExpenseDetailsViewModel({
    required ICreditCardTransactionFind creditCardExpenseFind,
    required ICreditCardTransactionDelete creditCardExpenseDelete,
    required ICategoryFind categoryFind,
    required ICreditCardFind creditCardFind,
    required IAccountFind accountFind,
  })  : _creditCardExpenseFind = creditCardExpenseFind,
        _categoryFind = categoryFind,
        _creditCardFind = creditCardFind {
    load = Command1(_load);
    delete = Command1(creditCardExpenseDelete.delete);
    deleteInstallments = Command1(
      (args) => creditCardExpenseDelete.deleteInstallments(args.entity, args.scope),
    );
  }

  late CreditCardTransactionEntity _creditCardExpense;

  CreditCardTransactionEntity get creditCardExpense => _creditCardExpense;

  List<CreditCardTransactionEntity> _installments = [];
  List<CreditCardTransactionEntity> get installments => List.unmodifiable(_installments);

  bool get isInstallmentPurchase => _installments.length > 1;

  int get currentInstallmentNumber =>
      _creditCardExpense.installmentNumber ?? _parseInstallmentNumber(_creditCardExpense.description) ?? 1;

  int get totalInstallments =>
      _creditCardExpense.installmentCount ?? _parseInstallmentCount(_creditCardExpense.description) ?? _installments.length.clamp(1, 24).toInt();

  late CategoryEntity _category;

  CategoryEntity get category => _category;

  late CreditCardEntity _creditCardCard;

  CreditCardEntity get creditCardCard => _creditCardCard;

  Future<void> _load(String idCreditCardExpense) async {
    _creditCardExpense = await _creditCardExpenseFind.findById(idCreditCardExpense) ??
        (throw Exception(R.strings.transactionNotFound));

    _installments = await _creditCardExpenseFind.findInstallments(_creditCardExpense);
    final current = _installments.where((item) => item.id == _creditCardExpense.id).firstOrNull;
    if (current != null) {
      _creditCardExpense.installmentGroupId = current.installmentGroupId;
      _creditCardExpense.installmentNumber =
          current.installmentNumber ?? _parseInstallmentNumber(current.description);
      _creditCardExpense.installmentCount =
          current.installmentCount ?? _parseInstallmentCount(current.description);
    }

    await Future.wait([
      _categoryFind.findById(_creditCardExpense.idCategory!, deleted: true).then(
            (value) => _category = value ?? (throw Exception(R.strings.categoryNotFound)),
          ),
      _creditCardFind.findById(_creditCardExpense.idCreditCard!, deleted: true).then(
            (value) => _creditCardCard = value ?? (throw Exception(R.strings.creditCardNotFound)),
          ),
    ]);
  }

  int? _parseInstallmentNumber(String description) {
    final match = RegExp(r'\((\d+)\/(\d+)\)\s*$').firstMatch(description.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  int? _parseInstallmentCount(String description) {
    final match = RegExp(r'\((\d+)\/(\d+)\)\s*$').firstMatch(description.trim());
    return match == null ? null : int.tryParse(match.group(2)!);
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
