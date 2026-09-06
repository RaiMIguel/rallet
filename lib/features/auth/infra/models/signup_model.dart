import 'package:rallet/features/auth/infra/models/auth_model.dart';
import 'package:rallet/features/user_account/infra/models/user_account_model.dart';

class SignupModel {
  AuthModel auth;
  UserAccountModel userAccount;

  SignupModel({required this.auth, required this.userAccount});
}
