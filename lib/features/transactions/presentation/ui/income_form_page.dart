import 'dart:math';

import 'package:collection/collection.dart';
import 'package:rallet/di/dependency_injection.dart';
import 'package:rallet/features/account/domain/entities/account_entity.dart';
import 'package:rallet/features/account/domain/enums/financial_institution_enum.dart';
import 'package:rallet/features/account/presentation/ui/components/accounts_list_bottom_sheet.dart';
import 'package:rallet/features/category/domain/entities/category_entity.dart';
import 'package:rallet/features/category/presentation/ui/components/categories_list_bottom_sheet.dart';
import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/domain/entities/transaction_by_text_entity.dart';
import 'package:rallet/features/transactions/domain/enums/recurrence_scope_enum.dart';
import 'package:rallet/features/transactions/presentation/view_models/income_form_view_model.dart';
import 'package:rallet/features/transactions/presentation/ui/components/recurrence_scope_dialog.dart';
import 'package:rallet/shared/classes/form_result_navigation.dart';
import 'package:rallet/shared/extensions/date_time_extension.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/extensions/int_extension.dart';
import 'package:rallet/shared/extensions/string_extension.dart';
import 'package:rallet/shared/presentation/mixins/theme_context.dart';
import 'package:rallet/shared/presentation/ui/app_locale.dart';
import 'package:rallet/shared/presentation/ui/components/dialog/date_picker.dart';
import 'package:rallet/shared/presentation/ui/components/dialog/error_dialog.dart';
import 'package:rallet/shared/presentation/ui/components/form/mask/mask_input_formatter.dart';
import 'package:rallet/shared/presentation/ui/components/form/validators/input_greater_than_value_validator.dart';
import 'package:rallet/shared/presentation/ui/components/form/validators/input_required_validator.dart';
import 'package:rallet/shared/presentation/ui/components/form/validators/input_validators.dart';
import 'package:rallet/shared/presentation/ui/components/group_tile.dart';
import 'package:rallet/shared/presentation/ui/components/sliver/sliver_app_bar_medium.dart';
import 'package:rallet/shared/presentation/ui/components/sliver/sliver_scaffold.dart';
import 'package:rallet/shared/presentation/ui/components/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class IncomeFormPage extends StatefulWidget {
  static const route = 'income-form';

  final IncomeEntity? income;

  const IncomeFormPage({Key? key, this.income}) : super(key: key);

  @override
  State<IncomeFormPage> createState() => _IncomeFormPageState();
}

class _IncomeFormPageState extends State<IncomeFormPage> with ThemeContext {
  final IncomeFormViewModel viewModel = DI.get<IncomeFormViewModel>();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController amountController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController observationController = TextEditingController();

