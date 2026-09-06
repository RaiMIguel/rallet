import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rallet/di/dependency_injection.dart';
import 'package:rallet/features/backup/presentation/ui/backup_page.dart';
import 'package:rallet/features/privacy/domain/services/account_deletion_service.dart';
import 'package:rallet/main.dart';
import 'package:rallet/shared/presentation/mixins/theme_context.dart';
import 'package:rallet/shared/presentation/ui/app.dart';
import 'package:rallet/shared/presentation/ui/components/dialog/error_dialog.dart';

class PrivacyDataPage extends StatefulWidget {
  static const String route = 'privacy-data';

  const PrivacyDataPage({super.key});

  @override
  State<PrivacyDataPage> createState() => _PrivacyDataPageState();
}

class _PrivacyDataPageState extends State<PrivacyDataPage> with ThemeContext {
  bool _isDeleting = false;

  bool get _isPortuguese =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'pt';

  String _text(String pt, String en) => _isPortuguese ? pt : en;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_text('Privacidade e dados', 'Privacy and data')),
        centerTitle: true,
        bottom: _isDeleting
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderCard(
                title: _text('Seus dados, com clareza', 'Your data, clearly'),
                message: _text(
                  'O Rallet separa seus dados financeiros locais da sua identidade de acesso online.',
                  'Rallet keeps your local financial data separate from your online sign-in identity.',
                ),
              ),
              const SizedBox(height: 18),
              _SectionTitle(_text('O que fica no aparelho', 'What stays on your device')),
              const SizedBox(height: 8),
              _InfoCard(
                icon: Icons.phone_android_outlined,
                title: _text('Dados financeiros locais', 'Local financial data'),
                description: _text(
                  'Contas, receitas, despesas, cartões, faturas, planejamentos e demais informações financeiras são armazenados no banco local do Rallet neste dispositivo.',
                  'Accounts, income, expenses, cards, bills, plans and other financial information are stored in Rallet’s local database on this device.',
                ),
              ),
              const SizedBox(height: 10),
              _InfoCard(
                icon: Icons.backup_outlined,
                title: _text('Backups', 'Backups'),
                description: _text(
                  'O arquivo de backup só é criado quando você solicita. Ao compartilhar ou salvar esse arquivo, o destino é escolhido por você.',
                  'A backup file is only created when you request it. When you share or save it, you choose the destination.',
                ),
              ),
              const SizedBox(height: 18),
              _SectionTitle(_text('O que usa a nuvem', 'What uses the cloud')),
              const SizedBox(height: 8),
              _InfoCard(
                icon: Icons.lock_person_outlined,
                title: _text('Login e perfil', 'Sign-in and profile'),
                description: _text(
                  'No Android, o login usa Firebase Authentication. O Firestore mantém apenas os dados do perfil necessários ao acesso: nome, e-mail, identificador interno e datas de criação/alteração.',
                  'On Android, sign-in uses Firebase Authentication. Firestore stores only the profile data required for access: name, email, internal identifier and creation/update timestamps.',
                ),
              ),
              const SizedBox(height: 10),
              _InfoCard(
                icon: Icons.sync_disabled_outlined,
                title: _text('Sem sincronização financeira na nuvem', 'No cloud financial sync'),
                description: _text(
                  'Nesta versão, seus lançamentos financeiros não são enviados ao Firestore e não são sincronizados automaticamente entre aparelhos.',
                  'In this version, your financial entries are not sent to Firestore and are not automatically synced between devices.',
                ),
              ),
              const SizedBox(height: 22),
              _SectionTitle(_text('Seus controles', 'Your controls')),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isDeleting ? null : () => context.pushNamed(BackupPage.route),
                icon: const Icon(Icons.backup_outlined),
                label: Text(_text('Fazer backup antes', 'Create a backup first')),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                onPressed: _isDeleting || !Platform.isAndroid ? null : _deleteAccount,
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(strings.deleteAccount),
              ),
              if (!Platform.isAndroid) ...[
                const SizedBox(height: 8),
                Text(
                  _text(
                    'A exclusão da conta online está disponível no Android, onde o login Firebase é utilizado.',
                    'Online account deletion is available on Android, where Firebase sign-in is used.',
                  ),
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                _text(
                  'Excluir a conta remove o perfil online e apaga os dados financeiros locais deste aparelho. Um backup exportado anteriormente não é apagado automaticamente.',
                  'Deleting the account removes the online profile and erases local financial data from this device. A previously exported backup is not deleted automatically.',
                ),
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 26),
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

  Future<void> _deleteAccount() async {
    if (_isDeleting) return;

    try {
      final AccountDeletionService service = DI.get<AccountDeletionService>();
      final bool requiresPassword = await service.requiresPassword();
      if (!mounted) return;

      final _DeleteAccountConfirmation? confirmation =
          await _showDeleteConfirmation(requiresPassword: requiresPassword);
      if (confirmation == null || !mounted) return;

      setState(() => _isDeleting = true);

      await service.deleteAccount(password: confirmation.password);

      if (!mounted) return;
      await reset();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      await ErrorDialog.show(context, error.toString());
    }
  }

  Future<_DeleteAccountConfirmation?> _showDeleteConfirmation({
    required bool requiresPassword,
  }) async {
    final TextEditingController confirmationController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final String expectedPhrase = _text('EXCLUIR', 'DELETE');

    final _DeleteAccountConfirmation? result = await showDialog<_DeleteAccountConfirmation>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        bool obscurePassword = true;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final bool phraseMatches = confirmationController.text.trim().toUpperCase() == expectedPhrase;
            final bool passwordReady = !requiresPassword || passwordController.text.isNotEmpty;
            final bool canDelete = phraseMatches && passwordReady;

            return AlertDialog(
              icon: Icon(Icons.warning_amber_rounded, color: colorScheme.error),
              title: Text(strings.deleteAccount),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _text(
                        'Esta ação é permanente. Faça um backup antes de continuar se quiser preservar seus dados financeiros.',
                        'This action is permanent. Create a backup before continuing if you want to preserve your financial data.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _text(
                        'Serão removidos seu perfil do Rallet, sua conta de autenticação e todos os dados locais deste aparelho.',
                        'Your Rallet profile, authentication account and all local data on this device will be removed.',
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: confirmationController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: _text('Digite $expectedPhrase para confirmar', 'Type $expectedPhrase to confirm'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    if (requiresPassword) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: strings.password,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                            icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Text(
                        _text(
                          'O Google solicitará sua conta novamente para confirmar sua identidade.',
                          'Google will ask you to select your account again to confirm your identity.',
                        ),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(strings.cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                  ),
                  onPressed: canDelete
                      ? () => Navigator.of(dialogContext).pop(
                            _DeleteAccountConfirmation(
                              password: requiresPassword ? passwordController.text : null,
                            ),
                          )
                      : null,
                  child: Text(strings.deleteAccount),
                ),
              ],
            );
          },
        );
      },
    );

    confirmationController.dispose();
    passwordController.dispose();
    return result;
  }
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String message;

  const _HeaderCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 34,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
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

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteAccountConfirmation {
  final String? password;

  const _DeleteAccountConfirmation({required this.password});
}
