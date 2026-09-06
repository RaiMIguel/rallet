import 'package:rallet/features/auth/domain/entities/auth_entity.dart';
import 'package:rallet/features/user_account/domain/entities/user_account_entity.dart';

class SignupEntity {
  AuthEntity auth;
  UserAccountEntity userAccount;

  SignupEntity({required this.auth, required this.userAccount});
}
