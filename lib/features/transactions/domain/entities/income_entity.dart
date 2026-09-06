import 'package:rallet/features/transactions/domain/entities/i_transaction_entity.dart';
import 'package:rallet/shared/domain/entities/entity.dart';

class IncomeEntity extends Entity implements ITransactionEntity {
  String description;

  @override
  double amount;

  @override
  DateTime date;

  bool received;
  String? observation;

  String? idAccount;
  String? idCategory;

  /// Identifica se este lançamento faz parte de uma recorrência mensal.
  bool recurring;

  /// Identificador compartilhado entre as ocorrências da mesma recorrência.
  String? recurrenceId;

  /// Valor esperado antes da realização, quando a diferença deve ser auditada.
  double? expectedAmount;

  /// Diferencia correção de cadastro de variação real do planejamento.
  bool trackVariance;

  /// Momento em que o usuário confirmou explicitamente a diferença real.
  DateTime? varianceRegisteredAt;

  /// Momento em que a receita foi efetivamente recebida. A data original do
  /// lançamento continua sendo a data prevista/competência.
  DateTime? realizedAt;

  /// Positivo = receita acima do esperado. Negativo = abaixo do esperado.
  double get varianceAmount {
    if (!trackVariance ||
        expectedAmount == null ||
        varianceRegisteredAt == null) return 0;
    return amount - expectedAmount!;
  }

  IncomeEntity({
    required super.id,
    required super.createdAt,
    required super.deletedAt,
    required this.description,
    required this.amount,
    required this.date,
    required this.received,
    required this.observation,
    required this.idAccount,
    required this.idCategory,
    this.recurring = false,
    this.recurrenceId,
    this.expectedAmount,
    this.trackVariance = false,
    this.varianceRegisteredAt,
    this.realizedAt,
  });

  IncomeEntity clone() {
    return IncomeEntity(
      id: id,
      createdAt: createdAt,
      deletedAt: deletedAt,
      description: description,
      amount: amount,
      date: date,
      received: received,
      observation: observation,
      idAccount: idAccount,
      idCategory: idCategory,
      recurring: recurring,
      recurrenceId: recurrenceId,
      expectedAmount: expectedAmount,
      trackVariance: trackVariance,
      varianceRegisteredAt: varianceRegisteredAt,
      realizedAt: realizedAt,
    );
  }
}
