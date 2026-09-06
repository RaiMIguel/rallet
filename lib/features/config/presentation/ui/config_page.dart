import 'dart:io';

import 'package:rallet/di/dependency_injection.dart';
import 'package:rallet/features/auth/presentation/ui/login_page.dart';
import 'package:rallet/features/backup/presentation/ui/backup_page.dart';
import 'package:rallet/features/backup/presentation/ui/restore_backup_page.dart';
import 'package:rallet/features/config/presentation/ui/about_rallet_page.dart';
import 'package:rallet/features/config/presentation/ui/components/languages.dart';
import 'package:rallet/features/config/presentation/ui/components/switch_theme_mode.dart';
import 'package:rallet/features/privacy/presentation/ui/privacy_data_page.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local.dart';
import 'package:rallet/shared/infra/drivers/auth/i_auth_driver.dart';
import 'package:rallet/shared/presentation/mixins/theme_context.dart';
import 'package:rallet/shared/presentation/ui/components/navigation/nav_drawer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ConfigPage extends StatefulWidget {
  static const String route = 'config';

  const ConfigPage({Key? key}) : super(key: key);

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> with ThemeContext {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  bool _switchingAccount = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          tooltip: strings.menu,
          icon: const Icon(Icons.menu),
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(strings.settings),
        centerTitle: true,
      ),
      drawer: const NavDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.language_outlined),
                title: Text(strings.language),
                trailing: const Icon(Icons.chevron_right),
                onTap: language,
              ),
              const Divider(),
              const SwitchThemeMode(),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: Text(strings.backup),
                trailing: const Icon(Icons.chevron_right),
                onTap: goBackup,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.restore_rounded),
                title: Text(strings.reset),
                trailing: const Icon(Icons.chevron_right),
                onTap: goRestoreBackup,
              ),
              const Divider(),
              if (!Platform.isLinux) ...[
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: Text(
                    Localizations.localeOf(context).languageCode.toLowerCase() == 'pt'
                        ? 'Conta'
                        : 'Account',
                  ),
                  subtitle: Text(
                    FirebaseAuth.instance.currentUser?.email ??
                        (Localizations.localeOf(context).languageCode.toLowerCase() == 'pt'
                            ? 'Conta não identificada'
                            : 'Account not identified'),
                  ),
                  trailing: _switchingAccount
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.swap_horiz_rounded),
                  onTap: _switchingAccount ? null : switchAccount,
                ),
                const Divider(),
              ],
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: Text(
                  Localizations.localeOf(context).languageCode.toLowerCase() == 'pt'
                      ? 'Privacidade e dados'
                      : 'Privacy and data',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: goPrivacyData,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(strings.aboutRallet),
                subtitle: const Text('Rallet by Rotecº'),
                trailing: const Icon(Icons.chevron_right),
                onTap: goAbout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> language() => Languages.show(context);

  void goBackup() => context.pushNamed(BackupPage.route);

  void goRestoreBackup() => context.pushNamed(RestoreBackupPage.route);

  void goPrivacyData() => context.pushNamed(PrivacyDataPage.route);

  Future<void> switchAccount() async {
    final bool isPortuguese =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'pt';
    final String currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.swap_horiz_rounded),
        title: Text(isPortuguese ? 'Trocar conta' : 'Switch account'),
        content: Text(
          isPortuguese
              ? 'Você sairá de ${currentEmail.isEmpty ? 'sua conta atual' : currentEmail}. '
                  'Os dados financeiros desta conta continuarão guardados separadamente neste aparelho e voltarão a aparecer quando você entrar nela novamente.'
              : 'You will sign out of ${currentEmail.isEmpty ? 'your current account' : currentEmail}. '
                  'This account’s financial data will remain stored separately on this device and will appear again when you sign in to it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(isPortuguese ? 'Cancelar' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(isPortuguese ? 'Trocar conta' : 'Switch account'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _switchingAccount = true);
    try {
      await DI.get<IAuthDriver>().logout();
      await DI.get<IDatabaseLocal>().switchToSignedOutSession();
      if (!mounted) return;
      context.goNamed(LoginPage.route);
    } catch (error) {
      if (!mounted) return;
      setState(() => _switchingAccount = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(isPortuguese ? 'Não foi possível trocar a conta' : 'Could not switch account'),
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void goAbout() => context.pushNamed(AboutRalletPage.route);
}
