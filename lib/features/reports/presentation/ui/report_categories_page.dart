import 'package:rallet/di/dependency_injection.dart';
import 'package:rallet/features/reports/presentation/enums/date_period_enum.dart';
import 'package:rallet/features/reports/presentation/ui/components/report_categories_chart.dart';
import 'package:rallet/features/reports/presentation/view_models/report_categories_view_model.dart';
import 'package:rallet/shared/presentation/mixins/theme_context.dart';
import 'package:rallet/shared/presentation/ui/components/calculation_info_button.dart';
import 'package:rallet/shared/presentation/ui/components/filters/date_period_filter.dart';
import 'package:rallet/shared/presentation/ui/components/filters/filters_bottom_sheet.dart';
import 'package:rallet/shared/presentation/ui/components/message_error_widget.dart';
import 'package:rallet/shared/presentation/ui/components/no_content_widget.dart';
import 'package:flutter/material.dart';

class ReportCategoriesPage extends StatefulWidget {
  static const String route = 'report-categories';

  final DateTimeRange? initialRange;

  const ReportCategoriesPage({Key? key, this.initialRange}) : super(key: key);

  @override
  State<ReportCategoriesPage> createState() => _ReportCategoriesPageState();
}

class _ReportCategoriesPageState extends State<ReportCategoriesPage> with ThemeContext {
  final ReportCategoriesViewModel viewModel = DI.get<ReportCategoriesViewModel>();

  List<Tab> get tabs => [Tab(text: strings.expenses), Tab(text: strings.incomes)];

  DateTime? dateInitialFilter;
  DateTime? dateFinalFilter;

  @override
  void initState() {
    super.initState();

    final DateTimeRange defaultRange = DatePeriodEnum.oneMonth.getDateTime();
    dateInitialFilter = widget.initialRange?.start ?? defaultRange.start;
    dateFinalFilter = widget.initialRange?.end ?? defaultRange.end;

    viewModel.findByPeriod.execute((startDate: dateInitialFilter, endDate: dateFinalFilter));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: 0,
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.categories),
          actions: [
            const CalculationInfoButton(
              title: 'Detalhamento por categoria',
              description:
                  'Este detalhamento usa as mesmas regras de competência dos Relatórios para permitir conferência dos totais.',
              items: [
                'Despesas comuns são agrupadas pela data do lançamento.',
                'Compras de cartão são agrupadas pelo vencimento da fatura.',
                'Pagamentos de fatura não entram novamente como despesa.',
                'Crédito via cartão entra somente pelo juros/taxa; planejamentos são identificados como juros planejados.',
              ],
              formula: 'Total das categorias = Soma das despesas consideradas no período',
            ),
            IconButton(
              tooltip: strings.filters,
              onPressed: filters,
              icon: const Icon(Icons.filter_list_outlined),
            ),
          ],
          bottom: TabBar(tabs: tabs),
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: viewModel.findByPeriod,
            builder: (_, __) {
              if (viewModel.findByPeriod.running) return const Center(child: CircularProgressIndicator());
              if (viewModel.findByPeriod.hasError) return MessageErrorWidget(viewModel.findByPeriod.error.toString());

              return TabBarView(
                children: [
                  Visibility(
                    visible: viewModel.reportCategoriesExpenses.isNotEmpty,
                    replacement: NoContentWidget(child: Text(strings.noRecordsFound)),
                    child: ReportCategoriesChart(entities: viewModel.reportCategoriesExpenses, total: viewModel.totalExpenses),
                  ),
                  Visibility(
                    visible: viewModel.reportCategoriesIncomes.isNotEmpty,
                    replacement: NoContentWidget(child: Text(strings.noRecordsFound)),
                    child: ReportCategoriesChart(entities: viewModel.reportCategoriesIncomes, total: viewModel.totalIncomes),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> filters() async {
    await FiltersBottomSheet.show(
      context: context,
      filter: () => viewModel.findByPeriod.execute((startDate: dateInitialFilter, endDate: dateFinalFilter)),
      children: [
        DatePeriodFilter(
          periods: DatePeriodEnum.values,
          onSelected: (DateTime? dateTimeInitial, DateTime? dateTimeFinal) {
            dateInitialFilter = dateTimeInitial;
            dateFinalFilter = dateTimeFinal;
          },
          dateRange: dateInitialFilter != null && dateFinalFilter != null ? DateTimeRange(start: dateInitialFilter!, end: dateFinalFilter!) : null,
        ),
      ],
    );
  }
}
