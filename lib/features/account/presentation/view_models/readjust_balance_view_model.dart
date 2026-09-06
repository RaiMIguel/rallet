import 'package:rallet/features/account/domain/entities/account_entity.dart';
import 'package:rallet/features/account/domain/enums/adjustment_option_enum.dart';
import 'package:rallet/features/account/domain/use_cases/i_account_readjustment_transaction.dart';
import 'package:rallet/features/account/domain/use_cases/i_account_save.dart';
import 'package:rallet/features/account/helpers/account_factory.dart';
import 'package:rallet/shared/presentation/commands/command.dart';
import 'package:flutter/foundation.dart';

typedef ReadjustBalanceParams = ({double readjustmentValue, ReadjustmentOptionEnum option, String description});

class ReadjustBalanceViewModel extends ChangeNotifier {
  final IAccountSave _accountSave;
  final IAccountReadjustmentTransaction _accountReadjustmentTransaction;

  late final Command1<void, ReadjustBalanceParams> readjustBalance;

  ReadjustBalanceViewModel({
    required IAccountSave accountSave,
    required IAccountReadjustmentTransaction accountReadjustmentTransaction,
  })  : _accountSave = accountSave,
        _accountReadjustmentTransaction = accountReadjustmentTransaction {
    readjustBalance = Command1<void, ReadjustBalanceParams>(_readjustBalance);
  }

  AccountEntity _account = AccountFactory.newEntity();

  AccountEntity get account => _account;

  void setAccount(AccountEntity value) {
    _account = value;
    notifyListeners();
  }

  Future<void> _readjustBalance(ReadjustBalanceParams params) async {
    if (params.option == ReadjustmentOptionEnum.changeInitialAmount) {
      setAccount(await _accountSave.changeInitialAmount(entity: account, readjustmentValue: params.readjustmentValue));
    } else {
      setAccount(await _accountReadjustmentTransaction.createTransaction(account: account, readjustmentValue: params.readjustmentValue, description: params.description));
    }
  }
}
