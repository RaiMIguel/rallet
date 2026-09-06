import 'package:rallet/features/card_cash_advance/domain/enums/card_cash_advance_status_enum.dart';
import 'package:rallet/shared/domain/entities/entity.dart';
import 'package:rallet/shared/extensions/double_extension.dart';

class CardCashAdvancePlanEntity extends Entity {
  String description;
  String idAccount;
  String idCreditCard;
  double amountReceived;
  double amountCharged;
  DateTime plannedDate;
  DateTime billDueDate;
  CardCashAdvanceStatusEnum status;
  DateTime? realizedAt;
  String? idStatement;
  String? idCreditCardTransaction;

  CardCashAdvancePlanEntity({
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

  bool get isPlanned => status == CardCashAdvanceStatusEnum.planned;
  bool get isRealized => status == CardCashAdvanceStatusEnum.realized;

  /// Data usada para exibir a entrada vinculada em Transações. Planejamentos
  /// futuros usam a data prevista; operações realizadas usam a data real.
  DateTime get linkedEntryDate => isRealized ? (realizedAt ?? plannedDate) : plannedDate;

  bool linkedEntryBelongsToPeriod(DateTime start, DateTime end) =>
      !linkedEntryDate.isBefore(start) && !linkedEntryDate.isAfter(end);

  double get financialCost => (amountCharged - amountReceived).clamp(0, double.infinity).toDouble().toRound(2);

  CardCashAdvancePlanEntity clone() => CardCashAdvancePlanEntity(
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
}
