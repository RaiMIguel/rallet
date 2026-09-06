import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/entities/i_transaction_entity.dart';
import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/domain/entities/transfer_entity.dart';
import 'package:rallet/features/transactions/domain/enums/recurrence_scope_enum.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_expense_delete.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_income_delete.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_transaction_delete.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_transfer_delete.dart';
import 'package:rallet/shared/domain/repositories/i_local_db_transaction_repository.dart';

class TransactionDelete implements ITransactionDelete {
  final IIncomeDelete _incomeDelete;
  final IExpenseDelete _expenseDelete;
  final ITransferDelete _transferDelete;
  final ILocalDBTransactionRepository _localDBTransactionRepository;

  TransactionDelete({
    required IIncomeDelete incomeDelete,
    required IExpenseDelete expenseDelete,
    required ITransferDelete transferDelete,
    required ILocalDBTransactionRepository localDBTransactionRepository,
  })  : _incomeDelete = incomeDelete,
        _expenseDelete = expenseDelete,
        _transferDelete = transferDelete,
        _localDBTransactionRepository = localDBTransactionRepository;

  @override
  Future<void> deleteTransactions(
    List<ITransactionEntity> transactions, {
    RecurrenceScopeEnum recurrenceScope = RecurrenceScopeEnum.single,
  }) async {
    if (recurrenceScope == RecurrenceScopeEnum.single) {
      await _localDBTransactionRepository.openTransaction((txn) async {
        final List<Future<void>> futures = [];

        for (final transaction in transactions) {
          futures.add(
            switch (transaction) {
              IncomeEntity income => _incomeDelete.delete(income, txn: txn),
              ExpenseEntity expense => _expenseDelete.delete(expense, txn: txn),
              TransferEntity transfer => _transferDelete.delete(transfer, txn: txn),
              _ => Future<void>.value(),
            },
          );
        }

        await Future.wait(futures);
      });
      return;
    }

    final Set<String> processedRecurrences = {};

    for (final transaction in transactions) {
      switch (transaction) {
        case IncomeEntity income:
          if (income.recurrenceId != null) {
            final String key = 'income:${income.recurrenceId}';
            if (!processedRecurrences.add(key)) continue;

            final List<IncomeEntity> selectedSeries = transactions
                .whereType<IncomeEntity>()
                .where((item) => item.recurrenceId == income.recurrenceId)
                .toList()
              ..sort((a, b) => a.date.compareTo(b.date));
            final IncomeEntity reference = selectedSeries.first;

            await _incomeDelete.delete(
              reference,
              recurrenceScope: recurrenceScope,
              recurrenceReferenceDate: reference.date,
            );
          } else {
            await _incomeDelete.delete(income);
          }
          break;
        case ExpenseEntity expense:
          if (expense.recurrenceId != null) {
            final String key = 'expense:${expense.recurrenceId}';
            if (!processedRecurrences.add(key)) continue;

            final List<ExpenseEntity> selectedSeries = transactions
                .whereType<ExpenseEntity>()
                .where((item) => item.recurrenceId == expense.recurrenceId)
                .toList()
              ..sort((a, b) => a.date.compareTo(b.date));
            final ExpenseEntity reference = selectedSeries.first;

            await _expenseDelete.delete(
              reference,
              recurrenceScope: recurrenceScope,
              recurrenceReferenceDate: reference.date,
            );
          } else {
            await _expenseDelete.delete(expense);
          }
          break;
        case TransferEntity transfer:
          await _transferDelete.delete(transfer);
          break;
        default:
          break;
      }
    }
  }
}
