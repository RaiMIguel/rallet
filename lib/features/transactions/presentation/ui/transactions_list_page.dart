import 'package:rallet/di/dependency_injection.dart';
import 'package:rallet/features/category/domain/enums/category_type_enum.dart';
import 'package:rallet/features/first_steps/presentation/guided_tour.dart';
import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';
import 'package:rallet/features/purchase_planning/presentation/ui/purchase_planning_page.dart';
import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/entities/i_transaction_entity.dart';
import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/domain/enums/recurrence_scope_enum.dart';
import 'package:rallet/features/transactions/presentation/ui/components/fab_transactions.dart';
import 'package:rallet/features/transactions/presentation/ui/components/filters_transactions.dart';
import 'package:rallet/features/transactions/presentation/ui/components/linked_account_operations_transactions.dart';
import 'package:rallet/features/transactions/presentation/ui/components/list_transactions.dart';
import 'package:rallet/features/transactions/presentation/ui/components/planned_expenses_transactions.dart';
import 'package:rallet/features/transactions/presentation/ui/components/projected_commitments_transactions.dart';
import 'package:rallet/features/transactions/presentation/ui/components/recurrence_scope_dialog.dart';
import 'package:rallet/features/transactions/presentation/ui/components/totals_transactions.dart';
import 'package:rallet/features/transactions/presentation/ui/components/transactions_search.dart';
import 'package:rallet/features/transactions/presentation/view_models/transactions_list_view_model.dart';
import 'package:rallet/shared/extensions/date_time_extension.dart';
import 'package:rallet/shared/presentation/mixins/theme_context.dart';
import 'package:rallet/shared/presentation/notifiers/event_notifier.dart';
import 'package:rallet/shared/presentation/ui/components/app_bar_custom.dart';
import 'package:rallet/shared/presentation/ui/components/dialog/error_dialog.dart';
import 'package:rallet/shared/presentation/ui/components/dialog/loading_dialog.dart';
import 'package:rallet/shared/presentation/ui/components/dialog/month_year_picker/month_year_picker_dialog.dart';
import 'package:rallet/shared/presentation/ui/components/list/selectable/list_mode_selectable.dart';
import 'package:rallet/shared/presentation/ui/components/message_error_widget.dart';
import 'package:rallet/shared/presentation/ui/components/navigation/nav_drawer.dart';
import 'package:rallet/shared/presentation/ui/components/no_content_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TransactionsListPage extends StatefulWidget {
  static const String route = 'transactions-list';

  final CategoryTypeEnum? categoryTypeFilter;

  const TransactionsListPage({
    super.key,
    this.categoryTypeFilter,
  });

  @override
  State<TransactionsListPage> createState() => _TransactionsListPageState();
}

