import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local_transaction.dart';

abstract interface class ICardCashAdvanceRepository {
  Future<CardCashAdvancePlanEntity> save(CardCashAdvancePlanEntity entity, {ITransactionExecutor? txn});
  Future<CardCashAdvancePlanEntity?> findById(String id, {ITransactionExecutor? txn});
  Future<List<CardCashAdvancePlanEntity>> findPlanned({ITransactionExecutor? txn});
  Future<List<CardCashAdvancePlanEntity>> findAll({bool deleted = false, ITransactionExecutor? txn});
  Future<void> delete(CardCashAdvancePlanEntity entity, {ITransactionExecutor? txn});
}
