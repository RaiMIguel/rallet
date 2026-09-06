import 'package:rallet/features/account/presentation/ui/accounts_list_page.dart';
import 'package:rallet/features/category/presentation/ui/categories_list_page.dart';
import 'package:rallet/features/credit_card/presentation/ui/credit_cards_details_page.dart';
import 'package:rallet/features/first_steps/presentation/ui/first_steps_page.dart';
import 'package:rallet/shared/presentation/mixins/theme_context.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NavDrawer extends StatefulWidget {
  final int? selectedIndex;

  const NavDrawer({Key? key, this.selectedIndex}) : super(key: key);

  @override
  State<NavDrawer> createState() => _NavDrawerState();
}

class _NavDrawerState extends State<NavDrawer> with ThemeContext {
  Map<int, NavigationDrawerDestination> get destinations => {
        CategoriesListPage.indexDrawer: NavigationDrawerDestination(
          label: Text(strings.categories),
          icon: const Icon(Icons.category_outlined),
          selectedIcon: const Icon(Icons.category),
        ),
        CreditCardsDetailsPage.indexDrawer: NavigationDrawerDestination(
          label: Text(strings.creditCards),
          icon: const Icon(Icons.credit_card_outlined),
          selectedIcon: const Icon(Icons.credit_card),
        ),
        AccountsListPage.indexDrawer: NavigationDrawerDestination(
          label: Text(strings.accounts),
          icon: const Icon(Icons.account_balance_outlined),
          selectedIcon: const Icon(Icons.account_balance),
        ),
      };

  void onDestinationSelected(int? index) {
    context.pop();
    switch (index) {
      case CategoriesListPage.indexDrawer:
        context.goNamed(CategoriesListPage.route);
        break;
      case CreditCardsDetailsPage.indexDrawer:
        context.goNamed(CreditCardsDetailsPage.route);
        break;
      case AccountsListPage.indexDrawer:
        context.goNamed(AccountsListPage.route);
        break;
    }
  }

  void _openTutorial() {
    context.pop();
    context.pushNamed(FirstStepsPage.route, extra: false);
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor =
        theme.navigationDrawerTheme.backgroundColor ?? colorScheme.surface;

    return Stack(
      children: [
        NavigationDrawer(
          selectedIndex: widget.selectedIndex,
          onDestinationSelected: onDestinationSelected,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
              child: Text(
                strings.menu,
                style: textTheme.titleSmall,
              ),
            ),
            destinations[CategoriesListPage.indexDrawer]!,
            destinations[CreditCardsDetailsPage.indexDrawer]!,
            destinations[AccountsListPage.indexDrawer]!,
            const SizedBox(height: 88),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Material(
              color: backgroundColor,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 28),
                    leading: const Icon(Icons.menu_book_outlined),
                    title: const Text('Tutorial de funções'),
                    subtitle: const Text('Reveja os recursos do Rallet'),
                    onTap: _openTutorial,
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
