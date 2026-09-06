import 'package:rallet/features/category/domain/enums/category_type_enum.dart';
import 'package:rallet/features/transactions/presentation/view_models/transactions_list_view_model.dart';
import 'package:rallet/l10n/generated/app_localizations.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:flutter/material.dart';

class TotalsTransactions extends StatelessWidget {
  final TransactionsListViewModel viewModel;

  const TotalsTransactions({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final CategoryTypeEnum? type = viewModel.filterType.firstOrNull;
    final bool forecast = viewModel.selectedPeriodUsesForecast;

    if (type == CategoryTypeEnum.expense) {
      return Row(
        children: [
          Expanded(
            child: _MetricCard(
              label: AppLocalizations.of(context)!.monthlyExpense,
              value: viewModel.monthlyExpenseForSummary,
              icon: Icons.trending_down_rounded,
              contextLabel: forecast ? 'Previsto' : 'Realizado',
              tone: _MetricTone.expense,
              onTap: () => _showMonthlyExpenseInfo(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MetricCard(
              label: 'A pagar',
              value: viewModel.monthlyPayableForSummary,
              icon: Icons.payments_outlined,
              contextLabel: 'Pendente',
              tone: _MetricTone.expense,
              onTap: () => _showPayableInfo(context),
            ),
          ),
        ],
      );
    }

    if (type == CategoryTypeEnum.income) {
      return Row(
        children: [
          Expanded(
            child: _MetricCard(
              label: AppLocalizations.of(context)!.monthlyIncome,
              value: viewModel.monthlyIncomeForSummary,
              icon: Icons.trending_up_rounded,
              contextLabel: forecast ? 'Previsto' : 'Realizado',
              tone: _MetricTone.income,
              onTap: () => _showMonthlyIncomeInfo(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MetricCard(
              label: 'A receber',
              value: viewModel.monthlyReceivableForSummary,
              icon: Icons.account_balance_wallet_outlined,
              contextLabel: 'Pendente',
              tone: _MetricTone.income,
              onTap: () => _showReceivableInfo(context),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: _periodBalanceLabel,
            value: viewModel.periodClosingBalance,
            icon: Icons.account_balance_wallet_outlined,
            contextLabel:
                viewModel.selectedPeriodIsPast ? 'Realizado' : 'Previsto',
            onTap: () => _showPeriodBalanceInfo(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            label: AppLocalizations.of(context)!.monthlyBalance,
            value: viewModel.monthlyBalanceForSummary,
            icon: Icons.bar_chart_rounded,
            contextLabel: forecast ? 'Previsto' : 'Realizado',
            onTap: () => _showMonthlyBalanceInfo(context),
          ),
        ),
      ],
    );
  }

  String get _periodBalanceLabel => viewModel.selectedPeriodIsPast
      ? 'Saldo no fim do mês'
      : 'Saldo previsto no fim do mês';

  Future<void> _showMonthlyIncomeInfo(BuildContext context) async {
    final bool forecast = viewModel.selectedPeriodUsesForecast;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MetricExplanationSheet(
        title: 'Receitas do mês',
        value: viewModel.monthlyIncomeForSummary,
        statusLabel: forecast ? 'Previsto' : 'Realizado',
        description: forecast
            ? 'É a receita econômica conhecida para o mês selecionado, incluindo o que já entrou e o que ainda está previsto.'
            : 'É a receita econômica que foi realmente recebida no mês selecionado.',
        rows: [
          _ExplanationRow(
            label: forecast ? 'Receitas conhecidas do mês' : 'Receitas realizadas',
            value: viewModel.monthlyIncomeForSummary,
            positive: true,
          ),
        ],
        note: 'Crédito via cartão não entra como receita. Se houver um crédito planejado para cair na conta, ele aparece em A receber porque afeta o caixa, mas continua fora deste total.',
      ),
    );
  }

  Future<void> _showReceivableInfo(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MetricExplanationSheet(
        title: 'A receber',
        value: viewModel.monthlyReceivableForSummary,
        statusLabel: 'Pendente',
        description: 'Mostra o que ainda deve entrar no caixa no mês selecionado.',
        rows: [
          _ExplanationRow(
            label: 'Receitas ainda não recebidas',
            value: viewModel.monthlyPendingIncomeReceivable,
            positive: true,
          ),
          _ExplanationRow(
            label: 'Créditos planejados a entrar',
            value: viewModel.monthlyPlannedCreditReceivable,
            positive: true,
          ),
        ],
        note: 'A receber é uma visão de caixa. Por isso um crédito planejado pode aparecer aqui sem ser tratado como renda pelo Rallet.',
      ),
    );
  }

  Future<void> _showMonthlyExpenseInfo(BuildContext context) async {
    final bool forecast = viewModel.selectedPeriodUsesForecast;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MetricExplanationSheet(
        title: 'Despesas do mês',
        value: viewModel.monthlyExpenseForSummary,
        statusLabel: forecast ? 'Previsto' : 'Realizado',
        description: forecast
            ? 'É o custo econômico conhecido para o mês selecionado, seguindo as mesmas regras usadas pelos relatórios do Rallet.'
            : 'É o custo econômico que foi realmente realizado no mês selecionado.',
        rows: forecast
            ? [
                _ExplanationRow(
                  label: 'Despesas fora do cartão',
                  value: -viewModel.monthlyRegisteredExpensesForecast,
                ),
                _ExplanationRow(
                  label: 'Compras no cartão',
                  value: -viewModel.monthlyCreditCardPurchasesForecast,
                ),
                _ExplanationRow(
                  label: 'Custos financeiros',
                  value: -(viewModel.monthlyRealizedFinancialCostsForecast +
                      viewModel.monthlyPlannedFinancialCostsForecast),
                ),
                _ExplanationRow(
                  label: 'Despesas planejadas',
                  value: -viewModel.monthlyPlannedPurchasesForecast,
                ),
              ]
            : [
                _ExplanationRow(
                  label: 'Despesas realizadas',
                  value: viewModel.monthlyExpenseRealized,
                ),
              ],
        note: 'Despesas e A pagar respondem perguntas diferentes. O pagamento da fatura e o principal de crédito não viram uma nova despesa econômica.',
      ),
    );
  }

  Future<void> _showPayableInfo(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MetricExplanationSheet(
        title: 'A pagar',
        value: viewModel.monthlyPayableForSummary,
        statusLabel: 'Pendente',
        description: 'Mostra as obrigações que ainda exigem saída de caixa no mês selecionado.',
        rows: [
          _ExplanationRow(
            label: 'Despesas pendentes',
            value: viewModel.monthlyPendingExpensesPayable,
          ),
          _ExplanationRow(
            label: 'Faturas em aberto',
            value: viewModel.monthlyOpenBillsPayable,
          ),
          _ExplanationRow(
            label: 'Cobranças de créditos planejados',
            value: viewModel.monthlyPlannedCreditChargesPayable,
          ),
          _ExplanationRow(
            label: 'Despesas planejadas',
            value: viewModel.monthlyPlannedExpensesPayable,
          ),
        ],
        note: 'A pagar é uma visão de caixa. Pode ser maior que Despesas porque inclui faturas, principal de crédito e outros compromissos sem transformá-los em nova despesa econômica.',
      ),
    );
  }

  Future<void> _showPeriodBalanceInfo(BuildContext context) async {
    final bool past = viewModel.selectedPeriodIsPast;
    final bool current = viewModel.startDate.year == DateTime.now().year &&
        viewModel.startDate.month == DateTime.now().month;

    final List<_ExplanationRow> rows = past
        ? [
            _ExplanationRow(
              label: 'Saldo no início do mês',
              value: viewModel.periodBalanceBase,
              positive: viewModel.periodBalanceBase >= 0,
            ),
            _ExplanationRow(
              label: 'Saldo real no encerramento',
              value: viewModel.periodClosingBalance,
              positive: viewModel.periodClosingBalance >= 0,
            ),
          ]
        : [
            _ExplanationRow(
              label: current
                  ? 'Saldo atual das contas'
                  : 'Saldo previsto no início do mês',
              value: viewModel.periodBalanceBase,
              positive: viewModel.periodBalanceBase >= 0,
            ),
            _ExplanationRow(
              label: 'Entradas ainda previstas',
              value: viewModel.periodPendingIncome,
              positive: true,
            ),
            _ExplanationRow(
              label: 'Saídas ainda previstas',
              value: viewModel.periodPendingExpense,
            ),
            _ExplanationRow(
              label: 'Faturas ainda previstas',
              value: -viewModel.periodBillsAmount,
            ),
          ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _MetricExplanationSheet(
        title: _periodBalanceLabel,
        value: viewModel.periodClosingBalance,
        statusLabel: past ? 'Realizado' : 'Previsto',
        description: past
            ? 'É quanto havia nas contas incluídas no saldo total ao encerrar o mês selecionado.'
            : 'É a projeção de quanto deve restar nas contas incluídas no saldo total ao final do mês selecionado, usando a mesma lógica temporal da Home.',
        rows: rows,
        note: past
            ? 'Contas marcadas para não participar do saldo total ficam fora deste valor. Transferências entre contas incluídas não criam receita nem despesa.'
            : 'A projeção parte do saldo real atual (ou do saldo projetado trazido dos meses anteriores) e aplica entradas, saídas e faturas ainda conhecidas. Crédito recebido pode alterar o caixa sem virar receita econômica.',
      ),
    );
  }

  Future<void> _showMonthlyBalanceInfo(BuildContext context) async {
    final bool forecast = viewModel.selectedPeriodUsesForecast;
    final String status = forecast ? 'Previsto' : 'Realizado';

    final List<_ExplanationRow> rows = forecast
        ? [
            _ExplanationRow(
              label: 'Receitas previstas',
              value: viewModel.monthlyIncomeForecast,
              positive: true,
            ),
            _ExplanationRow(
              label: 'Despesas fora do cartão',
              value: -viewModel.monthlyRegisteredExpensesForecast,
            ),
            _ExplanationRow(
              label: 'Compras no cartão',
              value: -viewModel.monthlyCreditCardPurchasesForecast,
            ),
            _ExplanationRow(
              label: 'Custos financeiros já vinculados',
              value: -viewModel.monthlyRealizedFinancialCostsForecast,
            ),
            _ExplanationRow(
              label: 'Custos financeiros planejados',
              value: -viewModel.monthlyPlannedFinancialCostsForecast,
            ),
            _ExplanationRow(
              label: 'Despesas planejadas',
              value: -viewModel.monthlyPlannedPurchasesForecast,
            ),
          ]
        : [
            _ExplanationRow(
              label: 'Receitas realizadas',
              value: viewModel.monthlyIncomeRealized,
              positive: true,
            ),
            _ExplanationRow(
              label: 'Despesas realizadas',
              value: viewModel.monthlyExpenseRealized,
            ),
          ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _MetricExplanationSheet(
        title: 'Balanço mensal',
        value: viewModel.monthlyBalanceForSummary,
        statusLabel: status,
        description: forecast
            ? 'Mostra o resultado esperado do mês selecionado com o que já aconteceu e com os compromissos conhecidos pelo Rallet.'
            : 'Mostra o resultado econômico realizado no mês selecionado: receitas realizadas menos despesas realizadas.',
        rows: rows,
        note: forecast
            ? 'O principal de crédito via cartão não entra como receita. O pagamento da fatura não é contado novamente como despesa: compras, custos financeiros e planejamentos são considerados na competência correta. Transferências permanecem neutras.'
            : 'Pagamento de fatura e transferências não criam uma nova despesa econômica. O Rallet evita contar a mesma movimentação duas vezes.',
      ),
    );
  }
}

enum _MetricTone { automatic, income, expense }

class _MetricCard extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final String? contextLabel;
  final VoidCallback? onTap;
  final _MetricTone tone;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.contextLabel,
    this.onTap,
    this.tone = _MetricTone.automatic,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color valueColor = switch (tone) {
      _MetricTone.income => value == 0
          ? scheme.onSurface
          : const Color(0xFF2CC985),
      _MetricTone.expense => value == 0
          ? scheme.onSurface
          : const Color(0xFFFF5C68),
      _MetricTone.automatic => value < 0
          ? const Color(0xFFFF5C68)
          : value > 0
              ? const Color(0xFF2CC985)
              : scheme.onSurface,
    };

    final Widget content = Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
          if (contextLabel != null) ...[
            const SizedBox(height: 5),
            Text(
              contextLabel!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value.money,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _MetricExplanationSheet extends StatelessWidget {
  final String title;
  final double value;
  final String statusLabel;
  final String description;
  final List<_ExplanationRow> rows;
  final String note;

  const _MetricExplanationSheet({
    required this.title,
    required this.value,
    required this.statusLabel,
    required this.description,
    required this.rows,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color valueColor = value < 0
        ? const Color(0xFFFF5C68)
        : value > 0
            ? const Color(0xFF2CC985)
            : scheme.onSurface;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value.money,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .45),
                ),
              ),
              child: Column(
                children: [
                  for (int index = 0; index < rows.length; index++) ...[
                    rows[index],
                    if (index != rows.length - 1)
                      Divider(
                        height: 20,
                        color: scheme.outlineVariant.withValues(alpha: .45),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    note,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
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
}

class _ExplanationRow extends StatelessWidget {
  final String label;
  final double? value;
  final bool positive;

  const _ExplanationRow({
    required this.label,
    this.value,
    this.positive = false,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double? amount = value;
    final Color amountColor = amount == null
        ? scheme.onSurfaceVariant
        : amount < 0
            ? const Color(0xFFFF5C68)
            : (amount > 0 || positive)
                ? const Color(0xFF2CC985)
                : scheme.onSurface;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            amount?.money ?? '-',
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
