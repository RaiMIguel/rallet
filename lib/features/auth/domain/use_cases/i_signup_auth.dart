import 'package:rallet/features/auth/domain/entities/signup_entity.dart';

abstract interface class ISignupAuth {
  Future<void> signup(SignupEntity entity);

  Future<void> sendEmailVerification();

  Future<bool> emailAlreadyExists(String email);

  Future<bool> checkEmailVerified();

  Future<void> completeRegistration();
}