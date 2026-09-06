import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rallet/features/user_account/infra/data_sources/i_user_account_cloud_data_source.dart';
import 'package:rallet/features/user_account/infra/models/user_account_model.dart';
import 'package:rallet/shared/classes/connectivity_network.dart';
import 'package:rallet/shared/domain/domain/i_delete_app_data.dart';
import 'package:rallet/shared/presentation/ui/app_locale.dart';

/// Exclui a identidade online do usuário e, somente após a confirmação da
/// exclusão remota, limpa os dados locais do aparelho.
///
/// O fluxo exige autenticação recente porque o Firebase Authentication
/// protege operações sensíveis como a exclusão de conta.
class AccountDeletionService {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final IUserAccountCloudDataSource _userAccountCloudDataSource;
  final IDeleteAppData _deleteAppData;

  AccountDeletionService({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
    required IUserAccountCloudDataSource userAccountCloudDataSource,
    required IDeleteAppData deleteAppData,
  })  : _firebaseAuth = firebaseAuth,
        _googleSignIn = googleSignIn,
        _userAccountCloudDataSource = userAccountCloudDataSource,
        _deleteAppData = deleteAppData;

  Future<bool> requiresPassword() async {
    final User user = _firebaseAuth.currentUser ??
        (throw Exception(R.strings.failedToAuthenticate));

    return user.providerData.any((provider) => provider.providerId == 'password');
  }

  Future<void> deleteAccount({String? password}) async {
    await ConnectivityNetwork.hasInternet();

    final User originalUser = _firebaseAuth.currentUser ??
        (throw Exception(R.strings.failedToAuthenticate));
    final String email = originalUser.email ??
        (throw Exception(R.strings.failedToAuthenticate));

    final User authenticatedUser = await _reauthenticate(
      user: originalUser,
      email: email,
      password: password,
    );

    // O perfil é removido antes do Firebase Auth porque as regras do Firestore
    // exigem um usuário autenticado. Se a exclusão do Auth falhar, tentamos
    // restaurar o perfil para não deixar a conta em estado inconsistente.
    final UserAccountModel? deletedProfile =
        await _userAccountCloudDataSource.deleteByEmail(email);

    try {
      await authenticatedUser.delete();
    } on FirebaseAuthException catch (error) {
      if (deletedProfile != null) {
        try {
          await _userAccountCloudDataSource.restore(deletedProfile);
        } catch (_) {
          // Preserva o erro original. A recuperação remota é best effort.
        }
      }
      throw _friendlyAuthError(error);
    }

    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (_) {
      // A conta Firebase já foi excluída; falha no logout Google não deve
      // impedir a limpeza dos dados locais.
    }

    await _deleteAppData.delete();
  }

  Future<User> _reauthenticate({
    required User user,
    required String email,
    required String? password,
  }) async {
    try {
      final Set<String> providers =
          user.providerData.map((provider) => provider.providerId).toSet();

      debugPrint(
        'Rallet account deletion auth start: '
        'uid=${user.uid}; email=$email; providers=$providers',
      );

      if (providers.contains('password')) {
        if (password == null || password.isEmpty) {
          throw Exception(R.strings.incorrectPassword);
        }

        final AuthCredential credential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );

        final UserCredential result =
            await user.reauthenticateWithCredential(credential);
        final User? authenticatedUser = result.user ?? _firebaseAuth.currentUser;

        if (authenticatedUser == null) {
          throw Exception(R.strings.failedToAuthenticate);
        }

        return authenticatedUser;
      }

      if (providers.contains('google.com')) {
        // Força o seletor do Google para confirmar novamente a identidade.
        // Não fazemos validação manual de e-mail/UID aqui: o próprio Firebase
        // reauthenticateWithCredential garante que a credencial pertence ao
        // mesmo usuário e retorna user-mismatch se outra conta for escolhida.
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.signOut();
        }

        final GoogleSignInAccount? account = await _googleSignIn.signIn();
        if (account == null) {
          debugPrint('Rallet account deletion auth cancelled by user.');
          throw Exception(R.strings.failedToAuthenticate);
        }

        debugPrint(
          'Rallet account deletion Google account selected: '
          'email=${account.email}',
        );

        final GoogleSignInAuthentication authentication =
            await account.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: authentication.accessToken,
          idToken: authentication.idToken,
        );

        final UserCredential result =
            await user.reauthenticateWithCredential(credential);
        final User? authenticatedUser = result.user ?? _firebaseAuth.currentUser;

        if (authenticatedUser == null) {
          throw Exception(R.strings.failedToAuthenticate);
        }

        debugPrint(
          'Rallet account deletion Google reauth success: '
          'uid=${authenticatedUser.uid}; email=${authenticatedUser.email}',
        );

        return authenticatedUser;
      }

      debugPrint(
        'Rallet account deletion unsupported providers: $providers',
      );
      throw Exception(R.strings.failedToAuthenticate);
    } on FirebaseAuthException catch (error) {
      debugPrint(
        'Rallet account deletion authentication failed: '
        'code=${error.code}; message=${error.message}',
      );
      throw _friendlyAuthError(error);
    } catch (error) {
      debugPrint('Rallet account deletion authentication failed: $error');
      rethrow;
    }
  }

  Exception _friendlyAuthError(FirebaseAuthException error) {
    switch (error.code.toLowerCase()) {
      case 'wrong-password':
      case 'auth/wrong-password':
      case 'invalid-credential':
      case 'auth/invalid-credential':
        return Exception(R.strings.incorrectPassword);
      case 'user-mismatch':
      case 'auth/user-mismatch':
        return Exception(R.strings.failedToAuthenticate);
      default:
        return Exception(error.message ?? R.strings.failedToAuthenticate);
    }
  }
}
