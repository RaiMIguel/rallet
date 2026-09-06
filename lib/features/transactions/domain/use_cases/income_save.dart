import 'package:rallet/features/ad/domain/use_cases/i_ad_access.dart';
import 'package:rallet/features/statement/domain/entities/statement_entity.dart';
import 'package:rallet/features/statement/domain/repositories/i_statement_repository.dart';
import 'package:rallet/features/statement/helpers/statement_factory.dart';
import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/domain/enums/recurrence_scope_enum.dart';
import 'package:rallet/features/transactions/domain/repositories/i_income_repository.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_income_save.dart';
import 'package:rallet/shared/domain/repositories/i_local_db_transaction_repository.dart';
import 'package:rallet/shared/exceptions/exceptions.dart';
import 'package:rallet/shared/extensions/date_time_extension.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local_transaction.dart';
import 'package:rallet/shared/presentation/ui/app_locale.dart';
import 'package:uuid/uuid.dart';

class IncomeSave implements IIncomeSave {
  static const int _recurrenceMonthsAhead = 120;

  final IIncomeRepository _repository;
  final IStatementRepository _statementRepository;
  final ILocalDBTransactionRepository _localDBTransactionRepository;
  final IAdAccess _adAccess;

  IncomeSave({
    required IIncomeRepository repository,
    required IStatementRepository statementRepository,
    required ILocalDBTransactionRepository localDBTransactionRepository,
    required IAdAccess adAccess,
  })  : _repository = repository,
        _statementRepository = statementRepository,
        _localDBTransactionRepository = localDBTransactionRepository,
        _adAccess = adAccess;

