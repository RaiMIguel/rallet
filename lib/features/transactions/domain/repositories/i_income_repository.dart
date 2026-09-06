import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/domain/entities/transaction_by_text_entity.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local_transaction.dart';

abstract interface class IIncomeRepository {
  Future<IncomeEntity> save(IncomeEntity entity, {ITransactionExecutor? txn});

  Future<List<IncomeEntity>> saveMany(List<IncomeEntity> entities, {ITransactionExecutor? txn});

  Future<void> delete(IncomeEntity entity, {ITransactionExecutor? txn});

  Future<List<IncomeEntity>> findByPeriod(DateTime startDate, DateTime endDate);

  Future<List<TransactionByTextEntity>> findByText(String text);

  Future<List<IncomeEntity>> findUnreceived();

  Future<List<IncomeEntity>> findByRecurrenceId(String recurrenceId);

  Future<IncomeEntity?> findById(String id);
}
