import 'package:rallet/di/dependency_injection.dart';
import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/card_cash_advance/presentation/ui/card_cash_advance_form_page.dart';
import 'package:rallet/features/card_cash_advance/presentation/view_models/card_cash_advance_details_view_model.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/presentation/ui/components/dialog/confim_dialog.dart';
import 'package:rallet/shared/presentation/ui/components/dialog/error_dialog.dart';
import 'package:rallet/shared/presentation/ui/components/draggable_bottom_sheet.dart';
import 'package:rallet/shared/presentation/ui/components/message_error_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CardCashAdvanceDetailsSheet extends StatefulWidget {
  final CardCashAdvancePlanEntity plan;

  const CardCashAdvanceDetailsSheet._({required this.plan});

  static Future<bool?> show({
    required BuildContext context,
    required CardCashAdvancePlanEntity plan,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      enableDrag: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => CardCashAdvanceDetailsSheet._(plan: plan),
    );
  }

  @override
  State<CardCashAdvanceDetailsSheet> createState() =>
      _CardCashAdvanceDetailsSheetState();
}

class _CardCashAdvanceDetailsSheetState
    extends State<CardCashAdvanceDetailsSheet> {
  final CardCashAdvanceDetailsViewModel viewModel =
      DI.get<CardCashAdvanceDetailsViewModel>();

  @override
  void initState() {
    super.initState();
    viewModel.load.execute(widget.plan);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        viewModel,
        viewModel.load,
        viewModel.undoRealization,
        viewModel.repairLinkedTransaction,
      ]),
      builder: (_, __) {
        return DraggableBottomSheet(
          initialChildSize: .78,
          builder: (scrollController) {
            if (viewModel.load.running) {
              return const Center(child: CircularProgressIndicator());
            }
            if (viewModel.load.hasError) {
              return MessageErrorWidget(viewModel.load.error.toString());
            }

            final plan = viewModel.plan;
            final ColorScheme scheme = Theme.of(context).colorScheme;
            const Color success = Color(0xFF1AA56B);

            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.add_card_outlined, color: scheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.description.trim().isEmpty
                                  ? 'Crédito via cartão'
                                  : plan.description,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  plan.isRealized
                                      ? Icons.check_circle_rounded
                                      : Icons.schedule_rounded,
                                  size: 17,
                                  color: plan.isRealized ? success : scheme.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(plan.isRealized ? 'Realizado' : 'Planejado'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _DetailRow(
                    label: 'Valor recebido',
                    value: plan.amountReceived.money,
                  ),
                  _DetailRow(
                    label: 'Valor cobrado no cartão',
                    value: plan.amountCharged.money,
                  ),
                  _DetailRow(
                    label: 'Custo financeiro',
                    value: plan.financialCost.money,
                  ),
                  const _DetailRow(
                    label: 'Origem',
                    value: 'Crédito via cartão',
                  ),
                  _DetailRow(
                    label: 'Conta',
                    value: viewModel.account?.description ?? 'Conta indisponível',
                  ),
                  _DetailRow(
                    label: 'Cartão',
                    value: viewModel.creditCard?.description ?? 'Cartão indisponível',
                  ),
                  _DetailRow(
                    label: 'Data planejada',
                    value: DateFormat('dd/MM/yyyy').format(plan.plannedDate),
                  ),
                  if (plan.realizedAt != null)
                    _DetailRow(
                      label: 'Realizado em',
                      value: DateFormat('dd/MM/yyyy HH:mm').format(plan.realizedAt!),
                    ),
                  _DetailRow(
                    label: 'Vencimento da fatura',
                    value: DateFormat('dd/MM/yyyy').format(plan.billDueDate),
                  ),
                  const SizedBox(height: 16),
                  if (plan.isPlanned)
                    FilledButton.icon(
                      onPressed: () => _editPlan(plan),
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: const Text('Editar planejamento'),
                    )
                  else if (viewModel.linkedTransactionMissing) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer.withValues(alpha: .65),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'A cobrança vinculada deste crédito foi removida da fatura. A entrada na conta foi preservada. Repare o vínculo antes de ajustar a operação.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onErrorContainer,
                            ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: viewModel.repairLinkedTransaction.running
                          ? null
                          : _repairLinkedTransaction,
                      icon: viewModel.repairLinkedTransaction.running
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.build_circle_outlined),
                      label: const Text('Reparar movimentação'),
                    ),
                  ] else ...[
                    Text(
                      'Para alterar valor, conta, cartão ou data sem quebrar o vínculo financeiro, o Rallet desfaz a realização completa e volta esta operação para planejamento.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: viewModel.undoRealization.running
                          ? null
                          : _undoAndEdit,
                      icon: viewModel.undoRealization.running
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.undo_rounded),
                      label: const Text('Desfazer realização e ajustar'),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editPlan(CardCashAdvancePlanEntity plan) async {
    final result = await context.pushNamed(
      CardCashAdvanceFormPage.route,
      extra: CardCashAdvanceFormArgs(plan: plan),
    );
    if (!mounted) return;
    if (result == true) Navigator.of(context).pop(true);
  }

  Future<void> _repairLinkedTransaction() async {
    try {
      await viewModel.repairLinkedTransaction.execute();
      viewModel.repairLinkedTransaction.throwIfError();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Movimentação restaurada na fatura original.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await ErrorDialog.show(context, e.toString());
    }
  }

  Future<void> _undoAndEdit() async {
    final bool confirm = await ConfirmDialog.show(
      context: context,
      title: 'Desfazer realização?',
      message:
          'A entrada na conta e o lançamento vinculado no cartão serão revertidos juntos. Depois a operação voltará para planejamento para você ajustar.',
    );
    if (!confirm) return;

    try {
      await viewModel.undoRealization.execute();
      viewModel.undoRealization.throwIfError();
      final plan = viewModel.undoRealization.result;
      if (plan == null || !mounted) return;

      final result = await context.pushNamed(
        CardCashAdvanceFormPage.route,
        extra: CardCashAdvanceFormArgs(plan: plan),
      );
      if (!mounted) return;
      Navigator.of(context).pop(result == true || plan.isPlanned);
    } catch (e) {
      if (!mounted) return;
      await ErrorDialog.show(context, e.toString());
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
