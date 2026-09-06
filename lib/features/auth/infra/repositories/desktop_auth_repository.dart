import 'package:rallet/features/auth/domain/entities/auth_entity.dart';
import 'package:rallet/features/auth/domain/entities/signup_entity.dart';
import 'package:rallet/features/auth/domain/enums/auth_type.dart';
import 'package:rallet/features/auth/domain/repositories/i_auth_repository.dart';

/// Sessão local da versão Linux.
///
/// As informações financeiras permanecem no SQLite local do Rallet. Essa
/// sessão apenas remove a dependência do Firebase no início do aplicativo.
class DesktopAuthRepository implements IAuthRepository {
  AuthEntity get _desktopAuth => AuthEntity(
        id: 'xp-finance-linux-local',
        createdAt: null,
        deletedAt: null,
        email: 'desktop@xpfinance.local',
        emailVerified: true,
        password: null,
        type: AuthType.email,
      );

  Never _unsupported() => throw UnsupportedError(
        'Autenticação em nuvem não está disponível na versão Linux.',
      );

  @override
  Future<AuthEntity?> find() async => _desktopAuth;

  @override
  Future<bool> checkEmailVerified() async => true;

  @override
  Future<bool> emailAlreadyExists(String email) async => false;

  @override
  Future<AuthEntity> loginWithEmailAndPassword(AuthEntity entity) async =>
      _unsupported();

  @override
  Future<AuthEntity?> loginWithGoogle(AuthEntity entity) async =>
      _unsupported();

  @override
  Future<void> saveEmailVerified(bool isEmailVerified) async {}

  @override
  Future<void> sendEmailResetPassword(String email) async => _unsupported();

  @override
  Future<void> sendEmailVerification() async => _unsupported();

  @override
  Future<SignupEntity> signupWithEmailAndPassword(SignupEntity entity) async =>
      _unsupported();

  @override
  Future<SignupEntity?> signupWithGoogle() async => _unsupported();
}
