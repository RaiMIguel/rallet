import 'package:rallet/shared/infra/models/model.dart';

class CreditCardTransactionModel extends Model {
  final String description;
  final double amount;
  final DateTime date;
  final String idCategory;

  final String idCreditCard;
  final String idCreditCardBill;

  final String? observation;
  final String? installmentGroupId;
  final int? installmentNumber;
  final int? installmentCount;
  final String? cashAdvancePlanId;
  final double? cashAdvancePrincipal;
  final String? plannedPurchaseId;
  final double? plannedPurchasePrincipal;

  CreditCardTransactionModel({
    required super.id,
    required super.createdAt,
    required super.deletedAt,
    required this.description,
    required this.amount,
    required this.date,
    required this.idCategory,
    required this.idCreditCard,
    required this.idCreditCardBill,
    required this.observation,
    this.installmentGroupId,
    this.installmentNumber,
    this.installmentCount,
    this.cashAdvancePlanId,
    this.cashAdvancePrincipal,
    this.plannedPurchaseId,
    this.plannedPurchasePrincipal,
  });

  @override
  CreditCardTransactionModel clone() {
    return CreditCardTransactionModel(
      id: id,
      createdAt: createdAt,
      deletedAt: deletedAt,
      description: description,
      amount: amount,
      date: date,
      idCategory: idCategory,
      idCreditCard: idCreditCard,
      idCreditCardBill: idCreditCardBill,
      observation: observation,
      installmentGroupId: installmentGroupId,
      installmentNumber: installmentNumber,
      installmentCount: installmentCount,
      cashAdvancePlanId: cashAdvancePlanId,
      cashAdvancePrincipal: cashAdvancePrincipal,
      plannedPurchaseId: plannedPurchaseId,
      plannedPurchasePrincipal: plannedPurchasePrincipal,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      ...baseMap(),
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
      'id_category': idCategory,
      'id_credit_card': idCreditCard,
      'id_credit_card_bill': idCreditCardBill,
      'observation': observation,
      'installment_group_id': installmentGroupId,
      'installment_number': installmentNumber,
      'installment_count': installmentCount,
      'cash_advance_plan_id': cashAdvancePlanId,
      'cash_advance_principal': cashAdvancePrincipal,
      'planned_purchase_id': plannedPurchaseId,
      'planned_purchase_principal': plannedPurchasePrincipal,
    };
  }
}