  final FocusNode descriptionFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    Future(() async {
      try {
        await viewModel.init.execute(widget.income);
        viewModel.init.throwIfError();

        amountController.text = viewModel.income.amount.abs().moneyWithoutSymbol;
        descriptionController.text = viewModel.income.description;
        dateController.text = viewModel.income.date.format();
        observationController.text = viewModel.income.observation ?? '';
      } catch (e) {
        if (!mounted) return;
        ErrorDialog.show(context, e.toString());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([viewModel.save, viewModel.delete]),
      builder: (_, __) {
        return SliverScaffold(
          appBar: SliverAppBarMedium(
            title: Text(strings.income),
            loading: viewModel.isLoading,
            actions: [
              FilledButton(
                onPressed: save,
                child: Text(strings.save),
              ),
            ],
          ),
          body: ListenableBuilder(
            listenable: Listenable.merge([viewModel, viewModel.init]),
            builder: (_, __) {
              if (viewModel.init.running) return const SizedBox.shrink();

              return Form(
                key: formKey,
                child: Column(
                  children: [
                    const Spacing.y(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: amountController,
                            decoration: InputDecoration(
                              label: Text(strings.amount),
                              prefixText: NumberFormat.simpleCurrency(locale: R.locale.toString()).currencySymbol,
                            ),
                            validator: InputValidators([InputRequiredValidator(), InputGreaterThanValueValidator(0)]).validate,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            enabled: !viewModel.isLoading,
                            onSaved: (String? value) => viewModel.income.amount = (value ?? '').moneyToDouble(),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, MaskInputFormatter.currency()],
                          ),
                          const Spacing.y(),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return Autocomplete<TransactionByTextEntity>(
                                textEditingController: descriptionController,
                                focusNode: descriptionFocusNode,
                                displayStringForOption: (TransactionByTextEntity option) => option.description,
                                fieldViewBuilder: (_, textController, focusNode, ___) {
                                  return TextFormField(
                                    decoration: InputDecoration(label: Text(strings.description)),
                                    textCapitalization: TextCapitalization.sentences,
                                    controller: textController,
                                    focusNode: focusNode,
                                    validator: InputRequiredValidator().validate,
                                    onSaved: (String? value) => viewModel.income.description = value?.trim() ?? '',
                                    enabled: !viewModel.isLoading,
                                  );
                                },
                                optionsBuilder: (TextEditingValue textEditingValue) async {
                                  if (textEditingValue.text.length <= 1) return [];

                                  await viewModel.findByText.execute(textEditingValue.text);
                                  viewModel.findByText.throwIfError();

                                  return viewModel.findByText.result ?? [];
                                },
                                onSelected: (TransactionByTextEntity selection) {
                                  viewModel.setIdCategory(selection.idCategory);
                                  if (selection.idAccount != null && viewModel.accounts.any((c) => c.id == selection.idAccount && c.deletedAt == null)) viewModel.setIdAccount(selection.idAccount!);
                                  viewModel.income.observation = selection.observation;
                                  observationController.text = selection.observation ?? '';
                                },
                                optionsViewBuilder: (context, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 12,
                                      color: colorScheme.surface,
                                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(4.0))),
                                      child: SizedBox(
                                        height: min(160, 80.0 * options.length),
                                        width: constraints.biggest.width,
                                        child: ListView.builder(
                                          physics: const BouncingScrollPhysics(),
                                          padding: EdgeInsets.zero,
                                          itemCount: options.length,
                                          itemBuilder: (_, index) {
                                            final TransactionByTextEntity income = options.elementAt(index);
                                            final category = viewModel.categories.firstWhereOrNull((category) => category.id == income.idCategory);
                                            if (category == null) return const SizedBox.shrink();

                                            return ListTile(
                                              dense: true,
                                              leading: CircleAvatar(
                                                radius: 18,
                                                backgroundColor: Color(category.color.toColor()!),
                                                child: Icon(category.icon.parseIconData(), color: Colors.white),
                                              ),
                                              title: Text(income.description),
                                              subtitle: Text(category.description),
                                              onTap: () => onSelected(income),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const Spacing.y(),
                          TextFormField(
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.calendar_today_outlined),
                              label: Text(strings.date),
                            ),
                            readOnly: true,
                            controller: dateController,
                            validator: InputRequiredValidator().validate,
                            enabled: !viewModel.isLoading,
                            onTap: selectDate,
                          ),
                        ],
                      ),
                    ),
                    const Spacing.y(),
                    const Divider(),
                    ListTile(
                      leading: viewModel.income.received ? const Icon(Icons.task_alt_outlined) : const Icon(Icons.push_pin_outlined),
                      title: Text(viewModel.income.received ? strings.received : strings.unReceived),
                      trailing: Switch(value: viewModel.income.received, onChanged: viewModel.setReceived),
                      onTap: () => viewModel.setReceived(!viewModel.income.received),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.repeat),
                      title: Text(strings.monthlyRecurrence),
                      subtitle: Text(
                        viewModel.isEditingRecurrence
                            ? 'Ao salvar, você poderá aplicar a alteração somente neste lançamento ou na recorrência.'
                            : strings.monthlyRecurrenceDescription,
                      ),
                      trailing: Switch(
                        value: viewModel.income.recurring,
                        onChanged: !viewModel.isLoading ? viewModel.setRecurring : null,
                      ),
                      onTap: !viewModel.isLoading
                          ? () => viewModel.setRecurring(!viewModel.income.recurring)
                          : null,
                    ),
                    const Divider(),
                    GroupTile(
                      onTap: selectCategory,
                      title: strings.category,
                      enabled: !viewModel.isLoading,
                      tile: viewModel.income.idCategory != null
                          ? Builder(
                              builder: (_) {
                                final CategoryEntity? category = viewModel.categories.firstWhereOrNull(
                                  (category) => category.id == viewModel.income.idCategory,
                                );
                                if (category == null) {
                                  return ListTile(
                                    leading: const Icon(Icons.warning_amber_rounded),
                                    title: const Text('Categoria não encontrada'),
                                    subtitle: const Text('Selecione novamente antes de salvar.'),
                                    trailing: const Icon(Icons.chevron_right),
                                    enabled: !viewModel.isLoading,
                                  );
                                }
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Color(category.color.toColor() ?? 0),
                                    child: Icon(category.icon.parseIconData(), color: Colors.white),
                                  ),
                                  title: Text(category.description),
                                  trailing: const Icon(Icons.chevron_right),
                                  enabled: !viewModel.isLoading,
                                );
                              },
                            )
                          : ListTile(
                              leading: const Icon(Icons.category_outlined),
                              title: Text(strings.selectCategory),
                              trailing: const Icon(Icons.chevron_right),
                              enabled: !viewModel.isLoading,
                            ),
                    ),
                    const Divider(),
                    GroupTile(
                      onTap: selectAccount,
                      title: strings.account,
                      enabled: !viewModel.isLoading,
                      tile: viewModel.income.idAccount != null
                          ? Builder(
                              builder: (_) {
                                final AccountEntity? account = viewModel.accounts.firstWhereOrNull(
                                  (account) => account.id == viewModel.income.idAccount,
                                );
                                if (account == null) {
                                  return ListTile(
                                    leading: const Icon(Icons.warning_amber_rounded),
                                    title: const Text('Conta não encontrada'),
                                    subtitle: const Text('Selecione novamente antes de salvar.'),
                                    trailing: const Icon(Icons.chevron_right),
                                    enabled: !viewModel.isLoading,
                                  );
                                }
                                return ListTile(
                                  leading: account.financialInstitution?.icon() ?? const Icon(Icons.account_balance_outlined),
                                  title: Text(account.description),
                                  trailing: const Icon(Icons.chevron_right),
                                  enabled: !viewModel.isLoading,
                                );
                              },
                            )
                          : ListTile(
                              leading: const Icon(Icons.account_balance_outlined),
                              title: Text(strings.selectAccount),
                              trailing: const Icon(Icons.chevron_right),
                              enabled: !viewModel.isLoading,
                            ),
                    ),
                    const Divider(),
                    const Spacing.y(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextFormField(
                        controller: observationController,
                        decoration: InputDecoration(label: Text("${strings.observation} (${strings.optional})")),
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 2,
                        maxLines: 5,
                        onSaved: (String? value) => viewModel.income.observation = value?.trim() ?? '',
                        enabled: !viewModel.isLoading,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> save() async {
    if (viewModel.isLoading) return;

    try {
      if (formKey.currentState?.validate() ?? false) {
        formKey.currentState?.save();

        if (viewModel.amountChanged) {
          final bool? trackRealDifference = await _askAmountChangeMode(
            expected: viewModel.originalAmount,
            actual: viewModel.income.amount,
          );
          if (trackRealDifference == null) return;
          if (trackRealDifference) {
            viewModel.markAmountAsRealizedVariance();
          } else {
            viewModel.markAmountAsCorrection();
          }
        }

        if (viewModel.isEditingRecurrence) {
          if (!mounted) return;
          final RecurrenceScopeEnum? scope = await RecurrenceScopeDialog.show(
            context: context,
            deleting: false,
            stopping: viewModel.isStoppingRecurrence,
          );
          if (scope == null) return;
          viewModel.setRecurrenceScope(scope);
        }

        await viewModel.save.execute(viewModel.income);
        viewModel.save.throwIfError();

        if (!mounted) return;
        if (viewModel.income.trackVariance &&
            viewModel.income.expectedAmount != null &&
            viewModel.income.varianceRegisteredAt != null) {
          final double difference = viewModel.income.varianceAmount;
          final String message = difference >= 0
              ? 'Receita ${difference.money} acima do esperado.'
              : 'Atenção: receita ${difference.abs().money} abaixo do esperado.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
        context.pop(FormResultNavigation.save(viewModel.income));
      }
    } catch (e) {
      if (!mounted) return;
      await ErrorDialog.show(context, e.toString());
    }
  }


  Future<bool?> _askAmountChangeMode({
    required double expected,
    required double actual,
  }) {
    final double difference = actual - expected;
    final String impact = difference >= 0
        ? '${difference.abs().money} acima do esperado.'
        : '${difference.abs().money} abaixo do esperado.';

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Como registrar esta alteração?'),
        content: Text(
          'Valor anterior: ${expected.money}\n'
          'Novo valor: ${actual.money}\n\n'
          '$impact\n\n'
          'Use “Só corrigir valor” quando o cadastro sempre esteve errado. Isso não gera economia nem desvio. '
          'Use “Registrar diferença real” somente quando o valor anterior era realmente o esperado e o que aconteceu foi diferente.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(null),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Só corrigir valor'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Registrar diferença real'),
          ),
        ],
      ),
    );
  }

  Future<void> delete() async {
    if (viewModel.isLoading) return;

    try {
      RecurrenceScopeEnum scope = RecurrenceScopeEnum.single;

      if (viewModel.isEditingRecurrence) {
        final RecurrenceScopeEnum? selected = await RecurrenceScopeDialog.show(
          context: context,
          deleting: true,
        );
        if (selected == null) return;
        scope = selected;
      }

      await viewModel.delete.execute(scope);
      viewModel.delete.throwIfError();

      if (!mounted) return;
      context.pop(FormResultNavigation<IncomeEntity>.delete());
    } catch (e) {
      await ErrorDialog.show(context, e.toString());
    }
  }

  Future<void> selectCategory() async {
    if (viewModel.isLoading) return;

    final CategoryEntity? result = await CategoriesListBottomSheet.show(
      context: context,
      categorySelected: viewModel.categories.firstWhereOrNull((category) => category.id == viewModel.income.idCategory),
      categories: viewModel.categories.where((category) => category.deletedAt == null).toList(),
      onCategoryCreated: (CategoryEntity category) => viewModel.categories.add(category),
    );

    if (result == null) return;

    viewModel.setIdCategory(result.id);
  }

  Future<void> selectAccount() async {
    if (viewModel.isLoading) return;

    final AccountEntity? result = await AccountsListBottomSheet.show(
      context: context,
      accountSelected: viewModel.accounts.firstWhereOrNull((account) => account.id == viewModel.income.idAccount),
      accounts: viewModel.accounts.where((account) => account.deletedAt == null).toList(),
      onAccountCreated: (AccountEntity account) => viewModel.accounts.add(account),
    );

    if (result == null) return;

    viewModel.setIdAccount(result.id);
  }

  Future<void> selectDate() async {
    if (viewModel.isLoading) return;

    final DateTime? result = await showDatePickerDefault(
      context: context,
      initialDate: viewModel.income.date,
    );

    if (result == null || result == viewModel.income.date) return;

    if (result.isAfter(DateTime.now()) && viewModel.income.date.isBefore(DateTime.now())) viewModel.setReceived(false);

    dateController.text = result.format();
    viewModel.setDate(result);
  }
}
