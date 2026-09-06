import 'package:rallet/features/transactions/domain/entities/i_transaction_entity.dart';
import 'package:rallet/shared/domain/entities/entity.dart';

class ExpenseEntity extends Entity implements ITransactionEntity {
  String description;
  late double _amount;

  bool paid;
  String? observation;

  String? idCategory;

  String? idCreditCard;
  String? idCreditCardTransaction;

  String? idAccount;

  /// Identifica se este lançamento faz parte de uma recorrência mensal.
  bool recurring;

  /// Identificador compartilhado entre as ocorrências da mesma recorrência.
  String? recurrenceId;

  /// Valor esperado antes da realização, quando o usuário opta por
  /// acompanhar a diferença entre planejado e realizado.
  double? expectedAmount;

  /// Diferencia uma simples correção de cadastro de uma variação real.
  bool trackVariance;

  /// Momento em que o usuário confirmou explicitamente que a diferença entre
  /// o valor anterior e o realizado deve entrar no relatório.
  DateTime? varianceRegisteredAt;

  /// Momento em que a despesa foi efetivamente paga. A data original do
  /// lançamento continua sendo a data prevista/competência.
  DateTime? realizedAt;

  @override
  DateTime date;

  @override
  double get amount => _amount;

  set amount(double value) => _amount = -value.abs();

  double get realizedAmount => amount.abs();

  /// Positivo = economia. Negativo = gasto acima do esperado.
  double get varianceAmount {
    if (!trackVariance ||
        expectedAmount == null ||
        varianceRegisteredAt == null) return 0;
    return expectedAmount!.abs() - realizedAmount;
  }

  ExpenseEntity({
    required super.id,
    required super.createdAt,
    required super.deletedAt,
    required this.description,
    required double amount,
    required this.date,
    required this.paid,
    required this.observation,
    required this.idAccount,
    required this.idCategory,
    required this.idCreditCard,
    required this.idCreditCardTransaction,
    this.recurring = false,
    this.recurrenceId,
    this.expectedAmount,
    this.trackVariance = false,
    this.varianceRegisteredAt,
    this.realizedAt,
  }) {
    this.amount = amount;
  }

  ExpenseEntity clone() {
    return ExpenseEntity(
      id: id,
      createdAt: createdAt,
      deletedAt: deletedAt,
      description: description,
      amount: amount,
      date: date,
      paid: paid,
      observation: observation,
      idAccount: idAccount,
      idCategory: idCategory,
      idCreditCard: idCreditCard,
      idCreditCardTransaction: idCreditCardTransaction,
      recurring: recurring,
      recurrenceId: recurrenceId,
      expectedAmount: expectedAmount,
      trackVariance: trackVariance,
      varianceRegisteredAt: varianceRegisteredAt,
      realizedAt: realizedAt,
    );
  }
}
