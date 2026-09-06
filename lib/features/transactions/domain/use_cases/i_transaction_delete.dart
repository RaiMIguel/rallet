import 'package:rallet/features/transactions/domain/entities/i_transaction_entity.dart';
import 'package:rallet/features/transactions/domain/enums/recurrence_scope_enum.dart';

abstract interface class ITransactionDelete {
  Future<void> deleteTransactions(
    List<ITransactionEntity> transactions, {
    RecurrenceScopeEnum recurrenceScope = RecurrenceScopeEnum.single,
  });
}
