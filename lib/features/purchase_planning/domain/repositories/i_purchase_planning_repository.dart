import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';

abstract interface class IPurchasePlanningRepository {
  Future<PlannedPurchaseEntity> save(PlannedPurchaseEntity entity);
  Future<void> delete(PlannedPurchaseEntity entity);
  Future<List<PlannedPurchaseEntity>> findAll();
  Future<PlannedPurchaseEntity?> findById(String id);
}
