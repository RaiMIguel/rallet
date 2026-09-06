import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';
import 'package:rallet/features/purchase_planning/domain/entities/purchase_simulation_entity.dart';

abstract interface class IPurchasePlanning {
  Future<PlannedPurchaseEntity> save(PlannedPurchaseEntity entity);
  Future<void> delete(PlannedPurchaseEntity entity);
  Future<List<PlannedPurchaseEntity>> findAll();
  Future<void> realizeCreditCardPurchase(PlannedPurchaseEntity entity);
  Future<PurchaseSimulationEntity> simulate({
    required double amount,
    required DateTime desiredDate,
    double reserveAmount = 0,
    PlannedPurchasePaymentType paymentType = PlannedPurchasePaymentType.cash,
    String? idCreditCard,
    String? idAccount,
    int installmentCount = 1,
    double? totalCharged,
    String? editingPlanId,
  });
}
