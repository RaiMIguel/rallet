import 'package:rallet/features/user_account/infra/models/user_account_model.dart';

abstract interface class IUserAccountCloudDataSource {
  Future<UserAccountModel> insert(UserAccountModel model);

  Future<UserAccountModel> update(UserAccountModel model);

  Future<UserAccountModel?> getByEmail(String email);

  Future<UserAccountModel?> deleteByEmail(String email);

  Future<void> restore(UserAccountModel model);
}
