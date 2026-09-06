import 'package:rallet/di/dependency_injection.dart';
import 'package:rallet/features/first_steps/presentation/guided_tour.dart';
import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';
import 'package:rallet/features/purchase_planning/domain/entities/purchase_simulation_entity.dart';
import 'package:rallet/features/purchase_planning/presentation/view_models/purchase_planning_view_model.dart';
import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/presentation/ui/expense_form_page.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/extensions/string_extension.dart';
import 'package:rallet/shared/presentation/ui/components/calculation_info_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PurchasePlanningPage extends StatefulWidget {
  static const String route = 'purchase-planning';
  final PlannedPurchaseEntity? plan;

  const PurchasePlanningPage({super.key, this.plan});

  @override
  State<PurchasePlanningPage> createState() => _PurchasePlanningPageState();
}

class _PurchasePlanningPageState extends State<PurchasePlanningPage> {
  final PurchasePlanningViewModel viewModel = DI.get<PurchasePlanningViewModel>();
  final _formKey = GlobalKey<FormState>();
  final descriptionController = TextEditingController();
  final amountController = TextEditingController();
  final reserveController = TextEditingController();
  final totalChargedController = TextEditingController();
  final observationController = TextEditingController();

  DateTime plannedDate = DateTime.now();
  PlannedPurchasePaymentType paymentType = PlannedPurchasePaymentType.cash;
  String? selectedCardId;
  String? selectedCategoryId;
  String? selectedAccountId;
  int installmentCount = 2;
  bool showPossibilities = false;

  bool get isCreditCard => paymentType != PlannedPurchasePaymentType.cash;
  bool get isInstallment => paymentType == PlannedPurchasePaymentType.creditCardInstallments;
  double get amount => amountController.text.moneyToDouble();
  double get reserve => reserveController.text.moneyToDouble();
  double get totalCharged => isCreditCard
      ? totalChargedController.text.moneyToDouble()
      : amount;

