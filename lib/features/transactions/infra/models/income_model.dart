import 'package:rallet/shared/infra/models/model.dart';

class IncomeModel extends Model {
  String description;
  double amount;
  DateTime date;
  bool received;
  String? observation;

  String idAccount;
  String idCategory;

  bool recurring;
  String? recurrenceId;
  double? expectedAmount;
  bool trackVariance;
  DateTime? varianceRegisteredAt;
  DateTime? realizedAt;

  IncomeModel({
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
    required this.recurring,
    required this.recurrenceId,
    required this.expectedAmount,
    required this.trackVariance,
    this.varianceRegisteredAt,
    this.realizedAt,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      ...baseMap(),
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
      'received': received ? 1 : 0,
      'observation': observation,
      'id_account': idAccount,
      'id_category': idCategory,
      'recurring': recurring ? 1 : 0,
      'recurrence_id': recurrenceId,
      'expected_amount': expectedAmount,
      'track_variance': trackVariance ? 1 : 0,
      'variance_registered_at': varianceRegisteredAt?.toIso8601String(),
      'realized_at': realizedAt?.toIso8601String(),
    };
  }

  @override
  IncomeModel clone() {
    return IncomeModel(
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
