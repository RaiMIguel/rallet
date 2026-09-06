import 'package:collection/collection.dart';
import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/entities/i_transaction_entity.dart';
import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/domain/entities/transfer_entity.dart';
import 'package:rallet/features/transactions/presentation/ui/components/details/expense_details_sheet.dart';
import 'package:rallet/features/transactions/presentation/ui/components/details/income_details_sheet.dart';
import 'package:rallet/features/transactions/presentation/ui/components/details/transfer_details_sheet.dart';
import 'package:rallet/features/transactions/presentation/ui/components/settle_transaction_dialog.dart';
import 'package:rallet/features/transactions/presentation/view_models/transactions_list_view_model.dart';
import 'package:rallet/shared/classes/form_result_navigation.dart';
import 'package:rallet/shared/extensions/date_time_extension.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/extensions/int_extension.dart';
import 'package:rallet/shared/extensions/string_extension.dart';
import 'package:rallet/shared/presentation/ui/components/dialog/error_dialog.dart';
import 'package:rallet/shared/presentation/ui/components/list/selectable/item_selectable.dart';
import 'package:rallet/shared/presentation/ui/components/list/selectable/list_tile_selectable.dart';
import 'package:rallet/shared/presentation/ui/components/list/selectable/list_view_selectable.dart';
import 'package:flutter/material.dart';

class ListTransactions extends StatefulWidget {
  final TransactionsListViewModel viewModel;

  const ListTransactions({super.key, required this.viewModel});

  @override
  State<ListTransactions> createState() => _ListTransactionsState();
}

class _ListTransactionsState extends State<ListTransactions> {
  final Set<String> _settlingIds = <String>{};

