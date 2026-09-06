import 'package:rallet/features/ad/domain/use_cases/i_ad_access.dart';
import 'package:rallet/features/category/domain/entities/category_entity.dart';
import 'package:rallet/features/category/domain/repositories/i_category_repository.dart';
import 'package:rallet/features/category/domain/use_cases/i_category_delete.dart';

class CategoryDelete implements ICategoryDelete {
  final ICategoryRepository _repository;
  final IAdAccess _adAccess;

  CategoryDelete({required ICategoryRepository repository, required IAdAccess adAccess}) : _repository = repository, _adAccess = adAccess;

  @override
  Future<void> delete(CategoryEntity entity) => _repository.delete(entity).then((_) => _adAccess.consumeUse());
}
