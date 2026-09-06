import 'package:rallet/di/dependency_injection.dart';
import 'package:rallet/features/account/domain/entities/account_entity.dart';
import 'package:rallet/features/account/domain/enums/financial_institution_enum.dart';
import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/card_cash_advance/presentation/view_models/card_cash_advance_form_view_model.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/shared/extensions/date_time_extension.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/extensions/string_extension.dart';
import 'package:rallet/shared/presentation/mixins/theme_context.dart';
import 'package:rallet/shared/presentation/ui/components/calculation_info_button.dart';
import 'package:rallet/shared/presentation/ui/app_locale.dart';
import 'package:rallet/shared/presentation/ui/components/dialog/date_picker.dart';
import 'package:rallet/shared/presentation/ui/components/dialog/error_dialog.dart';
import 'package:rallet/shared/presentation/ui/components/form/mask/mask_input_formatter.dart';
import 'package:rallet/shared/presentation/ui/components/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CardCashAdvanceFormArgs {
  final CardCashAdvancePlanEntity? plan;
  final double? suggestedAmount;
  final String? idCreditCard;
  final String? idAccount;

  const CardCashAdvanceFormArgs({
    this.plan,
    this.suggestedAmount,
    this.idCreditCard,
    this.idAccount,
  });
}

class CardCashAdvanceFormPage extends StatefulWidget {
  static const String route = 'card-cash-advance-form';

  final CardCashAdvanceFormArgs args;

  const CardCashAdvanceFormPage({super.key, required this.args});

  @override
  State<CardCashAdvanceFormPage> createState() => _CardCashAdvanceFormPageState();
}

class _CardCashAdvanceFormPageState extends State<CardCashAdvanceFormPage> with ThemeContext {
  final CardCashAdvanceFormViewModel viewModel = DI.get<CardCashAdvanceFormViewModel>();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final descriptionController = TextEditingController();
  final receivedController = TextEditingController();
  final chargedController = TextEditingController();
  final dateController = TextEditingController();
  bool initialized = false;

  @override
  void initState() {
    super.initState();
    Future(() async {
      await viewModel.load(
        existing: widget.args.plan,
        suggestedAmount: widget.args.suggestedAmount,
        preferredCreditCardId: widget.args.idCreditCard,
        preferredAccountId: widget.args.idAccount,
      );
      descriptionController.text = viewModel.plan.description;
      receivedController.text = viewModel.plan.amountReceived > 0 ? viewModel.plan.amountReceived.moneyWithoutSymbol : '';
      chargedController.text = viewModel.plan.amountCharged > 0 ? viewModel.plan.amountCharged.moneyWithoutSymbol : '';
      dateController.text = viewModel.plan.plannedDate.format();
      if (!mounted) return;
      setState(() => initialized = true);
    });
  }

