import 'package:collection/collection.dart';
import 'package:rallet/di/dependency_injection.dart';
import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/card_cash_advance/presentation/ui/card_cash_advance_form_page.dart';
import 'package:rallet/features/category/domain/enums/category_type_enum.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/features/credit_card/presentation/ui/credit_card_bill_details_page.dart';
import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';
import 'package:rallet/features/purchase_planning/presentation/ui/purchase_planning_page.dart';
import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/entities/i_transaction_entity.dart';
import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/domain/enums/recurrence_scope_enum.dart';
import 'package:rallet/features/transactions/presentation/ui/components/details/expense_details_sheet.dart';
import 'package:rallet/features/transactions/presentation/ui/components/details/income_details_sheet.dart';
import 'package:rallet/features/transactions/presentation/ui/components/recurrence_scope_dialog.dart';
import 'package:rallet/features/transactions/presentation/ui/components/settle_transaction_dialog.dart';
import 'package:rallet/features/transactions/presentation/view_models/transactions_unpaid_unreceived_view_model.dart';
import 'package:rallet/shared/classes/form_result_navigation.dart';
import 'package:rallet/shared/extensions/date_time_extension.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/extensions/int_extension.dart';
import 'package:rallet/shared/extensions/string_extension.dart';
import 'package:rallet/shared/presentation/mixins/theme_context.dart';
import 'package:rallet/shared/presentation/ui/components/app_bar_custom.dart';
import 'package:rallet/shared/presentation/ui/components/dialog/error_dialog.dart';
import 'package:rallet/shared/presentation/ui/components/list/selectable/item_selectable.dart';
import 'package:rallet/shared/presentation/ui/components/list/selectable/list_mode_selectable.dart';
import 'package:rallet/shared/presentation/ui/components/list/selectable/list_tile_selectable.dart';
import 'package:rallet/shared/presentation/ui/components/list/selectable/list_view_selectable.dart';
import 'package:rallet/shared/presentation/ui/components/message_error_widget.dart';
import 'package:rallet/shared/presentation/ui/components/no_content_widget.dart';
import 'package:rallet/shared/presentation/ui/components/spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TransactionsUnpaidUnreceivedArgs {
  final CategoryTypeEnum categoryType;
  final DateTime? initialMonth;

  const TransactionsUnpaidUnreceivedArgs({
    required this.categoryType,
    this.initialMonth,
  });
}

class TransactionsUnpaidUnreceivedPage extends StatefulWidget {
  static const String route = 'transactions-unpaid-unreceived';

  final CategoryTypeEnum categoryType;
  final DateTime? initialMonth;

  const TransactionsUnpaidUnreceivedPage({
    super.key,
    required this.categoryType,
    this.initialMonth,
  });

  @override
  State<TransactionsUnpaidUnreceivedPage> createState() =>
      _TransactionsUnpaidUnreceivedPageState();
}

