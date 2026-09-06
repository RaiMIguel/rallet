import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/features/credit_card/domain/enums/installment_scope_enum.dart';

abstract interface class ICreditCardTransactionDelete {
  Future<void> delete(CreditCardTransactionEntity entity);

  Future<void> deleteMany(List<CreditCardTransactionEntity> entities);

  Future<void> deleteInstallments(
    CreditCardTransactionEntity entity,
    InstallmentScopeEnum scope,
  );
}