  @override
  void dispose() {
    descriptionController.dispose();
    receivedController.dispose();
    chargedController.dispose();
    dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.plan == null ? 'Planejar cobertura' : 'Alterar planejamento'),
        actions: [
          if (widget.args.plan != null)
            IconButton(
              tooltip: 'Cancelar planejamento',
              onPressed: viewModel.isLoading ? null : cancelPlan,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: !initialized
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: viewModel,
              builder: (_, __) => Form(
                key: formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline, color: colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Enquanto estiver planejado, este crédito entra nas projeções e em A receber/A pagar, mas não altera o saldo nem o limite real do cartão.',
                              style: textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacing.y(1.5),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Descrição'),
                      enabled: !viewModel.isLoading,
                      validator: (value) => value?.trim().isEmpty == true ? 'Informe uma descrição.' : null,
                      onChanged: (value) => viewModel.plan.description = value,
                    ),
                    const Spacing.y(),
                    TextFormField(
                      controller: receivedController,
                      decoration: InputDecoration(
                        labelText: 'Valor que você vai receber',
                        prefixText: NumberFormat.simpleCurrency(locale: R.locale.toString()).currencySymbol,
                      ),
                      enabled: !viewModel.isLoading,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, MaskInputFormatter.currency()],
                      validator: _validateMoney,
                      onChanged: (value) => viewModel.setAmounts(received: value.moneyToDouble()),
                    ),
                    const Spacing.y(),
                    TextFormField(
                      controller: chargedController,
                      decoration: InputDecoration(
                        labelText: 'Valor previsto na fatura',
                        prefixText: NumberFormat.simpleCurrency(locale: R.locale.toString()).currencySymbol,
                        helperText: 'Inclua juros e taxas previstos.',
                      ),
                      enabled: !viewModel.isLoading,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, MaskInputFormatter.currency()],
                      validator: _validateMoney,
                      onChanged: (value) => viewModel.setAmounts(charged: value.moneyToDouble()),
                    ),
                    const Spacing.y(),
                    TextFormField(
                      controller: dateController,
                      decoration: const InputDecoration(
                        labelText: 'Data em que pretende pegar o crédito',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      readOnly: true,
                      enabled: !viewModel.isLoading,
                      onTap: selectDate,
                    ),
                    const Spacing.y(1.5),
                    _SelectorTile(
                      icon: Icons.account_balance_outlined,
                      label: 'Conta que receberá',
                      value: viewModel.selectedAccount?.description ?? 'Selecionar conta',
                      onTap: viewModel.isLoading ? null : selectAccount,
                    ),
                    const SizedBox(height: 8),
                    _SelectorTile(
                      icon: Icons.credit_card_outlined,
                      label: 'Cartão usado',
                      value: viewModel.selectedCreditCard?.description ?? 'Selecionar cartão',
                      onTap: viewModel.isLoading ? null : selectCard,
                    ),
                    const Spacing.y(1.5),
                    _PreviewCard(viewModel: viewModel),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: !initialized
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: viewModel.isLoading ? null : savePlan,
                        icon: const Icon(Icons.schedule_outlined),
                        label: const Text('Salvar planejamento'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: viewModel.isLoading ? null : realize,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Realizar agora'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String? _validateMoney(String? value) {
    if ((value ?? '').moneyToDouble() <= 0) return 'Informe um valor maior que zero.';
    return null;
  }

  Future<void> selectDate() async {
    final result = await showDatePickerDefault(context: context, initialDate: viewModel.plan.plannedDate);
    if (result == null) return;
    viewModel.setPlannedDate(result);
    dateController.text = result.format();
  }

  Future<void> selectAccount() async {
    final AccountEntity? result = await showModalBottomSheet<AccountEntity>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: viewModel.accounts
              .where((item) => item.deletedAt == null)
              .map((account) => ListTile(
                    leading: account.financialInstitution?.icon(),
                    title: Text(account.description),
                    trailing: account.id == viewModel.plan.idAccount ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(sheetContext, account),
                  ))
              .toList(),
        ),
      ),
    );
    if (result != null) viewModel.setAccount(result.id);
  }

  Future<void> selectCard() async {
    final CreditCardEntity? result = await showModalBottomSheet<CreditCardEntity>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: viewModel.creditCards
              .where((item) => item.deletedAt == null)
              .map((card) => ListTile(
                    leading: const Icon(Icons.credit_card_outlined),
                    title: Text(card.description),
                    subtitle: Text('Disponível real: ${(card.amountLimit - card.amountLimitUtilized).money}'),
                    trailing: card.id == viewModel.plan.idCreditCard ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(sheetContext, card),
                  ))
              .toList(),
        ),
      ),
    );
    if (result != null) viewModel.setCreditCard(result.id);
  }

  bool _prepare() {
    if (!(formKey.currentState?.validate() ?? false)) return false;
    viewModel.plan.description = descriptionController.text.trim();
    viewModel.plan.amountReceived = receivedController.text.moneyToDouble();
    viewModel.plan.amountCharged = chargedController.text.moneyToDouble();
    if (viewModel.plan.idAccount.isEmpty || viewModel.plan.idCreditCard.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione a conta e o cartão.')));
      return false;
    }
    return true;
  }

  Future<void> savePlan() async {
    if (!_prepare()) return;
    await viewModel.save.execute(viewModel.plan);
    try {
      viewModel.save.throwIfError();
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ErrorDialog.show(context, e.toString());
    }
  }

  Future<void> realize() async {
    if (!_prepare()) return;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Realizar operação?'),
        content: Text(
          'Entrarão ${viewModel.plan.amountReceived.money} na conta e ${viewModel.plan.amountCharged.money} serão lançados no cartão. A entrada não será contabilizada como receita.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirm != true) return;

    await viewModel.realize.execute(viewModel.plan);
    try {
      viewModel.realize.throwIfError();
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ErrorDialog.show(context, e.toString());
    }
  }

  Future<void> cancelPlan() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar planejamento?'),
        content: const Text('Ele deixará de aparecer em A pagar, A receber e nas projeções do Radar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Cancelar planejamento')),
        ],
      ),
    );
    if (confirm != true) return;
    await viewModel.cancel.execute(viewModel.plan);
    try {
      viewModel.cancel.throwIfError();
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ErrorDialog.show(context, e.toString());
    }
  }
}

