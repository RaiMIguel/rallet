import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';

abstract interface class ICreditCardSave {
  Future<CreditCardEntity> save(CreditCardEntity entity);
}
