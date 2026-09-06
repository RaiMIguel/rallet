import 'package:rallet/shared/domain/entities/entity.dart';

class UserAccountEntity extends Entity {
  String name;
  String email;

  UserAccountEntity({
    required super.id,
    required super.createdAt,
    required super.deletedAt,
    required this.name,
    required this.email,
  });
}
