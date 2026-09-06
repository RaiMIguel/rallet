import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/card_cash_advance/presentation/ui/card_cash_advance_details_sheet.dart';
import 'package:rallet/features/card_cash_advance/presentation/ui/card_cash_advance_form_page.dart';
import 'package:rallet/features/credit_card/presentation/ui/credit_card_bill_details_page.dart';
import 'package:rallet/features/home/domain/entities/financial_radar_entity.dart';
import 'package:rallet/features/home/presentation/view_models/home_view_model.dart';
import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';
import 'package:rallet/features/purchase_planning/presentation/ui/purchase_planning_page.dart';
import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/presentation/ui/components/details/expense_details_sheet.dart';
import 'package:rallet/features/transactions/presentation/ui/components/details/income_details_sheet.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/presentation/ui/components/calculation_info_button.dart';
import 'package:rallet/shared/presentation/ui/components/app_bar_custom.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class FinancialAlertsPage extends StatefulWidget {
  static const String route = 'financial-alerts';

  final HomeViewModel viewModel;

  const FinancialAlertsPage({
    super.key,
    required this.viewModel,
  });

  @override
  State<FinancialAlertsPage> createState() => _FinancialAlertsPageState();
}

class _FinancialAlertsPageState extends State<FinancialAlertsPage> {
  static const int _initialMovementsLimit = 10;

  final Map<String, GlobalKey> _eventKeys = {};
  bool _showAllMovements = false;

  HomeViewModel get viewModel => widget.viewModel;

