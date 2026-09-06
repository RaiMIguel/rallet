import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';
import 'package:rallet/shared/infra/models/model.dart';

class PlannedPurchaseModel extends Model<PlannedPurchaseModel> {
  final String description;
  final double amount;
  final DateTime plannedDate;
  final double reserveAmount;
  final PlannedPurchasePaymentType paymentType;
  final String? idCreditCard;
  final int installmentCount;
  final double totalCharged;
  final DateTime? firstBillDueDate;
  final String? idCategory;
  final String? idAccount;
  final String? observation;

  PlannedPurchaseModel({
    required super.id,
    required super.createdAt,
    required super.deletedAt,
    required this.description,
    required this.amount,
    required this.plannedDate,
    required this.reserveAmount,
    required this.paymentType,
    required this.idCreditCard,
    required this.installmentCount,
    required this.totalCharged,
    required this.firstBillDueDate,
    required this.idCategory,
    required this.idAccount,
    required this.observation,
  });

  @override
  PlannedPurchaseModel clone() => PlannedPurchaseModel(
        id: id,
        createdAt: createdAt,
        deletedAt: deletedAt,
        description: description,
        amount: amount,
        plannedDate: plannedDate,
        reserveAmount: reserveAmount,
        paymentType: paymentType,
        idCreditCard: idCreditCard,
        installmentCount: installmentCount,
        totalCharged: totalCharged,
        firstBillDueDate: firstBillDueDate,
        idCategory: idCategory,
        idAccount: idAccount,
        observation: observation,
      );

  @override
  Map<String, dynamic> toMap() => {
        ...baseMap(),
        'description': description,
        'amount': amount,
        'planned_date': plannedDate.toIso8601String(),
        'reserve_amount': reserveAmount,
        'payment_type': paymentType.index,
        'id_credit_card': idCreditCard,
        'installment_count': installmentCount,
        'total_charged': totalCharged,
        'first_bill_due_date': firstBillDueDate?.toIso8601String(),
        'id_category': idCategory,
        'id_account': idAccount,
        'observation': observation,
      };
}
