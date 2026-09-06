import 'package:rallet/features/credit_card/domain/entities/credit_card_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';

class CreditCardWithBillEntity {
  final CreditCardEntity creditCard;
  final CreditCardBillEntity? bill;

  CreditCardWithBillEntity({required this.creditCard, required this.bill});
}
