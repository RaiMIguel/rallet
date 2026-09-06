import 'package:rallet/features/credit_card/infra/models/credit_card_transaction_model.dart';
import 'package:rallet/shared/infra/data_sources/i_local_data_source.dart';

abstract interface class ICreditCardTransactionLocalDataSource implements ILocalDataSource<CreditCardTransactionModel> {
  Future<List<CreditCardTransactionModel>> findByPeriod({required DateTime? startDate, required DateTime? endDate, bool onlyPaid = false, bool ignoreBillPayment = false});
}
