import 'package:rallet/features/ad/domain/use_cases/i_ad_access.dart';
import 'package:rallet/features/statement/domain/repositories/i_statement_repository.dart';
import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/domain/enums/recurrence_scope_enum.dart';
import 'package:rallet/features/transactions/domain/repositories/i_income_repository.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_income_delete.dart';
import 'package:rallet/shared/domain/repositories/i_local_db_transaction_repository.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local_transaction.dart';

class IncomeDelete implements IIncomeDelete {
  final IIncomeRepository _repository;
  final IStatementRepository _statementRepository;
  final ILocalDBTransactionRepository _localDBTransactionRepository;
  final IAdAccess _adAccess;

  IncomeDelete({
    required IIncomeRepository repository,
    required IStatementRepository statementRepository,
    required ILocalDBTransactionRepository localDBTransactionRepository,
    required IAdAccess adAccess,
  })  : _repository = repository,
        _statementRepository = statementRepository,
        _localDBTransactionRepository = localDBTransactionRepository,
        _adAccess = adAccess;

  @override
  Future<void> delete(
    IncomeEntity entity, {
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
    final List<IncomeEntity> series =
        await _repository.findByRecurrenceId(entity.recurrenceId!);

    final List<IncomeEntity> targets = series.where((occurrence) {
      if (recurrenceScope == RecurrenceScopeEnum.all) return true;
      return !occurrence.date.isBefore(referenceDate);
    }).toList();

    await _localDBTransactionRepository.openTransaction((newTxn) async {
      for (final IncomeEntity occurrence in targets) {
        await _deleteOne(occurrence, newTxn);
      }
    });

    await _adAccess.consumeUse();
  }

  Future<void> _deleteOne(
    IncomeEntity entity,
    ITransactionExecutor txn,
  ) async {
    await Future.wait([
      _repository.delete(entity, txn: txn),
      _statementRepository.deleteByIdIncome(entity.id, txn: txn),
    ]);
  }
}
