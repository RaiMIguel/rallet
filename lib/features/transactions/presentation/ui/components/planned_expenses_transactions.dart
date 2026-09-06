import 'package:collection/collection.dart';
import 'package:rallet/features/category/domain/entities/category_entity.dart';
import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';
import 'package:rallet/features/transactions/presentation/view_models/transactions_list_view_model.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PlannedExpensesTransactions extends StatelessWidget {
  final TransactionsListViewModel viewModel;
  final Future<void> Function(PlannedPurchaseEntity plan) onOpen;

  const PlannedExpensesTransactions({
    super.key,
    required this.viewModel,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (viewModel.plannedExpenses.isEmpty) return const SizedBox.shrink();
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.event_note_outlined, color: scheme.primary),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Despesas planejadas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Text(
                    viewModel.plannedExpensesAmount.money,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Entram na previsão, mas continuam separadas do que já foi realizado.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              ...viewModel.plannedExpenses.map((plan) {
                final CategoryEntity? category = viewModel.categories
                    .firstWhereOrNull((item) => item.id == plan.idCategory);
                final double due = plan.amountDueInPeriod(
                  viewModel.startDate,
                  viewModel.endDate,
                );
                final String payment = plan.isCreditCard
                    ? (plan.isInstallment
                        ? '${plan.installmentCount}x no cartão'
                        : 'Cartão à vista')
                    : 'À vista';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: scheme.primary.withValues(alpha: .10),
                    child: Icon(Icons.schedule_rounded, color: scheme.primary),
                  ),
                  title: Text(plan.description),
                  subtitle: Text(
                    '${category?.description ?? 'Sem categoria'} • $payment • ${DateFormat('dd/MM').format(plan.plannedDate)}',
                  ),
                  trailing: Text(
                    due.money,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  onTap: () => onOpen(plan),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
