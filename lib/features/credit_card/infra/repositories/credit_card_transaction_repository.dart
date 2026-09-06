import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/features/credit_card/domain/repositories/i_credit_card_transaction_repository.dart';
import 'package:rallet/features/credit_card/helpers/factories/credit_card_transaction_factory.dart';
import 'package:rallet/features/credit_card/infra/data_sources/i_credit_card_transaction_local_data_source.dart';
import 'package:rallet/features/credit_card/infra/models/credit_card_transaction_model.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local_transaction.dart';
import 'package:rallet/shared/infra/models/model.dart';
import 'package:rallet/shared/presentation/notifiers/event_notifier.dart';

class CreditCardTransactionRepository implements ICreditCardTransactionRepository {
  final ICreditCardTransactionLocalDataSource _dataSource;
  final IDatabaseLocalTransaction _dbTransaction;
  final EventNotifier _eventNotifier;

  CreditCardTransactionRepository({
    required ICreditCardTransactionLocalDataSource dataSource,
    required IDatabaseLocalTransaction dbTransaction,
    required EventNotifier eventNotifier,
  })  : _dataSource = dataSource,
        _dbTransaction = dbTransaction,
        _eventNotifier = eventNotifier;

  @override
  Future<CreditCardTransactionEntity?> findById(String id, {ITransactionExecutor? txn}) async {
    if (txn == null) {
      return await _dbTransaction.openTransaction((newTxn) => findById(id, txn: newTxn));
    }

    final CreditCardTransactionModel? result = await _dataSource.findOne(
      where: '${Model.idColumnName} = ?',
      whereArgs: [id],
      txn: txn,
    );

    return result != null ? CreditCardTransactionFactory.toEntity(result) : null;
  }

  @override
  Future<CreditCardTransactionEntity?> findByIdIncludingDeleted(
    String id, {
    ITransactionExecutor? txn,
  }) async {
    if (txn == null) {
      return await _dbTransaction.openTransaction(
        (newTxn) => findByIdIncludingDeleted(id, txn: newTxn),
      );
    }

    final CreditCardTransactionModel? result = await _dataSource.findOne(
      where: '${Model.idColumnName} = ?',
      whereArgs: [id],
      deleted: true,
      txn: txn,
    );

    return result != null ? CreditCardTransactionFactory.toEntity(result) : null;
  }

  @override
  Future<CreditCardTransactionEntity?> findByCashAdvancePlanId(
    String cashAdvancePlanId, {
    ITransactionExecutor? txn,
  }) async {
    final CreditCardTransactionModel? result = await _dataSource.findOne(
      where: 'cash_advance_plan_id = ?',
      whereArgs: [cashAdvancePlanId],
      txn: txn,
    );
    return result == null ? null : CreditCardTransactionFactory.toEntity(result);
  }

  @override
  Future<List<CreditCardTransactionEntity>> findInstallments(
    CreditCardTransactionEntity entity, {
    ITransactionExecutor? txn,
  }) async {
    if (entity.installmentGroupId?.isNotEmpty == true) {
      final List<CreditCardTransactionModel> result = await _dataSource.findAll(
        where: 'installment_group_id = ?',
        whereArgs: [entity.installmentGroupId],
        txn: txn,
      );

      final List<CreditCardTransactionEntity> entities =
          result.map(CreditCardTransactionFactory.toEntity).toList();
      entities.sort(_sortInstallments);
      return entities;
    }

    // Compatibilidade com compras parceladas criadas na v5, quando ainda
    // não existia installment_group_id no banco. O padrão gerado era
    // "Descrição (4/21)" e uma parcela por mês.
    final _LegacyInstallmentInfo? current = _parseLegacy(entity.description);
    if (current == null || current.total <= 1) return [entity];

    final List<CreditCardTransactionModel> candidates = await _dataSource.findAll(
      where: 'id_credit_card = ? AND id_category = ? AND amount > 0',
      whereArgs: [entity.idCreditCard, entity.idCategory],
      txn: txn,
    );

    final List<CreditCardTransactionEntity> possible = candidates
        .map(CreditCardTransactionFactory.toEntity)
        .where((candidate) {
          final info = _parseLegacy(candidate.description);
          if (info == null) return false;
          if (info.baseDescription != current.baseDescription || info.total != current.total) return false;
          if ((candidate.amount - entity.amount).abs() > 0.011) return false;

          final int monthDistance =
              (candidate.date.year - entity.date.year) * 12 +
              candidate.date.month - entity.date.month;
          return monthDistance == info.number - current.number;
        })
        .toList();

    final List<CreditCardTransactionEntity> resolved = [];
    for (int number = 1; number <= current.total; number++) {
      final matches = possible.where((candidate) {
        final info = _parseLegacy(candidate.description);
        return info?.number == number;
      }).toList();

      if (matches.isEmpty) continue;
      matches.sort((a, b) {
        final int aDay = (a.date.day - entity.date.day).abs();
        final int bDay = (b.date.day - entity.date.day).abs();
        return aDay.compareTo(bDay);
      });
      resolved.add(matches.first);
    }

    if (!resolved.any((item) => item.id == entity.id)) resolved.add(entity);

    for (final item in resolved) {
      final info = _parseLegacy(item.description);
      if (info != null) {
        item.installmentNumber = info.number;
        item.installmentCount = info.total;
      }
    }

    resolved.sort(_sortInstallments);
    return resolved.length > 1 ? resolved : [entity];
  }

