import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/features/credit_card/domain/enums/installment_scope_enum.dart';

abstract interface class ICreditCardTransactionSave {
  Future<CreditCardTransactionEntity> save(
    CreditCardTransactionEntity entity, {
    int installmentCount = 1,
    InstallmentScopeEnum installmentScope = InstallmentScopeEnum.single,
  });
}
