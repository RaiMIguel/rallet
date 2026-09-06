import 'package:rallet/features/category/domain/enums/category_type_enum.dart';
import 'package:rallet/features/transactions/presentation/view_models/transactions_list_view_model.dart';
import 'package:rallet/l10n/generated/app_localizations.dart';
import 'package:rallet/shared/extensions/date_time_extension.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FiltersTransactions extends StatelessWidget {
  final TransactionsListViewModel viewModel;
  final bool enabled;
  final VoidCallback? onSelectMonth;

  const FiltersTransactions({
    super.key,
    required this.viewModel,
    required this.enabled,
    this.onSelectMonth,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListenableBuilder(
          listenable: Listenable.merge([viewModel, viewModel.findByPeriod]),
          builder: (_, __) => _MonthNavigation(
            date: viewModel.startDate,
            enabled: enabled && !viewModel.findByPeriod.running,
            onPrevious: () => _changeMonth(viewModel.startDate.subtractMonths(1)),
            onNext: () => _changeMonth(viewModel.startDate.addMonths(1)),
            onTap: onSelectMonth,
          ),
        ),
        const SizedBox(height: 14),
        SegmentedButton<CategoryTypeEnum?>(
          multiSelectionEnabled: false,
          showSelectedIcon: true,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 8, vertical: 11),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            side: WidgetStatePropertyAll(
              BorderSide(color: scheme.outlineVariant.withValues(alpha: .75)),
            ),
          ),
          segments: [
            ButtonSegment<CategoryTypeEnum?>(
              value: null,
              label: Text(
                AppLocalizations.of(context)!.allFilter,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            ButtonSegment<CategoryTypeEnum?>(
              value: CategoryTypeEnum.income,
              label: Text(
                CategoryTypeEnum.income.descriptionPlural,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            ButtonSegment<CategoryTypeEnum?>(
              value: CategoryTypeEnum.expense,
              label: Text(
                CategoryTypeEnum.expense.descriptionPlural,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          selected: viewModel.filterType,
          onSelectionChanged: enabled ? viewModel.setFilterType : null,
        ),
      ],
    );
  }

  void _changeMonth(DateTime date) {
    viewModel.findByPeriod.execute((
      startDate: date.getInitialMonth(),
      endDate: date.getFinalMonth(),
    ));
  }
}

class _MonthNavigation extends StatelessWidget {
  final DateTime date;
  final bool enabled;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onTap;

  const _MonthNavigation({
    required this.date,
    required this.enabled,
    required this.onPrevious,
    required this.onNext,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String raw = DateFormat('MMMM yyyy', 'pt_BR').format(date);
    final String label = raw.isEmpty ? raw : '${raw[0].toUpperCase()}${raw.substring(1)}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .55)),
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Mês anterior',
              onPressed: enabled ? onPrevious : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: enabled ? onTap : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Próximo mês',
              onPressed: enabled ? onNext : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
