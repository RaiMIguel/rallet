import 'package:rallet/features/credit_card/domain/entities/credit_card_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_with_bill_entity.dart';

abstract interface class ICreditCardFind {
  Future<List<CreditCardEntity>> findAll();

  Future<CreditCardEntity?> findById(
    String id, {
    bool deleted = false,
  });

  Future<List<CreditCardWithBillEntity>>
      findCreditCardsWithBill();

  Future<List<CreditCardBillEntity>> findBillsByPeriod(
    DateTime startDate,
    DateTime endDate,
  );

  /// Retorna todas as faturas cujo vencimento pertence ao período,
  /// inclusive faturas já pagas. Útil para relatórios históricos.
  Future<List<CreditCardBillEntity>> findAllBillsByPeriod(
    DateTime startDate,
    DateTime endDate,
  );

  Future<CreditCardEntity?> findByIdAccount(String id);
}