import 'package:rallet/di/dependency_injection.dart';
import 'package:rallet/features/first_steps/presentation/notifiers/first_steps_notifier.dart';
import 'package:rallet/features/first_steps/presentation/guided_tour.dart';
import 'package:rallet/features/home/presentation/ui/components/home_alert_first_steps.dart';
import 'package:rallet/features/home/presentation/ui/components/home_card_accounts_balance.dart';
import 'package:rallet/features/home/presentation/ui/components/home_card_bill_credit_card.dart';
import 'package:rallet/features/home/presentation/ui/components/home_card_transaction_unpaid_unreceived.dart';
import 'package:rallet/features/home/presentation/ui/components/home_economy_explanation_notice.dart';
import 'package:rallet/features/home/presentation/ui/components/home_financial_alerts_card.dart';
import 'package:rallet/features/home/presentation/ui/components/home_monthly_economy_card.dart';
import 'package:rallet/features/home/presentation/view_models/home_view_model.dart';
import 'package:rallet/features/transactions/presentation/ui/components/fab_transactions.dart';
import 'package:rallet/shared/presentation/mixins/theme_context.dart';
import 'package:rallet/shared/presentation/notifiers/event_notifier.dart';
import 'package:rallet/shared/presentation/ui/components/navigation/nav_drawer.dart';
import 'package:rallet/shared/presentation/ui/components/card_visibility_settings_sheet.dart';
import 'package:rallet/shared/presentation/ui/components/spacing.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  static const String route = 'home';

  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with ThemeContext {
  final HomeViewModel viewModel = DI.get<HomeViewModel>();

  final EventNotifier eventNotifier = DI.get<EventNotifier>();
  final FirstStepsNotifier firstStepsNotifier = DI.get<FirstStepsNotifier>();

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController scrollController = ScrollController();

  int homeResetVersion = 0;

  static const String _hiddenCardsKey = 'ui.home.hidden_cards.v1';
  static const String _cardOrderKey = 'ui.home.card_order.v1';
  static const Map<String, String> _customizableCards = {
    'pending': 'Pendentes a receber e a pagar',
    'creditCard': 'Fatura do cartão',
    'economy': 'Economia do mês',
    'radar': 'Radar financeiro',
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
    eventNotifier.addListener(_onEvent);
  }

  void _onEvent() {
    if (eventNotifier.value == EventType.home) {
      _resetHome();
      return;
    }

    if ([
      EventType.income,
      EventType.expense,
      EventType.transfer,
      EventType.creditCard,
      EventType.account,
      EventType.cashAdvance,
      EventType.purchasePlan,
    ].contains(eventNotifier.value)) {
      viewModel.load();
    }
  }

  Future<void> _resetHome() async {
    if (mounted) {
      setState(() => homeResetVersion++);
    }

    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) scrollController.jumpTo(0);
      });
    }

    await viewModel.resetToCurrentMonth();
  }

  @override
  void dispose() {
    eventNotifier.removeListener(_onEvent);
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        leading: GuidedTourTarget(
          id: GuidedTourTargets.homeMenu,
          child: IconButton(
            tooltip: strings.menu,
            icon: const Icon(Icons.menu),
            onPressed: () => scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        title: Text(strings.home),
        centerTitle: true,
        actions: [
          GuidedTourTarget(
            id: GuidedTourTargets.homeCustomize,
            child: IconButton(
              tooltip: 'Personalizar Home',
              icon: const Icon(Icons.tune_rounded),
              onPressed: _openCustomization,
            ),
          ),
          ListenableBuilder(
            listenable: viewModel,
            builder: (_, __) {
              if (viewModel.hideAmounts) {
                return IconButton(
                  icon: const Icon(Icons.visibility_off_outlined),
                  onPressed: viewModel.toggleHideAmounts,
                );
              }

              return IconButton(
                icon: const Icon(Icons.visibility_outlined),
                onPressed: viewModel.toggleHideAmounts,
              );
            },
          ),
        ],
      ),
      drawer: const NavDrawer(),
      floatingActionButton: const FabTransactions(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: Column(
            children: [
              HomeAlertFirstSteps(notifier: firstStepsNotifier),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacing.y(),
                      GuidedTourTarget(
                        id: GuidedTourTargets.homeBalance,
                        child: HomeCardAccountsBalance(viewModel: viewModel),
                      ),
                      const Spacing.y(),
                      ..._buildCustomizableCards(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
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

  List<Widget> _buildCustomizableCards() {
    final List<Widget> cards = <Widget>[];

    for (final String id in cardOrder) {
      if (!_isCardVisible(id)) continue;

      switch (id) {
        case 'pending':
          cards.add(
            ListenableBuilder(
              key: const ValueKey('home-card-pending'),
              listenable: viewModel.loadTransactionsUnpaidUnreceived,
              builder: (_, __) {
                if (viewModel.loadTransactionsUnpaidUnreceived.running) {
                  if (viewModel.loadTransactionsUnpaidUnreceived.previous?.error == null &&
                      (viewModel.loadTransactionsUnpaidUnreceived.previous?.result?.amountsIncome ?? 0) == 0 &&
                      (viewModel.loadTransactionsUnpaidUnreceived.previous?.result?.amountsExpense ?? 0) == 0) {
                    return const SizedBox.shrink();
                  }
                } else if (viewModel.loadTransactionsUnpaidUnreceived.completed &&
                    (viewModel.loadTransactionsUnpaidUnreceived.result?.amountsIncome ?? 0) == 0 &&
                    (viewModel.loadTransactionsUnpaidUnreceived.result?.amountsExpense ?? 0) == 0) {
                  return const SizedBox.shrink();
                }

                return Column(
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Expanded(child: HomeCardTransactionUnpaidUnreceived.income(viewModel: viewModel)),
                          const Spacing.x(),
                          Expanded(child: HomeCardTransactionUnpaidUnreceived.expense(viewModel: viewModel)),
                        ],
                      ),
                    ),
                    const Spacing.y(),
                  ],
                );
              },
            ),
          );
          break;
        case 'creditCard':
          cards.add(
            ListenableBuilder(
              key: const ValueKey('home-card-credit-card'),
              listenable: viewModel.loadSelectedMonthCreditCards,
              builder: (_, __) {
                if (viewModel.loadSelectedMonthCreditCards.running) {
                  if (viewModel.loadSelectedMonthCreditCards.previous?.error == null &&
                      viewModel.loadSelectedMonthCreditCards.previous?.result?.isEmpty != false) {
                    return const SizedBox.shrink();
                  }
                } else if (viewModel.loadSelectedMonthCreditCards.completed &&
                    viewModel.loadSelectedMonthCreditCards.result?.isEmpty != false) {
                  return const SizedBox.shrink();
                }

                return Column(
                  children: [
                    GuidedTourTarget(
                      id: GuidedTourTargets.homeBill,
                      child: HomeCardBillCreditCard(
                        key: ValueKey(homeResetVersion),
                        viewModel: viewModel,
                      ),
                    ),
                    const Spacing.y(),
                  ],
                );
              },
            ),
          );
          break;
        case 'economy':
          cards.add(
            Column(
              key: const ValueKey('home-card-economy'),
              children: [
                GuidedTourTarget(
                  id: GuidedTourTargets.homeEconomy,
                  child: HomeMonthlyEconomyCard(viewModel: viewModel),
                ),
                HomeEconomyExplanationNotice(viewModel: viewModel),
                const Spacing.y(),
              ],
            ),
          );
          break;
        case 'radar':
          cards.add(
            Column(
              key: const ValueKey('home-card-radar-slot'),
              children: [
                GuidedTourTarget(
                  id: GuidedTourTargets.homeRadar,
                  child: HomeFinancialAlertsCard(
                    key: const ValueKey('home-card-radar'),
                    viewModel: viewModel,
                  ),
                ),
                const Spacing.y(),
              ],
            ),
          );
          break;
      }
    }

    return cards;
  }

  Future<void> _openCustomization() async {
    final CardCustomizationResult? result = await showCardVisibilitySettingsSheet(
      context: context,
      title: 'Personalizar Home',
      description:
          'Escolha o que aparece e a ordem dos cards. O saldo e o seletor de mês permanecem sempre visíveis. As mudanças só são salvas ao tocar em Aplicar.',
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

  Future<void> onRefresh() async {
    await _resetHome();
    await Future.delayed(const Duration(milliseconds: 250));
  }
}
