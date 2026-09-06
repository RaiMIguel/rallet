import 'package:flutter/material.dart';
import 'package:rallet/shared/presentation/mixins/theme_context.dart';
import 'package:rallet/shared/presentation/ui/app.dart';

class AboutRalletPage extends StatefulWidget {
  static const String route = 'about-rallet';

  const AboutRalletPage({super.key});

  @override
  State<AboutRalletPage> createState() => _AboutRalletPageState();
}

class _AboutRalletPageState extends State<AboutRalletPage> with ThemeContext {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.aboutRallet),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Image.asset(
                  'assets/images/rallet_logo.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                appName,
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                strings.personalFinance,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              _AboutCard(
                children: [
                  _InfoRow(
                    icon: Icons.code_outlined,
                    label: strings.developedBy,
                    value: 'Raí Miguel / Rotecº',
                  ),
                  const Divider(height: 1),
                  _InfoRow(
                    icon: Icons.account_tree_outlined,
                    label: strings.basedOnProject,
                    value: 'Finan Master\nGabriel Hainzenreder',
                  ),
                  const Divider(height: 1),
                  _InfoRow(
                    icon: Icons.balance_outlined,
                    label: strings.licenseLabel,
                    value: 'GNU AGPL v3.0',
                  ),
                  const Divider(height: 1),
                  _InfoRow(
                    icon: Icons.source_outlined,
                    label: strings.sourceCode,
                    value: strings.sourceCodePreparing,
                  ),
                  const Divider(height: 1),
                  _InfoRow(
                    icon: Icons.info_outline,
                    label: strings.versionLabel,
                    value: appVersion,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Rallet by Rotecº',
                textAlign: TextAlign.center,
                style: textTheme.labelLarge?.copyWith(
                  color: ralletOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final List<Widget> children;

  const _AboutCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
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
