import 'package:rallet/features/ad/domain/use_cases/i_ad_access.dart';
import 'package:rallet/features/statement/domain/entities/statement_entity.dart';
import 'package:rallet/features/statement/domain/repositories/i_statement_repository.dart';
import 'package:rallet/features/statement/helpers/statement_factory.dart';
import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/enums/recurrence_scope_enum.dart';
import 'package:rallet/features/transactions/domain/repositories/i_expense_repository.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_expense_save.dart';
import 'package:rallet/shared/domain/repositories/i_local_db_transaction_repository.dart';
import 'package:rallet/shared/exceptions/exceptions.dart';
import 'package:rallet/shared/extensions/date_time_extension.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local_transaction.dart';
import 'package:rallet/shared/presentation/ui/app_locale.dart';
import 'package:uuid/uuid.dart';

class ExpenseSave implements IExpenseSave {
  static const int _recurrenceMonthsAhead = 120;

  final IExpenseRepository _repository;
  final IStatementRepository _statementRepository;
  final ILocalDBTransactionRepository _localDBTransactionRepository;
  final IAdAccess _adAccess;

  ExpenseSave({
    required IExpenseRepository repository,
    required IStatementRepository statementRepository,
    required ILocalDBTransactionRepository localDBTransactionRepository,
    required IAdAccess adAccess,
  })  : _repository = repository,
        _statementRepository = statementRepository,
        _localDBTransactionRepository = localDBTransactionRepository,
        _adAccess = adAccess;

  @override
  Future<ExpenseEntity> save(
    ExpenseEntity entity, {
    RecurrenceScopeEnum recurrenceScope = RecurrenceScopeEnum.single,
    DateTime? recurrenceReferenceDate,
  }) async {
    _validate(entity);

    // `date` continua sendo a data prevista/competência. Quando o lançamento
    // já nasce realizado, preservamos uma data real separada para o extrato.
    if (entity.paid) {
      entity.realizedAt ??= entity.date;
    } else {
      entity.realizedAt = null;
    }

    if (entity.recurrenceId != null && !entity.recurring) {
      return _stopRecurrence(
        entity,
        recurrenceScope: recurrenceScope,
        recurrenceReferenceDate: recurrenceReferenceDate ?? entity.date,
      );
    }

    final bool createRecurrence = entity.recurring && entity.recurrenceId == null;
    if (createRecurrence) entity.recurrenceId = const Uuid().v1();

    if (!createRecurrence &&
        entity.recurrenceId != null &&
        recurrenceScope != RecurrenceScopeEnum.single) {
      return _saveRecurrence(
        entity,
        recurrenceScope: recurrenceScope,
        recurrenceReferenceDate: recurrenceReferenceDate ?? entity.date,
      );
    }

    final StatementEntity? existingStatement =
        entity.isNew ? null : await _statementRepository.findByIdExpense(entity.id);

    return _localDBTransactionRepository.openTransaction<ExpenseEntity>((txn) async {
      final List<ExpenseEntity> entitiesToSave = [entity];

      if (createRecurrence) {
        for (int month = 1; month <= _recurrenceMonthsAhead; month++) {
          entitiesToSave.add(
            ExpenseEntity(
              id: null,
              createdAt: null,
              deletedAt: null,
              description: entity.description,
              amount: entity.amount,
              date: entity.date.addMonths(month),
              paid: false,
              observation: entity.observation,
              idAccount: entity.idAccount,
              idCategory: entity.idCategory,
              idCreditCard: null,
              idCreditCardTransaction: null,
              recurring: true,
              recurrenceId: entity.recurrenceId,
              realizedAt: null,
            ),
          );
        }
      }

      final List<ExpenseEntity> saved = await _repository.saveMany(entitiesToSave, txn: txn);
      if (saved.isEmpty) {
        throw Exception('Não foi possível salvar a despesa: o repositório não retornou o lançamento persistido.');
      }
      final ExpenseEntity entitySaved = saved.first;

      await _syncStatement(entitySaved, existingStatement, txn);
      await _adAccess.consumeUse();

      return entitySaved;
    });
  }

