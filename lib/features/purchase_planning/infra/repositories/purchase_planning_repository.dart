import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';
import 'package:rallet/features/purchase_planning/domain/repositories/i_purchase_planning_repository.dart';
import 'package:rallet/features/purchase_planning/infra/data_sources/i_purchase_planning_local_data_source.dart';
import 'package:rallet/features/purchase_planning/infra/models/planned_purchase_model.dart';

class PurchasePlanningRepository implements IPurchasePlanningRepository {
  final IPurchasePlanningLocalDataSource _dataSource;

  PurchasePlanningRepository({required IPurchasePlanningLocalDataSource dataSource})
      : _dataSource = dataSource;

  PlannedPurchaseModel _toModel(PlannedPurchaseEntity entity) => PlannedPurchaseModel(
        id: entity.id,
        createdAt: entity.createdAt,
        deletedAt: entity.deletedAt,
        description: entity.description,
        amount: entity.amount,
        plannedDate: entity.plannedDate,
        reserveAmount: entity.reserveAmount,
        paymentType: entity.paymentType,
        idCreditCard: entity.idCreditCard,
        installmentCount: entity.installmentCount,
        totalCharged: entity.totalCharged,
        firstBillDueDate: entity.firstBillDueDate,
        idCategory: entity.idCategory,
        idAccount: entity.idAccount,
        observation: entity.observation,
      );

  PlannedPurchaseEntity _toEntity(PlannedPurchaseModel model) => PlannedPurchaseEntity(
        id: model.id,
        createdAt: model.createdAt,
        deletedAt: model.deletedAt,
        description: model.description,
        amount: model.amount,
        plannedDate: model.plannedDate,
        reserveAmount: model.reserveAmount,
        paymentType: model.paymentType,
        idCreditCard: model.idCreditCard,
        installmentCount: model.installmentCount,
        totalCharged: model.totalCharged,
        firstBillDueDate: model.firstBillDueDate,
        idCategory: model.idCategory,
        idAccount: model.idAccount,
        observation: model.observation,
      );

  @override
  Future<PlannedPurchaseEntity> save(PlannedPurchaseEntity entity) async =>
      _toEntity(await _dataSource.upsert(_toModel(entity)));

  @override
  Future<void> delete(PlannedPurchaseEntity entity) => _dataSource.delete(_toModel(entity));

  @override
  Future<List<PlannedPurchaseEntity>> findAll() async =>
      (await _dataSource.findAll()).map(_toEntity).toList();

  @override
  Future<PlannedPurchaseEntity?> findById(String id) async {
    final model = await _dataSource.findById(id);
    return model == null ? null : _toEntity(model);
  }
}
