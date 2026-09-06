import 'package:rallet/features/auth/domain/entities/auth_entity.dart';

abstract interface class ILoginAuth {
  Future<void> login(AuthEntity entity);
}