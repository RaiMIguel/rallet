import 'package:rallet/di/dependency_injection.dart';
import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/enums/recurrence_scope_enum.dart';
import 'package:rallet/features/transactions/presentation/ui/components/details/actions_transaction_details_sheet.dart';
import 'package:rallet/features/transactions/presentation/ui/components/details/header_transaction_details_sheet.dart';
import 'package:rallet/features/transactions/presentation/ui/components/details/label_value_transaction_details_sheet.dart';
import 'package:rallet/features/transactions/presentation/ui/components/recurrence_scope_dialog.dart';
import 'package:rallet/features/transactions/presentation/ui/components/settle_transaction_dialog.dart';
import 'package:rallet/features/transactions/presentation/ui/expense_form_page.dart';
import 'package:rallet/features/transactions/presentation/view_models/expense_details_view_model.dart';
import 'package:rallet/shared/classes/form_result_navigation.dart';
import 'package:rallet/shared/extensions/date_time_extension.dart';
import 'package:rallet/shared/extensions/int_extension.dart';
import 'package:rallet/shared/extensions/string_extension.dart';
import 'package:rallet/shared/presentation/mixins/theme_context.dart';
import 'package:rallet/shared/presentation/ui/components/dialog/confim_dialog.dart';
import 'package:rallet/shared/presentation/ui/components/dialog/error_dialog.dart';
import 'package:rallet/shared/presentation/ui/components/draggable_bottom_sheet.dart';
import 'package:rallet/shared/presentation/ui/components/message_error_widget.dart';
import 'package:rallet/shared/presentation/ui/components/spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ExpenseDetailsSheet extends StatefulWidget {
  final String id;
  final void Function(FormResultNavigation<ExpenseEntity>)? onChanged;

  const ExpenseDetailsSheet._({required this.id, this.onChanged});

  static Future<void> show({required BuildContext context, required String id,void Function(FormResultNavigation<ExpenseEntity>)? onChanged}) async {
    return await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      enableDrag: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => ExpenseDetailsSheet._(id: id, onChanged: onChanged),
    );
  }

  @override
  State<ExpenseDetailsSheet> createState() => _ExpenseDetailsSheetState();
}

class _ExpenseDetailsSheetState extends State<ExpenseDetailsSheet> with ThemeContext {
  final ExpenseDetailsViewModel viewModel = DI.get<ExpenseDetailsViewModel>();