  GlobalKey _eventKey(String id) =>
      _eventKeys.putIfAbsent(id, () => GlobalKey());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(
        title: Text('Alertas financeiros'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            viewModel,
            viewModel.loadFinancialRadar,
          ]),
          builder: (_, __) {
            final previous = viewModel.loadFinancialRadar.previous;

            if (viewModel.loadFinancialRadar.running &&
                previous?.completed != true) {
              return const Center(child: CircularProgressIndicator());
            }

            if (viewModel.loadFinancialRadar.hasError &&
                previous?.completed != true) {
              return _RadarError(
                onRetry: viewModel.loadFinancialRadar.execute,
              );
            }

            final FinancialRadarEntity? radar =
                viewModel.loadFinancialRadar.result ?? previous?.result;

            if (radar == null) {
              return _RadarError(
                onRetry: viewModel.loadFinancialRadar.execute,
              );
            }

            final blockingLimitAlert = radar.blockingCardLimitAlerts.isEmpty
                ? null
                : radar.blockingCardLimitAlerts.first;

            return RefreshIndicator(
              onRefresh: viewModel.loadFinancialRadar.execute,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  _RadarHeader(
                    radar: radar,
                    radarMonths: viewModel.radarMonths,
                    hideAmounts: viewModel.hideAmounts,
                    onSettings: () => _showRadarSettings(context),
                  ),
                  const SizedBox(height: 16),
                  if (radar.alerts.isNotEmpty) ...[
                    Text(
                      'Riscos de caixa',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    ...radar.alerts.asMap().entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _DetailedAlertCard(
                                  number: entry.key + 1,
                                  alert: entry.value,
                                  hideAmounts: viewModel.hideAmounts,
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () async {
                                      final result = await context.pushNamed(
                                        CardCashAdvanceFormPage.route,
                                        extra: CardCashAdvanceFormArgs(
                                          suggestedAmount: entry.value.shortage,
                                        ),
                                      );
                                      if (result == true && context.mounted) {
                                        await viewModel.load();
                                      }
                                    },
                                    icon: const Icon(Icons.credit_card_outlined),
                                    label: const Text(
                                      'Planejar cobertura deste alerta',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ] else if (blockingLimitAlert != null) ...[
                    _PrimaryLimitAlertCard(
                      alert: blockingLimitAlert,
                      hideAmounts: viewModel.hideAmounts,
                    ),
                  ] else ...[
                    _HealthyCard(
                      radar: radar,
                      hideAmounts: viewModel.hideAmounts,
                    ),
                  ],
                  if (radar.firstRiskDate != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _scrollToFirstRisk(radar),
                        icon: const Icon(Icons.south_rounded),
                        label: Text(
                          'Primeiro risco em ${DateFormat('dd/MM').format(radar.firstRiskDate!)}',
                        ),
                      ),
                    ),
                  ],
                  if (radar.plannedPurchases.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Despesas planejadas',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Essas despesas já participam da projeção. Toque em uma delas para ajustar o próprio planejamento.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 10),
                    ...radar.plannedPurchases.map(
                      (purchase) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.shopping_bag_outlined),
                          title: Text(purchase.description),
                          subtitle: Text(
                            purchase.isCreditCard
                                ? '${purchase.isInstallment ? '${purchase.installmentCount}x' : 'Cartão à vista'} • prevista em ${DateFormat('dd/MM/yyyy').format(purchase.plannedDate)}${purchase.firstBillDueDate == null ? '' : ' • 1ª fatura ${DateFormat('dd/MM').format(purchase.firstBillDueDate!)}'}'
                                : 'Planejada para ${DateFormat('dd/MM/yyyy').format(purchase.plannedDate)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                viewModel.hideAmounts
                                    ? '●●●●'
                                    : (purchase.isCreditCard
                                            ? purchase.totalCharged
                                            : purchase.amount)
                                        .money,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () async {
                            final result = await context.pushNamed(
                              PurchasePlanningPage.route,
                              extra: purchase,
                            );
                            if (result == true && context.mounted) {
                              await viewModel.load();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await context.pushNamed(
                          PurchasePlanningPage.route,
                        );
                        if (result == true && context.mounted) {
                          await viewModel.load();
                        }
                      },
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                      label: const Text('Planejar outra despesa'),
                    ),
                  ],
                  if (radar.safetyOnlyCardAlerts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Limite de segurança dos cartões',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Aqui aparecem apenas avisos do limite de segurança pessoal. Falta de limite do banco aparece no alerta principal e na data exata da linha do tempo.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 10),
                    ...radar.safetyOnlyCardAlerts.map(
                      (alert) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CardSafetyAlertCard(
                          alert: alert,
                          hideAmounts: viewModel.hideAmounts,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await context.pushNamed(
                        CardCashAdvanceFormPage.route,
                        extra: CardCashAdvanceFormArgs(
                          suggestedAmount: radar.alerts.isEmpty
                              ? null
                              : radar.alerts.first.shortage,
                        ),
                      );
                      if (result == true && context.mounted) {
                        await viewModel.load();
                      }
                    },
                    icon: const Icon(Icons.add_card_outlined),
                    label: Text(
                      radar.alerts.isEmpty
                          ? 'Planejar crédito pelo cartão'
                          : 'Novo planejamento de cobertura',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await context.pushNamed(
                        PurchasePlanningPage.route,
                      );
                      if (result == true && context.mounted) {
                        await viewModel.load();
                      }
                    },
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Planejar uma despesa'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Próximos movimentos considerados',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Receitas e despesas pendentes, planejamentos e faturas abertas usados na projeção dos próximos ${viewModel.radarMonths} ${viewModel.radarMonths == 1 ? 'mês' : 'meses'}.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 10),
                  if (radar.events.isEmpty)
                    _EmptyMovements()
                  else ...[
                    Card(
                      child: Column(
                        children: (_showAllMovements
                                ? radar.events
                                : radar.events.take(_initialMovementsLimit))
                            .map(
                              (event) => _EventTile(
                                key: _eventKey(event.id),
                                event: event,
                                hideAmounts: viewModel.hideAmounts,
                                onTap: event.origin == null
                                    ? null
                                    : () => _openEventOrigin(context, event),
                                onWarningTap: event.warningMessage == null
                                    ? null
                                    : () => _showWarningDetails(
                                          context,
                                          event,
                                        ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    if (radar.events.length > _initialMovementsLimit)
                      Align(
                        alignment: Alignment.center,
                        child: TextButton.icon(
                          onPressed: () => setState(
                            () => _showAllMovements = !_showAllMovements,
                          ),
                          icon: Icon(
                            _showAllMovements
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                          ),
                          label: Text(
                            _showAllMovements
                                ? 'Ver menos'
                                : 'Ver mais (${radar.events.length - _initialMovementsLimit})',
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openEventOrigin(
    BuildContext context,
    FinancialRadarEventEntity event,
  ) async {
    final origin = event.origin;
    bool changed = false;

    if (origin is ExpenseEntity) {
      await ExpenseDetailsSheet.show(
        context: context,
        id: origin.id,
        onChanged: (_) => changed = true,
      );
    } else if (origin is IncomeEntity) {
      await IncomeDetailsSheet.show(
        context: context,
        id: origin.id,
        onChanged: (_) => changed = true,
      );
    } else if (origin is PlannedPurchaseEntity) {
      final result = await context.pushNamed(
        PurchasePlanningPage.route,
        extra: origin,
      );
      changed = result == true;
    } else if (origin is CardCashAdvancePlanEntity) {
      if (origin.isRealized) {
        changed = await CardCashAdvanceDetailsSheet.show(
              context: context,
              plan: origin,
            ) ==
            true;
      } else {
        final result = await context.pushNamed(
          CardCashAdvanceFormPage.route,
          extra: CardCashAdvanceFormArgs(plan: origin),
        );
        changed = result == true;
      }
    } else if (origin is FinancialRadarBillOrigin &&
        origin.creditCard != null) {
      final result = await context.pushNamed(
        CreditCardBillDetailsPage.route,
        extra: CreditCardBillDetailsArgsPage(
          bill: origin.bill,
          creditCard: origin.creditCard!,
        ),
      );
      changed = result != null;
    }

    if (changed && context.mounted) {
      await viewModel.load();
    }
  }

  void _showWarningDetails(
    BuildContext context,
    FinancialRadarEventEntity event,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(event.warningMessage ?? 'Alerta do Radar'),
        content: Text(
          event.warningDetails ??
              'Este aviso foi gerado a partir da projeção cadastrada no Rallet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  void _scrollToFirstRisk(FinancialRadarEntity radar) {
    final riskDate = radar.firstRiskDate;
    if (riskDate == null) return;

    FinancialRadarEventEntity? target;
    for (final event in radar.events) {
      if (_sameDay(event.date, riskDate) && event.hasWarning) {
        target = event;
        break;
      }
    }
    if (target == null) {
      for (final event in radar.events) {
        if (_sameDay(event.date, riskDate)) {
          target = event;
          break;
        }
      }
    }

    if (target != null &&
        !_showAllMovements &&
        radar.events.indexWhere((event) => event.id == target!.id) >=
            _initialMovementsLimit) {
      setState(() => _showAllMovements = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToFirstRisk(radar);
      });
      return;
    }

    final eventContext = target == null
        ? null
        : _eventKeys[target.id]?.currentContext;
    if (eventContext == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O risco está no período, mas não há um movimento navegável nessa data.'),
        ),
      );
      return;
    }

    Scrollable.ensureVisible(
      eventContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: .15,
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _showRadarSettings(BuildContext context) async {
    int selected = viewModel.radarMonths;
    final int? result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.settings_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Configurações do Radar',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Escolha até onde o Rallet deve projetar seus compromissos futuros.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [1, 3, 6, 12].map((months) {
                    return ChoiceChip(
                      label: Text('$months ${months == 1 ? 'mês' : 'meses'}'),
                      selected: selected == months,
                      onSelected: (_) => setState(() => selected = months),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Personalizado: $selected ${selected == 1 ? 'mês' : 'meses'}',
                      ),
                    ),
                    IconButton(
                      tooltip: 'Diminuir',
                      onPressed: selected <= 1
                          ? null
                          : () => setState(() => selected--),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    IconButton(
                      tooltip: 'Aumentar',
                      onPressed: selected >= 24
                          ? null
                          : () => setState(() => selected++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                Text(
                  'Limite: 1 a 24 meses. A configuração fica salva neste dispositivo.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(selected),
                  child: const Text('Aplicar período'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null) await viewModel.setRadarMonths(result);
  }
}

class _RadarHeader extends StatelessWidget {
  final FinancialRadarEntity radar;
  final int radarMonths;
  final bool hideAmounts;
  final VoidCallback onSettings;

  const _RadarHeader({
    required this.radar,
    required this.radarMonths,
    required this.hideAmounts,
    required this.onSettings,
  });

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
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.radar_rounded,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Radar financeiro',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        'Projeção até ${DateFormat('dd/MM/yyyy').format(radar.horizonEnd)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Configurar período do Radar',
                  onPressed: onSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
                const CalculationInfoButton(
                  title: 'Projeção do Radar',
                  description:
                      'O Radar simula o saldo dia a dia usando apenas os lançamentos cadastrados no Rallet.',
                  items: [
                    'Parte do saldo atual das contas marcadas para compor o saldo total.',
                    'Soma receitas pendentes na data prevista e subtrai despesas pendentes.',
                    'Subtrai o saldo aberto das faturas na data de vencimento.',
                    'Planejamentos de crédito continuam no cenário de caixa mesmo quando o limite projetado é insuficiente; nesse caso o Rallet marca a operação com alerta para deixar claro que ela depende de ajuste.',
                    'Despesas planejadas à vista saem na data escolhida; as do cartão afetam as faturas e comprometem o limite pelo total.',
                    'O limite de cada cartão é projetado no tempo: compras e créditos comprometem o total, enquanto pagamentos de fatura liberam limite.',
                    'Pendências vencidas são tratadas como necessidade de caixa no dia atual.',
                  ],
                  formula:
                      'Saldo projetado = saldo atual + entradas previstas − saídas previstas',
                  note:
                      'O menor saldo previsto é recalculado sempre que os lançamentos ou planejamentos mudam.',
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.date_range_outlined, size: 17),
                label: Text(
                  'Horizonte: $radarMonths ${radarMonths == 1 ? 'mês' : 'meses'}',
                ),
              ),
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _HeaderValue(
                    label: 'Saldo atual',
                    value: hideAmounts ? '●●●●' : radar.currentBalance.money,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HeaderValue(
                    label: 'Menor saldo previsto',
                    value: hideAmounts
                        ? '●●●●'
                        : radar.minimumProjectedBalance.money,
                    subtitle: DateFormat('dd/MM')
                        .format(radar.minimumBalanceDate),
                    valueColor: radar.minimumProjectedBalance < 0
                        ? const Color(0xFFE34B42)
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderValue extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color? valueColor;

  const _HeaderValue({
    required this.label,
    required this.value,
    this.subtitle,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
      ],
    );
  }
}

class _DetailedAlertCard extends StatelessWidget {
  final int number;
  final FinancialAlertEntity alert;
  final bool hideAmounts;

  const _DetailedAlertCard({
    required this.number,
    required this.alert,
    required this.hideAmounts,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    const Color danger = Color(0xFFE34B42);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: danger.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? .14
                  : .08,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: danger),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alerta $number • Saldo insuficiente para pagamentos nesse dia.',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: danger,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hideAmounts
                            ? 'Cobertura insuficiente até ${DateFormat('dd/MM').format(alert.worstDate)}'
                            : 'Você precisa de ${alert.shortage.money} até ${DateFormat('dd/MM').format(alert.worstDate)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        hideAmounts
                            ? 'O saldo projetado fica abaixo de zero neste período.'
                            : 'No ponto mais crítico, o saldo projetado chega a ${alert.lowestBalance.money}.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.calendar_today_outlined,
                      label:
                          'Risco começa ${DateFormat('dd/MM').format(alert.riskStartDate)}',
                    ),
                    _InfoChip(
                      icon: Icons.receipt_long_outlined,
                      label:
                          '${alert.chargesCount} cobrança${alert.chargesCount == 1 ? '' : 's'}',
                    ),
                    if (alert.recoveryDate != null)
                      _InfoChip(
                        icon: Icons.trending_up_rounded,
                        label:
                            'Volta ao positivo ${DateFormat('dd/MM').format(alert.recoveryDate!)}',
                      )
                    else
                      const _InfoChip(
                        icon: Icons.error_outline_rounded,
                        label: 'Não normaliza no período',
                      ),
                  ],
                ),
                if (alert.events.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Movimentos até o ponto crítico',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  ...alert.events.map(
                    (event) => _EventTile(
                      event: event,
                      hideAmounts: hideAmounts,
                      compact: true,
                    ),
                  ),
                ],
                if (!hideAmounts && alert.events.isNotEmpty) ...[
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Cobranças consideradas',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      Text(
                        alert.chargesAmount.money,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                  if (alert.incomesAmount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Receitas consideradas',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        Text(
                          alert.incomesAmount.money,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final FinancialRadarEventEntity event;
  final bool hideAmounts;
  final bool compact;
  final VoidCallback? onTap;
  final VoidCallback? onWarningTap;

  const _EventTile({
    super.key,
    required this.event,
    required this.hideAmounts,
    this.compact = false,
    this.onTap,
    this.onWarningTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool income = event.isIncome;
    final bool limitOnly = !event.affectsCashFlow;
    final Color amountColor = limitOnly
        ? const Color(0xFFE58A00)
        : income
            ? const Color(0xFF1AA56B)
            : const Color(0xFFE34B42);

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: compact ? 34 : 40,
              height: compact ? 34 : 40,
              decoration: BoxDecoration(
                color: amountColor.withValues(alpha: .10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _eventIcon(event.type, income),
                size: compact ? 17 : 19,
                color: amountColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.description,
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: compact
                        ? Theme.of(context).textTheme.bodyMedium
                        : Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        event.isPlanned
                            ? Icons.event_note_outlined
                            : Icons.schedule_rounded,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${DateFormat('dd/MM').format(event.date)} • ${_typeLabel(event.type)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (limitOnly)
                  Text(
                    'Limite',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: amountColor,
                        ),
                  ),
                Text(
                  hideAmounts
                      ? '●●●●'
                      : limitOnly
                          ? event.amount.abs().money
                          : '${income ? '+' : '-'}${event.amount.abs().money}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: amountColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            if (onTap != null && !compact) ...[
              const SizedBox(width: 3),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
        if (event.warningMessage != null) ...[
          const SizedBox(height: 8),
          Material(
            color: const Color(0xFFE34B42).withValues(alpha: .08),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onWarningTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Color(0xFFE34B42),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        event.warningMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFE34B42),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    if (onWarningTap != null)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text(
                          'Por quê?',
                          style: TextStyle(
                            color: Color(0xFFE34B42),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );

    final Widget padded = Padding(
      padding: compact
          ? const EdgeInsets.symmetric(vertical: 7)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: content,
    );

    if (compact || onTap == null) return padded;
    return InkWell(onTap: onTap, child: padded);
  }

  static IconData _eventIcon(FinancialRadarEventType type, bool income) {
    switch (type) {
      case FinancialRadarEventType.creditCardBill:
      case FinancialRadarEventType.plannedCashAdvanceCharge:
        return Icons.credit_card_outlined;
      case FinancialRadarEventType.plannedCashAdvanceIncome:
        return Icons.add_card_outlined;
      case FinancialRadarEventType.plannedPurchase:
        return Icons.shopping_bag_outlined;
      case FinancialRadarEventType.cardLimitCommitment:
        return Icons.speed_rounded;
      case FinancialRadarEventType.income:
      case FinancialRadarEventType.expense:
        return income ? Icons.south_west_rounded : Icons.north_east_rounded;
    }
  }

  static String _typeLabel(FinancialRadarEventType type) {
    switch (type) {
      case FinancialRadarEventType.income:
        return 'Receita pendente';
      case FinancialRadarEventType.expense:
        return 'Despesa pendente';
      case FinancialRadarEventType.creditCardBill:
        return 'Fatura pendente';
      case FinancialRadarEventType.plannedCashAdvanceIncome:
        return 'Entrada planejada';
      case FinancialRadarEventType.plannedCashAdvanceCharge:
        return 'Cobrança planejada';
      case FinancialRadarEventType.plannedPurchase:
        return 'Despesa planejada';
      case FinancialRadarEventType.cardLimitCommitment:
        return 'Compromisso de limite';
    }
  }
}

class _PrimaryLimitAlertCard extends StatelessWidget {
  final CreditCardSafetyAlertEntity alert;
  final bool hideAmounts;

  const _PrimaryLimitAlertCard({
    required this.alert,
    required this.hideAmounts,
  });

  @override
  Widget build(BuildContext context) {
    const Color danger = Color(0xFFE34B42);
    final date = alert.riskDate;
    final String title =
        'Limite insuficiente no cartão ${alert.cardDescription} para esse compromisso nesse dia.';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: danger, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: danger,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (date != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Data do risco: ${DateFormat('dd/MM/yyyy').format(date)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    hideAmounts
                        ? 'O planejamento continua no Radar para você ajustar valor, data ou cartão.'
                        : 'Disponível antes: ${(alert.availableBeforeRisk ?? 0).money}. '
                            'Compromisso: ${(alert.requiredAmountAtRisk ?? 0).money}. '
                            'Faltariam ${alert.bankShortage.money}.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'O Rallet não remove nem move o planejamento automaticamente.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardSafetyAlertCard extends StatelessWidget {
  final CreditCardSafetyAlertEntity alert;
  final bool hideAmounts;

  const _CardSafetyAlertCard({
    required this.alert,
    required this.hideAmounts,
  });

  @override
  Widget build(BuildContext context) {
    final bool exceeded = alert.level == CreditCardSafetyAlertLevel.exceeded;
    final bool critical = alert.level == CreditCardSafetyAlertLevel.critical;
    final Color color = exceeded || critical
        ? const Color(0xFFE34B42)
        : const Color(0xFFE58A00);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.speed_rounded, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    alert.cardDescription,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(
                  alert.bankLimitExceeded
                      ? 'Falta limite'
                      : '${(alert.safetyRatio * 100).round()}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              alert.bankLimitExceeded
                  ? hideAmounts
                      ? 'Existe uma operação planejada que não cabe no limite projetado deste cartão.'
                      : '${alert.riskDescription ?? 'Operação planejada'} exige ${(alert.requiredAmountAtRisk ?? 0).money}, mas havia ${(alert.availableBeforeRisk ?? 0).money} disponíveis${alert.riskDate == null ? '' : ' em ${DateFormat('dd/MM/yyyy').format(alert.riskDate!)}'}. Faltam ${alert.bankShortage.money}.'
                  : exceeded
                      ? hideAmounts
                          ? 'Seu limite de segurança foi ultrapassado.'
                          : 'Seu limite de segurança foi ultrapassado em ${alert.amountOverSafety.money}.'
                      : critical
                          ? 'Você está muito próximo do limite de segurança definido.'
                          : 'Você está se aproximando do limite de segurança definido.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                Text(
                  hideAmounts
                      ? 'Utilizado agora: ●●●●'
                      : 'Utilizado agora: ${alert.utilized.money}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (alert.plannedAmount > 0)
                  Text(
                    hideAmounts
                        ? 'Pico projetado: ●●●●'
                        : 'Pico projetado: ${alert.projectedUtilized.money}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                Text(
                  hideAmounts
                      ? 'Limite do banco: ●●●●'
                      : 'Limite do banco: ${alert.amountLimit.money}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (alert.safetyLimit < alert.amountLimit - 0.004)
                  Text(
                    hideAmounts
                        ? 'Segurança pessoal: ●●●●'
                        : 'Segurança pessoal: ${alert.safetyLimit.money}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthyCard extends StatelessWidget {
  final FinancialRadarEntity radar;
  final bool hideAmounts;

  const _HealthyCard({
    required this.radar,
    required this.hideAmounts,
  });

  @override
  Widget build(BuildContext context) {
    const Color success = Color(0xFF1AA56B);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_rounded, color: success, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tudo sob controle',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Não identificamos falta de saldo nem de limite contratual para os compromissos cadastrados até ${DateFormat('dd/MM/yyyy').format(radar.horizonEnd)}.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hideAmounts
                        ? 'Menor saldo previsto: ●●●●'
                        : 'A menor projeção é ${radar.minimumProjectedBalance.money} em ${DateFormat('dd/MM').format(radar.minimumBalanceDate)}.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMovements extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              Icons.event_available_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Nenhuma receita, despesa pendente ou fatura aberta foi encontrada para este período.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _RadarError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            const Text(
              'Não foi possível calcular a projeção financeira.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