  @override
  Future<IncomeEntity> save(
    IncomeEntity entity, {
    RecurrenceScopeEnum recurrenceScope = RecurrenceScopeEnum.single,
    DateTime? recurrenceReferenceDate,
  }) async {
    _validate(entity);

    // `date` continua sendo a data prevista/competência. Quando o lançamento
    // já nasce realizado, preservamos uma data real separada para o extrato.
    if (entity.received) {
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
        entity.isNew ? null : await _statementRepository.findByIdIncome(entity.id);

    return _localDBTransactionRepository.openTransaction<IncomeEntity>((txn) async {
      final List<IncomeEntity> entitiesToSave = [entity];

      if (createRecurrence) {
        for (int month = 1; month <= _recurrenceMonthsAhead; month++) {
          entitiesToSave.add(
            IncomeEntity(
              id: null,
              createdAt: null,
              deletedAt: null,
              description: entity.description,
              amount: entity.amount,
              date: entity.date.addMonths(month),
              received: false,
              observation: entity.observation,
              idAccount: entity.idAccount,
              idCategory: entity.idCategory,
              recurring: true,
              recurrenceId: entity.recurrenceId,
              realizedAt: null,
            ),
          );
        }
      }

      final List<IncomeEntity> saved = await _repository.saveMany(entitiesToSave, txn: txn);
      if (saved.isEmpty) {
        throw Exception('Não foi possível salvar a receita: o repositório não retornou o lançamento persistido.');
      }
      final IncomeEntity entitySaved = saved.first;

      await _syncStatement(entitySaved, existingStatement, txn);
      await _adAccess.consumeUse();

      return entitySaved;
    });
  }

  Future<IncomeEntity> _stopRecurrence(
    IncomeEntity entity, {
    required RecurrenceScopeEnum recurrenceScope,
    required DateTime recurrenceReferenceDate,
  }) async {
    final String recurrenceId = entity.recurrenceId!;
    final List<IncomeEntity> series = await _repository.findByRecurrenceId(recurrenceId);
    final StatementEntity? existingStatement = await _statementRepository.findByIdIncome(entity.id);

    entity.recurring = false;
    entity.recurrenceId = null;

    return _localDBTransactionRepository.openTransaction<IncomeEntity>((txn) async {
      if (recurrenceScope != RecurrenceScopeEnum.single) {
        final List<IncomeEntity> futureOccurrences = series
            .where(
              (occurrence) =>
                  occurrence.id != entity.id &&
                  occurrence.date.isAfter(recurrenceReferenceDate),
            )
            .toList();

        for (final IncomeEntity occurrence in futureOccurrences) {
          await _repository.delete(occurrence, txn: txn);
          await _statementRepository.deleteByIdIncome(occurrence.id, txn: txn);
        }
      }

      final IncomeEntity saved = await _repository.save(entity, txn: txn);
      await _syncStatement(saved, existingStatement, txn);
      await _adAccess.consumeUse();
      return saved;
    });
  }

  Future<IncomeEntity> _saveRecurrence(
    IncomeEntity entity, {
    required RecurrenceScopeEnum recurrenceScope,
    required DateTime recurrenceReferenceDate,
  }) async {
    final String recurrenceId = entity.recurrenceId!;
    final List<IncomeEntity> series = await _repository.findByRecurrenceId(recurrenceId);

    final List<IncomeEntity> targets = series.where((occurrence) {
      if (recurrenceScope == RecurrenceScopeEnum.all) return true;
      return !occurrence.date.isBefore(recurrenceReferenceDate);
    }).toList();

    if (!targets.any((occurrence) => occurrence.id == entity.id)) {
      targets.add(entity);
    }

    final List<IncomeEntity> updated = targets.map((occurrence) {
      if (occurrence.id == entity.id) return entity;

      final IncomeEntity copy = occurrence.clone();
      final int monthOffset = differenceInMonths(recurrenceReferenceDate, occurrence.date);

      copy.description = entity.description;
      copy.amount = entity.amount;
      copy.date = entity.date.addMonths(monthOffset);
      copy.observation = entity.observation;
      copy.idAccount = entity.idAccount;
      copy.idCategory = entity.idCategory;
      copy.recurring = true;
      copy.recurrenceId = recurrenceId;

      // O status recebido de cada ocorrência é individual e não deve ser propagado.
      return copy;
    }).toList();

    final Map<String, StatementEntity?> existingStatements = {};
    for (final IncomeEntity occurrence in updated) {
      existingStatements[occurrence.id] =
          await _statementRepository.findByIdIncome(occurrence.id);
    }

    return _localDBTransactionRepository.openTransaction<IncomeEntity>((txn) async {
      final List<IncomeEntity> saved = await _repository.saveMany(updated, txn: txn);
      if (saved.isEmpty) {
        throw Exception('Não foi possível atualizar a recorrência de receita: nenhum lançamento foi retornado.');
      }

      for (final IncomeEntity occurrence in saved) {
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
    IncomeEntity entity,
    StatementEntity? existing,
    ITransactionExecutor txn,
  ) async {
    if (entity.received) {
      final StatementEntity statement = existing == null
          ? StatementFactory.fromIncome(entity)
          : existing..updateFromIncome(entity);
      await _statementRepository.save(statement, txn: txn);
    } else if (existing != null) {
      await _statementRepository.delete(existing, txn: txn);
    }
  }

  void _validate(IncomeEntity entity) {
    if (entity.description.trim().isEmpty) {
      throw ValidationException(R.strings.uninformedDescription);
    }
    if (entity.amount <= 0) throw ValidationException(R.strings.greaterThanZero);
    if (entity.idCategory == null) throw ValidationException(R.strings.uninformedCategory);
    if (entity.idAccount == null) throw ValidationException(R.strings.uninformedAccount);
  }

  @override
  Future<void> saveReceived({required bool received, required String id}) async {
    final IncomeEntity income = await _repository.findById(id) ??
        (throw Exception(R.strings.transactionNotFound));
    if (received && !income.received) {
      income.realizedAt = DateTime.now();
    } else if (!received) {
      income.realizedAt = null;
    }
    income.received = received;

    // Marcar como recebido/pendente afeta somente esta ocorrência.
    await save(income);
  }
}
