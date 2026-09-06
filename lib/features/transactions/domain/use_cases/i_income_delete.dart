import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/domain/enums/recurrence_scope_enum.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local_transaction.dart';

abstract interface class IIncomeDelete {
  Future<void> delete(
    IncomeEntity entity, {
    ITransactionExecutor? txn,
    RecurrenceScopeEnum recurrenceScope = RecurrenceScopeEnum.single,
    DateTime? recurrenceReferenceDate,
  });
}