  @override
  void initState() {
    viewModel.load.execute(widget.id);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([viewModel, viewModel.load]),
      builder: (_, __) {
        return DraggableBottomSheet(
          initialChildSize: 0.7,
          builder: (scrollController) {
            if (viewModel.load.running) return const Center(child: CircularProgressIndicator());
            if (viewModel.load.hasError) return MessageErrorWidget(viewModel.load.error.toString());

            if (viewModel.load.completed) {
              return SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          HeaderTransactionDetailsSheet(
                            description: viewModel.expense.description,
                            amount: viewModel.expense.amount,
                            iconAvatar: viewModel.category.icon.parseIconData(),
                            backgroundColorAvatar: Color(viewModel.category.color.toColor()!),
                            onBackgroundColorAvatar: Colors.white,
                            financialInstitution: viewModel.account.financialInstitution,
                          ),
                          const Spacing.y(1.5),
                          ActionsTransactionDetailsSheet(
                            onEditPressed: viewModel.expense.idCreditCardTransaction == null ? goFormsPage : null,
                            onDeletePressed: delete,
                            children: [
                              if (viewModel.expense.idCreditCardTransaction == null)
                                ListenableBuilder(
                                  listenable: Listenable.merge([viewModel.savePaid, viewModel.settle]),
                                  builder: (_, __) {
                                    final bool running = viewModel.savePaid.running || viewModel.settle.running;
                                    return FilledButton.icon(
                                      label: Text(viewModel.expense.paid ? strings.undoPayment : strings.markAsPaid),
                                      icon: running
                                          ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: colorScheme.onPrimary, strokeWidth: 2.5))
                                          : Icon(viewModel.expense.paid ? Icons.push_pin_outlined : Icons.task_alt_outlined),
                                      style: viewModel.expense.paid ? null : FilledButton.styleFrom(backgroundColor: colorScheme.surfaceDim, foregroundColor: colorScheme.onSurface),
                                      onPressed: running
                                          ? null
                                          : viewModel.expense.paid
                                              ? _undoPayment
                                              : _settlePayment,
                                    );
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacing.y(),
                    const Divider(),
                    const Spacing.y(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              LabelValueTransactionDetailsSheet(
                                label: viewModel.expense.paid
                                    ? 'Data prevista'
                                    : strings.date,
                                value: viewModel.expense.date.formatDateToRelative(),
                              ),
                              LabelValueTransactionDetailsSheet(
                                label: strings.account,
                                value: viewModel.account.description,
                                crossAxisAlignment: CrossAxisAlignment.end,
                              ),
                            ],
                          ),
                          const Spacing.y(1.5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              LabelValueTransactionDetailsSheet(
                                label: strings.category,
                                value: viewModel.category.description,
                              ),
                              LabelValueTransactionDetailsSheet(
                                label: strings.type,
                                value: strings.expense,
                                crossAxisAlignment: CrossAxisAlignment.end,
                              ),
                            ],
                          ),
                          const Spacing.y(1.5),
                          if (viewModel.expense.paid &&
                              viewModel.expense.realizedAt != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                LabelValueTransactionDetailsSheet(
                                  label: 'Realizado em',
                                  value: DateFormat('dd/MM/yyyy HH:mm')
                                      .format(viewModel.expense.realizedAt!),
                                ),
                                LabelValueTransactionDetailsSheet(
                                  label: 'Origem',
                                  value: 'Despesa',
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                ),
                              ],
                            ),
                            const Spacing.y(1.5),
                          ] else ...[
                            LabelValueTransactionDetailsSheet(
                              label: 'Origem',
                              value: 'Despesa pendente',
                            ),
                            const Spacing.y(1.5),
                          ],
                          if (viewModel.expense.observation?.isNotEmpty == true) ...[
                            LabelValueTransactionDetailsSheet(
                              label: strings.observation,
                              value: viewModel.expense.observation!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        );
      },
    );
  }


  Future<void> _settlePayment() async {
    final result = await SettleTransactionDialog.show(
      context: context,
      description: viewModel.expense.description,
      expectedAmount: viewModel.expense.amount.abs(),
      expense: true,
    );
    if (result == null || !mounted) return;
    try {
      await viewModel.settle.execute((
        realizedAmount: result.realizedAmount,
        trackVariance: result.trackVariance,
        realizedAt: result.realizedAt,
      ));
      viewModel.settle.throwIfError();
      widget.onChanged?.call(FormResultNavigation.save(viewModel.expense));
    } catch (e) {
      if (!mounted) return;
      await ErrorDialog.show(context, e.toString());
    }
  }

  Future<void> _undoPayment() async {
    try {
      await viewModel.savePaid.execute(false);
      viewModel.savePaid.throwIfError();
      widget.onChanged?.call(FormResultNavigation.save(viewModel.expense));
    } catch (e) {
      if (!mounted) return;
      await ErrorDialog.show(context, e.toString());
    }
  }

  Future<void> goFormsPage() async {
    final FormResultNavigation<ExpenseEntity>? result = await context.pushNamed(ExpenseFormPage.route, extra: viewModel.expense);

    if (result?.isSave == true) {
      widget.onChanged?.call(result!);
      viewModel.load.execute(result!.value!.id);
    }
  }

  Future<void> delete() async {
    try {
      RecurrenceScopeEnum scope = RecurrenceScopeEnum.single;

      if (viewModel.expense.recurring && viewModel.expense.recurrenceId != null) {
        final RecurrenceScopeEnum? selected = await RecurrenceScopeDialog.show(
          context: context,
          deleting: true,
        );
        if (selected == null) return;
        scope = selected;
      } else {
        final bool confirm = await ConfirmDialog.show(
          context: context,
          title: strings.deleteExpense,
          message: strings.deleteExpenseConfirmation,
        );
        if (!confirm) return;
      }

      await viewModel.delete.execute(scope);
      viewModel.delete.throwIfError();

      widget.onChanged?.call(FormResultNavigation<ExpenseEntity>.delete());

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      await ErrorDialog.show(context, e.toString());
    }
  }
}