  @override
  Widget build(BuildContext context) {
    return ListViewSelectable.builder(
      key: ObjectKey(widget.viewModel.transactions),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 50),
      list: widget.viewModel.transactions,
      itemBuilder: (ItemSelectable<ITransactionEntity> item) {
        final ITransactionEntity transaction = item.value;

        if (transaction is ExpenseEntity) {
          return _expenseTile(item, transaction);
        }
        if (transaction is IncomeEntity) {
          return _incomeTile(item, transaction);
        }
        if (transaction is TransferEntity) {
          return _transferTile(item, transaction);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _expenseTile(
    ItemSelectable<ITransactionEntity> item,
    ExpenseEntity expense,
  ) {
    final category = widget.viewModel.categories.firstWhereOrNull(
      (category) => category.id == expense.idCategory,
    );
    final account = expense.idAccount == null
        ? null
        : widget.viewModel.accountById(expense.idAccount!);
    final card = expense.idCreditCard == null
        ? null
        : widget.viewModel.creditCardById(expense.idCreditCard!);

    final String source = card?.description ?? account?.description ?? 'Sem conta';
    final String meta = '${category?.description ?? 'Categoria indisponível'} • $source';

    return _PremiumTileShell(
      child: ListTileSelectable<ITransactionEntity>(
        value: item,
        contentPadding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
        leading: _CategoryAvatar(
          colorValue: category?.color.toColor(),
          icon: category?.icon.parseIconData() ?? Icons.receipt_long_outlined,
        ),
        title: _TransactionTitle(
          text: expense.description,
          recurring: expense.recurring,
        ),
        subtitle: _TransactionSubtitle(
          meta: meta,
          status: expense.paid ? 'Realizada' : 'Pendente',
          statusType: expense.paid ? _StatusType.realized : _StatusType.pending,
          loading: _settlingIds.contains(expense.id),
          statusTooltip: expense.paid ? null : 'Marcar como paga',
          onStatusTap: expense.paid || _settlingIds.contains(expense.id)
              ? null
              : () => _confirmSettle(expense),
        ),
        trailing: _AmountAndDate(
          amount: expense.amount,
          dateLabel: expense.paid && expense.realizedAt != null
              ? expense.realizedAt!.formatDateToRelative()
              : expense.date.formatDateToRelative(),
        ),
        onTap: () => goDetails(context: context, entity: expense),
      ),
    );
  }

  Widget _incomeTile(
    ItemSelectable<ITransactionEntity> item,
    IncomeEntity income,
  ) {
    final category = widget.viewModel.categories.firstWhereOrNull(
      (category) => category.id == income.idCategory,
    );
    final account = income.idAccount == null
        ? null
        : widget.viewModel.accountById(income.idAccount!);
    final String meta =
        '${category?.description ?? 'Categoria indisponível'} • ${account?.description ?? 'Sem conta'}';

    return _PremiumTileShell(
      child: ListTileSelectable<ITransactionEntity>(
        value: item,
        contentPadding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
        leading: _CategoryAvatar(
          colorValue: category?.color.toColor(),
          icon: category?.icon.parseIconData() ?? Icons.payments_outlined,
        ),
        title: _TransactionTitle(
          text: income.description,
          recurring: income.recurring,
        ),
        subtitle: _TransactionSubtitle(
          meta: meta,
          status: income.received ? 'Realizada' : 'Pendente',
          statusType: income.received ? _StatusType.realized : _StatusType.pending,
          loading: _settlingIds.contains(income.id),
          statusTooltip: income.received ? null : 'Marcar como recebida',
          onStatusTap: income.received || _settlingIds.contains(income.id)
              ? null
              : () => _confirmSettle(income),
        ),
        trailing: _AmountAndDate(
          amount: income.amount,
          dateLabel: income.received && income.realizedAt != null
              ? income.realizedAt!.formatDateToRelative()
              : income.date.formatDateToRelative(),
        ),
        onTap: () => goDetails(context: context, entity: income),
      ),
    );
  }

  Widget _transferTile(
    ItemSelectable<ITransactionEntity> item,
    TransferEntity transfer,
  ) {
    final to = transfer.idAccountTo == null
        ? null
        : widget.viewModel.accountById(transfer.idAccountTo!);
    final from = transfer.idAccountFrom == null
        ? null
        : widget.viewModel.accountById(transfer.idAccountFrom!);

    return Column(
      children: [
        _PremiumTileShell(
          child: ListTileSelectable<ITransactionEntity>(
            value: item,
            contentPadding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
            leading: const _TransferAvatar(incoming: true),
            title: const _TransactionTitle(text: 'Transferência recebida'),
            subtitle: _TransactionSubtitle(
              meta: 'Transferência • ${to?.description ?? 'Conta indisponível'}',
              status: 'Transferência',
              statusType: _StatusType.transfer,
            ),
            trailing: _AmountAndDate(
              amount: transfer.amount.abs(),
              dateLabel: transfer.date.formatDateToRelative(),
            ),
            onTap: () => goDetails(context: context, entity: transfer),
          ),
        ),
        _PremiumTileShell(
          child: ListTileSelectable<ITransactionEntity>(
            value: item,
            contentPadding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
            leading: const _TransferAvatar(incoming: false),
            title: const _TransactionTitle(text: 'Transferência enviada'),
            subtitle: _TransactionSubtitle(
              meta: 'Transferência • ${from?.description ?? 'Conta indisponível'}',
              status: 'Transferência',
              statusType: _StatusType.transfer,
            ),
            trailing: _AmountAndDate(
              amount: -transfer.amount.abs(),
              dateLabel: transfer.date.formatDateToRelative(),
            ),
            onTap: () => goDetails(context: context, entity: transfer),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSettle(ITransactionEntity transaction) async {
    if (_settlingIds.contains(transaction.id)) return;

    final bool isExpense = transaction is ExpenseEntity;
    final String description = isExpense
        ? transaction.description
        : (transaction as IncomeEntity).description;
    final double expected = transaction.amount.abs();

    final SettleTransactionResult? result = await SettleTransactionDialog.show(
      context: context,
      description: description,
      expectedAmount: expected,
      expense: isExpense,
    );

    if (result == null || !mounted) return;

    setState(() => _settlingIds.add(transaction.id));
    try {
      await widget.viewModel.settleTransaction(
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
      if (mounted) setState(() => _settlingIds.remove(transaction.id));
    }
  }

  Future<void> goDetails({
    required BuildContext context,
    required ITransactionEntity entity,
  }) async {
    FormResultNavigation? result;

    switch (entity.runtimeType) {
      case ExpenseEntity:
        await ExpenseDetailsSheet.show(
          context: context,
          id: entity.id,
          onChanged: (value) => result = value,
        );
        break;
      case IncomeEntity:
        await IncomeDetailsSheet.show(
          context: context,
          id: entity.id,
          onChanged: (value) => result = value,
        );
        break;
      case TransferEntity:
        await TransferDetailsSheet.show(
          context: context,
          id: entity.id,
          onChanged: (value) => result = value,
        );
        break;
    }

    if (result == null) return;

    widget.viewModel.findByPeriod.execute((
      startDate: widget.viewModel.startDate,
      endDate: widget.viewModel.endDate,
    ));
  }
}

class _PremiumTileShell extends StatelessWidget {
  final Widget child;

  const _PremiumTileShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: .35),
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CategoryAvatar extends StatelessWidget {
  final int? colorValue;
  final IconData icon;

  const _CategoryAvatar({required this.colorValue, required this.icon});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color base = colorValue == null
        ? scheme.secondaryContainer
        : Color(colorValue!);

    return CircleAvatar(
      radius: 22,
      backgroundColor: base,
      child: Icon(
        icon,
        size: 23,
        color: colorValue == null ? scheme.onSecondaryContainer : Colors.white,
      ),
    );
  }
}

class _TransferAvatar extends StatelessWidget {
  final bool incoming;

  const _TransferAvatar({required this.incoming});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 22,
      backgroundColor: scheme.tertiaryContainer,
      child: Icon(
        incoming ? Icons.south_west_rounded : Icons.north_east_rounded,
        size: 22,
        color: scheme.onTertiaryContainer,
      ),
    );
  }
}

class _TransactionTitle extends StatelessWidget {
  final String text;
  final bool recurring;

  const _TransactionTitle({required this.text, this.recurring = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        if (recurring) ...[
          const SizedBox(width: 5),
          Icon(
            Icons.repeat_rounded,
            size: 15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ],
    );
  }
}

enum _StatusType { realized, pending, transfer }

class _TransactionSubtitle extends StatelessWidget {
  final String meta;
  final String status;
  final _StatusType statusType;
  final bool loading;
  final String? statusTooltip;
  final VoidCallback? onStatusTap;

  const _TransactionSubtitle({
    required this.meta,
    required this.status,
    required this.statusType,
    this.loading = false,
    this.statusTooltip,
    this.onStatusTap,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 5),
          _StatusPill(
            label: status,
            type: statusType,
            loading: loading,
            tooltip: statusTooltip,
            onTap: onStatusTap,
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final _StatusType type;
  final bool loading;
  final String? tooltip;
  final VoidCallback? onTap;

  const _StatusPill({
    required this.label,
    required this.type,
    this.loading = false,
    this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color;
    final IconData icon;

    switch (type) {
      case _StatusType.realized:
        color = const Color(0xFF24B977);
        icon = Icons.check_circle_outline_rounded;
        break;
      case _StatusType.pending:
        color = scheme.primary;
        icon = Icons.schedule_rounded;
        break;
      case _StatusType.transfer:
        color = scheme.tertiary;
        icon = Icons.swap_horiz_rounded;
        break;
    }

    final Widget pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.8, color: color),
            )
          else
            Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );

    if (onTap == null) return pill;

    final Widget interactive = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: pill,
      ),
    );

    return tooltip == null
        ? interactive
        : Tooltip(message: tooltip!, child: interactive);
  }
}

class _AmountAndDate extends StatelessWidget {
  final double amount;
  final String dateLabel;

  const _AmountAndDate({required this.amount, required this.dateLabel});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color amountColor = amount < 0
        ? const Color(0xFFFF5C68)
        : amount > 0
            ? const Color(0xFF2CC985)
            : scheme.onSurface;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 116),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              amount.money,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dateLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
