import 'dart:math' as math;

import 'package:rallet/di/dependency_injection.dart';
import 'package:rallet/features/first_steps/presentation/guided_tour.dart';
import 'package:rallet/features/reports/domain/entities/reports_dashboard_entity.dart';
import 'package:rallet/features/reports/presentation/ui/financial_result_explanation_page.dart';
import 'package:rallet/features/reports/presentation/ui/report_categories_page.dart';
import 'package:rallet/features/reports/presentation/ui/planned_vs_realized_report_page.dart';
import 'package:rallet/features/reports/presentation/view_models/reports_dashboard_view_model.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/presentation/mixins/theme_context.dart';
import 'package:rallet/shared/presentation/notifiers/event_notifier.dart';
import 'package:rallet/shared/presentation/ui/components/calculation_info_button.dart';
import 'package:rallet/shared/presentation/ui/components/navigation/nav_drawer.dart';
import 'package:rallet/shared/presentation/ui/components/card_visibility_settings_sheet.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportsPage extends StatefulWidget {
  static const String route = 'reports';

  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> with ThemeContext {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController scrollController = ScrollController();
  final ReportsDashboardViewModel viewModel = DI.get<ReportsDashboardViewModel>();
  final EventNotifier eventNotifier = DI.get<EventNotifier>();

  static const String _hiddenCardsKey = 'ui.reports.hidden_cards.v1';
  static const String _cardOrderKey = 'ui.reports.card_order.v1';
  static const Map<String, String> _customizableCards = {
    'summary': 'Resumo do mês',
    'greenPath': 'Caminho para o verde',
    'categories': 'Categorias',
    'financialCosts': 'Custos financeiros',
    'plannedExpenses': 'Despesas planejadas',
    'plannedVsRealized': 'Planejado × realizado',
    'fixedVariable': 'Fixas × variáveis',
    'evolution': 'Evolução das despesas',
    'comparison': 'Comparação mensal',
    'futureCommitments': 'Compromissos futuros',
  };

  Set<String> hiddenCards = <String>{};
  List<String> cardOrder = _customizableCards.keys.toList();

  @override
  void initState() {
    super.initState();
    final SharedPreferences preferences = DI.get<SharedPreferences>();
    hiddenCards = preferences.getStringList(_hiddenCardsKey)?.toSet() ?? <String>{};
    cardOrder = _normalizedOrder(preferences.getStringList(_cardOrderKey));
    viewModel.initialize();
    eventNotifier.addListener(_onFinancialEvent);
  }

  void _onFinancialEvent() {
    if (eventNotifier.value == EventType.reportsHome) {
      _resetToCurrentMonthAndTop();
      return;
    }

    if (![
      EventType.income,
      EventType.expense,
      EventType.creditCard,
      EventType.cashAdvance,
      EventType.purchasePlan,
      EventType.transfer,
    ].contains(eventNotifier.value)) {
      return;
    }

    if (!viewModel.loadDashboard.running) {
      viewModel.loadDashboard.execute();
    }
  }

  Future<void> _resetToCurrentMonthAndTop() async {
    _scrollToTop();
    await viewModel.goCurrentMonth();
  }

  void _scrollToTop() {
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) scrollController.jumpTo(0);
      });
    }
  }

  Future<void> _onRefresh() => _resetToCurrentMonthAndTop();

  @override
  void dispose() {
    eventNotifier.removeListener(_onFinancialEvent);
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          tooltip: strings.menu,
          icon: const Icon(Icons.menu),
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(strings.reports),
        centerTitle: true,
        actions: [
          GuidedTourTarget(
            id: GuidedTourTargets.reportsCustomize,
            child: IconButton(
              tooltip: 'Personalizar Relatórios',
              icon: const Icon(Icons.tune_rounded),
              onPressed: _openCustomization,
            ),
          ),
        ],
      ),
      drawer: const NavDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListenableBuilder(
            listenable: Listenable.merge([viewModel, viewModel.loadDashboard]),
            builder: (_, __) {
              final previous = viewModel.loadDashboard.previous;

              if (viewModel.loadDashboard.running && previous?.completed != true) {
                return const Center(child: CircularProgressIndicator());
              }

              if (viewModel.loadDashboard.hasError && previous?.completed != true) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      viewModel.loadDashboard.error.toString().replaceAll('Exception: ', ''),
                      style: textTheme.bodyLarge?.copyWith(color: colorScheme.error),
                    ),
                  ],
                );
              }

              final ReportsDashboardEntity? data =
                  viewModel.loadDashboard.result ?? previous?.result;

              if (data == null) {
                return const SizedBox.shrink();
              }

              return ListView(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  GuidedTourTarget(
                    id: GuidedTourTargets.reportsMonth,
                    child: _MonthSelector(viewModel: viewModel),
                  ),
                  ..._buildCustomizableSections(data),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  bool _isCardVisible(String id) => !hiddenCards.contains(id);

  List<String> _normalizedOrder(List<String>? stored) {
    final Set<String> valid = _customizableCards.keys.toSet();
    final List<String> normalized = <String>[];

    for (final String id in stored ?? const <String>[]) {
      if (valid.contains(id) && !normalized.contains(id)) normalized.add(id);
    }
    for (final String id in _customizableCards.keys) {
      if (!normalized.contains(id)) normalized.add(id);
    }

    return normalized;
  }

  List<Widget> _buildCustomizableSections(ReportsDashboardEntity data) {
    final List<Widget> sections = <Widget>[];

    for (final String id in cardOrder) {
      if (!_isCardVisible(id)) continue;

      Widget? card;
      switch (id) {
        case 'summary':
          card = _SummaryCard(data: data);
          break;
        case 'greenPath':
          final DateTime now = DateTime.now();
          final bool currentMonth = data.month.year == now.year && data.month.month == now.month;
          if (currentMonth) card = _GreenPathCard(data: data.greenPath, viewModel: viewModel);
          break;
        case 'categories':
          card = _CategoriesCard(data: data, onOpen: categories);
          break;
        case 'financialCosts':
          if (data.financialCostItems.isNotEmpty) {
            card = _FinancialCostsCard(data: data);
          }
          break;
        case 'plannedExpenses':
          if (data.plannedExpenseItems.isNotEmpty) {
            card = _PlannedExpensesCard(data: data);
          }
          break;
        case 'plannedVsRealized':
          card = GuidedTourTarget(
            id: GuidedTourTargets.reportsPlannedVsRealized,
            child: _PlannedVsRealizedCard(
              data: data,
              onOpen: () => _openPlannedVsRealized(data),
            ),
          );
          break;
        case 'fixedVariable':
          card = _FixedVariableCard(data: data);
          break;
        case 'evolution':
          card = _EvolutionCard(data: data);
          break;
        case 'comparison':
          card = _ComparisonCard(data: data);
          break;
        case 'futureCommitments':
          card = _FutureCommitmentsCard(data: data);
          break;
      }

      if (card != null) {
        sections.add(
          KeyedSubtree(
            key: ValueKey('report-card-$id-slot'),
            child: Column(
              children: [
                KeyedSubtree(key: ValueKey('report-card-$id'), child: card),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      }
    }

    return sections;
  }

  Future<void> _openCustomization() async {
    final CardCustomizationResult? result = await showCardVisibilitySettingsSheet(
      context: context,
      title: 'Personalizar Relatórios',
      description:
          'Escolha quais seções aparecem e em que ordem. As mudanças só são salvas ao tocar em Aplicar e não interferem em nenhum cálculo.',
      options: _customizableCards,
      hiddenCards: hiddenCards,
      cardOrder: cardOrder,
    );

    if (result == null || !mounted) return;

    setState(() {
      hiddenCards = result.hiddenCards;
      cardOrder = _normalizedOrder(result.cardOrder);
    });

    final SharedPreferences preferences = DI.get<SharedPreferences>();
    await preferences.setStringList(_hiddenCardsKey, hiddenCards.toList()..sort());
    await preferences.setStringList(_cardOrderKey, cardOrder);
  }

  Future<void> categories() => context.pushNamed(
        ReportCategoriesPage.route,
        extra: DateTimeRange(
          start: DateTime(viewModel.selectedMonth.year, viewModel.selectedMonth.month, 1),
          end: DateTime(viewModel.selectedMonth.year, viewModel.selectedMonth.month + 1, 0, 23, 59, 59),
        ),
      );

  Future<void> _openPlannedVsRealized(ReportsDashboardEntity data) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlannedVsRealizedReportPage(data: data),
        ),
      );
}

class _MonthSelector extends StatelessWidget {
  final ReportsDashboardViewModel viewModel;

  const _MonthSelector({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final String label = DateFormat('MMMM yyyy', 'pt_BR')
        .format(viewModel.selectedMonth);
    final String formatted = label[0].toUpperCase() + label.substring(1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: viewModel.previousMonth,
          icon: const Icon(Icons.chevron_left),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: viewModel.goCurrentMonth,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              formatted,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
        IconButton(
          onPressed: viewModel.nextMonth,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatefulWidget {
  final ReportsDashboardEntity data;

  const _SummaryCard({required this.data});

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  bool expanded = false;

  ReportsDashboardEntity get data => widget.data;

  @override
  void didUpdateWidget(covariant _SummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) {
      expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double savings = data.savings;
    final List<ReportFinancialCostItem> linkedCreditCosts = data.financialCostItems
        .where((item) => !item.purchaseInstallment && item.financialCost > 0)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Resumo do mês',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const CalculationInfoButton(
                  title: 'Resumo do mês',
                  description:
                      'Saldo, A pagar e Despesas são números diferentes: saldo é o dinheiro disponível nas contas; A pagar são obrigações pendentes; Despesas mostram o custo econômico do período.',
                  items: [
                    'Receitas: receitas lançadas no mês, recebidas ou pendentes.',
                    'Despesas: gastos do período sem contar duas vezes o pagamento de uma fatura.',
                    'Crédito recebido pelo cartão não é renda. No relatório entra apenas o custo financeiro da operação.',
                    'A pagar pode ser maior que Despesas porque inclui principal de crédito, faturas e outros compromissos que ainda exigem caixa.',
                  ],
                  formula:
                      'Economia = Receitas − Despesas econômicas do período',
                  note:
                      'Exemplo: receber R\$ 500 e ficar devendo R\$ 550 pode adicionar R\$ 550 aos compromissos de caixa, mas apenas R\$ 50 ao custo financeiro do relatório.',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Receitas',
                    value: data.incomes.money,
                    color: const Color(0xFF1AA56B),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'Despesas',
                    value: data.expenses.money,
                    color: const Color(0xFFE34B42),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'Economia',
                    value: savings.money,
                    color: savings >= 0
                        ? scheme.primary
                        : const Color(0xFFE34B42),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Ainda pode sair do caixa: ${data.cashCommitments.total.money}',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'São três leituras diferentes: saldo = dinheiro disponível; A pagar = obrigações que ainda exigem caixa; Despesas = custo econômico do mês, sem duplicar faturas nem o principal de créditos.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            if (data.financialExplanation.shouldExplainEconomyVsPending) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.pushNamed(
                  FinancialResultExplanationPage.route,
                  extra: data.month,
                ),
                icon: const Icon(Icons.calculate_outlined),
                label: Text(
                  data.financialExplanation
                          .shouldExplainPositiveEconomyWithNegativePendingCash
                      ? 'Entender por que ainda houve economia'
                      : 'Entender por que os valores são diferentes',
                ),
              ),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () => setState(() => expanded = !expanded),
                icon: Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                label: Text(expanded ? 'Menos informações' : 'Mais informações'),
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  data.incomes <= 0
                      ? 'Taxa de economia indisponível sem receitas consideradas.'
                      : '${data.savingsRate.round()}% da receita considerada ficou como economia neste mês.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 14),
              Divider(color: scheme.outlineVariant),
              const SizedBox(height: 8),
              Text(
                'Composição das despesas',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              _BreakdownLine(
                label: 'Despesas comuns',
                value: data.regularExpenses,
              ),
              _BreakdownLine(
                label: 'Compras em faturas',
                value: data.creditCardPurchases,
              ),
              _BreakdownLine(
                label: 'Juros e custos financeiros',
                value: data.financialCosts,
                emphasized: data.financialCosts > 0,
              ),
              _BreakdownLine(
                label: 'Despesas planejadas',
                value: data.plannedPurchases,
                emphasized: data.plannedPurchases > 0,
              ),
              if (data.financialCosts > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 2, bottom: 4),
                  child: Text(
                    'Planejados: ${data.plannedFinancialCosts.money}  •  Realizados: ${data.realizedFinancialCosts.money}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
              if (linkedCreditCosts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Como o custo do crédito foi formado',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Text(
                          _linkedCreditDescription(linkedCreditCosts.first),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      if (linkedCreditCosts.length > 1)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () =>
                                _showAllLinkedCreditCosts(linkedCreditCosts),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(
                              '+${linkedCreditCosts.length - 1} ${linkedCreditCosts.length == 2 ? 'vínculo de crédito' : 'vínculos de crédito'} · Ver mais',
                            ),
                          ),
                        ),
                      Text(
                        'O valor que entra na conta é crédito, não receita. O principal devolvido na fatura também não vira uma nova despesa; somente a diferença é custo.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    data.isExpenseCompositionConsistent
                        ? Icons.verified_outlined
                        : Icons.warning_amber_rounded,
                    size: 17,
                    color: data.isExpenseCompositionConsistent
                        ? const Color(0xFF1AA56B)
                        : scheme.error,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      data.isExpenseCompositionConsistent
                          ? 'Composição conferida: as parcelas acima fecham com o total de despesas.'
                          : 'Atenção: a composição difere do total em ${data.expenseCompositionDifference.money}.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: scheme.outlineVariant),
              const SizedBox(height: 8),
              Text(
                'Detalhamento do que ainda pode sair do caixa',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Aqui entram obrigações de caixa. Elas não são somadas novamente às despesas do relatório.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              _BreakdownLine(
                label: 'Despesas pendentes',
                value: data.cashCommitments.pendingExpenses,
              ),
              _BreakdownLine(
                label: 'Faturas em aberto',
                value: data.cashCommitments.openBills,
              ),
              _BreakdownLine(
                label: 'Cobranças de créditos planejados',
                value: data.cashCommitments.plannedCreditCharges,
              ),
              _BreakdownLine(
                label: 'Despesas planejadas',
                value: data.cashCommitments.plannedExpenses,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _linkedCreditDescription(ReportFinancialCostItem item) {
    if (item.planned) {
      return '${item.description}: a operação prevê uma entrada de ${item.amountReceived.money} na conta vinculada a uma cobrança de ${item.amountCharged.money} na fatura. A diferença de ${item.financialCost.money} é o custo financeiro considerado no relatório.';
    }

    return '${item.description}: essa operação vinculou uma entrada de ${item.amountReceived.money} na conta a uma cobrança de ${item.amountCharged.money} na fatura. Por isso, o relatório considera apenas ${item.financialCost.money} como custo financeiro.';
  }

  Future<void> _showAllLinkedCreditCosts(
    List<ReportFinancialCostItem> items,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final ColorScheme scheme = Theme.of(sheetContext).colorScheme;

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .78,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Text(
                  'Vínculos de crédito do mês',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Cada item liga o valor que entrou na conta à cobrança correspondente na fatura. Apenas a diferença é tratada como custo financeiro.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 14),
                ...items.map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.description,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              item.planned ? 'Planejado' : 'Realizado',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: scheme.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _linkedCreditDescription(item),
                          style:
                              Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Fatura considerada: ${DateFormat('dd/MM/yyyy').format(item.billDueDate)}',
                          style: Theme.of(sheetContext)
                              .textTheme
                              .labelMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _GreenAccentPreset { blue, green, orange, red, none }

const String _greenOkAccentPreference = 'reports_green_path_ok_accent';
const String _greenDebtAccentPreference = 'reports_green_path_debt_accent';

_GreenAccentPreset _readGreenPreset(
  SharedPreferences preferences,
  String key,
  _GreenAccentPreset fallback,
) {
  final String? stored = preferences.getString(key);
  return _GreenAccentPreset.values.firstWhere(
    (preset) => preset.name == stored,
    orElse: () => fallback,
  );
}

Color _greenPresetColor(_GreenAccentPreset preset, ColorScheme scheme) {
  return switch (preset) {
    _GreenAccentPreset.blue => const Color(0xFF3C65F6),
    _GreenAccentPreset.green => const Color(0xFF2CC985),
    _GreenAccentPreset.orange => scheme.primary,
    _GreenAccentPreset.red => const Color(0xFFE34B42),
    _GreenAccentPreset.none => scheme.onSurfaceVariant,
  };
}

String _greenPresetLabel(_GreenAccentPreset preset) {
  return switch (preset) {
    _GreenAccentPreset.blue => 'Azul',
    _GreenAccentPreset.green => 'Verde',
    _GreenAccentPreset.orange => 'Laranja',
    _GreenAccentPreset.red => 'Vermelho',
    _GreenAccentPreset.none => 'Sem cor',
  };
}

class _GreenPathCard extends StatefulWidget {
  final ReportGreenPathEntity data;
  final ReportsDashboardViewModel viewModel;

  const _GreenPathCard({
    required this.data,
    required this.viewModel,
  });

  @override
  State<_GreenPathCard> createState() => _GreenPathCardState();
}

class _GreenPathCardState extends State<_GreenPathCard> {
  SharedPreferences get _preferences => DI.get<SharedPreferences>();

  bool get _debtState => widget.data.hasOpenDebt || !widget.data.isGreen;

  _GreenAccentPreset get _accentPreset => _debtState
      ? _readGreenPreset(
          _preferences,
          _greenDebtAccentPreference,
          _GreenAccentPreset.red,
        )
      : _readGreenPreset(
          _preferences,
          _greenOkAccentPreference,
          _GreenAccentPreset.green,
        );

  Future<void> _showAppearanceSettings() async {
    _GreenAccentPreset okPreset = _readGreenPreset(
      _preferences,
      _greenOkAccentPreference,
      _GreenAccentPreset.green,
    );
    _GreenAccentPreset debtPreset = _readGreenPreset(
      _preferences,
      _greenDebtAccentPreference,
      _GreenAccentPreset.red,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final ColorScheme scheme = Theme.of(context).colorScheme;

          Widget options({
            required _GreenAccentPreset selected,
            required ValueChanged<_GreenAccentPreset> onSelected,
          }) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _GreenAccentPreset.values.map((preset) {
                final bool isSelected = preset == selected;
                final Color color = _greenPresetColor(preset, scheme);
                return ChoiceChip(
                  selected: isSelected,
                  onSelected: (_) => onSelected(preset),
                  avatar: preset == _GreenAccentPreset.none
                      ? Icon(
                          Icons.block_rounded,
                          size: 17,
                          color: isSelected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        )
                      : Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                  label: Text(_greenPresetLabel(preset)),
                );
              }).toList(),
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.palette_outlined,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aparência do Caminho para o verde',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Escolha a cor quando estiver tudo ok e quando houver dívidas.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Quando estiver tudo ok',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                options(
                  selected: okPreset,
                  onSelected: (preset) =>
                      setModalState(() => okPreset = preset),
                ),
                const SizedBox(height: 18),
                Text(
                  'Quando houver dívidas',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                options(
                  selected: debtPreset,
                  onSelected: (preset) =>
                      setModalState(() => debtPreset = preset),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setModalState(() {
                          okPreset = _GreenAccentPreset.green;
                          debtPreset = _GreenAccentPreset.red;
                        });
                      },
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Restaurar padrão'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        await _preferences.setString(
                          _greenOkAccentPreference,
                          okPreset.name,
                        );
                        await _preferences.setString(
                          _greenDebtAccentPreference,
                          debtPreset.name,
                        );
                        if (!mounted) return;
                        Navigator.of(this.context).pop();
                        setState(() {});
                      },
                      child: const Text('Aplicar'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ReportGreenPathEntity data = widget.data;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final _GreenAccentPreset preset = _accentPreset;
    final Color accent = _greenPresetColor(preset, scheme);
    final bool accentEnabled = preset != _GreenAccentPreset.none;
    final DateTime? forecast = data.estimatedGreenMonth;
    final String forecastLabel = forecast == null
        ? 'Além de ${data.projectionMonths} meses'
        : data.isGreen && !data.hasOpenDebt && data.monthsToGreen == 0
            ? 'Situação normalizada'
            : _greenMonthLabel(forecast);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: accentEnabled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(
                      alpha: _debtState
                          ? (dark ? .14 : .08)
                          : (dark ? .09 : .05),
                    ),
                    scheme.surfaceContainer,
                  ],
                )
              : null,
          border: Border.all(
            color: accentEnabled
                ? accent.withValues(alpha: _debtState ? .26 : .12)
                : scheme.outlineVariant.withValues(alpha: .65),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: dark ? .13 : .08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _debtState
                          ? Icons.account_balance_wallet_outlined
                          : Icons.check_circle_outline_rounded,
                      color: accent,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Caminho para o verde',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Projeção: ${data.projectionMonths} meses',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<int>(
                    tooltip: 'Horizonte da projeção',
                    initialValue: data.projectionMonths,
                    onSelected: widget.viewModel.setGreenPathMonths,
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 6, child: Text('6 meses')),
                      PopupMenuItem(value: 12, child: Text('12 meses')),
                      PopupMenuItem(value: 24, child: Text('24 meses')),
                    ],
                    icon: Icon(
                      Icons.schedule_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Personalizar cores',
                    visualDensity: VisualDensity.compact,
                    onPressed: _showAppearanceSettings,
                    icon: Icon(
                      Icons.palette_outlined,
                      size: 19,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.isGreen
                              ? 'Cobertura disponível'
                              : 'Falta para o verde',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data.isGreen
                              ? data.availableBalance.money
                              : data.amountMissing.money,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: accentEnabled ? accent : null,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          forecast == null ? 'Horizonte' : 'Normalização',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          forecastLabel,
                          textAlign: TextAlign.end,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: accentEnabled ? accent : null,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _GreenCompactMetric(
                      label: 'Dívidas',
                      value: data.openDebt.money,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _GreenCompactMetric(
                      label: '1 mês normal',
                      value: data.monthlyLivingCost.money,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showGreenPathDetails(
                    context,
                    data,
                    widget.viewModel,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Ver detalhes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GreenCompactMetric extends StatelessWidget {
  final String label;
  final String value;

  const _GreenCompactMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showGreenPathDetails(
  BuildContext context,
  ReportGreenPathEntity data,
  ReportsDashboardViewModel viewModel,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .86,
      minChildSize: .55,
      maxChildSize: .96,
      builder: (context, controller) => _GreenPathDetailsSheet(
        data: data,
        viewModel: viewModel,
        controller: controller,
      ),
    ),
  );
}

class _GreenPathDetailsSheet extends StatelessWidget {
  final ReportGreenPathEntity data;
  final ReportsDashboardViewModel viewModel;
  final ScrollController controller;

  const _GreenPathDetailsSheet({
    required this.data,
    required this.viewModel,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final SharedPreferences preferences = DI.get<SharedPreferences>();
    final bool debtState = data.hasOpenDebt || !data.isGreen;
    final _GreenAccentPreset preset = debtState
        ? _readGreenPreset(
            preferences,
            _greenDebtAccentPreference,
            _GreenAccentPreset.red,
          )
        : _readGreenPreset(
            preferences,
            _greenOkAccentPreference,
            _GreenAccentPreset.green,
          );
    final Color accent = _greenPresetColor(preset, scheme);
    final DateTime? forecast = data.estimatedGreenMonth;
    final List<ReportGreenDebtItem> cardDebts = data.debtItems
        .where((item) => item.kind == ReportGreenDebtKind.creditCardBill)
        .toList();
    final List<ReportGreenDebtItem> otherDebts = data.debtItems
        .where((item) => item.kind == ReportGreenDebtKind.pendingExpense)
        .toList();

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text(
          'Caminho para o verde',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          'Esta leitura projeta mês a mês quando seu dinheiro conseguiria cobrir as dívidas que ainda restarem e manter o equivalente a um mês normal de despesas. A projeção considera pendências, faturas, parcelas, créditos vinculados e planejamentos conhecidos, no mesmo espírito do Radar.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 14),
        Text(
          'Horizonte da projeção',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [6, 12, 24].map((months) {
            return ChoiceChip(
              label: Text('$months meses'),
              selected: data.projectionMonths == months,
              onSelected: data.projectionMonths == months
                  ? null
                  : (_) async {
                      Navigator.of(context).pop();
                      await viewModel.setGreenPathMonths(months);
                    },
            );
          }).toList(),
        ),
        const SizedBox(height: 7),
        Text(
          'Ao trocar o período, o relatório é recalculado. Se uma fatura ou planejamento futuro fizer você voltar ao vermelho, o Rallet empurra a normalização para depois desse compromisso.',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: .20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                forecast != null
                    ? data.isGreen && data.monthsToGreen == 0
                        ? 'Cobertura já disponível'
                        : 'Previsão para normalizar'
                    : 'Ainda não normaliza no horizonte',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                forecast != null
                    ? data.isGreen && data.monthsToGreen == 0
                        ? 'Agora'
                        : _greenMonthLabel(forecast)
                    : 'Próximos ${data.projectionMonths} meses',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                forecast != null
                    ? data.monthsToGreen == 0
                        ? 'Seu saldo já cobre o valor necessário hoje e a projeção não identifica uma perda dessa condição dentro do período analisado.'
                        : 'A condição aparece em ${_greenMonthLabel(forecast)} e permanece atendida até o fim dos ${data.projectionMonths} meses analisados, considerando os compromissos já cadastrados.'
                    : _greenNoForecastReason(data),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _GreenSectionTitle(title: 'Como o valor foi calculado'),
        const SizedBox(height: 7),
        _GreenEquationLine(label: 'Dívidas em aberto', value: data.openDebt),
        _GreenEquationLine(
          label: '+ 1 mês normal de despesas',
          value: data.monthlyLivingCost,
        ),
        const Divider(height: 18),
        _GreenEquationLine(
          label: 'Valor para ficar no verde',
          value: data.greenTarget,
          emphasized: true,
        ),
        _GreenEquationLine(
          label: 'Dinheiro disponível hoje',
          value: data.availableBalance,
        ),
        _GreenEquationLine(
          label: 'Ainda falta',
          value: data.amountMissing,
          emphasized: true,
        ),
        const SizedBox(height: 18),
        _GreenSectionTitle(
          title: 'Projeção mês a mês',
          trailing: '${data.projectionMonths} meses',
        ),
        const SizedBox(height: 5),
        Text(
          'Cada linha parte do saldo atual e aplica os recebimentos e compromissos conhecidos daquele mês. “Cobertura necessária” é a dívida que ainda restaria naquele ponto + um mês normal de despesas.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
        ),
        const SizedBox(height: 9),
        ...data.projection.map(
          (point) => _GreenProjectionRow(point: point, accent: accent),
        ),
        const SizedBox(height: 18),
        _GreenSectionTitle(
          title: 'Quais são as dívidas?',
          trailing: data.openDebt.money,
        ),
        const SizedBox(height: 5),
        Text(
          'O total abaixo mostra obrigações que já existem hoje. Compras parceladas no cartão aparecem nas respectivas faturas futuras; recorrências futuras ainda não vencidas continuam como custo mensal e não são somadas como uma dívida de vários anos.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
        ),
        const SizedBox(height: 10),
        if (data.debtItems.isEmpty)
          Text(
            'Nenhuma dívida aberta foi encontrada.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        if (cardDebts.isNotEmpty) ...[
          _GreenDebtGroupHeader(
            icon: Icons.credit_card_rounded,
            label: 'Cartões, faturas e parcelas',
            value: data.creditCardDebt,
          ),
          const SizedBox(height: 7),
          ...cardDebts.map((item) => _GreenDebtItemCard(item: item)),
        ],
        if (otherDebts.isNotEmpty) ...[
          const SizedBox(height: 8),
          _GreenDebtGroupHeader(
            icon: Icons.receipt_long_rounded,
            label: 'Outras despesas em aberto',
            value: data.pendingExpenseDebt,
          ),
          const SizedBox(height: 7),
          ...otherDebts.map((item) => _GreenDebtItemCard(item: item)),
        ],
        const SizedBox(height: 18),
        _GreenSectionTitle(title: 'Ritmo mensal estimado'),
        const SizedBox(height: 7),
        _GreenEquationLine(
          label: data.incomeBasedOnRecurring
              ? 'Renda recorrente cadastrada'
              : 'Renda mensal estimada',
          value: data.monthlyIncome,
        ),
        _GreenEquationLine(
          label: 'Custo mensal normal estimado',
          value: data.monthlyLivingCost,
        ),
        _GreenEquationLine(
          label: 'Sobra para recuperação',
          value: data.monthlyRecoveryCapacity,
          emphasized: true,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Para não voltar ao vermelho',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                'Com despesas fora do cartão estimadas em ${data.nonCardMonthlyCost.money}, sua renda deixa até ${data.sustainableCardCapacity.money} para fatura e outras compras no cartão sem ultrapassar a renda mensal. É um teto matemático, não uma meta de gasto.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
              if (data.nextMonthCardBill > 0.01) ...[
                const SizedBox(height: 8),
                Text(
                  data.nextMonthCardExcess > 0.01
                      ? 'A próxima fatura registrada é ${data.nextMonthCardBill.money}, ou ${data.nextMonthCardExcess.money} acima dessa margem pessoal.'
                      : 'A próxima fatura registrada é ${data.nextMonthCardBill.money} e cabe nessa margem, se os demais gastos permanecerem próximos da estimativa.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: data.nextMonthCardExcess > 0.01
                            ? scheme.error
                            : null,
                      ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          data.historyMonthsAnalyzed > 0
              ? 'O custo mensal usa a média de ${data.historyMonthsAnalyzed} ${data.historyMonthsAnalyzed == 1 ? 'mês concluído' : 'meses concluídos'} com dados. A previsão pode mudar quando novas receitas, despesas, faturas, juros ou pagamentos forem registrados.'
              : 'Ainda não há histórico concluído suficiente; o Rallet usa os dados disponíveis do mês atual como referência. A previsão tende a ficar mais estável com mais histórico.',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
        ),
      ],
    );
  }
}

class _GreenProjectionRow extends StatelessWidget {
  final ReportGreenProjectionPoint point;
  final Color accent;

  const _GreenProjectionRow({
    required this.point,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool ok = point.green;
    final Color statusColor = ok ? const Color(0xFF2CC985) : accent;
    final String month = DateFormat('MMM/yy', 'pt_BR').format(point.month);

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .32),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: statusColor.withValues(alpha: ok ? .14 : .22),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline_rounded : Icons.timelapse_rounded,
            size: 18,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 58,
            child: Text(
              month,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo ${point.projectedBalance.money} • cobertura ${point.requiredCoverage.money}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  'Movimento do mês ${point.netMovement >= 0 ? '+' : ''}${point.netMovement.money} • dívida restante ${point.remainingDebt.money}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GreenSectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;

  const _GreenSectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
      ],
    );
  }
}

class _GreenDebtGroupHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;

  const _GreenDebtGroupHeader({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        Text(
          value.money,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _GreenDebtItemCard extends StatelessWidget {
  final ReportGreenDebtItem item;

  const _GreenDebtItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String dueLabel = item.dueDate.isBefore(
      DateTime.now().subtract(const Duration(days: 1)),
    )
        ? 'Vencida em ${DateFormat('dd/MM/yyyy').format(item.dueDate)}'
        : 'Vence em ${DateFormat('dd/MM/yyyy').format(item.dueDate)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .65)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.originLabel} • $dueLabel',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                item.amount.money,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          if (item.components.isNotEmpty) ...[
            const Divider(height: 18),
            Text(
              'O que forma esta fatura',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 5),
            ...item.components.map(
              (component) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            component.description,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            component.originLabel,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      component.amount.money,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            if (item.alreadyPaid > 0.01) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pagamentos/abatimentos já lançados',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  Text(
                    '-${item.alreadyPaid.money}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

String _greenMonthLabel(DateTime date) {
  final String raw = DateFormat('MMMM yyyy', 'pt_BR').format(date);
  return raw.isEmpty ? '' : raw[0].toUpperCase() + raw.substring(1);
}

String _greenNoForecastReason(ReportGreenPathEntity data) {
  if (data.projection.isNotEmpty) {
    final ReportGreenProjectionPoint last = data.projection.last;
    final double shortfall =
        (last.requiredCoverage - last.projectedBalance).clamp(0, double.infinity).toDouble();
    final String endLabel = _greenMonthLabel(last.month);
    final String extension = data.projectionMonths < 24
        ? ' Você pode ampliar o horizonte para ${data.projectionMonths == 6 ? '12 ou 24' : '24'} meses para enxergar mais adiante.'
        : '';

    if (shortfall > 0.01) {
      return 'Com os compromissos atualmente cadastrados, em $endLabel ainda faltariam aproximadamente ${shortfall.money} para cobrir a dívida restante e um mês normal de despesas.$extension';
    }
  }

  if (data.monthlyRecoveryCapacity < -0.01) {
    final double deficit = data.monthlyLivingCost - data.monthlyIncome;
    return 'Sua referência mensal está negativa em ${deficit.money}. Sem reduzir esse déficit ou aumentar a renda, a projeção não encontra uma normalização estável dentro do período analisado.';
  }

  return 'A projeção ainda não encontrou um ponto em que a cobertura permaneça suficiente até o fim do horizonte. Novas faturas, parcelas e planejamentos conhecidos podem estar empurrando essa data para frente.';
}

class _GreenEquationLine extends StatelessWidget {
  final String label;
  final double value;
  final bool emphasized;

  const _GreenEquationLine({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value.money,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownLine extends StatelessWidget {
  final String label;
  final double value;
  final bool emphasized;

  const _BreakdownLine({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: emphasized ? FontWeight.w600 : null,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value.money,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: emphasized ? scheme.primary : null,
                ),
          ),
        ],
      ),
    );
  }
}

class _FinancialCostsCard extends StatelessWidget {
  final ReportsDashboardEntity data;

  const _FinancialCostsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<ReportFinancialCostItem> items = data.financialCostItems;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Juros e custos financeiros',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const CalculationInfoButton(
                  title: 'Juros e custos financeiros',
                  description:
                      'Esta seção explica juros e custos de crédito, incluindo crédito via cartão e parcelamentos planejados, sem misturar principal com custo financeiro.',
                  items: [
                    'Planejado: o custo já participa do cenário dos relatórios, mas ainda não alterou saldo nem limite real.',
                    'Realizado: a entrada já ocorreu e a cobrança já foi criada no cartão.',
                    'Em compras parceladas, o preço-base fica separado do custo adicional do parcelamento.',
                  ],
                  formula: 'Custo financeiro = total cobrado − valor-base',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Total no mês: ${data.financialCosts.money}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            if (items.isNotEmpty) _FinancialCostItemCard(item: items.first),
            if (items.length > 1)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showAllFinancialCosts(context, items),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(_moreItemsLabel(items)),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  data.isFinancialCostCompositionConsistent
                      ? Icons.verified_outlined
                      : Icons.warning_amber_rounded,
                  size: 17,
                  color: data.isFinancialCostCompositionConsistent
                      ? const Color(0xFF1AA56B)
                      : scheme.error,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    data.isFinancialCostCompositionConsistent
                        ? 'Custos conferidos: as operações do mês fecham com o valor usado no resumo.'
                        : 'Atenção: há ${data.financialCostCompositionDifference.money} de diferença entre o resumo e as operações listadas.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _moreItemsLabel(List<ReportFinancialCostItem> items) {
    final int remaining = items.length - 1;
    final bool remainingAreCreditLinks =
        items.skip(1).every((item) => !item.purchaseInstallment);

    if (remainingAreCreditLinks) {
      return '+$remaining ${remaining == 1 ? 'vínculo de crédito' : 'vínculos de crédito'} · Ver mais';
    }

    return '+$remaining ${remaining == 1 ? 'custo financeiro' : 'custos financeiros'} · Ver mais';
  }

  Future<void> _showAllFinancialCosts(
    BuildContext context,
    List<ReportFinancialCostItem> items,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .82,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                'Juros e custos financeiros do mês',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              ...items.map((item) => _FinancialCostItemCard(item: item)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinancialCostItemCard extends StatelessWidget {
  final ReportFinancialCostItem item;

  const _FinancialCostItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .40),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.description,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: (item.planned
                          ? scheme.primary
                          : const Color(0xFF1AA56B))
                      .withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.planned ? 'Planejado' : 'Realizado',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: item.planned
                            ? scheme.primary
                            : const Color(0xFF1AA56B),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FinancialDetailLine(
            label: item.purchaseInstallment
                ? 'Preço-base no mês'
                : 'Valor recebido',
            value: item.amountReceived.money,
          ),
          _FinancialDetailLine(
            label: item.purchaseInstallment
                ? 'Cobrado no mês'
                : 'Valor cobrado',
            value: item.amountCharged.money,
          ),
          _FinancialDetailLine(
            label: 'Juros/taxas',
            value: item.financialCost.money,
            emphasized: true,
          ),
          _FinancialDetailLine(
            label: 'Custo da operação',
            value: '${item.costRate.toStringAsFixed(2)}%',
          ),
          _FinancialDetailLine(
            label: 'Vencimento considerado',
            value: DateFormat('dd/MM/yyyy').format(item.billDueDate),
          ),
        ],
      ),
    );
  }
}

class _FinancialDetailLine extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _FinancialDetailLine({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
                    color: emphasized ? Theme.of(context).colorScheme.primary : null,
                  ),
            ),
          ],
        ),
      );
}

class _PlannedExpensesCard extends StatelessWidget {
  final ReportsDashboardEntity data;

  const _PlannedExpensesCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Despesas planejadas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const CalculationInfoButton(
                  title: 'Despesas planejadas',
                  description:
                      'Mostra o que você pretende gastar no mês sem confundir planejamento com despesa já realizada.',
                  items: [
                    'A categoria escolhida no planejamento é preservada nos relatórios.',
                    'À vista entra na data prevista; no cartão entra pelo vencimento das parcelas.',
                    'Ao realizar a despesa, o planejamento deve ser substituído pelo lançamento real para não duplicar valores.',
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Previsto no mês: ${data.plannedExpensesDetailedTotal.money}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            ...data.plannedExpenseItems.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.description,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            '${item.categoryName} • ${item.paymentLabel} • ${DateFormat('dd/MM').format(item.date)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.amount.money,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlannedVsRealizedCard extends StatelessWidget {
  final ReportsDashboardEntity data;
  final VoidCallback onOpen;

  const _PlannedVsRealizedCard({
    required this.data,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    const Color positive = Color(0xFF1AA56B);
    const Color negative = Color(0xFFE34B42);
    final bool netPositive = data.netVariance >= 0;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Planejado x realizado',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                data.varianceItems.isEmpty
                    ? 'Nenhuma diferença real registrada neste mês.'
                    : '${data.varianceItems.length} diferença(s) registrada(s) neste mês.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _CompactVarianceMetric(
                      label: 'Positivo',
                      value: '+ ${data.positiveVariance.money}',
                      color: positive,
                    ),
                  ),
                  Expanded(
                    child: _CompactVarianceMetric(
                      label: 'Negativo',
                      value: '- ${data.negativeVariance.money}',
                      color: negative,
                    ),
                  ),
                  Expanded(
                    child: _CompactVarianceMetric(
                      label: 'Saldo',
                      value:
                          '${netPositive ? '+' : '-'} ${data.netVariance.abs().money}',
                      color: netPositive ? positive : negative,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactVarianceMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  const _CompactVarianceMetric({
    required this.label,
    required this.value,
    required this.color,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Metric({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _CategoriesCard extends StatelessWidget {
  final ReportsDashboardEntity data;
  final VoidCallback onOpen;

  const _CategoriesCard({required this.data, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final top = data.expenseCategories.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Para onde foi meu dinheiro?', style: Theme.of(context).textTheme.titleLarge)),
                const CalculationInfoButton(
                  title: 'Despesas por categoria',
                  description:
                      'A composição usa a mesma regra do Resumo do mês para que o total detalhado possa ser conferido.',
                  items: [
                    'Despesas comuns usam a data do lançamento.',
                    'Compras de cartão entram no mês de vencimento da fatura, e não no mês em que a compra foi feita.',
                    'Crédito via cartão entra somente pelo juros/taxa; o principal emprestado não é gasto de consumo.',
                    'Juros de operações planejadas aparecem em Outros, identificados como planejamento.',
                  ],
                  formula: 'Total por categorias = Total de despesas consideradas',
                ),
                IconButton(
                  tooltip: 'Ver categorias',
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_outlined),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (top.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Ainda não há despesas consideradas neste mês.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              )
            else
              Row(
                children: [
                  SizedBox(
                    width: 135,
                    height: 135,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 38,
                        sectionsSpace: 2,
                        sections: top.map((category) {
                          final double amount = category.amount.abs();
                          return PieChartSectionData(
                            value: amount,
                            radius: 24,
                            showTitle: false,
                            color: _categoryColor(category.category.color, Theme.of(context).colorScheme.primary),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      children: top.map((category) {
                        final Color color = _categoryColor(category.category.color, Theme.of(context).colorScheme.primary);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  category.category.description,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(category.amount.abs().money),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            if (data.expenseCategories.isNotEmpty) ...[
              const SizedBox(height: 14),
              Divider(color: Theme.of(context).colorScheme.outlineVariant),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    data.isCategoryCompositionConsistent
                        ? Icons.verified_outlined
                        : Icons.warning_amber_rounded,
                    size: 17,
                    color: data.isCategoryCompositionConsistent
                        ? const Color(0xFF1AA56B)
                        : Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      data.isCategoryCompositionConsistent
                          ? 'Categorias conferidas: o detalhamento fecha com o total de despesas.'
                          : 'O detalhamento por categoria difere ${data.categoryCompositionDifference.money} do total.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Color _categoryColor(String value, Color fallback) {
    try {
      final String clean = value.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
      if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }
}

class _FixedVariableCard extends StatelessWidget {
  final ReportsDashboardEntity data;

  const _FixedVariableCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final double total = data.fixedExpenses + data.variableExpenses;
    final double fixedRatio = total <= 0 ? 0 : data.fixedExpenses / total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Fixas x variáveis', style: Theme.of(context).textTheme.titleLarge),
                ),
                const CalculationInfoButton(
                  title: 'Fixas x variáveis',
                  description:
                      'Esta divisão ajuda a identificar quanto do mês já nasce comprometido.',
                  items: [
                    'Fixas/parceladas: despesas recorrentes e parcelas normais de cartão.',
                    'Variáveis: restante das despesas consideradas no mês.',
                    'Juros de crédito via cartão ficam como variável, pois dependem de cada operação.',
                  ],
                  formula: 'Variáveis = Despesas totais − Fixas/parceladas',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Recorrências e parcelas são consideradas comprometidas.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: [
                    Expanded(
                      flex: math.max(1, (fixedRatio * 1000).round()).toInt(),
                      child: Container(color: Theme.of(context).colorScheme.primary),
                    ),
                    Expanded(
                      flex: math.max(1, ((1 - fixedRatio) * 1000).round()).toInt(),
                      child: Container(color: Theme.of(context).colorScheme.primaryContainer),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _Metric(label: 'Fixas/parceladas', value: data.fixedExpenses.money, color: Theme.of(context).colorScheme.primary)),
                const SizedBox(width: 12),
                Expanded(child: _Metric(label: 'Variáveis', value: data.variableExpenses.money, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EvolutionCard extends StatelessWidget {
  final ReportsDashboardEntity data;

  const _EvolutionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final double maxY = data.evolution.isEmpty
        ? 100.0
        : math.max(100.0, data.evolution.map((e) => e.expenses).reduce(math.max) * 1.20).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Evolução de despesas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            SizedBox(
              height: 210,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final int index = value.round();
                          if (index < 0 || index >= data.evolution.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('MMM', 'pt_BR').format(data.evolution[index].month).replaceAll('.', ''),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 3,
                      color: Theme.of(context).colorScheme.primary,
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
                      ),
                      dotData: const FlDotData(show: true),
                      spots: [
                        for (int i = 0; i < data.evolution.length; i++)
                          FlSpot(i.toDouble(), data.evolution[i].expenses),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final ReportsDashboardEntity data;

  const _ComparisonCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final double variation = data.expenseVariationPercent;
    final bool lower = variation < 0;
    final bool equal = variation.abs() < .01;
    final double difference = data.expenses - data.previousMonthExpenses;

    String message;
    if (data.previousMonthExpenses <= 0) {
      message = 'Não há base suficiente no mês anterior para fazer uma comparação.';
    } else if (equal) {
      message = 'Suas despesas ficaram praticamente iguais ao mês anterior.';
    } else if (lower) {
      message = 'Você gastou ${difference.abs().money} a menos que no mês anterior.';
    } else {
      message = 'Você gastou ${difference.abs().money} a mais que no mês anterior.';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (lower ? const Color(0xFF1AA56B) : Theme.of(context).colorScheme.primary)
                    .withValues(alpha: .10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                lower ? Icons.south_east_rounded : equal ? Icons.horizontal_rule : Icons.north_east_rounded,
                color: lower ? const Color(0xFF1AA56B) : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Comparação mensal', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  if (data.previousMonthExpenses > 0)
                    Text(
                      '${variation.abs().toStringAsFixed(1)}% ${lower ? 'menor' : equal ? 'igual' : 'maior'}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: lower ? const Color(0xFF1AA56B) : Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  const SizedBox(height: 3),
                  Text(message, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FutureCommitmentsCard extends StatelessWidget {
  final ReportsDashboardEntity data;

  const _FutureCommitmentsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final double maxAmount = data.futureCommitments.isEmpty
        ? 1.0
        : math.max(1.0, data.futureCommitments.map((e) => e.amount).reduce(math.max)).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Comprometimento futuro', style: Theme.of(context).textTheme.titleLarge),
                ),
                const CalculationInfoButton(
                  title: 'Comprometimento futuro',
                  description:
                      'Mostra valores que ainda precisarão de caixa nos próximos meses.',
                  items: [
                    'Soma despesas pendentes do mês.',
                    'Soma apenas o saldo ainda aberto das faturas.',
                    'Soma o valor total que será cobrado em operações de crédito ainda planejadas.',
                    'Operações já realizadas não são adicionadas de novo porque sua cobrança já está na fatura.',
                  ],
                  formula:
                      'Comprometimento = Pendências + Faturas em aberto + Cobranças planejadas',
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Contas pendentes e faturas já previstas nos próximos meses.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 18),
            ...data.futureCommitments.map((item) {
              final double ratio = item.amount / maxAmount;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat('MMMM', 'pt_BR').format(item.month),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Text(item.amount.money, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .5),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
