import 'package:rallet/features/card_cash_advance/presentation/ui/card_cash_advance_form_page.dart';
import 'package:rallet/features/credit_card/presentation/ui/credit_card_bill_details_page.dart';
import 'package:rallet/features/transactions/presentation/view_models/transactions_list_view_model.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Compromissos futuros exibidos sem duplicar a transação econômica.
class ProjectedCommitmentsTransactions extends StatefulWidget {
  final TransactionsListViewModel viewModel;
  final Future<void> Function() onChanged;

  const ProjectedCommitmentsTransactions({
    super.key,
    required this.viewModel,
    required this.onChanged,
  });

  @override
  State<ProjectedCommitmentsTransactions> createState() =>
      _ProjectedCommitmentsTransactionsState();
}

class _ProjectedCommitmentsTransactionsState
    extends State<ProjectedCommitmentsTransactions> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final int count = widget.viewModel.forecastBills.length +
        widget.viewModel.forecastCashAdvancePlans.length;
    if (count == 0) return const SizedBox.shrink();

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
                          color: scheme.tertiary.withValues(alpha: .11),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          Icons.event_available_outlined,
                          size: 19,
                          color: scheme.tertiary,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Compromissos previstos',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Faturas e cobranças que já afetam a previsão',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      _CountBadge(count: count),
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
                    ...widget.viewModel.forecastBills.map((bill) {
                      final card = widget.viewModel.creditCardById(bill.idCreditCard);
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: scheme.tertiary.withValues(alpha: .10),
                          child: Icon(Icons.schedule_rounded, size: 19, color: scheme.tertiary),
                        ),
                        title: Text(
                          card == null ? 'Fatura do cartão' : 'Fatura • ${card.description}',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        subtitle: Text(
                          'Pendente • vence em ${DateFormat('dd/MM/yyyy').format(bill.billDueDate)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              bill.billAmount.abs().money,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            if (card != null) ...[
                              const SizedBox(width: 2),
                              const Icon(Icons.chevron_right_rounded, size: 18),
                            ],
                          ],
                        ),
                        onTap: card == null
                            ? null
                            : () async {
                                final result = await context.pushNamed(
                                  CreditCardBillDetailsPage.route,
                                  extra: CreditCardBillDetailsArgsPage(
                                    bill: bill,
                                    creditCard: card,
                                  ),
                                );
                                if (result != null) await widget.onChanged();
                              },
                      );
                    }),
                    ...widget.viewModel.forecastCashAdvancePlans.map((plan) {
                      final card = widget.viewModel.creditCardById(plan.idCreditCard);
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: scheme.primary.withValues(alpha: .10),
                          child: Icon(Icons.event_note_outlined, size: 19, color: scheme.primary),
                        ),
                        title: Text(
                          'Crédito planejado • cobrança',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        subtitle: Text(
                          '${card?.description ?? 'Cartão'} • fatura ${DateFormat('dd/MM/yyyy').format(plan.billDueDate)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              plan.amountCharged.abs().money,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.chevron_right_rounded, size: 18),
                          ],
                        ),
                        onTap: () async {
                          final result = await context.pushNamed(
                            CardCashAdvanceFormPage.route,
                            extra: CardCashAdvanceFormArgs(plan: plan),
                          );
                          if (result == true) await widget.onChanged();
                        },
                      );
                    }),
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
        color: scheme.tertiary.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.tertiary.withValues(alpha: .22)),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.tertiary,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