class _TransactionsListPageState extends State<TransactionsListPage>
    with ThemeContext {
  final TransactionsListViewModel viewModel = DI.get<TransactionsListViewModel>();
  final EventNotifier eventNotifier = DI.get<EventNotifier>();
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController scrollController = ScrollController();

  List<ITransactionEntity> listSelectable = [];

  @override
  void initState() {
    super.initState();
    eventNotifier.addListener(_onEvent);

    Future(() async {
      final DateTime dateNow = DateTime.now();
      await viewModel.init.execute((
        startDate: dateNow.getInitialMonth(),
        endDate: dateNow.getFinalMonth(),
        filterType: {widget.categoryTypeFilter},
      ));
      viewModel.init.throwIfError();
    });
  }

  void _onEvent() {
    if (eventNotifier.value == EventType.transactionsHome) {
      _resetNavigationState();
      return;
    }

    if ([
      EventType.income,
      EventType.expense,
      EventType.transfer,
      EventType.purchasePlan,
      EventType.cashAdvance,
      EventType.creditCard,
      EventType.account,
    ].contains(eventNotifier.value)) {
      onRefresh();
    }
  }

  Future<void> _resetNavigationState() async {
    viewModel.setFilterType({null});
    viewModel.setStatusFilter(TransactionStatusFilter.all);
    await _refreshCurrentMonth();
  }

  Future<void> _refreshCurrentMonth() async {
    final DateTime now = DateTime.now();
    await onRefresh(
      startDate: now.getInitialMonth(),
      endDate: now.getFinalMonth(),
    );
    _scrollToTop();
  }

  void _scrollToTop() {
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) scrollController.jumpTo(0);
      });
    }
  }

  @override
  void dispose() {
    eventNotifier.removeListener(_onEvent);
    scrollController.dispose();
    super.dispose();
  }

  Future<void> onRefresh({DateTime? startDate, DateTime? endDate}) async {
    if (viewModel.init.hasError) {
      await viewModel.init.execute((
        startDate: startDate ?? viewModel.startDate,
        endDate: endDate ?? viewModel.endDate,
        filterType: viewModel.filterType,
      ));
    } else {
      await viewModel.findByPeriod.execute((
        startDate: startDate ?? viewModel.startDate,
        endDate: endDate ?? viewModel.endDate,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListModeSelectable(
      list: listSelectable,
      updateList: (List value) =>
          setState(() => listSelectable = value.cast<ITransactionEntity>()),
      child: Scaffold(
        key: scaffoldKey,
        appBar: AppBarCustom(
          leading: IconButton(
            tooltip: strings.menu,
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => scaffoldKey.currentState?.openDrawer(),
          ),
          title: Text(strings.transactions),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: strings.search,
              icon: const Icon(Icons.search_rounded),
              onPressed: () => TransactionsSearch.show(context: context),
            ),
            ListenableBuilder(
              listenable: viewModel,
              builder: (_, __) => GuidedTourTarget(
                id: GuidedTourTargets.transactionsStatus,
                child: _FilterActionButton(
                  active: viewModel.statusFilter != TransactionStatusFilter.all,
                  onPressed: _openStatusFilters,
                ),
              ),
            ),
          ],
          actionsInModeSelection: [
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: deleteTransactions,
            ),
          ],
        ),
        drawer: const NavDrawer(),
        floatingActionButton: Visibility(
          visible: listSelectable.isEmpty,
          child: const FabTransactions(),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshCurrentMonth,
            child: SingleChildScrollView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  viewModel,
                  viewModel.init,
                  viewModel.findByPeriod,
                ]),
                builder: (_, __) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GuidedTourTarget(
                          id: GuidedTourTargets.transactionsFilters,
                          child: FiltersTransactions(
                            viewModel: viewModel,
                            enabled: listSelectable.isEmpty,
                            onSelectMonth: selectDate,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _buildContent(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final bool isLoading = viewModel.init.running || viewModel.findByPeriod.running;
    final bool hasError = viewModel.init.hasError || viewModel.findByPeriod.hasError;

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 36),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (hasError) {
      return MessageErrorWidget(
        viewModel.init.error?.toString() ??
            viewModel.findByPeriod.error?.toString() ??
            '',
      );
    }

    final bool hasProjectedCommitments =
        viewModel.filterType.firstOrNull != CategoryTypeEnum.income &&
            (viewModel.forecastBills.isNotEmpty ||
                viewModel.forecastCashAdvancePlans.isNotEmpty);

    if (viewModel.transactions.isEmpty &&
        viewModel.plannedExpenses.isEmpty &&
        viewModel.realizedCashAdvances.isEmpty &&
        viewModel.plannedLinkedCashAdvances.isEmpty &&
        !hasProjectedCommitments) {
      return NoContentWidget(child: Text(strings.noTransactionsRegistered));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TotalsTransactions(viewModel: viewModel),
        ),
        const SizedBox(height: 12),
        LinkedAccountOperationsTransactions(
          viewModel: viewModel,
          onChanged: () => onRefresh(),
        ),
        if (viewModel.filterType.firstOrNull != CategoryTypeEnum.income)
          ProjectedCommitmentsTransactions(
            viewModel: viewModel,
            onChanged: () => onRefresh(),
          ),
        if (viewModel.transactions.isNotEmpty) ...[
          _TransactionsSectionHeader(count: viewModel.transactions.length),
          const SizedBox(height: 8),
          ListTransactions(viewModel: viewModel),
        ],
        PlannedExpensesTransactions(
          viewModel: viewModel,
          onOpen: _openPlannedExpense,
        ),
      ],
    );
  }

  Future<void> _openStatusFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return ListenableBuilder(
          listenable: viewModel,
          builder: (_, __) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Filtros',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => viewModel.setStatusFilter(
                          TransactionStatusFilter.all,
                        ),
                        child: const Text('Limpar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Status',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  _StatusFilterGrid(
                    selected: viewModel.statusFilter,
                    onSelected: (status) {
                      viewModel.setStatusFilter(status);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openPlannedExpense(PlannedPurchaseEntity plan) async {
    final result = await context.pushNamed(
      PurchasePlanningPage.route,
      extra: plan,
    );
    if (result == true) await onRefresh();
  }

  Future<void> selectDate() async {
    final DateTime? date = await showMonthYearPicker(
      context: context,
      initialDate: viewModel.startDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );

    if (date != null) {
      await onRefresh(
        startDate: date.getInitialMonth(),
        endDate: date.getFinalMonth(),
      );
    }
  }

  Future<void> deleteTransactions() async {
    try {
      RecurrenceScopeEnum recurrenceScope = RecurrenceScopeEnum.single;

      final bool hasRecurring = listSelectable.any(
        (transaction) =>
            (transaction is ExpenseEntity && transaction.recurring) ||
            (transaction is IncomeEntity && transaction.recurring),
      );

      if (hasRecurring) {
        final RecurrenceScopeEnum? selected = await RecurrenceScopeDialog.show(
          context: context,
          deleting: true,
        );
        if (selected == null) return;
        recurrenceScope = selected;
      }

      if (!mounted) return;
      await LoadingDialog.show(
        context: context,
        message: strings.deletingTransactions,
        onAction: () async {
          await viewModel.deleteTransactions.execute((
            transactions: listSelectable,
            recurrenceScope: recurrenceScope,
          ));
          viewModel.deleteTransactions.throwIfError();
        },
      );

      if (!mounted) return;
      setState(() => listSelectable = []);
      await onRefresh();
    } catch (e) {
      if (!mounted) return;
      await ErrorDialog.show(context, e.toString());
    }
  }
}

class _FilterActionButton extends StatelessWidget {
  final bool active;
  final VoidCallback onPressed;

  const _FilterActionButton({required this.active, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Filtros',
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.tune_rounded),
          if (active)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionsSectionHeader extends StatelessWidget {
  final int count;

  const _TransactionsSectionHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Transações do mês',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterGrid extends StatelessWidget {
  final TransactionStatusFilter selected;
  final ValueChanged<TransactionStatusFilter> onSelected;

  const _StatusFilterGrid({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatusFilterOption(
              width: width,
              value: TransactionStatusFilter.all,
              selected: selected == TransactionStatusFilter.all,
              icon: Icons.select_all_rounded,
              label: 'Todas',
              onSelected: onSelected,
            ),
            _StatusFilterOption(
              width: width,
              value: TransactionStatusFilter.realized,
              selected: selected == TransactionStatusFilter.realized,
              icon: Icons.check_circle_outline_rounded,
              label: 'Realizadas',
              onSelected: onSelected,
            ),
            _StatusFilterOption(
              width: width,
              value: TransactionStatusFilter.pending,
              selected: selected == TransactionStatusFilter.pending,
              icon: Icons.schedule_rounded,
              label: 'Pendentes',
              onSelected: onSelected,
            ),
            _StatusFilterOption(
              width: width,
              value: TransactionStatusFilter.planned,
              selected: selected == TransactionStatusFilter.planned,
              icon: Icons.event_note_outlined,
              label: 'Planejadas',
              onSelected: onSelected,
            ),
          ],
        );
      },
    );
  }
}

class _StatusFilterOption extends StatelessWidget {
  final double width;
  final TransactionStatusFilter value;
  final bool selected;
  final IconData icon;
  final String label;
  final ValueChanged<TransactionStatusFilter> onSelected;

  const _StatusFilterOption({
    required this.width,
    required this.value,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: .14)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => onSelected(value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: selected
                    ? scheme.primary.withValues(alpha: .75)
                    : scheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
