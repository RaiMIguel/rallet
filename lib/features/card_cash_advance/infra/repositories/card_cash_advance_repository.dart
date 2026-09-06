import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/card_cash_advance/domain/enums/card_cash_advance_status_enum.dart';
import 'package:rallet/features/card_cash_advance/domain/repositories/i_card_cash_advance_repository.dart';
import 'package:rallet/features/card_cash_advance/infra/data_sources/i_card_cash_advance_local_data_source.dart';
import 'package:rallet/features/card_cash_advance/infra/models/card_cash_advance_plan_model.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local_transaction.dart';

class CardCashAdvanceRepository implements ICardCashAdvanceRepository {
  final ICardCashAdvanceLocalDataSource _dataSource;

  CardCashAdvanceRepository({required ICardCashAdvanceLocalDataSource dataSource})
      : _dataSource = dataSource;

  CardCashAdvancePlanModel _toModel(CardCashAdvancePlanEntity entity) => CardCashAdvancePlanModel(
        id: entity.id,
        createdAt: entity.createdAt,
        deletedAt: entity.deletedAt,
        description: entity.description,
        idAccount: entity.idAccount,
        idCreditCard: entity.idCreditCard,
        amountReceived: entity.amountReceived,
        amountCharged: entity.amountCharged,
        plannedDate: entity.plannedDate,
        billDueDate: entity.billDueDate,
        status: entity.status,
        realizedAt: entity.realizedAt,
        idStatement: entity.idStatement,
        idCreditCardTransaction: entity.idCreditCardTransaction,
      );

  CardCashAdvancePlanEntity _toEntity(CardCashAdvancePlanModel model) => CardCashAdvancePlanEntity(
        id: model.id,
        createdAt: model.createdAt,
        deletedAt: model.deletedAt,
        description: model.description,
        idAccount: model.idAccount,
        idCreditCard: model.idCreditCard,
        amountReceived: model.amountReceived,
        amountCharged: model.amountCharged,
        plannedDate: model.plannedDate,
        billDueDate: model.billDueDate,
        status: model.status,
        realizedAt: model.realizedAt,
        idStatement: model.idStatement,
        idCreditCardTransaction: model.idCreditCardTransaction,
      );

  @override
  Future<CardCashAdvancePlanEntity> save(CardCashAdvancePlanEntity entity, {ITransactionExecutor? txn}) async =>
      _toEntity(await _dataSource.upsert(_toModel(entity), txn: txn));

  @override
  Future<CardCashAdvancePlanEntity?> findById(String id, {ITransactionExecutor? txn}) async {
    final model = await _dataSource.findById(id, txn: txn);
    return model == null ? null : _toEntity(model);
  }

  @override
  Future<List<CardCashAdvancePlanEntity>> findPlanned({ITransactionExecutor? txn}) async =>
      (await _dataSource.findAll(where: 'status = ?', whereArgs: [CardCashAdvanceStatusEnum.planned.value], txn: txn))
          .map(_toEntity)
          .toList();

  @override
  Future<List<CardCashAdvancePlanEntity>> findAll({bool deleted = false, ITransactionExecutor? txn}) async =>
      (await _dataSource.findAll(deleted: deleted, txn: txn)).map(_toEntity).toList();

  @override
  Future<void> delete(CardCashAdvancePlanEntity entity, {ITransactionExecutor? txn}) =>
      _dataSource.delete(_toModel(entity), txn: txn);
}
