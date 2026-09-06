import 'package:rallet/di/dependency_injection.dart';
import 'package:rallet/features/account/domain/entities/account_entity.dart';
import 'package:rallet/features/account/domain/entities/account_history_item_entity.dart';
import 'package:rallet/features/card_cash_advance/presentation/ui/card_cash_advance_details_sheet.dart';
import 'package:rallet/features/transactions/presentation/ui/components/details/expense_details_sheet.dart';
import 'package:rallet/features/transactions/presentation/ui/components/details/income_details_sheet.dart';
import 'package:rallet/features/transactions/presentation/ui/components/details/transfer_details_sheet.dart';
import 'package:rallet/features/account/domain/enums/financial_institution_enum.dart';
import 'package:rallet/features/account/presentation/ui/account_form_page.dart';
import 'package:rallet/features/account/presentation/ui/components/readjust_balance_dialog.dart';
import 'package:rallet/features/account/presentation/view_models/account_details_view_model.dart';
import 'package:rallet/shared/classes/form_result_navigation.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/presentation/mixins/theme_context.dart';
import 'package:rallet/shared/presentation/ui/app_router.dart';
import 'package:rallet/shared/presentation/ui/components/dialog/confim_dialog.dart';
import 'package:rallet/shared/presentation/ui/components/dialog/error_dialog.dart';
import 'package:rallet/shared/presentation/ui/components/sliver/sliver_app_bar_medium.dart';
import 'package:rallet/shared/presentation/ui/components/sliver/sliver_scaffold.dart';
import 'package:rallet/shared/presentation/ui/components/spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AccountDetailsPage extends StatefulWidget {
  static const route = 'account-details';

  final AccountEntity account;

  const AccountDetailsPage({Key? key, required this.account}) : super(key: key);

  @override
  State<AccountDetailsPage> createState() => _AccountDetailsPageState();
}

class _AccountDetailsPageState extends State<AccountDetailsPage> with ThemeContext {
  final AccountDetailsViewModel viewModel = DI.get<AccountDetailsViewModel>();

  bool accountChanged = false;

