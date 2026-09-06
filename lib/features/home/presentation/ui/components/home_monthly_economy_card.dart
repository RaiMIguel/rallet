import 'dart:math' as math;

import 'package:rallet/features/home/domain/entities/home_monthly_economy_entity.dart';
import 'package:rallet/features/home/presentation/view_models/home_view_model.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/presentation/ui/components/calculation_info_button.dart';
import 'package:flutter/material.dart';

class HomeMonthlyEconomyCard extends StatelessWidget {
  final HomeViewModel viewModel;

  const HomeMonthlyEconomyCard({
    super.key,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListenableBuilder(
          listenable: Listenable.merge([
            viewModel,
            viewModel.loadMonthlyEconomy,
          ]),
          builder: (_, __) {
            final previous = viewModel.loadMonthlyEconomy.previous;

            if (viewModel.loadMonthlyEconomy.running && previous?.completed != true) {
              return const SizedBox(
                height: 190,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (viewModel.loadMonthlyEconomy.hasError && previous?.completed != true) {
              return Text(
                viewModel.loadMonthlyEconomy.error.toString().replaceAll('Exception: ', ''),
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
              );
            }

            final HomeMonthlyEconomyEntity economy =
                viewModel.loadMonthlyEconomy.result ??
                    previous?.result ??
                    const HomeMonthlyEconomyEntity(incomes: 0, expenses: 0);

            final double savings = economy.savings;
            final double rate = economy.savingsRate;
            final bool positive = savings > 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Economia mensal',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            positive
                                ? 'Quanto da sua renda ficou livre no mês'
                                : 'Como receitas e despesas estão se equilibrando',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const CalculationInfoButton(
                      title: 'Economia mensal',
                      description:
                          'Este indicador usa o cenário cadastrado para o mês selecionado, inclusive lançamentos pendentes e custos de planejamentos.',
                      items: [
                        'Receitas consideradas: receitas lançadas no mês, recebidas ou ainda pendentes.',
                        'Despesas consideradas: despesas comuns + compras de cartão das faturas que vencem no mês + juros/taxas de crédito via cartão + compras planejadas salvas.',
                        'Em crédito via cartão, o principal recebido não é tratado como receita. Somente juros/taxas entram como custo financeiro.',
                        'Pagamento da fatura não é somado novamente como despesa, evitando dupla contagem.',
                      ],
                      formula: 'Economia = Receitas consideradas − Despesas consideradas',
                      note: 'Valores monetários são arredondados para 2 casas decimais.',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool compact = constraints.maxWidth < 330;
                    final Widget ring = _EconomyRing(
                      percentage: rate.abs().clamp(0, 100).toDouble(),
                      displayPercentage: rate,
                      hideAmounts: viewModel.hideAmounts,
                      positive: positive,
                    );
                    final Widget amounts = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AmountLine(
                          label: 'Receitas',
                          amount: economy.incomes,
                          color: const Color(0xFF2CC985),
                          hideAmounts: viewModel.hideAmounts,
                        ),
                        const SizedBox(height: 10),
                        _AmountLine(
                          label: 'Despesas',
                          amount: economy.expenses,
                          color: const Color(0xFFE34B42),
                          hideAmounts: viewModel.hideAmounts,
                        ),
                      ],
                    );

                    if (compact) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ring,
                          const SizedBox(width: 14),
                          Expanded(child: amounts),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ring,
                        const SizedBox(width: 18),
                        Expanded(child: amounts),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: .34),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          savings >= 0 ? 'Economia do mês' : 'Resultado do mês',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        viewModel.hideAmounts
                            ? '●●●●'
                            : savings > 0
                                ? savings.money
                                : savings == 0
                                    ? 'R\$ 0,00'
                                    : '-${savings.abs().money}',
                        style: textTheme.titleMedium?.copyWith(
                          color: savings > 0
                              ? colorScheme.primary
                              : savings < 0
                                  ? const Color(0xFFE34B42)
                                  : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _messageBackground(context, savings, rate),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 28,
                        width: 28,
                        decoration: BoxDecoration(
                          color: _messageColor(context, savings, rate).withValues(alpha: .11),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _messageIcon(savings, rate),
                          size: 16,
                          color: _messageColor(context, savings, rate),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _message(economy),
                          style: textTheme.bodySmall?.copyWith(height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _message(HomeMonthlyEconomyEntity economy) {
    if (economy.incomes <= 0 && economy.expenses <= 0) {
      return 'Cadastre receitas e despesas para acompanhar sua economia mensal e criar uma referência para os próximos meses.';
    }
    if (economy.incomes <= 0) {
      return 'Ainda não há receitas consideradas neste mês. Organize as entradas previstas e acompanhe os gastos para evitar fechar o período no vermelho.';
    }

    final double rate = economy.savingsRate;
    final int percentage = rate.abs().round();
    if (rate >= 30) {
      return 'Excelente: cerca de $percentage% das receitas ficaram livres. Continue economizando e fortalecendo sua reserva.';
    }
    if (rate >= 20) {
      return 'Muito bom: aproximadamente $percentage% das receitas ficaram livres. Continue nesse ritmo para aumentar sua folga financeira.';
    }
    if (rate >= 10) {
      return 'Bom resultado: você preservou cerca de $percentage% das receitas. Manter essa consistência faz diferença no longo prazo.';
    }
    if (rate > 0) {
      return 'O mês segue positivo, com cerca de $percentage% das receitas preservadas. Pequenos ajustes podem aumentar essa economia.';
    }
    if (rate == 0) {
      return 'Receitas e despesas estão praticamente empatadas. Uma pequena redução de gastos já pode colocar o mês no positivo.';
    }
    return 'As despesas estão cerca de $percentage% acima das receitas consideradas. Priorize gastos variáveis, parcelas e contas do mês para recuperar margem.';
  }

  IconData _messageIcon(double savings, double rate) {
    if (savings > 0 && rate >= 20) return Icons.celebration_outlined;
    if (savings > 0) return Icons.trending_up_outlined;
    if (savings == 0) return Icons.remove_rounded;
    return Icons.priority_high_rounded;
  }

  Color _messageColor(BuildContext context, double savings, double rate) {
    if (savings > 0) return Theme.of(context).colorScheme.primary;
    if (savings == 0) return Theme.of(context).colorScheme.onSurfaceVariant;
    return const Color(0xFFB83C25);
  }

  Color _messageBackground(BuildContext context, double savings, double rate) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (savings > 0) {
      return Theme.of(context).colorScheme.primary.withValues(alpha: dark ? .08 : .05);
    }
    if (savings == 0) {
      return Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .40);
    }
    return const Color(0xFFFFDACC).withValues(alpha: dark ? .09 : .50);
  }
}

class _AmountLine extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool hideAmounts;

  const _AmountLine({
    required this.label,
    required this.amount,
    required this.color,
    required this.hideAmounts,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          hideAmounts ? '●●●●' : amount.money,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _EconomyRing extends StatelessWidget {
  final double percentage;
  final double displayPercentage;
  final bool hideAmounts;
  final bool positive;

  const _EconomyRing({
    required this.percentage,
    required this.displayPercentage,
    required this.hideAmounts,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color = positive
        ? scheme.primary
        : displayPercentage < 0
            ? const Color(0xFFE34B42)
            : scheme.onSurfaceVariant;
    final Color background = scheme.outlineVariant.withValues(alpha: .42);

    return SizedBox(
      height: 124,
      width: 124,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(124),
            painter: _RingPainter(
              percentage: percentage,
              color: color,
              background: background,
            ),
          ),
          Container(
            height: 86,
            width: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainer.withValues(alpha: .72),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: .24),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  hideAmounts ? '●●' : '${displayPercentage.round()}%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.4,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  'economia',
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

class _RingPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final Color background;

  _RingPainter({
    required this.percentage,
    required this.color,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2 - 10;

    final Paint base = Paint()
      ..color = background
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final Paint glow = Paint()
      ..color = color.withValues(alpha: .16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final Paint progress = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    const double start = -math.pi / 2;
    final double sweep = math.pi * 2 * (percentage / 100);

    canvas.drawCircle(center, radius, base);
    if (percentage > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        glow,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        progress,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.percentage != percentage ||
      oldDelegate.color != color ||
      oldDelegate.background != background;
}
