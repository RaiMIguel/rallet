import 'package:rallet/di/dependency_injection.dart';
import 'package:rallet/shared/presentation/notifiers/event_notifier.dart';
import 'package:rallet/shared/presentation/mixins/theme_context.dart';
import 'package:rallet/shared/presentation/ui/components/navigation/nav_destination.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NavBarRail extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const NavBarRail({super.key, required this.navigationShell});

  @override
  State<NavBarRail> createState() => _NavBarRailState();
}

class _NavBarRailState extends State<NavBarRail> with ThemeContext {
  /// Toda entrada por uma aba principal volta para a raiz daquela aba.
  /// Isso evita preservar subpáginas/rolagens antigas e deixa a navegação
  /// previsível: mês atual, topo e contexto principal.
  void goBranch(int index) {
    final EventNotifier notifier = DI.get<EventNotifier>();
    switch (index) {
      case 0:
        notifier.notify(EventType.home);
        break;
      case 1:
        notifier.notify(EventType.transactionsHome);
        break;
      case 2:
        notifier.notify(EventType.reportsHome);
        break;
      case 3:
        notifier.notify(EventType.settingsHome);
        break;
    }

    widget.navigationShell.goBranch(
      index,
      initialLocation: true,
    );
  }

  List<NavBarRailDestination> get destinations => [
        NavBarRailDestination(description: strings.home, icon: Icons.home_outlined, iconSelected: Icons.home),
        NavBarRailDestination(description: strings.transactions, icon: Icons.sync_alt_outlined, iconSelected: Icons.sync_alt),
        NavBarRailDestination(description: strings.reports, icon: Icons.bar_chart_outlined, iconSelected: Icons.bar_chart),
        NavBarRailDestination(description: strings.settings, icon: Icons.settings_outlined, iconSelected: Icons.settings),
      ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        if (constraints.maxWidth < 800) {
          return Scaffold(
            body: widget.navigationShell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: widget.navigationShell.currentIndex,
              onDestinationSelected: goBranch,
              destinations: destinations.map((e) => NavigationDestination(icon: Icon(e.icon), label: e.description, selectedIcon: Icon(e.iconSelected))).toList(),
            ),
          );
        } else {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  labelType: NavigationRailLabelType.all,
                  selectedIndex: widget.navigationShell.currentIndex,
                  onDestinationSelected: goBranch,
                  groupAlignment: 0,
                  destinations: destinations.map((e) => NavigationRailDestination(icon: Icon(e.icon), label: Text(e.description), selectedIcon: Icon(e.iconSelected))).toList(),
                ),
                Expanded(child: widget.navigationShell),
              ],
            ),
          );
        }
      },
    );
  }
}