class _SelectorTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _SelectorTile({required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(icon),
          title: Text(label),
          subtitle: Text(value),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}

class _PreviewCard extends StatelessWidget {
  final CardCashAdvanceFormViewModel viewModel;

  const _PreviewCard({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plan = viewModel.plan;
    final card = viewModel.selectedCreditCard;
    return Card(
      color: scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Prévia do planejamento',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const CalculationInfoButton(
                  title: 'Crédito via cartão',
                  description:
                      'A operação separa entrada de caixa, dívida e custo financeiro para não transformar dinheiro emprestado em renda.',
                  items: [
                    'Valor recebido: entra na conta quando a operação é realizada, mas não é classificado como receita.',
                    'Valor cobrado: é o total que será comprometido no cartão/fatura.',
                    'Custo financeiro: somente a diferença entre o total cobrado e o valor recebido.',
                    'Enquanto estiver planejado, saldo e limite reais não mudam; o Radar e os relatórios usam o cenário planejado.',
                    'Ao realizar, o planejamento vira entrada real na conta e transação real no cartão sem duplicar a despesa nos relatórios.',
                  ],
                  formula:
                      'Custo financeiro = Valor cobrado − Valor recebido',
                  note:
                      'O limite projetado considera também outros planejamentos salvos no mesmo cartão.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _line('Entrada planejada', plan.amountReceived.money),
            _line('Cobrança prevista no cartão', plan.amountCharged.money),
            _line('Custo financeiro', plan.financialCost.money),
            if (plan.amountReceived > 0)
              _line(
                'Custo da operação',
                '${((plan.financialCost / plan.amountReceived) * 100).toStringAsFixed(2)}%',
              ),
            _line('Vencimento estimado', plan.billDueDate.format()),
            if (card != null) ...[
              const Divider(height: 24),
              _line('Limite total', card.amountLimit.money),
              _line('Utilizado real', card.amountLimitUtilized.money),
              _line('Disponível real hoje', (card.amountLimit - card.amountLimitUtilized).money),
              if (viewModel.otherPlansAmountForSelectedCard > 0)
                _line('Outros planejamentos', viewModel.otherPlansAmountForSelectedCard.money),
              _line('Utilizado após os planos', viewModel.projectedCardUtilized.money),
              _line('Disponível após este plano', viewModel.plannedCardAvailable.money),
              if (card.safetyLimit != null) ...[
                const SizedBox(height: 8),
                _line('Limite de segurança', card.safetyLimit!.money),
                _SafetyMessage(
                  projectedUtilized: viewModel.projectedCardUtilized,
                  safetyLimit: card.safetyLimit!,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}


class _SafetyMessage extends StatelessWidget {
  final double projectedUtilized;
  final double safetyLimit;

  const _SafetyMessage({
    required this.projectedUtilized,
    required this.safetyLimit,
  });

  @override
  Widget build(BuildContext context) {
    if (safetyLimit <= 0) return const SizedBox.shrink();

    final double ratio = projectedUtilized / safetyLimit;
    if (ratio < .70) return const SizedBox.shrink();

    final bool exceeded = projectedUtilized > safetyLimit;
    final bool critical = ratio >= .90;
    final Color color = exceeded || critical
        ? const Color(0xFFE34B42)
        : const Color(0xFFE58A00);

    final String message = exceeded
        ? 'Este planejamento ultrapassa seu limite de segurança em ${(projectedUtilized - safetyLimit).money}.'
        : critical
            ? 'Atenção: você usará ${(ratio * 100).round()}% do limite de segurança.'
            : 'Você chegará a ${(ratio * 100).round()}% do limite de segurança.';

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
