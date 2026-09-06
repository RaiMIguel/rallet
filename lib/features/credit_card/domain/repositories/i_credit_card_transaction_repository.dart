import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local_transaction.dart';

abstract interface class ICreditCardTransactionRepository {
  Future<CreditCardTransactionEntity?> findById(String id, {ITransactionExecutor? txn});

  /// Busca inclusive uma movimentação removida logicamente. Usado apenas para
  /// recuperação segura de vínculos financeiros órfãos.
  Future<CreditCardTransactionEntity?> findByIdIncludingDeleted(
    String id, {
    ITransactionExecutor? txn,
  });

  Future<CreditCardTransactionEntity?> findByCashAdvancePlanId(
    String cashAdvancePlanId, {
    ITransactionExecutor? txn,
  });

  Future<List<CreditCardTransactionEntity>> findInstallments(
    CreditCardTransactionEntity entity, {
    ITransactionExecutor? txn,
  });

  Future<CreditCardTransactionEntity> save(CreditCardTransactionEntity entity, {ITransactionExecutor? txn});

  Future<void> saveMany(List<CreditCardTransactionEntity> transactions, {ITransactionExecutor? txn});

  Future<void> delete(CreditCardTransactionEntity entity, {ITransactionExecutor? txn});

  Future<void> deleteMany(List<CreditCardTransactionEntity> entities, {ITransactionExecutor? txn});
}
