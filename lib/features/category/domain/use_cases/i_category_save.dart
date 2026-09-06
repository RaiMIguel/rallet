import 'package:rallet/features/category/domain/entities/category_entity.dart';

abstract interface class ICategorySave {
  Future<CategoryEntity> save(CategoryEntity entity);
}