  @override
  void initState() {
    super.initState();

    viewModel.setAccount(widget.account);
    viewModel.loadHistory.execute(widget.account);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([viewModel, viewModel.loadHistory]),
      builder: (_, __) {
        return WillPopScope(
          // canPop: !accountChanged,
          // onPopInvoked: (_) => context.pop(FormResultNavigation.save(notifier.account)),
          onWillPop: () async {
            if (accountChanged) {
              context.pop(FormResultNavigation.save(viewModel.account));
            }
            return true;
          },
          child: SliverScaffold(
            appBar: SliverAppBarMedium(
              title: Text(strings.accountDetails),
              loading: viewModel.delete.running,
              actions: [
                PopupMenuButton(
                  tooltip: strings.moreOptions,
                  enabled: !viewModel.delete.running,
                  icon: const Icon(Icons.more_vert_outlined),
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem(
                      enabled: !viewModel.delete.running,
                      onTap: goAccountForm,
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 20),
                          const Spacing.x(),
                          Text(strings.edit),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      enabled: !viewModel.delete.running,
                      onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) => delete()),
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outlined, size: 20),
                          const Spacing.x(),
                          Text(strings.delete),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacing.y(),
                      Text(viewModel.account.description, style: textTheme.titleLarge),
                      const Spacing.y(1.5),
                      Text(strings.accountBalance),
                      const Spacing.y(0.5),
                      Text(viewModel.account.transactionsAmount.money, style: textTheme.headlineLarge),
                      const Spacing.y(0.5),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          viewModel.account.financialInstitution!.icon(24),
                          const Spacing.x(),
                          Text(viewModel.account.financialInstitution!.description, style: textTheme.titleMedium),
                        ],
                      ),
                      const Spacing.y(3),
                      IntrinsicWidth(
                        stepWidth: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: readjustBalance,
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(strings.readjustBalance),
                        ),
                      ),
                      const Spacing.y(2),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Histórico da conta',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Extrato do Rallet. O histórico mostra; a operação de origem controla a edição.',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (viewModel.loadHistory.running && viewModel.history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (viewModel.loadHistory.hasError)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      viewModel.loadHistory.error.toString(),
                      style: TextStyle(color: colorScheme.error),
                    ),
                  )
                else if (viewModel.history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                    child: Text(
                      'Nenhuma movimentação realizada nesta conta.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ..._historyByMonth(),
                const Spacing.y(3),
              ],
            ),
          ),
        );
      }
    );
  }

  List<Widget> _historyByMonth() {
    final Map<DateTime, List<AccountHistoryItemEntity>> grouped = {};

    for (final item in viewModel.history) {
      final DateTime month = DateTime(item.date.year, item.date.month);
      grouped.putIfAbsent(month, () => []).add(item);
    }

    final entries = grouped.entries.toList();
    return entries.asMap().entries.map((entry) {
      final int index = entry.key;
      final DateTime month = entry.value.key;
      final List<AccountHistoryItemEntity> items = entry.value.value;
      final String rawLabel = DateFormat('MMMM yyyy', 'pt_BR').format(month);
      final String label = rawLabel.isEmpty
          ? rawLabel
          : rawLabel[0].toUpperCase() + rawLabel.substring(1);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: PageStorageKey('account-history-${month.year}-${month.month}'),
            initiallyExpanded: index == 0,
            maintainState: false,
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text(
              label,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${items.length} ${items.length == 1 ? 'movimentação' : 'movimentações'}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            children: items.map(_historyTile).toList(),
          ),
        ),
      );
    }).toList();
  }

  Widget _historyTile(AccountHistoryItemEntity item) {
    final Color amountColor = item.amount >= 0
        ? const Color(0xFF1AA56B)
        : const Color(0xFFE34B42);
    final IconData originIcon = switch (item.originType) {
      AccountHistoryOriginType.initialBalance => Icons.account_balance_wallet_outlined,
      AccountHistoryOriginType.income => Icons.south_west_rounded,
      AccountHistoryOriginType.expense => Icons.north_east_rounded,
      AccountHistoryOriginType.transfer => Icons.swap_horiz_rounded,
      AccountHistoryOriginType.cardCashAdvance => Icons.add_card_outlined,
      AccountHistoryOriginType.balanceAdjustment => Icons.tune_rounded,
      AccountHistoryOriginType.unknown => Icons.receipt_long_outlined,
    };

    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          leading: CircleAvatar(
            backgroundColor: amountColor.withValues(alpha: .10),
            child: Icon(originIcon, color: amountColor),
          ),
          title: Text(item.title),
          subtitle: Text(
            '${item.subtitle ?? ''}${item.subtitle == null ? '' : ' • '}${DateFormat('dd/MM/yyyy').format(item.date)}\nSaldo após: ${item.balanceAfter.money}',
          ),
          isThreeLine: true,
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_rounded, size: 17, color: Color(0xFF1AA56B)),
                  const SizedBox(width: 4),
                  Text(
                    '${item.amount >= 0 ? '+' : ''}${item.amount.money}',
                    style: textTheme.labelLarge?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (item.hasEditableOrigin)
                const Icon(Icons.chevron_right, size: 18),
            ],
          ),
          onTap: item.hasEditableOrigin ? () => _openHistoryItem(item) : null,
        ),
        const Divider(height: 1),
      ],
    );
  }

  Future<void> _openHistoryItem(AccountHistoryItemEntity item) async {
    bool changed = false;

    if (item.expense != null) {
      await ExpenseDetailsSheet.show(
        context: context,
        id: item.expense!.id,
        onChanged: (_) => changed = true,
      );
    } else if (item.income != null) {
      await IncomeDetailsSheet.show(
        context: context,
        id: item.income!.id,
        onChanged: (_) => changed = true,
      );
    } else if (item.transfer != null) {
      await TransferDetailsSheet.show(
        context: context,
        id: item.transfer!.id,
        onChanged: (_) => changed = true,
      );
    } else if (item.cashAdvance != null) {
      changed = await CardCashAdvanceDetailsSheet.show(
            context: context,
            plan: item.cashAdvance!,
          ) ==
          true;
    }

    if (changed && mounted) {
      await viewModel.refreshHistory();
    }
  }

  Widget operation({required String value, required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(value, style: textTheme.titleLarge),
        Text(label, style: textTheme.labelLarge),
      ],
    );
  }

  Future<void> goAccountForm() async {
    if (viewModel.delete.running) return;

    final FormResultNavigation? result = await context.pushNamedWithAd(AccountFormPage.route, extra: viewModel.account);

    if (result?.isSave ?? false) {
      viewModel.setAccount(result!.value);
      accountChanged = true;
      await viewModel.refreshHistory();
    }

    if (result?.isDelete ?? false) {
      if (!mounted) return;
      context.pop(FormResultNavigation<AccountEntity>.delete());
    }
  }

  Future<void> readjustBalance() async {
    if (viewModel.delete.running) return;

    final AccountEntity? account = await ReadjustBalance.show(context: context, account: viewModel.account);
    if (account == null) return;

    viewModel.setAccount(account);
    accountChanged = true;
    await viewModel.refreshHistory();
  }

  Future<void> delete() async {
    try {
      if (viewModel.delete.running) return;

      final bool confirm = await ConfirmDialog.show(context: context, title: strings.deleteAccount, message: strings.deleteAccountConfirmation);
      if (!confirm) return;

      await viewModel.delete.execute(viewModel.account);

      viewModel.delete.throwIfError();

      if (!mounted) return;
      context.pop(FormResultNavigation<AccountEntity>.delete());
    } catch (e) {
      await ErrorDialog.show(context, e.toString());
    }
  }
}