  @override
  void initState() {
    super.initState();
    viewModel.load(widget.plan);
    final plan = widget.plan;
    if (plan != null) {
      descriptionController.text = plan.description;
      amountController.text = plan.amount.moneyWithoutSymbol;
      reserveController.text = plan.reserveAmount.moneyWithoutSymbol;
      totalChargedController.text = plan.totalCharged.moneyWithoutSymbol;
      plannedDate = plan.plannedDate;
      paymentType = plan.paymentType;
      selectedCardId = plan.idCreditCard;
      selectedCategoryId = plan.idCategory;
      selectedAccountId = plan.idAccount;
      observationController.text = plan.observation ?? '';
      installmentCount = plan.installmentCount.clamp(2, 24).toInt();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _simulate();
      });
    } else {
      reserveController.text = '0,00';
    }
  }

  @override
  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
    reserveController.dispose();
    totalChargedController.dispose();
    observationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan == null ? 'Planejar despesa' : 'Alterar despesa planejada'),
        actions: [
          const CalculationInfoButton(
            title: 'Como escolhemos o melhor momento?',
            description:
                'O Rallet testa a despesa em várias datas e acompanha o que acontece depois dela, em vez de olhar apenas o saldo do dia.',
            items: [
              'À vista: o valor inteiro sai do caixa na data da despesa.',
              'Cartão: o Rallet verifica o limite no dia e projeta a cobrança nas faturas.',
              'Parcelado: cada parcela entra no vencimento correspondente, mas o valor total compromete o limite quando a despesa acontece.',
              'Receitas, despesas, faturas, créditos e outras despesas planejadas entram na simulação.',
              'A recomendação orienta, mas não bloqueia: você pode escolher outra data.',
            ],
            formula: 'Data segura = fluxo futuro acima da margem + limite do cartão respeitado',
            note:
                'Quando há parcelas, a análise se estende além do período normal do Radar para enxergar o fim do parcelamento.',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (_, __) => Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              children: [
                GuidedTourTarget(
                  id: GuidedTourTargets.planningForm,
                  child: TextFormField(
                    controller: descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Qual despesa você quer planejar?',
                      hintText: 'Ex.: mercado, manutenção, TV, notebook...',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Informe a despesa.'
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: viewModel.categories.any((category) => category.id == selectedCategoryId)
                      ? selectedCategoryId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: viewModel.categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.description),
                        ),
                      )
                      .toList(),
                  validator: (_) => selectedCategoryId == null
                      ? 'Selecione a categoria da despesa.'
                      : null,
                  onChanged: (value) => setState(() => selectedCategoryId = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
                  decoration: const InputDecoration(
                    labelText: 'Valor previsto',
                    prefixText: 'R\$ ',
                  ),
                  validator: (_) => amount <= 0 ? 'Informe um valor maior que zero.' : null,
                  onChanged: (_) {
                    if (isCreditCard && totalChargedController.text.trim().isEmpty) {
                      totalChargedController.text = amountController.text;
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PlannedPurchasePaymentType>(
                  value: paymentType,
                  decoration: const InputDecoration(
                    labelText: 'Como pretende pagar?',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: PlannedPurchasePaymentType.cash,
                      child: Text('À vista / saldo da conta'),
                    ),
                    DropdownMenuItem(
                      value: PlannedPurchasePaymentType.creditCardSingle,
                      child: Text('Cartão à vista'),
                    ),
                    DropdownMenuItem(
                      value: PlannedPurchasePaymentType.creditCardInstallments,
                      child: Text('Cartão parcelado'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      paymentType = value;
                      if (isCreditCard) {
                        totalChargedController.text = amount.moneyWithoutSymbol;
                        selectedCardId ??= viewModel.creditCards.isEmpty ? null : viewModel.creditCards.first.id;
                      }
                    });
                  },
                ),
                if (!isCreditCard) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: viewModel.accounts.any((account) => account.id == selectedAccountId)
                        ? selectedAccountId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Conta que pagará',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                    items: viewModel.accounts
                        .map(
                          (account) => DropdownMenuItem(
                            value: account.id,
                            child: Text(account.description),
                          ),
                        )
                        .toList(),
                    validator: (_) => selectedAccountId == null
                        ? 'Selecione a conta da despesa.'
                        : null,
                    onChanged: (value) => setState(() => selectedAccountId = value),
                  ),
                ],
                if (isCreditCard) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: viewModel.creditCards.any((card) => card.id == selectedCardId)
                        ? selectedCardId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Cartão',
                      prefixIcon: Icon(Icons.credit_card_outlined),
                    ),
                    items: viewModel.creditCards
                        .map(
                          (card) => DropdownMenuItem(
                            value: card.id,
                            child: Text(card.description),
                          ),
                        )
                        .toList(),
                    validator: (_) => selectedCardId == null ? 'Selecione o cartão.' : null,
                    onChanged: (value) => setState(() => selectedCardId = value),
                  ),
                  const SizedBox(height: 12),
                  if (isInstallment) ...[
                    DropdownButtonFormField<int>(
                      value: installmentCount,
                      decoration: const InputDecoration(
                        labelText: 'Parcelas',
                        prefixIcon: Icon(Icons.calendar_view_month_outlined),
                      ),
                      items: List.generate(
                        23,
                        (index) => index + 2,
                      )
                          .map(
                            (count) => DropdownMenuItem(
                              value: count,
                              child: Text('${count}x'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => installmentCount = value ?? 2),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: totalChargedController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
                    decoration: InputDecoration(
                      labelText: isInstallment ? 'Total parcelado' : 'Total cobrado no cartão',
                      prefixText: 'R\$ ',
                      helperText: isInstallment && totalCharged > 0
                          ? '${installmentCount}x de aproximadamente ${(totalCharged / installmentCount).money}'
                          : 'Se não houver juros, informe o mesmo valor da despesa.',
                    ),
                    validator: (_) => totalCharged <= 0 ? 'Informe o total cobrado.' : null,
                  ),
                  if (totalCharged > amount) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Custo do parcelamento: ${(totalCharged - amount).money}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Data prevista'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(plannedDate)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _selectDate,
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: reserveController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
                  decoration: const InputDecoration(
                    labelText: 'Margem mínima depois da despesa (opcional)',
                    prefixText: 'R\$ ',
                    helperText: 'Ex.: R\$ 300 para o Rallet não considerar seguro ficar abaixo disso.',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: observationController,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Observação (opcional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: viewModel.loading ? null : _simulate,
                  icon: const Icon(Icons.auto_graph_outlined),
                  label: const Text('Analisar melhor momento'),
                ),
                if (viewModel.loading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                if (viewModel.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    viewModel.error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (viewModel.simulation != null) ...[
                  const SizedBox(height: 18),
                  _SimulationCard(
                    simulation: viewModel.simulation!,
                    onUseRecommendation: (date) => setState(() => plannedDate = date),
                    showPossibilities: showPossibilities,
                    onTogglePossibilities: () =>
                        setState(() => showPossibilities = !showPossibilities),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: viewModel.loading ? null : _save,
                  child: Text(widget.plan == null ? 'Salvar planejamento' : 'Salvar alterações'),
                ),
                if (widget.plan != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: viewModel.loading ? null : _registerPurchase,
                    icon: Icon(viewModel.plan?.isCreditCard == true
                        ? Icons.credit_score_outlined
                        : Icons.shopping_cart_checkout_outlined),
                    label: Text(viewModel.plan?.isCreditCard == true
                        ? 'Registrar despesa no cartão'
                        : 'Registrar despesa realizada'),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: viewModel.loading ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Cancelar planejamento'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: plannedDate.isBefore(today) ? today : plannedDate,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 2),
    );
    if (date != null) setState(() => plannedDate = date);
  }

  Future<void> _simulate() async {
    if (!_formKey.currentState!.validate()) return;
    await viewModel.simulate(
      amount: amount,
      desiredDate: plannedDate,
      reserveAmount: reserve,
      paymentType: paymentType,
      idCreditCard: selectedCardId,
      idAccount: isCreditCard ? null : selectedAccountId,
      installmentCount: isInstallment ? installmentCount : 1,
      totalCharged: totalCharged,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Sempre recalcula imediatamente antes de salvar. Assim o aviso usa as
    // mesmas informações atuais de saldo, faturas, planejamentos e limite que
    // alimentam o Radar, mesmo que o usuário tenha alterado algum campo depois
    // de tocar em "Analisar melhor momento".
    await _simulate();
    if (!mounted || viewModel.error != null) return;

    final PurchaseSimulationEntity? simulation = viewModel.simulation;
    if (simulation == null) return;
    if (!simulation.desiredOption.safe) {
      final bool continueAnyway = await _confirmUnsafePlan(simulation);
      if (!mounted || !continueAnyway) return;
    }

    final ok = await viewModel.save(
      description: descriptionController.text,
      amount: amount,
      plannedDate: plannedDate,
      reserveAmount: reserve,
      paymentType: paymentType,
      idCreditCard: selectedCardId,
      idCategory: selectedCategoryId,
      idAccount: isCreditCard ? null : selectedAccountId,
      observation: observationController.text,
      installmentCount: isInstallment ? installmentCount : 1,
      totalCharged: totalCharged,
    );
    if (!mounted || !ok) return;
    context.pop(true);
  }

  Future<bool> _confirmUnsafePlan(PurchaseSimulationEntity simulation) async {
    final option = simulation.desiredOption;
    final List<String> warnings = [];

    if (option.firstNegativeBalanceDate != null) {
      final date = DateFormat('dd/MM/yyyy').format(option.firstNegativeBalanceDate!);
      warnings.add(
        'Saldo insuficiente para pagamentos nesse dia ($date). '
        'Saldo projetado: ${(option.balanceAtFirstNegativeDate ?? option.minimumBalanceAfterPurchase).money}.',
      );
    } else if (option.minimumBalanceAfterPurchase + 0.0001 < simulation.reserveAmount) {
      final date = DateFormat('dd/MM/yyyy').format(option.minimumBalanceDate);
      warnings.add(
        'O saldo não fica negativo, mas cai abaixo da margem mínima em $date. '
        'Menor saldo: ${option.minimumBalanceAfterPurchase.money}.',
      );
    }

    if (option.firstCardLimitRiskDate != null) {
      final date = DateFormat('dd/MM/yyyy').format(option.firstCardLimitRiskDate!);
      warnings.add(
        'Limite insuficiente no cartão ${simulation.creditCardDescription ?? ''} '
        'para esse compromisso nesse dia ($date). '
        'Faltariam ${(option.cardLimitShortage ?? 0).money}.',
      );
    } else if (option.firstCardSafetyRiskDate != null) {
      final date = DateFormat('dd/MM/yyyy').format(option.firstCardSafetyRiskDate!);
      warnings.add(
        'O limite de segurança do cartão ${simulation.creditCardDescription ?? ''} '
        'será ultrapassado em $date por ${(option.cardSafetyAmountOver ?? 0).money}.',
      );
    }

    final bool radarMainAlert = simulation.desiredGeneratesRadarAlert;
    final bool radarSafetyAlert =
        !radarMainAlert && simulation.desiredGeneratesRadarSafetyWarning;
    final DateTime? firstRiskDate = option.firstNegativeBalanceDate ??
        option.firstCardLimitRiskDate ??
        option.firstCardSafetyRiskDate;
    final bool riskOutsideCurrentRadar =
        firstRiskDate != null && firstRiskDate.isAfter(simulation.radarHorizonEnd);

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Este planejamento exige atenção'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isInstallment
                        ? 'O Rallet analisou as parcelas e o impacto nas datas futuras antes de salvar.'
                        : 'O Rallet analisou o impacto desta despesa nas datas futuras antes de salvar.',
                  ),
                  const SizedBox(height: 12),
                  ...warnings.map(
                    (warning) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 19,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(warning)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    radarMainAlert
                        ? 'Se você salvar assim, o cenário do Radar terá um alerta nesse período. O Rallet não vai mover nem remover o planejamento: apenas avisará o risco.'
                        : radarSafetyAlert
                            ? 'Se você salvar assim, o Radar deverá mostrar um aviso referente ao limite de segurança do cartão.'
                            : riskOutsideCurrentRadar
                                ? 'O risco acontece depois do horizonte atual do Radar. A simulação enxergou mais longe para analisar o parcelamento; ele aparecerá no Radar quando esse período estiver dentro do horizonte configurado.'
                                : 'Este cenário não deve gerar o alerta principal do Radar, mas fica abaixo da margem mínima que você definiu.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (!isInstallment && option.firstNegativeBalanceDate != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Se quiser, volte e teste outra data ou uma opção parcelada em “Analisar melhor momento”.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(false),
                child: const Text('Voltar e ajustar'),
              ),
              FilledButton(
                onPressed: () => context.pop(true),
                child: const Text('Planejar mesmo assim'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _registerPurchase() async {
    final plan = viewModel.plan;
    if (plan == null) return;

    if (plan.isCreditCard) {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirmar despesa no cartão?'),
              content: Text(
                plan.isInstallment
                    ? '${plan.description}\n${plan.installmentCount} parcelas • total ${plan.totalCharged.money}\n\nO planejamento será convertido em uma despesa real no cartão e sairá das projeções como planejamento.'
                    : '${plan.description}\nTotal ${plan.totalCharged.money}\n\nO planejamento será convertido em uma despesa real no cartão.',
              ),
              actions: [
                TextButton(onPressed: () => context.pop(false), child: const Text('Voltar')),
                FilledButton(onPressed: () => context.pop(true), child: const Text('Confirmar')),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
      final ok = await viewModel.realizeCreditCardPurchase();
      if (!mounted || !ok) return;
      context.pop(true);
      return;
    }

    final result = await context.pushNamed(
      ExpenseFormPage.route,
      extra: ExpenseEntity(
        id: null,
        createdAt: null,
        deletedAt: null,
        description: plan.description,
        amount: plan.amount,
        date: DateTime.now(),
        paid: false,
        observation: [
          if (plan.observation != null && plan.observation!.trim().isNotEmpty)
            plan.observation!.trim(),
          'Originada de uma despesa planejada no Rallet',
        ].join(' • '),
        idAccount: plan.idAccount,
        idCategory: plan.idCategory,
        idCreditCard: null,
        idCreditCardTransaction: null,
      ),
    );
    if (result == null || !mounted) return;
    final removed = await viewModel.delete();
    if (!mounted || !removed) return;
    context.pop(true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancelar planejamento?'),
            content: const Text(
              'A despesa deixa de participar das projeções do Radar e dos relatórios.',
            ),
            actions: [
              TextButton(onPressed: () => context.pop(false), child: const Text('Voltar')),
              FilledButton(onPressed: () => context.pop(true), child: const Text('Cancelar planejamento')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final ok = await viewModel.delete();
    if (!mounted || !ok) return;
    context.pop(true);
  }
}

class _SimulationCard extends StatelessWidget {
  final PurchaseSimulationEntity simulation;
  final ValueChanged<DateTime> onUseRecommendation;
  final bool showPossibilities;
  final VoidCallback onTogglePossibilities;

  const _SimulationCard({
    required this.simulation,
    required this.onUseRecommendation,
    required this.showPossibilities,
    required this.onTogglePossibilities,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recommendation = simulation.recommendedOption;
    final String horizon = DateFormat('dd/MM/yyyy').format(simulation.horizonEnd);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Análise da despesa', style: Theme.of(context).textTheme.titleLarge)),
                CalculationInfoButton(
                  title: 'Leitura da análise',
                  description: simulation.isCreditCard
                      ? 'No cartão, o Rallet analisa duas coisas ao mesmo tempo: o limite necessário para assumir a despesa e o impacto das futuras faturas no seu caixa.'
                      : 'À vista, o Rallet verifica o saldo do dia e todos os compromissos que vêm depois.',
                  items: simulation.isCreditCard
                      ? [
                          'O total da despesa compromete o limite quando ela acontece.',
                          'As parcelas saem do caixa nos vencimentos previstos.',
                          'O limite vai sendo liberado conforme as faturas projetadas são pagas.',
                          'Se existir limite de segurança pessoal, ele também participa da recomendação.',
                        ]
                      : [
                          'Saldo após a despesa mostra a projeção no dia escolhido.',
                          'Menor saldo posterior procura o ponto mais apertado do período.',
                          'Uma data só é segura quando esse menor saldo respeita sua margem mínima.',
                        ],
                ),
              ],
            ),
            if (simulation.isCreditCard) ...[
              const SizedBox(height: 8),
              Text(
                '${simulation.creditCardDescription ?? 'Cartão'} • ${simulation.isInstallment ? '${simulation.installmentCount}x' : '1x'} • total ${simulation.totalCharged.money}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              if (simulation.financialCost > 0)
                Text(
                  'Custo adicional: ${simulation.financialCost.money}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
            ],
            const SizedBox(height: 12),
            if (recommendation != null) ...[
              _ResultBanner(
                icon: Icons.check_circle_outline,
                title: simulation.canBuyToday
                    ? 'A despesa cabe hoje pelos lançamentos atuais.'
                    : 'Melhor momento sugerido: ${DateFormat('dd/MM/yyyy').format(recommendation.date)}',
                subtitle: simulation.isCreditCard
                    ? 'Menor saldo até o fim da análise: ${recommendation.minimumBalanceAfterPurchase.money}. Limite projetado após a despesa: ${(recommendation.cardAvailableAfterPurchase ?? 0).money}.'
                    : 'Menor saldo após a despesa: ${recommendation.minimumBalanceAfterPurchase.money} em ${DateFormat('dd/MM').format(recommendation.minimumBalanceDate)}.',
                positive: true,
              ),
              if (!simulation.canBuyToday && recommendation.date != simulation.desiredDate) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => onUseRecommendation(recommendation.date),
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('Usar data recomendada'),
                ),
              ],
            ] else ...[
              _ResultBanner(
                icon: Icons.warning_amber_rounded,
                title: 'Não encontramos uma data segura até o fim do período analisado.',
                subtitle: simulation.isCreditCard && !simulation.desiredOption.cardLimitSafe
                    ? 'O limite do cartão ou o limite de segurança não comporta essa despesa na situação projetada.'
                    : simulation.highestSafeAmount > 0
                        ? 'Maior valor que caberia mantendo sua margem: ${simulation.highestSafeAmount.money}.'
                        : 'Com os lançamentos atuais, a margem definida fica comprometida. Análise até $horizon.',
                positive: false,
              ),
            ],
            const SizedBox(height: 10),
            _OptionRow(label: 'Na data escolhida', option: simulation.desiredOption, creditCard: simulation.isCreditCard),
            _OptionRow(label: 'Se realizar hoje', option: simulation.todayOption, creditCard: simulation.isCreditCard),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: onTogglePossibilities,
              icon: Icon(showPossibilities ? Icons.expand_less : Icons.auto_awesome_outlined),
              label: Text(showPossibilities ? 'Ocultar possibilidades' : 'Ver possibilidades'),
            ),
            if (showPossibilities) ...[
              Divider(color: scheme.outlineVariant),
              const SizedBox(height: 4),
              ...simulation.alternatives.map(
                (option) => _PossibilityTile(option: option, creditCard: simulation.isCreditCard),
              ),
              if (!simulation.isCreditCard && !simulation.hasSafeDate && simulation.highestSafeAmount > 0)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.price_check_outlined),
                  title: Text('Reduzir a despesa para até ${simulation.highestSafeAmount.money}'),
                  subtitle: Text(
                    simulation.highestSafeAmountDate == null
                        ? 'Valor máximo encontrado mantendo sua margem.'
                        : 'Maior margem encontrada em ${DateFormat('dd/MM/yyyy').format(simulation.highestSafeAmountDate!)}.',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool positive;

  const _ResultBanner({required this.icon, required this.title, required this.subtitle, required this.positive});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = positive ? const Color(0xFF1AA56B) : scheme.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String label;
  final PurchaseSimulationOptionEntity option;
  final bool creditCard;

  const _OptionRow({required this.label, required this.option, required this.creditCard});

  @override
  Widget build(BuildContext context) {
    final color = option.safe ? const Color(0xFF1AA56B) : Theme.of(context).colorScheme.error;
    final String value = creditCard
        ? '${option.minimumBalanceAfterPurchase.money} • limite ${(option.cardAvailableAfterPurchase ?? 0).money}'
        : option.minimumBalanceAfterPurchase.money;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(option.safe ? Icons.check_circle_outline : Icons.warning_amber_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w700, color: color))),
        ],
      ),
    );
  }
}

class _PossibilityTile extends StatelessWidget {
  final PurchaseSimulationOptionEntity option;
  final bool creditCard;

  const _PossibilityTile({required this.option, required this.creditCard});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(option.safe ? Icons.check_circle_outline : Icons.warning_amber_rounded),
      title: Text(DateFormat('dd/MM/yyyy').format(option.date)),
      subtitle: Text(
        creditCard
            ? 'Menor saldo: ${option.minimumBalanceAfterPurchase.money} • limite após despesa: ${(option.cardAvailableAfterPurchase ?? 0).money}${option.firstBillDueDate == null ? '' : ' • 1ª fatura ${DateFormat('dd/MM').format(option.firstBillDueDate!)}'}'
            : 'Após a despesa: ${option.balanceAfterPurchase.money} • menor saldo: ${option.minimumBalanceAfterPurchase.money}',
      ),
    );
  }
}
