import 'package:carousel_slider/carousel_slider.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/features/credit_card/domain/enums/bill_status_enum.dart';
import 'package:rallet/features/credit_card/presentation/ui/components/credit_card_simple_widget.dart';
import 'package:rallet/features/credit_card/presentation/ui/credit_card_bill_details_page.dart';
import 'package:rallet/features/credit_card/presentation/ui/credit_card_form_page.dart';
import 'package:rallet/features/credit_card/presentation/ui/credit_cards_details_page.dart';
import 'package:rallet/features/home/domain/entities/home_credit_card_month_entity.dart';
import 'package:rallet/features/home/presentation/view_models/home_view_model.dart';
import 'package:rallet/shared/classes/form_result_navigation.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/presentation/mixins/theme_context.dart';
import 'package:rallet/shared/presentation/ui/app_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class HomeCardBillCreditCard extends StatefulWidget {
  final HomeViewModel viewModel;

  const HomeCardBillCreditCard({super.key, required this.viewModel});

  @override
  State<HomeCardBillCreditCard> createState() => _HomeCardBillCreditCardState();
}

class _HomeCardBillCreditCardState extends State<HomeCardBillCreditCard>
    with ThemeContext {
  final CarouselController carouselController = CarouselController();
  int itemCarrouselCurrent = 0;

  BorderRadius get borderRadius => BorderRadius.circular(18);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.viewModel,
        widget.viewModel.loadSelectedMonthCreditCards,
      ]),
      builder: (_, __) {
        final command = widget.viewModel.loadSelectedMonthCreditCards;
        final prev = command.previous;

        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 200),
          child: Card(
            color: colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
            child: Builder(
              builder: (_) {
                if (command.hasError) {
                  return Center(
                    child: Text(
                      command.error
                          .toString()
                          .replaceAll('Exception: ', ''),
                      style: textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.error),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 3,
                    ),
                  );
                }

                if (command.running && prev?.completed != true) {
                  return const Center(
                    child: SizedBox(
                      height: 30,
                      width: 30,
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final items = command.result ?? prev?.result ?? const [];

                if (items.isEmpty) {
                  return Center(
                    child: ElevatedButton.icon(
                      onPressed: goCreditCardForm,
                      label: Text(strings.addCreditCard),
                      icon: const Icon(Icons.add),
                    ),
                  );
                }

                if (itemCarrouselCurrent >= items.length) {
                  itemCarrouselCurrent = 0;
                }

                return InkWell(
                  borderRadius: borderRadius,
                  onTap: () => _openItem(items[itemCarrouselCurrent]),
                  child: Column(
                    children: [
                      CarouselSlider(
                        items: List.generate(
                          items.length,
                          (index) => _buildCard(items[index]),
                        ),
                        options: CarouselOptions(
                          height: 205,
                          padEnds: items.length == 1,
                          viewportFraction: 1,
                          enableInfiniteScroll: false,
                          onPageChanged: (index, _) =>
                              setState(() => itemCarrouselCurrent = index),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          children: List.generate(
                            items.length,
                            (index) => Container(
                              width: itemCarrouselCurrent == index ? 10 : 6,
                              height: itemCarrouselCurrent == index ? 10 : 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.primary.withValues(
                                  alpha: itemCarrouselCurrent == index ? 1 : .4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(HomeCreditCardMonthEntity item) {
    final bool future = widget.viewModel.isSelectedMonthFuture;
    final bool past = widget.viewModel.isSelectedMonthPast;
    final String month = DateFormat('MMMM', 'pt_BR')
        .format(widget.viewModel.selectedMonth)
        .toLowerCase();
    final String title = future
        ? 'Fatura prevista de $month'
        : past
            ? 'Fatura de $month'
            : 'Fatura atual';
    final double mainAmount = future ? item.forecastAmount : item.billAmount;
    final BillStatusEnum? status = item.bill?.status;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CreditCardSimpleWidget(creditCard: item.creditCard),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!future && status != null) ...[
                Container(
                  width: 8,
                  height: 18,
                  decoration: BoxDecoration(
                    color: status.color,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                const SizedBox(width: 7),
                Text(status.description, style: textTheme.labelMedium),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.viewModel.hideAmounts ? '●●●●' : mainAmount.money,
            style: textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
          if (!future && !past && item.plannedAmount > 0) ...[
            const SizedBox(height: 2),
            Text(
              widget.viewModel.hideAmounts
                  ? 'Prevista com planejamentos: ●●●●'
                  : 'Prevista com planejamentos: ${item.forecastAmount.money}',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (future && item.plannedAmount > 0)
            Text(
              widget.viewModel.hideAmounts
                  ? 'Inclui ●●●● em planejamentos'
                  : 'Inclui ${item.plannedAmount.money} em planejamentos',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            '${future || past ? 'Limite disponível hoje' : strings.availableLimit} ${widget.viewModel.hideAmounts ? '●●●●' : (item.creditCard.amountLimit - item.creditCard.amountLimitUtilized).money}',
            style: textTheme.labelMedium,
          ),
          Text(
            '${strings.limit} ${widget.viewModel.hideAmounts ? '●●●●' : item.creditCard.amountLimit.money}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openItem(HomeCreditCardMonthEntity item) async {
    if (item.bill != null) {
      await context.pushNamed(
        CreditCardBillDetailsPage.route,
        extra: CreditCardBillDetailsArgsPage(
          bill: item.bill!,
          creditCard: item.creditCard,
        ),
      );
      await widget.viewModel.load();
      return;
    }

    await context.pushNamed(
      CreditCardsDetailsPage.route,
      extra: item.creditCard.id,
    );
    await widget.viewModel.load();
  }

  Future<void> goCreditCardForm() async {
    final FormResultNavigation<CreditCardEntity>? result =
        await context.pushNamedWithAd(CreditCardFormPage.route);

    if (result?.isSave == true && result?.value != null) {
      await widget.viewModel.load();
    }
  }
}
