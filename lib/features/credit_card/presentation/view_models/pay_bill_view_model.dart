import 'package:rallet/features/account/domain/entities/account_entity.dart';
import 'package:rallet/features/account/domain/use_cases/i_account_find.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_bill_save.dart';
import 'package:rallet/shared/presentation/commands/command.dart';
import 'package:flutter/foundation.dart';

class PayBillViewModel extends ChangeNotifier {
  final ICreditCardBillSave _creditCardBillSave;
  final IAccountFind _accountFind;

  late final Command0 save;

  late final Command0<List<AccountEntity>>
      loadAccounts;

  PayBillViewModel({
    required ICreditCardBillSave creditCardBillSave,
    required IAccountFind accountFind,
  })  : _creditCardBillSave = creditCardBillSave,
        _accountFind = accountFind {
    save = Command0(_save);

    loadAccounts = Command0(_loadAccounts);
  }

  double _payValue = 0;

  double get payValue => _payValue;

  void setPayValue(double value) {
    _payValue = value;

    notifyListeners();
  }

  String? _selectedAccountId;

  String? get selectedAccountId =>
      _selectedAccountId;

  void setSelectedAccount(String? id) {
    _selectedAccountId = id;

    notifyListeners();
  }

  late CreditCardBillEntity _bill;

  CreditCardBillEntity get bill => _bill;

  void load(CreditCardBillEntity bill) {
    _bill = bill;

    _selectedAccountId = null;

    loadAccounts.execute();
  }

  Future<List<AccountEntity>>
      _loadAccounts() async {
    final List<AccountEntity> accounts =
        await _accountFind.findAll();

    return accounts
        .where(
          (account) =>
              account.includeTotalBalance,
        )
        .toList();
  }

  Future<void> _save() async {
    final String? idAccount =
        _selectedAccountId;

    if (idAccount == null) {
      return;
    }

    _bill =
        await _creditCardBillSave.payBill(
      creditCardBill: _bill.clone(),
      payValue: payValue,
      idAccount: idAccount,
    );
  }
}