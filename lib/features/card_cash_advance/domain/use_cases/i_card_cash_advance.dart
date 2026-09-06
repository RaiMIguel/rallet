import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';

abstract interface class ICardCashAdvance {
  Future<CardCashAdvancePlanEntity> savePlan(CardCashAdvancePlanEntity entity);
  Future<CardCashAdvancePlanEntity> realize(CardCashAdvancePlanEntity entity);
  Future<CardCashAdvancePlanEntity> undoRealization(CardCashAdvancePlanEntity entity);
  Future<bool> hasMissingLinkedTransaction(CardCashAdvancePlanEntity entity);
  Future<CardCashAdvancePlanEntity> repairMissingLinkedTransaction(CardCashAdvancePlanEntity entity);
  Future<void> cancel(CardCashAdvancePlanEntity entity);
  Future<CardCashAdvancePlanEntity?> findById(String id);
  Future<List<CardCashAdvancePlanEntity>> findPlanned();
  Future<List<CardCashAdvancePlanEntity>> findAll();
}
