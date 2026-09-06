import 'package:rallet/features/credit_card/domain/entities/credit_card_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_with_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/repositories/i_credit_card_repository.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_find.dart';

class CreditCardFind implements ICreditCardFind {
  final ICreditCardRepository _repository;

  CreditCardFind({
    required ICreditCardRepository repository,
  }) : _repository = repository;

  @override
  Future<List<CreditCardEntity>> findAll() =>
      _repository.findAll();

  @override
  Future<CreditCardEntity?> findById(
    String id, {
    bool deleted = false,
  }) =>
      _repository.findById(
        id,
        deleted: deleted,
      );

  @override
  Future<List<CreditCardWithBillEntity>>
      findCreditCardsWithBill() =>
          _repository.findCreditCardsWithBill();

  @override
  Future<List<CreditCardBillEntity>> findBillsByPeriod(
    DateTime startDate,
    DateTime endDate,
  ) =>
      _repository.findBillsByPeriod(
        startDate,
        endDate,
      );

  @override
  Future<List<CreditCardBillEntity>> findAllBillsByPeriod(
    DateTime startDate,
    DateTime endDate,
  ) =>
      _repository.findAllBillsByPeriod(
        startDate,
        endDate,
      );

  @override
  Future<CreditCardEntity?> findByIdAccount(String id) =>
      _repository.findByIdAccount(id);
}