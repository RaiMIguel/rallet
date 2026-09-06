import 'package:rallet/features/home/domain/entities/home_monthly_economy_entity.dart';
import 'package:rallet/features/home/presentation/view_models/home_view_model.dart';
import 'package:rallet/features/reports/presentation/ui/financial_result_explanation_page.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeEconomyExplanationNotice extends StatelessWidget {
  final HomeViewModel viewModel;

  const HomeEconomyExplanationNotice({
    super.key,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        viewModel,
        viewModel.loadMonthlyEconomy,
        viewModel.loadTransactionsUnpaidUnreceived,
      ]),
      builder: (_, __) {
        final economyPrevious = viewModel.loadMonthlyEconomy.previous;
        final pendingPrevious = viewModel.loadTransactionsUnpaidUnreceived.previous;

        final HomeMonthlyEconomyEntity? economy =
            viewModel.loadMonthlyEconomy.result ?? economyPrevious?.result;
        final pending = viewModel.loadTransactionsUnpaidUnreceived.result ??
            pendingPrevious?.result;

        if (economy == null || pending == null) {
          return const SizedBox.shrink();
        }

        final double receivable = pending.amountsIncome.abs().toRound(2);
        final double payable = pending.amountsExpense.abs().toRound(2);
        final double savings = economy.savings.toRound(2);
        final double pendingBalance = (receivable - payable).toRound(2);
        final double indicatorDifference =
            (savings - pendingBalance).abs().toRound(2);
        final bool legacyCase =
            payable > receivable + 0.01 && savings > 0.01;

        final bool shouldShow = indicatorDifference > 0.01;
        if (!shouldShow) return const SizedBox.shrink();

        final String explanationText;
        if (viewModel.hideAmounts) {
          explanationText = legacyCase
              ? 'Ainda há mais dinheiro a pagar do que a receber, mas a Economia mensal ficou positiva. Abra o diagnóstico para ver os lançamentos reais que causaram essa diferença.'
              : 'A diferença entre A receber e A pagar não é igual à Economia mensal. Abra o diagnóstico para ver os lançamentos reais que causaram essa diferença.';
        } else if (legacyCase) {
          explanationText =
              'A pagar está em ${payable.money} e A receber em ${receivable.money}, mas a Economia mensal ficou positiva em ${savings.money}. Abra o diagnóstico para ver os lançamentos reais que causaram essa diferença.';
        } else {
          explanationText =
              'A receber está em ${receivable.money} e A pagar em ${payable.money}. A diferença entre eles é ${pendingBalance.money}, enquanto a Economia mensal está em ${savings.money}. Abra o diagnóstico para ver os lançamentos reais que causaram essa diferença.';
        }

        final ColorScheme scheme = Theme.of(context).colorScheme;
        final TextTheme textTheme = Theme.of(context).textTheme;

        return Container(
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.primary.withValues(alpha: .20),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.goNamed(
              FinancialResultExplanationPage.route,
              extra: viewModel.selectedMonth,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.calculate_outlined,
                      size: 19,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Esse resultado pode parecer estranho',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          explanationText,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Ver diagnóstico com os lançamentos reais',
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
