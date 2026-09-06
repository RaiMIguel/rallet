import 'package:rallet/features/credit_card/domain/entities/credit_card_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/shared/extensions/double_extension.dart';

/// Visão do cartão no mês selecionado da Home.
///
/// [billAmount] vem da fatura já existente. [plannedAmount] contém apenas
/// compromissos ainda planejados que ainda não viraram transação real de cartão.
/// Assim a Home consegue mostrar previsão sem criar lançamento e sem duplicar
/// valores que já estejam na fatura.
class HomeCreditCardMonthEntity {
  final CreditCardEntity creditCard;
  final CreditCardBillEntity? bill;
  final double billAmount;
  final double plannedAmount;

  const HomeCreditCardMonthEntity({
    required this.creditCard,
    required this.bill,
    required this.billAmount,
    required this.plannedAmount,
  });

  double get forecastAmount => (billAmount + plannedAmount).toRound(2);
}
