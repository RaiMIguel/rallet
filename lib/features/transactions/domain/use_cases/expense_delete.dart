import 'package:rallet/features/ad/domain/use_cases/i_ad_access.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/features/credit_card/domain/repositories/i_credit_card_transaction_repository.dart';
import 'package:rallet/features/statement/domain/repositories/i_statement_repository.dart';
import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/enums/recurrence_scope_enum.dart';
import 'package:rallet/features/transactions/domain/repositories/i_expense_repository.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_expense_delete.dart';
import 'package:rallet/shared/domain/repositories/i_local_db_transaction_repository.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local_transaction.dart';

class ExpenseDelete implements IExpenseDelete {
  final IExpenseRepository _repository;
  final IStatementRepository _statementRepository;
  final ICreditCardTransactionRepository _creditCardTransactionRepository;
  final ILocalDBTransactionRepository _localDBTransactionRepository;
  final IAdAccess _adAccess;

  ExpenseDelete({
    required IExpenseRepository repository,
    required IStatementRepository statementRepository,
    required ICreditCardTransactionRepository creditCardTransactionRepository,
    required ILocalDBTransactionRepository localDBTransactionRepository,
    required IAdAccess adAccess,
  })  : _repository = repository,
        _statementRepository = statementRepository,
        _creditCardTransactionRepository = creditCardTransactionRepository,
        _localDBTransactionRepository = localDBTransactionRepository,
        _adAccess = adAccess;

  @override
  Future<void> delete(
    ExpenseEntity entity, {
    ITransactionExecutor? txn,
    RecurrenceScopeEnum recurrenceScope = RecurrenceScopeEnum.single,
    DateTime? recurrenceReferenceDate,
  }) async {
    if (txn != null ||
        entity.recurrenceId == null ||
        recurrenceScope == RecurrenceScopeEnum.single) {
      if (txn == null) {
        await _localDBTransactionRepository.openTransaction(
          (newTxn) => _deleteOne(entity, newTxn),
        );
      } else {
        await _deleteOne(entity, txn);
      }

      await _adAccess.consumeUse();
      return;
    }

    final DateTime referenceDate = recurrenceReferenceDate ?? entity.date;
    final List<ExpenseEntity> series =
        await _repository.findByRecurrenceId(entity.recurrenceId!);

    final List<ExpenseEntity> targets = series.where((occurrence) {
      if (recurrenceScope == RecurrenceScopeEnum.all) return true;
      return !occurrence.date.isBefore(referenceDate);
    }).toList();

    await _localDBTransactionRepository.openTransaction((newTxn) async {
      for (final ExpenseEntity occurrence in targets) {
        await _deleteOne(occurrence, newTxn);
      }
    });

    await _adAccess.consumeUse();
  }

  Future<void> _deleteOne(
    ExpenseEntity entity,
    ITransactionExecutor txn,
  ) async {
    CreditCardTransactionEntity? creditCardTransaction;

    if (entity.idCreditCardTransaction != null) {
      creditCardTransaction = await _creditCardTransactionRepository.findById(
        entity.idCreditCardTransaction!,
        txn: txn,
      );
    }

    await Future.wait([
      _repository.delete(entity, txn: txn),
      if (creditCardTransaction != null)
        _creditCardTransactionRepository.delete(creditCardTransaction, txn: txn),
      _statementRepository.deleteByIdExpense(entity.id, txn: txn),
    ]);
  }
}
