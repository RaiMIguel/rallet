import 'package:rallet/features/auth/domain/entities/auth_entity.dart';

abstract interface class IAuthFind {
  Future<AuthEntity?> find();
}
