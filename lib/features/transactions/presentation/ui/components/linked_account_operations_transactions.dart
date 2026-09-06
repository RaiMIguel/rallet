import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/card_cash_advance/presentation/ui/card_cash_advance_details_sheet.dart';
import 'package:rallet/features/transactions/presentation/view_models/transactions_list_view_model.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Entradas vinculadas a uma operação que não é receita econômica.
///
/// Continua apenas como visão da operação original. O bloco visual pode ser
/// recolhido sem alterar qualquer cálculo financeiro.
class LinkedAccountOperationsTransactions extends StatefulWidget {
  final TransactionsListViewModel viewModel;
  final Future<void> Function() onChanged;

  const LinkedAccountOperationsTransactions({
    super.key,
    required this.viewModel,
    required this.onChanged,
  });

  @override
  State<LinkedAccountOperationsTransactions> createState() =>
      _LinkedAccountOperationsTransactionsState();
}

class _LinkedAccountOperationsTransactionsState
    extends State<LinkedAccountOperationsTransactions> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final List<CardCashAdvancePlanEntity> plans = [
      ...widget.viewModel.realizedCashAdvances,
      ...widget.viewModel.plannedLinkedCashAdvances,
    ]
      ..sort((a, b) => a.linkedEntryDate.compareTo(b.linkedEntryDate));

    if (plans.isEmpty) return const SizedBox.shrink();

    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 9),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: .38),
            ),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          Icons.link_rounded,
                          size: 19,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Movimentações vinculadas',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Entradas que movimentam a conta sem virar receita',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      _CountBadge(count: plans.length),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _expanded ? .5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 180),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Column(
                  children: [
                    Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: .45)),
                    ...plans.map((plan) => _LinkedMovementTile(
                          plan: plan,
                          viewModel: widget.viewModel,
                          onChanged: widget.onChanged,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkedMovementTile extends StatelessWidget {
  final CardCashAdvancePlanEntity plan;
  final TransactionsListViewModel viewModel;
  final Future<void> Function() onChanged;

  const _LinkedMovementTile({
    required this.plan,
    required this.viewModel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    const Color success = Color(0xFF24B977);
    final account = viewModel.accountById(plan.idAccount);
    final card = viewModel.creditCardById(plan.idCreditCard);
    final bool planned = plan.isPlanned;
    final Color statusColor = planned ? scheme.primary : success;
    final DateTime date = plan.linkedEntryDate;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: statusColor.withValues(alpha: .10),
        child: Icon(
          planned ? Icons.calendar_month_outlined : Icons.add_card_outlined,
          size: 19,
          color: statusColor,
        ),
      ),
      title: Text(
        plan.description.trim().isEmpty ? 'Crédito via cartão' : plan.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      subtitle: Text(
        '${planned ? 'Prevista' : 'Realizada'} • ${account?.description ?? 'Conta'} • ${card?.description ?? 'Cartão'} • ${DateFormat('dd/MM/yyyy').format(date)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '+${plan.amountReceived.money}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right_rounded, size: 18),
        ],
      ),
      onTap: () async {
        final changed = await CardCashAdvanceDetailsSheet.show(
          context: context,
          plan: plan,
        );
        if (changed == true) await onChanged();
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: .22)),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
