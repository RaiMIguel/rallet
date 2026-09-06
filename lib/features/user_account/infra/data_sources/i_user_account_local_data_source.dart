import 'package:rallet/features/user_account/infra/models/user_account_model.dart';
import 'package:rallet/shared/infra/data_sources/i_local_data_source.dart';

abstract interface class IUserAccountLocalDataSource implements ILocalDataSource<UserAccountModel> {
  Future<void> deleteAll();
}
