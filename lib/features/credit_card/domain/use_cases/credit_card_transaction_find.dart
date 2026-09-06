import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/features/credit_card/domain/repositories/i_credit_card_transaction_repository.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_transaction_find.dart';

class CreditCardTransactionFind implements ICreditCardTransactionFind {
  final ICreditCardTransactionRepository _repository;

  CreditCardTransactionFind({required ICreditCardTransactionRepository repository}) : _repository = repository;

  @override
  Future<CreditCardTransactionEntity?> findById(String id) => _repository.findById(id);

  @override
  Future<List<CreditCardTransactionEntity>> findInstallments(
    CreditCardTransactionEntity entity,
  ) =>
      _repository.findInstallments(entity);
}
