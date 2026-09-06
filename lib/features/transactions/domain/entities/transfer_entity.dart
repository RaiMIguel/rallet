import 'package:rallet/features/transactions/domain/entities/i_transaction_entity.dart';
import 'package:rallet/shared/domain/entities/entity.dart';

class TransferEntity extends Entity implements ITransactionEntity {
  @override
  double amount;

  @override
  DateTime date;

  String? idAccountFrom;
  String? idAccountTo;

  TransferEntity({
    required super.id,
    required super.createdAt,
    required super.deletedAt,
    required this.amount,
    required this.date,
    required this.idAccountFrom,
    required this.idAccountTo,
  });
}
