import 'package:rallet/features/card_cash_advance/domain/enums/card_cash_advance_status_enum.dart';
import 'package:rallet/shared/infra/models/model.dart';

class CardCashAdvancePlanModel extends Model {
  final String description;
  final String idAccount;
  final String idCreditCard;
  final double amountReceived;
  final double amountCharged;
  final DateTime plannedDate;
  final DateTime billDueDate;
  final CardCashAdvanceStatusEnum status;
  final DateTime? realizedAt;
  final String? idStatement;
  final String? idCreditCardTransaction;

  CardCashAdvancePlanModel({
    required super.id,
    required super.createdAt,
    required super.deletedAt,
    required this.description,
    required this.idAccount,
    required this.idCreditCard,
    required this.amountReceived,
    required this.amountCharged,
    required this.plannedDate,
    required this.billDueDate,
    required this.status,
    required this.realizedAt,
    required this.idStatement,
    required this.idCreditCardTransaction,
  });

  @override
  CardCashAdvancePlanModel clone() => CardCashAdvancePlanModel(
        id: id,
        createdAt: createdAt,
        deletedAt: deletedAt,
        description: description,
        idAccount: idAccount,
        idCreditCard: idCreditCard,
        amountReceived: amountReceived,
        amountCharged: amountCharged,
        plannedDate: plannedDate,
        billDueDate: billDueDate,
        status: status,
        realizedAt: realizedAt,
        idStatement: idStatement,
        idCreditCardTransaction: idCreditCardTransaction,
      );

  @override
  Map<String, dynamic> toMap() => {
        ...baseMap(),
        'description': description,
        'id_account': idAccount,
        'id_credit_card': idCreditCard,
        'amount_received': amountReceived,
        'amount_charged': amountCharged,
        'planned_date': plannedDate.toIso8601String(),
        'bill_due_date': billDueDate.toIso8601String(),
        'status': status.value,
        'realized_at': realizedAt?.toIso8601String(),
        'id_statement': idStatement,
        'id_credit_card_transaction': idCreditCardTransaction,
      };
}
