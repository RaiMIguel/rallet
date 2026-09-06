import 'package:collection/collection.dart';
import 'package:rallet/features/category/domain/entities/category_entity.dart';
import 'package:rallet/features/transactions/domain/entities/i_transaction_entity.dart';

class ReportCategoryEntity {
  final CategoryEntity category;

  final List<ITransactionEntity> transactions;

  double get amount => transactions.map((transaction) => transaction.amount).sum;

  ReportCategoryEntity({required this.category, required this.transactions});
}
