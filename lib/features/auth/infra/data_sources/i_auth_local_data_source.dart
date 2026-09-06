import 'package:rallet/features/auth/infra/models/auth_model.dart';
import 'package:rallet/shared/infra/data_sources/i_local_data_source.dart';

abstract interface class IAuthLocalDataSource implements ILocalDataSource<AuthModel> {
  Future<void> deleteAll();

  Future<void> saveEmailVerified(bool isEmailVerified);
}
