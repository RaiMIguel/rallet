import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/infra/models/income_model.dart';

abstract class IncomeFactory {
  static IncomeModel fromEntity(IncomeEntity entity) {
    return IncomeModel(
      id: entity.id,
      createdAt: entity.createdAt,
      deletedAt: entity.deletedAt,
      description: entity.description,
      amount: entity.amount,
      date: entity.date,
      received: entity.received,
      observation: entity.observation,
      idAccount: entity.idAccount!,
      idCategory: entity.idCategory!,
      recurring: entity.recurring,
      recurrenceId: entity.recurrenceId,
      expectedAmount: entity.expectedAmount,
      trackVariance: entity.trackVariance,
      varianceRegisteredAt: entity.varianceRegisteredAt,
      realizedAt: entity.realizedAt,
    );
  }

  static IncomeEntity toEntity(IncomeModel model) {
    return IncomeEntity(
      id: model.id,
      createdAt: model.createdAt,
      deletedAt: model.deletedAt,
      description: model.description,
      amount: model.amount,
      date: model.date,
      received: model.received,
      observation: model.observation,
      idAccount: model.idAccount,
      idCategory: model.idCategory,
      recurring: model.recurring,
      recurrenceId: model.recurrenceId,
      expectedAmount: model.expectedAmount,
      trackVariance: model.trackVariance,
      varianceRegisteredAt: model.varianceRegisteredAt,
      realizedAt: model.realizedAt,
    );
  }

  static IncomeEntity newEntity() {
    return IncomeEntity(
      id: null,
      createdAt: null,
      deletedAt: null,
      description: '',
      amount: 0,
      date: DateTime.now(),
      received: true,
      observation: null,
      idAccount: null,
      idCategory: null,
      recurring: false,
      recurrenceId: null,
      expectedAmount: null,
      trackVariance: false,
      varianceRegisteredAt: null,
      realizedAt: null,
    );
  }
}