  static int _sortInstallments(
    CreditCardTransactionEntity a,
    CreditCardTransactionEntity b,
  ) {
    final int? aNumber = a.installmentNumber ?? _parseLegacy(a.description)?.number;
    final int? bNumber = b.installmentNumber ?? _parseLegacy(b.description)?.number;
    if (aNumber != null && bNumber != null) return aNumber.compareTo(bNumber);
    return a.date.compareTo(b.date);
  }

  static _LegacyInstallmentInfo? _parseLegacy(String description) {
    final RegExpMatch? match = RegExp(r'^(.*) \((\d+)\/(\d+)\)$').firstMatch(description.trim());
    if (match == null) return null;

    final int? number = int.tryParse(match.group(2)!);
    final int? total = int.tryParse(match.group(3)!);
    if (number == null || total == null || number < 1 || total < 2 || number > total) return null;

    return _LegacyInstallmentInfo(
      baseDescription: match.group(1)!.trim(),
      number: number,
      total: total,
    );
  }

  @override
  Future<CreditCardTransactionEntity> save(CreditCardTransactionEntity entity, {ITransactionExecutor? txn}) async {
    final CreditCardTransactionModel transaction = await _dataSource.upsert(
      CreditCardTransactionFactory.fromEntity(entity),
      txn: txn,
    );

    _eventNotifier.notify(EventType.creditCard);

    return CreditCardTransactionFactory.toEntity(transaction);
  }

  @override
  Future<void> saveMany(List<CreditCardTransactionEntity> transactions, {ITransactionExecutor? txn}) async {
    if (txn == null) {
      await _dbTransaction.openTransaction((newTxn) => saveMany(transactions, txn: newTxn));
      return;
    }

    for (final transaction in transactions) {
      await _dataSource.upsert(CreditCardTransactionFactory.fromEntity(transaction), txn: txn);
    }

    _eventNotifier.notify(EventType.creditCard);
  }

  @override
  Future<void> delete(CreditCardTransactionEntity entity, {ITransactionExecutor? txn}) async {
    await _dataSource.delete(CreditCardTransactionFactory.fromEntity(entity), txn: txn);

    _eventNotifier.notify(EventType.creditCard);
  }

  @override
  Future<void> deleteMany(List<CreditCardTransactionEntity> entities, {ITransactionExecutor? txn}) async {
    if (txn == null) {
      return await _dbTransaction.openTransaction((newTxn) => deleteMany(entities, txn: newTxn));
    }

    for (final entity in entities) {
      await delete(entity, txn: txn);
    }

    _eventNotifier.notify(EventType.creditCard);
  }
}

class _LegacyInstallmentInfo {
  final String baseDescription;
  final int number;
  final int total;

  const _LegacyInstallmentInfo({
    required this.baseDescription,
    required this.number,
    required this.total,
  });
}
