import 'package:rallet/features/category/domain/enums/category_type_enum.dart';
import 'package:rallet/shared/domain/entities/entity.dart';

class CategoryEntity extends Entity {
  String description;
  CategoryTypeEnum? type;
  String color;
  int icon;

  CategoryEntity({
    required super.id,
    required super.createdAt,
    required super.deletedAt,
    required this.description,
    required this.type,
    required this.color,
    required this.icon,
  });

  CategoryEntity clone() {
    return CategoryEntity(
      id: id,
      createdAt: createdAt,
      deletedAt: deletedAt,
      description: description,
      type: type,
      color: color,
      icon: icon,
    );
  }
}
