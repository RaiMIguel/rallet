import 'package:rallet/features/category/domain/enums/category_type_enum.dart';
import 'package:rallet/features/reports/domain/entities/report_category_entity.dart';
import 'package:rallet/features/reports/domain/repositories/i_report_categories_repository.dart';
import 'package:rallet/features/reports/domain/use_cases/i_report_categories_find.dart';
import 'package:rallet/shared/presentation/ui/app_locale.dart';

class ReportCategoriesFind implements IReportCategoriesFind {
  final IReportCategoriesRepository _repository;

  ReportCategoriesFind({required IReportCategoriesRepository repository}) : _repository = repository;

  @override
  Future<List<ReportCategoryEntity>> findByPeriod({required DateTime? startDate, required DateTime? endDate, required CategoryTypeEnum type}) async {
    if (startDate != null && endDate != null && startDate.isAfter(endDate)) throw Exception(R.strings.errorStartDateAfterEndDate);

    return await _repository.findByPeriod(startDate: startDate, endDate: endDate, type: type);
  }
}
