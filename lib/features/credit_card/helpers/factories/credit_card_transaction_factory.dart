import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/features/credit_card/infra/models/credit_card_transaction_model.dart';

abstract class CreditCardTransactionFactory {
  static CreditCardTransactionModel fromEntity(CreditCardTransactionEntity entity) {
    return CreditCardTransactionModel(
      id: entity.id,
      createdAt: entity.createdAt,
      deletedAt: entity.deletedAt,
      description: entity.description,
      amount: entity.amount,
      date: entity.date,
      idCategory: entity.idCategory!,
      idCreditCard: entity.idCreditCard!,
      idCreditCardBill: entity.idCreditCardBill!,
      observation: entity.observation,
      installmentGroupId: entity.installmentGroupId,
      installmentNumber: entity.installmentNumber,
      installmentCount: entity.installmentCount,
      cashAdvancePlanId: entity.cashAdvancePlanId,
      cashAdvancePrincipal: entity.cashAdvancePrincipal,
      plannedPurchaseId: entity.plannedPurchaseId,
      plannedPurchasePrincipal: entity.plannedPurchasePrincipal,
    );
  }

  static CreditCardTransactionEntity toEntity(CreditCardTransactionModel model) {
    return CreditCardTransactionEntity(
      id: model.id,
      createdAt: model.createdAt,
      deletedAt: model.deletedAt,
      description: model.description,
      amount: model.amount,
      date: model.date,
      idCategory: model.idCategory,
      idCreditCard: model.idCreditCard,
      idCreditCardBill: model.idCreditCardBill,
      observation: model.observation,
      installmentGroupId: model.installmentGroupId,
      installmentNumber: model.installmentNumber,
      installmentCount: model.installmentCount,
      cashAdvancePlanId: model.cashAdvancePlanId,
      cashAdvancePrincipal: model.cashAdvancePrincipal,
      plannedPurchaseId: model.plannedPurchaseId,
      plannedPurchasePrincipal: model.plannedPurchasePrincipal,
    );
  }

  static CreditCardTransactionEntity newEntity() {
    return CreditCardTransactionEntity(
      id: null,
      createdAt: null,
      deletedAt: null,
      description: '',
      amount: 0,
      date: DateTime.now(),
      idCategory: null,
      idCreditCard: null,
      idCreditCardBill: null,
      observation: null,
      installmentGroupId: null,
      installmentNumber: null,
      installmentCount: null,
      cashAdvancePlanId: null,
      cashAdvancePrincipal: null,
      plannedPurchaseId: null,
      plannedPurchasePrincipal: null,
    );
  }
}