class _TransactionsUnpaidUnreceivedPageState
    extends State<TransactionsUnpaidUnreceivedPage>
    with ThemeContext {
  final TransactionsUnpaidUnreceivedViewModel viewModel =
      DI.get<TransactionsUnpaidUnreceivedViewModel>();

  List<ITransactionEntity> listSelectable = [];
  final Set<String> _busyIds = <String>{};

  @override
  void initState() {
    super.initState();

    Future(() async {
      if (widget.initialMonth != null) {
        viewModel.setSelectedMonth(widget.initialMonth!);
      }
      await viewModel.init.execute(widget.categoryType);
      viewModel.init.throwIfError();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListModeSelectable(
      list: listSelectable,
      updateList: (List value) => setState(
        () => listSelectable = value.cast<ITransactionEntity>(),
      ),
      child: Scaffold(
        appBar: AppBarCustom(
          title: Text(
            widget.categoryType == CategoryTypeEnum.expense
                ? strings.payable
                : strings.receivable,
          ),
          actionsInModeSelection: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: deleteTransactions,
            ),
          ],
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([viewModel, viewModel.init]),
            builder: (_, __) {
              if (viewModel.init.running &&
                  viewModel.transactions.isEmpty &&
                  viewModel.bills.isEmpty &&
                  viewModel.plans.isEmpty &&
                  viewModel.plannedExpenses.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (viewModel.init.hasError) {
                return MessageErrorWidget(viewModel.init.error.toString());
              }

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacing.y(0.5),
                    _MonthSelector(viewModel: viewModel),
                    const Spacing.y(0.5),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.categoryType == CategoryTypeEnum.expense
                                    ? strings.totalPayable
                                    : strings.totalReceivable,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                viewModel.totalPayableOrReceivable.abs().money,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Pendências',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                '${viewModel.transactions.length + viewModel.bills.length + viewModel.plans.length + viewModel.plannedExpenses.length}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacing.y(0.5),
                    if (viewModel.transactions.isEmpty &&
                        viewModel.bills.isEmpty &&
                        viewModel.plans.isEmpty &&
                        viewModel.plannedExpenses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 44),
                        child: NoContentWidget(
                          child: Text(strings.noTransactionsRegistered),
                        ),
                      ),
                    if (viewModel.plans.isNotEmpty)
                      ...viewModel.plans.map((plan) {
                        final CreditCardEntity creditCard =
                            viewModel.creditCardForPlan(plan);
                        final account = viewModel.accountForPlan(plan);
                        final bool isExpense =
                            widget.categoryType == CategoryTypeEnum.expense;
                        final DateTime referenceDate =
                            isExpense ? plan.billDueDate : plan.plannedDate;
                        final double amount = isExpense
                            ? plan.amountCharged
                            : plan.amountReceived;

                        return Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                backgroundColor:
                                    colorScheme.primary.withValues(alpha: .12),
                                child: Icon(
                                  Icons.schedule_rounded,
                                  color: colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                isExpense
                                    ? 'Crédito planejado na fatura • ${creditCard.description}'
                                    : 'Crédito planejado • ${creditCard.description}',
                              ),
                              subtitle: Text(
                                isExpense
                                    ? 'Planejado • vencimento ${referenceDate.formatDateToRelative()}'
                                    : 'Para ${account.description} • ${referenceDate.formatDateToRelative()}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _PendingActionButton(
                                    tooltip: 'Realizar operação agora',
                                    loading: _busyIds.contains(plan.id),
                                    onTap: _busyIds.contains(plan.id)
                                        ? null
                                        : () => realizeCashAdvance(plan),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        amount.money,
                                        style: textTheme.labelLarge?.copyWith(
                                          color: isExpense
                                              ? const Color(0XFFFF5454)
                                              : const Color(0XFF3CDE87),
                                        ),
                                      ),
                                      Text('Planejado'),
                                    ],
                                  ),
                                ],
                              ),
                              onTap: () => editCashAdvance(plan),
                            ),
                            const Divider(),
                          ],
                        );
                      }),
                    if (widget.categoryType == CategoryTypeEnum.expense &&
                        viewModel.plannedExpenses.isNotEmpty)
                      ...viewModel.plannedExpenses.map((plan) {
                        final double amount =
                            viewModel.plannedExpenseAmount(plan);
                        final String payment = plan.isCreditCard
                            ? (plan.isInstallment
                                ? '${plan.installmentCount}x no cartão'
                                : 'Cartão à vista')
                            : 'À vista';

                        return Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                backgroundColor:
                                    colorScheme.primary.withValues(alpha: .12),
                                child: Icon(
                                  Icons.event_note_outlined,
                                  color: colorScheme.primary,
                                ),
                              ),
                              title: Text(plan.description),
                              subtitle: Text(
                                '$payment • despesa planejada',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Revisar planejamento',
                                    icon: const Icon(Icons.edit_calendar_outlined),
                                    onPressed: () => editPlannedExpense(plan),
                                  ),
                                  const SizedBox(width: 4),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        amount.money,
                                        style: textTheme.labelLarge?.copyWith(
                                          color: const Color(0XFFFF5454),
                                        ),
                                      ),
                                      const Text('Planejado'),
                                    ],
                                  ),
                                ],
                              ),
                              onTap: () => editPlannedExpense(plan),
                            ),
                            const Divider(),
                          ],
                        );
                      }),
                    if (widget.categoryType == CategoryTypeEnum.expense &&
                        viewModel.bills.isNotEmpty)
                      ...viewModel.bills.map((bill) {
                        final CreditCardEntity creditCard =
                            viewModel.creditCardForBill(bill);

                        return Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                backgroundColor:
                                    colorScheme.secondaryContainer,
                                child: const Icon(Icons.credit_card_outlined),
                              ),
                              title: Text(
                                '${strings.creditCardBillPayable} • ${creditCard.description}',
                              ),
                              subtitle: Text(
                                '${strings.dueDate}: ${bill.billDueDate.formatDateToRelative()}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _PendingActionButton(
                                    tooltip: 'Abrir e pagar fatura',
                                    onTap: () => goBillDetails(bill),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        bill.billAmount.abs().money,
                                        style: textTheme.labelLarge?.copyWith(
                                          color: const Color(0XFFFF5454),
                                        ),
                                      ),
                                      Text(
                                        bill.billDueDate
                                            .formatDateToRelative(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              onTap: () => goBillDetails(bill),
                            ),
                            const Divider(),
                          ],
                        );
                      }),
                    if (viewModel.transactions.isNotEmpty)
                      ListViewSelectable.separated(
                        key: ObjectKey(viewModel.transactions),
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        list: viewModel.transactions,
                        itemBuilder:
                            (ItemSelectable<ITransactionEntity> item) {
                          final ITransactionEntity transaction = item.value;
                          final category =
                              viewModel.categories.firstWhereOrNull(
                            (category) =>
                                category.id ==
                                (transaction is ExpenseEntity
                                    ? transaction.idCategory
                                    : (transaction as IncomeEntity)
                                        .idCategory),
                          );

                          final bool isExpense =
                              transaction is ExpenseEntity;
                          final String description = isExpense
                              ? transaction.description
                              : (transaction as IncomeEntity).description;

                          return ListTileSelectable<ITransactionEntity>(
                            value: item,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: category == null
                                  ? Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                  : Color(category.color.toColor() ?? 0),
                              child: Icon(
                                category?.icon.parseIconData() ??
                                    Icons.receipt_long_outlined,
                                color: category == null
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                    : Colors.white,
                              ),
                            ),
                            title: Text(description),
                            subtitle: Text(
                              category?.description ?? 'Categoria indisponível',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _PendingActionButton(
                                  tooltip: isExpense
                                      ? 'Marcar como paga'
                                      : 'Marcar como recebida',
                                  loading: _busyIds.contains(transaction.id),
                                  onTap: _busyIds.contains(transaction.id)
                                      ? null
                                      : () => _confirmSettle(transaction),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      transaction.amount.abs().money,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: transaction.amount > 0
                                                ? const Color(0XFF3CDE87)
                                                : const Color(0XFFFF5454),
                                          ),
                                    ),
                                    Text(
                                      transaction.date
                                          .formatDateToRelative(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => goDetails(transaction),
                          );
                        },
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> editPlannedExpense(PlannedPurchaseEntity plan) async {
    final result = await context.pushNamed(
      PurchasePlanningPage.route,
      extra: plan,
    );

    if (result == true) await viewModel.refresh();
  }

  Future<void> editCashAdvance(CardCashAdvancePlanEntity plan) async {
    final result = await context.pushNamed(
      CardCashAdvanceFormPage.route,
      extra: CardCashAdvanceFormArgs(plan: plan),
    );

    if (result == true) await viewModel.refresh();
  }

  Future<void> realizeCashAdvance(CardCashAdvancePlanEntity plan) async {
    if (_busyIds.contains(plan.id)) return;
    final CreditCardEntity card = viewModel.creditCardForPlan(plan);
    final account = viewModel.accountForPlan(plan);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Realizar operação planejada?'),
        content: Text(
          'Entrarão ${plan.amountReceived.money} em ${account.description} e ${plan.amountCharged.money} serão lançados no cartão ${card.description}. A entrada não será contabilizada como receita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Realizar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busyIds.add(plan.id));
    try {
      await viewModel.realizePlan(plan);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operação realizada e lançada no cartão.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ErrorDialog.show(context, e.toString());
    } finally {
      if (mounted) setState(() => _busyIds.remove(plan.id));
    }
  }

  Future<void> _confirmSettle(ITransactionEntity transaction) async {
    if (_busyIds.contains(transaction.id)) return;

    final bool isExpense = transaction is ExpenseEntity;
    final String description = isExpense
        ? transaction.description
        : (transaction as IncomeEntity).description;

    final SettleTransactionResult? result =
        await SettleTransactionDialog.show(
      context: context,
      description: description,
      expectedAmount: transaction.amount.abs(),
      expense: isExpense,
    );

    if (result == null || !mounted) return;

    setState(() => _busyIds.add(transaction.id));
    try {
      await viewModel.settleTransaction(
        transaction,
        realizedAmount: result.realizedAmount,
        trackVariance: result.trackVariance,
        realizedAt: result.realizedAt,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isExpense
                ? 'Despesa marcada como paga.'
                : 'Receita marcada como recebida.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ErrorDialog.show(context, e.toString());
    } finally {
      if (mounted) setState(() => _busyIds.remove(transaction.id));
    }
  }

  Future<void> goBillDetails(CreditCardBillEntity bill) async {
    try {
      final CreditCardEntity creditCard =
          viewModel.creditCardForBill(bill);

      await context.pushNamed(
        CreditCardBillDetailsPage.route,
        extra: CreditCardBillDetailsArgsPage(
          bill: bill,
          creditCard: creditCard,
        ),
      );

      await viewModel.init.execute(widget.categoryType);
      viewModel.init.throwIfError();
    } catch (e) {
      if (!mounted) return;
      ErrorDialog.show(context, e.toString());
    }
  }

  Future<void> goDetails(ITransactionEntity transaction) async {
    FormResultNavigation<ITransactionEntity>? result;

    switch (transaction.runtimeType) {
      case ExpenseEntity:
        await ExpenseDetailsSheet.show(
          context: context,
          id: transaction.id,
          onChanged: (value) => result = value,
        );
        break;
      case IncomeEntity:
        await IncomeDetailsSheet.show(
          context: context,
          id: transaction.id,
          onChanged: (value) => result = value,
        );
        break;
    }

    if (result?.isSave == true || result?.isDelete == true) {
      await viewModel.init.execute(widget.categoryType);
      viewModel.init.throwIfError();
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
        final RecurrenceScopeEnum? selected =
            await RecurrenceScopeDialog.show(
          context: context,
          deleting: true,
        );
        if (selected == null) return;
        recurrenceScope = selected;
      }

      await viewModel.deleteTransactions(
        listSelectable,
        recurrenceScope: recurrenceScope,
      );

      setState(() => listSelectable = []);
    } catch (e) {
      if (!mounted) return;
      ErrorDialog.show(context, e.toString());
    }
  }
}

class _MonthSelector extends StatelessWidget {
  final TransactionsUnpaidUnreceivedViewModel viewModel;

  const _MonthSelector({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final String raw = DateFormat(
      'MMMM yyyy',
      'pt_BR',
    ).format(viewModel.selectedMonth);
    final String label = raw[0].toUpperCase() + raw.substring(1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Mês anterior',
          onPressed: viewModel.previousMonth,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: viewModel.goCurrentMonth,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Próximo mês',
          onPressed: viewModel.nextMonth,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _PendingActionButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onTap;
  final bool loading;

  const _PendingActionButton({
    required this.tooltip,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: primary.withValues(alpha: .10),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: loading
                ? SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: primary,
                    ),
                  )
                : Icon(
                    Icons.schedule_rounded,
                    size: 21,
                    color: primary,
                  ),
          ),
        ),
      ),
    );
  }
}
