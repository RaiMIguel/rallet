import 'package:rallet/features/reports/domain/entities/reports_dashboard_entity.dart';
import 'package:rallet/features/transactions/presentation/ui/components/details/expense_details_sheet.dart';
import 'package:rallet/features/transactions/presentation/ui/components/details/income_details_sheet.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/presentation/ui/components/calculation_info_button.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PlannedVsRealizedReportPage extends StatelessWidget {
  final ReportsDashboardEntity data;

  const PlannedVsRealizedReportPage({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    const Color positive = Color(0xFF1AA56B);
    const Color negative = Color(0xFFE34B42);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool netPositive = data.netVariance >= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planejado x realizado'),
        actions: const [
          CalculationInfoButton(
            title: 'O que entra neste relatório?',
            description:
                'Somente alterações em que você confirmou que o valor anterior era o esperado e o valor novo foi o que realmente aconteceu.',
            items: [
              '“Só corrigir valor” nunca gera economia ou desvio.',
              '“Registrar diferença real” grava o esperado e o realizado para este relatório.',
              'Despesa menor que o esperado é economia; maior é gasto acima do esperado.',
              'Receita maior que o esperado é positiva; menor é abaixo do esperado.',
            ],
            formula: 'Desvio líquido = resultados positivos − resultados negativos',
          ),
          SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Text(
            DateFormat('MMMM yyyy', 'pt_BR').format(data.month),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 14,
                children: [
                  _Metric(
                    label: 'Economias/ganhos',
                    value: '+ ${data.positiveVariance.money}',
                    color: positive,
                  ),
                  _Metric(
                    label: 'Desvios negativos',
                    value: '- ${data.negativeVariance.money}',
                    color: negative,
                    alignEnd: true,
                  ),
                  _Metric(
                    label: 'Saldo dos desvios',
                    value:
                        '${netPositive ? '+' : '-'} ${data.netVariance.abs().money}',
                    color: netPositive ? positive : negative,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (data.varianceItems.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.fact_check_outlined,
                      size: 38,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Nenhuma diferença registrada neste mês',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Este relatório só recebe um lançamento quando você altera o valor e escolhe “Registrar diferença real”. Correções de cadastro ficam fora daqui.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...data.varianceItems.map((item) {
              final Color color = item.positive ? positive : negative;
              final String message;
              if (item.expense) {
                message = item.positive
                    ? 'Economizou ${item.difference.abs().money}'
                    : '${item.difference.abs().money} acima do esperado';
              } else {
                message = item.positive
                    ? '${item.difference.abs().money} acima do esperado'
                    : '${item.difference.abs().money} abaixo do esperado';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () => item.expense
                      ? ExpenseDetailsSheet.show(context: context, id: item.id)
                      : IncomeDetailsSheet.show(context: context, id: item.id),
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: .10),
                    child: Icon(
                      item.positive
                          ? Icons.trending_up_rounded
                          : Icons.warning_amber_rounded,
                      color: color,
                    ),
                  ),
                  title: Text(item.description),
                  subtitle: Text(
                    '${DateFormat('dd/MM/yyyy').format(item.date)}\n'
                    'Esperado ${item.expectedAmount.money} • realizado ${item.realizedAmount.money}\nToque para abrir a origem',
                  ),
                  isThreeLine: true,
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 115),
                    child: Text(
                      message,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  const _Metric({
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
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}
