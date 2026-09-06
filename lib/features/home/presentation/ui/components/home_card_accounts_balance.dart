import 'package:rallet/features/account/presentation/ui/accounts_list_page.dart';
import 'package:rallet/features/home/presentation/ui/components/home_expense_evolution_chart.dart';
import 'package:rallet/features/home/presentation/view_models/home_view_model.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/presentation/mixins/theme_context.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeCardAccountsBalance extends StatefulWidget {
  final HomeViewModel viewModel;

  const HomeCardAccountsBalance({
    super.key,
    required this.viewModel,
  });

  @override
  State<HomeCardAccountsBalance> createState() =>
      _HomeCardAccountsBalanceState();
}

class _HomeCardAccountsBalanceState
    extends State<HomeCardAccountsBalance>
    with ThemeContext {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListenableBuilder(
          listenable: Listenable.merge([
            widget.viewModel,
            widget.viewModel.loadInitialBalance,
            widget.viewModel.loadSelectedBalance,
            widget.viewModel.loadSelectedMonthBills,
            widget.viewModel.loadSelectedMonthTransactions,
            widget.viewModel.loadBalanceEvolution,
          ]),
          builder: (_, __) {
            final bool loading =
                widget.viewModel.loadInitialBalance.running ||
                widget.viewModel.loadSelectedBalance.running ||
                widget.viewModel.loadSelectedMonthBills.running ||
                widget.viewModel.loadSelectedMonthTransactions.running;

            final bool hasInitialBalance =
                widget.viewModel.loadInitialBalance.result != null ||
                widget.viewModel.loadInitialBalance.previous?.completed == true;

            final bool hasSelectedBalance =
                widget.viewModel.loadSelectedBalance.result != null ||
                widget.viewModel.loadSelectedBalance.previous?.completed == true;

            final bool hasBills =
                widget.viewModel.loadSelectedMonthBills.result != null ||
                widget.viewModel.loadSelectedMonthBills.previous?.completed == true;

            final bool hasTransactions =
                widget.viewModel.loadSelectedMonthTransactions.result != null ||
                widget.viewModel.loadSelectedMonthTransactions.previous?.completed == true;

            final bool hasData =
                hasInitialBalance &&
                hasSelectedBalance &&
                hasBills &&
                hasTransactions;

            final bool hasError =
                widget.viewModel.loadInitialBalance.hasError ||
                widget.viewModel.loadSelectedBalance.hasError ||
                widget.viewModel.loadSelectedMonthBills.hasError ||
                widget.viewModel.loadSelectedMonthTransactions.hasError;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMonthSelector(loading),
                const SizedBox(height: 14),
                if (hasError)
                  Text(
                    'Não foi possível carregar os saldos.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                  )
                else if (loading && !hasData)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  )
                else
                  _buildBalanceOverview(),
                const SizedBox(height: 12),
                Divider(color: colorScheme.outlineVariant),
                const SizedBox(height: 10),
                HomeExpenseEvolutionChart(viewModel: widget.viewModel),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMonthSelector(bool loading) {
    final String monthName =
        MaterialLocalizations.of(context).formatMonthYear(
      widget.viewModel.selectedMonth,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Mês anterior',
          onPressed: loading ? null : widget.viewModel.previousMonth,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: GestureDetector(
            onTap: widget.viewModel.isSelectedMonthCurrent
                ? null
                : widget.viewModel.goCurrentMonth,
            child: Text(
              monthName,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Próximo mês',
          onPressed: loading ? null : widget.viewModel.nextMonth,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _buildBalanceOverview() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _BalanceItem(
            label: 'Inicial',
            value: widget.viewModel.initialBalance,
            hideAmounts: widget.viewModel.hideAmounts,
          ),
        ),
        _buildConnector(),
        Expanded(
          child: _BalanceItem(
            label: _middleBalanceLabel,
            value: widget.viewModel.currentBalance,
            hideAmounts: widget.viewModel.hideAmounts,
            onTap: widget.viewModel.isSelectedMonthCurrent
                ? seeAllAccounts
                : null,
            showChevron: widget.viewModel.isSelectedMonthCurrent,
          ),
        ),
        _buildConnector(),
        Expanded(
          child: _BalanceItem(
            label: 'Previsto',
            value: widget.viewModel.forecastBalance,
            hideAmounts: widget.viewModel.hideAmounts,
          ),
        ),
      ],
    );
  }

  String get _middleBalanceLabel {
    if (widget.viewModel.isSelectedMonthPast) return 'Final';
    if (widget.viewModel.isSelectedMonthFuture) return '';
    return 'Atual';
  }

  Widget _buildConnector() {
    return Padding(
      padding: const EdgeInsets.only(top: 42, left: 4, right: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 14,
            height: 1,
            color: colorScheme.outlineVariant,
          ),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  void seeAllAccounts() => context.goNamed(AccountsListPage.route);
}

class _BalanceItem extends StatelessWidget {
  final String label;
  final double value;
  final bool hideAmounts;
  final VoidCallback? onTap;
  final bool showChevron;

  const _BalanceItem({
    required this.label,
    required this.value,
    required this.hideAmounts,
    this.onTap,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Column(
        children: [
          SizedBox(
            height: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label.isNotEmpty)
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (showChevron) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hideAmounts ? '●●●●' : value.money,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Tooltip(
      message: 'Ver contas',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      ),
    );
  }
}
