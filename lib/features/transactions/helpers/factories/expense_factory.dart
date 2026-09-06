import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/infra/models/expense_model.dart';

abstract class ExpenseFactory {
  static ExpenseModel fromEntity(ExpenseEntity entity) {
    return ExpenseModel(
      id: entity.id,
      createdAt: entity.createdAt,
      deletedAt: entity.deletedAt,
      description: entity.description,
      amount: entity.amount,
      date: entity.date,
      paid: entity.paid,
      observation: entity.observation,
      idAccount: entity.idAccount!,
      idCategory: entity.idCategory!,
      idCreditCard: entity.idCreditCard,
      idCreditCardTransaction: entity.idCreditCardTransaction,
      recurring: entity.recurring,
      recurrenceId: entity.recurrenceId,
      expectedAmount: entity.expectedAmount,
      trackVariance: entity.trackVariance,
      varianceRegisteredAt: entity.varianceRegisteredAt,
      realizedAt: entity.realizedAt,
    );
  }

  static ExpenseEntity toEntity(ExpenseModel model) {
    return ExpenseEntity(
      id: model.id,
      createdAt: model.createdAt,
      deletedAt: model.deletedAt,
      description: model.description,
      amount: model.amount,
      date: model.date,
      paid: model.paid,
      observation: model.observation,
      idAccount: model.idAccount,
      idCategory: model.idCategory,
      idCreditCard: model.idCreditCard,
      idCreditCardTransaction: model.idCreditCardTransaction,
      recurring: model.recurring,
      recurrenceId: model.recurrenceId,
      expectedAmount: model.expectedAmount,
      trackVariance: model.trackVariance,
      varianceRegisteredAt: model.varianceRegisteredAt,
      realizedAt: model.realizedAt,
    );
  }

  static ExpenseEntity newEntity() {
    return ExpenseEntity(
      id: null,
      createdAt: null,
      deletedAt: null,
      description: '',
      amount: 0,
      date: DateTime.now(),
      paid: true,
      observation: null,
      idAccount: null,
      idCategory: null,
      idCreditCard: null,
      idCreditCardTransaction: null,
      recurring: false,
      recurrenceId: null,
      expectedAmount: null,
      trackVariance: false,
      varianceRegisteredAt: null,
      realizedAt: null,
    );
  }
}
