import 'package:rallet/features/category/domain/entities/category_entity.dart';

abstract interface class ICategoryDelete {
  Future<void> delete(CategoryEntity entity);
}
