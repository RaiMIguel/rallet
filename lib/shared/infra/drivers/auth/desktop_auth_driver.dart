import 'package:rallet/features/auth/infra/models/auth_model.dart';
import 'package:rallet/features/auth/infra/models/signup_model.dart';
import 'package:rallet/shared/infra/drivers/auth/i_auth_driver.dart';

/// Driver local usado pela versão Linux.
///
/// A autenticação Firebase/Google continua sendo usada nas plataformas móveis,
/// mas não é inicializada no Linux.
class DesktopAuthDriver implements IAuthDriver {
  Never _unsupported() => throw UnsupportedError(
        'Autenticação em nuvem não está disponível na versão Linux.',
      );

  @override
  Future<bool> checkEmailVerified() async => true;

  @override
  Future<bool> checkIsLogged() async => true;

  @override
  Future<AuthModel?> loginWithGoogle() async => _unsupported();

  @override
  Future<void> loginWithEmailAndPassword({
    required String email,
    required String password,
  }) async =>
      _unsupported();

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendEmailResetPassword(String email) async => _unsupported();

  @override
  Future<void> sendVerificationEmail() async => _unsupported();

  @override
  Future<SignupModel?> signupWithGoogle() async => _unsupported();

  @override
  Future<void> signupWithEmailAndPassword({
    required String email,
    required String password,
  }) async =>
      _unsupported();
}
