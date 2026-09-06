import 'package:rallet/features/transactions/domain/entities/i_transaction_entity.dart';
import 'package:rallet/shared/domain/entities/entity.dart';

class CreditCardTransactionEntity extends Entity implements ITransactionEntity {
  String description;

  @override
  double amount;

  @override
  DateTime date;

  String? idCategory;

  String? idCreditCard;
  String? idCreditCardBill;

  String? observation;

  /// Identificador compartilhado entre as parcelas da mesma compra.
  String? installmentGroupId;

  /// Número desta parcela dentro da compra parcelada (ex.: 4 de 21).
  int? installmentNumber;

  /// Quantidade total de parcelas da compra.
  int? installmentCount;

  /// Operação de crédito/empréstimo pelo cartão associada a este lançamento.
  String? cashAdvancePlanId;

  /// Parte principal recebida na conta. Nos relatórios somente a diferença
  /// entre amount e este principal é tratada como custo financeiro.
  double? cashAdvancePrincipal;

  /// Planejamento de compra que originou esta transação, quando aplicável.
  String? plannedPurchaseId;

  /// Parte do valor desta transação que corresponde ao preço-base da compra.
  /// A diferença para amount é custo financeiro do parcelamento.
  double? plannedPurchasePrincipal;

  bool get isInstallment =>
      installmentCount != null &&
      installmentCount! > 1 &&
      installmentNumber != null;

  CreditCardTransactionEntity({
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

  CreditCardTransactionEntity clone() {
    return CreditCardTransactionEntity(
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
}
