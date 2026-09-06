import 'package:rallet/features/category/domain/enums/category_type_enum.dart';
import 'package:rallet/features/reports/domain/entities/report_category_entity.dart';

abstract interface class IReportCategoriesRepository {
  Future<List<ReportCategoryEntity>> findByPeriod({required DateTime? startDate, required DateTime? endDate, required CategoryTypeEnum type});
}
