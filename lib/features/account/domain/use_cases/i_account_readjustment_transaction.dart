import 'package:rallet/features/account/domain/entities/account_entity.dart';

abstract interface class IAccountReadjustmentTransaction {
  Future<AccountEntity> createTransaction({required AccountEntity account, required double readjustmentValue, required String description});
}
