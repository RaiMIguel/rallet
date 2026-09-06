import 'package:rallet/features/ad/domain/use_cases/i_ad_access.dart';
import 'package:rallet/features/category/domain/entities/category_entity.dart';
import 'package:rallet/features/category/domain/repositories/i_category_repository.dart';
import 'package:rallet/features/category/domain/use_cases/i_category_save.dart';
import 'package:rallet/shared/exceptions/exceptions.dart';
import 'package:rallet/shared/presentation/ui/app_locale.dart';

class CategorySave implements ICategorySave {
  final ICategoryRepository _repository;
  final IAdAccess _adAccess;

  CategorySave({required ICategoryRepository repository, required IAdAccess adAccess}) : _repository = repository, _adAccess = adAccess;

  @override
  Future<CategoryEntity> save(CategoryEntity entity) async {
    if (entity.description.trim().isEmpty) throw ValidationException(R.strings.uninformedDescription);
    if (entity.type == null) throw ValidationException(R.strings.uninformedTypeCategory);
    if (entity.icon == 0) throw ValidationException(R.strings.uninformedIcon);
    if (entity.color.isEmpty) throw ValidationException(R.strings.uninformedColor);

    final CategoryEntity result = await _repository.save(entity);

    _adAccess.consumeUse();

    return result;
  }
}