  Future<ExpenseEntity> _stopRecurrence(
    ExpenseEntity entity, {
    required RecurrenceScopeEnum recurrenceScope,
    required DateTime recurrenceReferenceDate,
  }) async {
    final String recurrenceId = entity.recurrenceId!;
    final List<ExpenseEntity> series = await _repository.findByRecurrenceId(recurrenceId);
    final StatementEntity? existingStatement = await _statementRepository.findByIdExpense(entity.id);

    entity.recurring = false;
    entity.recurrenceId = null;

    return _localDBTransactionRepository.openTransaction<ExpenseEntity>((txn) async {
      if (recurrenceScope != RecurrenceScopeEnum.single) {
        final List<ExpenseEntity> futureOccurrences = series
            .where(
              (occurrence) =>
                  occurrence.id != entity.id &&
                  occurrence.date.isAfter(recurrenceReferenceDate),
            )
            .toList();

        for (final ExpenseEntity occurrence in futureOccurrences) {
          await _repository.delete(occurrence, txn: txn);
          await _statementRepository.deleteByIdExpense(occurrence.id, txn: txn);
        }
      }

      final ExpenseEntity saved = await _repository.save(entity, txn: txn);
      await _syncStatement(saved, existingStatement, txn);
      await _adAccess.consumeUse();
      return saved;
    });
  }

  Future<ExpenseEntity> _saveRecurrence(
    ExpenseEntity entity, {
    required RecurrenceScopeEnum recurrenceScope,
    required DateTime recurrenceReferenceDate,
  }) async {
    final String recurrenceId = entity.recurrenceId!;
    final List<ExpenseEntity> series = await _repository.findByRecurrenceId(recurrenceId);

    final List<ExpenseEntity> targets = series.where((occurrence) {
      if (recurrenceScope == RecurrenceScopeEnum.all) return true;
      return !occurrence.date.isBefore(recurrenceReferenceDate);
    }).toList();

    if (!targets.any((occurrence) => occurrence.id == entity.id)) {
      targets.add(entity);
    }

    final List<ExpenseEntity> updated = targets.map((occurrence) {
      if (occurrence.id == entity.id) return entity;

      final ExpenseEntity copy = occurrence.clone();
      final int monthOffset = differenceInMonths(recurrenceReferenceDate, occurrence.date);

      copy.description = entity.description;
      copy.amount = entity.amount;
      copy.date = entity.date.addMonths(monthOffset);
      copy.observation = entity.observation;
      copy.idAccount = entity.idAccount;
      copy.idCategory = entity.idCategory;
      copy.recurring = true;
      copy.recurrenceId = recurrenceId;

      // O status pago de cada ocorrência é individual e não deve ser propagado.
      return copy;
    }).toList();

    final Map<String, StatementEntity?> existingStatements = {};
    for (final ExpenseEntity occurrence in updated) {
      existingStatements[occurrence.id] =
          await _statementRepository.findByIdExpense(occurrence.id);
    }

    return _localDBTransactionRepository.openTransaction<ExpenseEntity>((txn) async {
      final List<ExpenseEntity> saved = await _repository.saveMany(updated, txn: txn);
      if (saved.isEmpty) {
        throw Exception('Não foi possível atualizar a recorrência de despesa: nenhum lançamento foi retornado.');
      }

      for (final ExpenseEntity occurrence in saved) {
        await _syncStatement(
          occurrence,
          existingStatements[occurrence.id],
          txn,
        );
      }

      await _adAccess.consumeUse();

      return saved.firstWhere(
        (occurrence) => occurrence.id == entity.id,
        orElse: () => saved.first,
      );
    });
  }

  Future<void> _syncStatement(
    ExpenseEntity entity,
    StatementEntity? existing,
    ITransactionExecutor txn,
  ) async {
    if (entity.paid) {
      final StatementEntity statement = existing == null
          ? StatementFactory.fromExpense(entity)
          : existing..updateFromExpense(entity);
      await _statementRepository.save(statement, txn: txn);
    } else if (existing != null) {
      await _statementRepository.delete(existing, txn: txn);
    }
  }

  void _validate(ExpenseEntity entity) {
    if (entity.description.trim().isEmpty) {
      throw ValidationException(R.strings.uninformedDescription);
    }
    if (entity.amount >= 0) throw ValidationException(R.strings.lessThanZero);
    if (entity.idCategory == null) throw ValidationException(R.strings.uninformedCategory);
    if (entity.idAccount == null) throw ValidationException(R.strings.uninformedAccount);
  }

  @override
  Future<void> savePaid({required bool paid, required String id}) async {
    final ExpenseEntity expense = await _repository.findById(id) ??
        (throw Exception(R.strings.transactionNotFound));
    if (paid && !expense.paid) {
      expense.realizedAt = DateTime.now();
    } else if (!paid) {
      expense.realizedAt = null;
    }
    expense.paid = paid;

    // Marcar como pago/pendente afeta somente esta ocorrência.
    await save(expense);
  }
}
