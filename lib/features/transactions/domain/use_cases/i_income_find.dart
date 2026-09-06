import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/domain/entities/transaction_by_text_entity.dart';

abstract interface class IIncomeFind {
  Future<List<TransactionByTextEntity>> findByText(String text);

  Future<IncomeEntity?> findById(String id);
}
