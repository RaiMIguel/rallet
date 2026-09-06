import 'dart:math';

import 'package:collection/collection.dart';
import 'package:rallet/features/home/domain/entities/home_balance_evolution_entity.dart';
import 'package:rallet/features/home/presentation/view_models/home_view_model.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/presentation/mixins/theme_context.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class HomeExpenseEvolutionChart extends StatefulWidget {
  final HomeViewModel viewModel;

  const HomeExpenseEvolutionChart({
    super.key,
    required this.viewModel,
  });

  @override
  State<HomeExpenseEvolutionChart> createState() =>
      _HomeExpenseEvolutionChartState();
}

class _HomeExpenseEvolutionChartState
    extends State<HomeExpenseEvolutionChart>
    with ThemeContext {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel.loadBalanceEvolution,
      builder: (_, __) {
        final previous = widget.viewModel.loadBalanceEvolution.previous;

        if (widget.viewModel.loadBalanceEvolution.hasError &&
            previous?.completed != true) {
          return Text(
            'Não foi possível carregar a evolução do saldo.',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
          );
        }

        if (widget.viewModel.loadBalanceEvolution.running &&
            previous?.completed != true) {
          return const SizedBox(
            height: 165,
            child: Center(
              child: SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }

        final List<HomeBalanceEvolutionEntity> values =
            widget.viewModel.loadBalanceEvolution.result ??
                previous?.result ??
                [];

        if (values.isEmpty) return const SizedBox.shrink();

        final List<HomeBalanceEvolutionEntity> actual =
            values.where((item) => !item.projected).toList();
        final List<HomeBalanceEvolutionEntity> projected =
            values.where((item) => item.projected).toList();

        // A evolução usa o mesmo traço sólido em meses reais e futuros.
        // A diferença entre real e previsto continua indicada pelo contexto
        // da tela, sem quebrar visualmente a curva com linha pontilhada.

        // A linha prevista começa exatamente no último ponto real para a
        // transição ficar visualmente contínua.
        if (projected.isNotEmpty && actual.isNotEmpty) {
          projected.insert(0, actual.last);
        }

        final double minBalance = values.map((item) => item.balance).min;
        final double maxBalance = values.map((item) => item.balance).max;
        final double spread = max((maxBalance - minBalance).abs(), 1.0);
        final double verticalPadding = spread * 0.18;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Evolução do saldo',
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (projected.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 2,
                        color: colorScheme.primary.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Previsto',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minX: 1,
                  maxX: values.last.date.day.toDouble(),
                  minY: minBalance - verticalPadding,
                  maxY: maxBalance + verticalPadding,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final int day = value.round();
                          final int lastDay = values.last.date.day;
                          final bool show = day == 1 ||
                              day == lastDay ||
                              day == 5 ||
                              day == 10 ||
                              day == 15 ||
                              day == 20 ||
                              day == 25;

                          if (!show) return const SizedBox.shrink();

                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 6,
                            child: Text(
                              day.toString().padLeft(2, '0'),
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    if (actual.isNotEmpty)
                      LineChartBarData(
                        spots: actual
                            .map(
                              (item) => FlSpot(
                                item.date.day.toDouble(),
                                item.balance,
                              ),
                            )
                            .toList(),
                        isCurved: true,
                        curveSmoothness: 0.18,
                        barWidth: 2.5,
                        color: colorScheme.primary,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(
                            radius: _showDot(spot.x.toInt(), values.last.date.day)
                                ? 2.8
                                : 0,
                            color: colorScheme.primary,
                            strokeWidth: 0,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: colorScheme.primary.withValues(alpha: 0.06),
                        ),
                      ),
                    if (projected.isNotEmpty)
                      LineChartBarData(
                        spots: projected
                            .map(
                              (item) => FlSpot(
                                item.date.day.toDouble(),
                                item.balance,
                              ),
                            )
                            .toList(),
                        isCurved: true,
                        curveSmoothness: 0.18,
                        barWidth: 2.5,
                        color: colorScheme.primary,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(
                            radius: _showDot(spot.x.toInt(), values.last.date.day)
                                ? 2.6
                                : 0,
                            color: colorScheme.primary,
                            strokeWidth: 0,
                          ),
                        ),
                        belowBarData: BarAreaData(show: false),
                      ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => colorScheme.surfaceContainerHighest,
                      getTooltipItems: (spots) {
                        return spots.map((spot) {
                          final int day = spot.x.round().clamp(1, values.last.date.day).toInt();
                          final HomeBalanceEvolutionEntity item =
                              values.firstWhere(
                            (value) => value.date.day == day,
                            orElse: () => values.last,
                          );

                          return LineTooltipItem(
                            '${day.toString().padLeft(2, '0')}/${item.date.month.toString().padLeft(2, '0')}\n',
                            textTheme.labelSmall!,
                            children: [
                              TextSpan(
                                text: widget.viewModel.hideAmounts
                                    ? '●●●●'
                                    : spot.y.money,
                                style: textTheme.labelLarge,
                              ),
                            ],
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _showDot(int day, int lastDay) {
    return day == 1 ||
        day == lastDay ||
        day == 5 ||
        day == 10 ||
        day == 15 ||
        day == 20 ||
        day == 25;
  }
}
