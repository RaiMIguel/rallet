import 'package:rallet/shared/infra/models/model.dart';

class ExpenseModel extends Model {
  String description;
  double amount;
  DateTime date;
  bool paid;
  String? observation;

  String idAccount;
  String idCategory;

  String? idCreditCard;
  String? idCreditCardTransaction;

  bool recurring;
  String? recurrenceId;
  double? expectedAmount;
  bool trackVariance;
  DateTime? varianceRegisteredAt;
  DateTime? realizedAt;

  ExpenseModel({
    required super.id,
    required super.createdAt,
    required super.deletedAt,
    required this.description,
    required this.amount,
    required this.date,
    required this.paid,
    required this.observation,
    required this.idAccount,
    required this.idCategory,
    required this.idCreditCard,
    required this.idCreditCardTransaction,
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
      'paid': paid ? 1 : 0,
      'observation': observation,
      'id_account': idAccount,
      'id_category': idCategory,
      'id_credit_card': idCreditCard,
      'id_credit_card_transaction': idCreditCardTransaction,
      'recurring': recurring ? 1 : 0,
      'recurrence_id': recurrenceId,
      'expected_amount': expectedAmount,
      'track_variance': trackVariance ? 1 : 0,
      'variance_registered_at': varianceRegisteredAt?.toIso8601String(),
      'realized_at': realizedAt?.toIso8601String(),
    };
  }

  @override
  ExpenseModel clone() {
    return ExpenseModel(
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
