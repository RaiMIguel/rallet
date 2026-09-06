import 'package:rallet/features/credit_card/presentation/ui/credit_card_expense_form_page.dart';
import 'package:rallet/features/purchase_planning/presentation/ui/purchase_planning_page.dart';
import 'package:rallet/features/transactions/presentation/ui/expense_form_page.dart';
import 'package:rallet/features/transactions/presentation/ui/income_form_page.dart';
import 'package:rallet/features/transactions/presentation/ui/transfer_form_page.dart';
import 'package:rallet/shared/presentation/mixins/theme_context.dart';
import 'package:rallet/shared/presentation/ui/app_router.dart';
import 'package:rallet/shared/presentation/ui/components/fab/expandable_fab.dart';
import 'package:rallet/shared/presentation/ui/components/fab/expandable_fab_child.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FabTransactions extends StatefulWidget {
  const FabTransactions({super.key});

  @override
  State<FabTransactions> createState() => _FabTransactionsState();
}

class _FabTransactionsState extends State<FabTransactions> with ThemeContext {
  @override
  Widget build(BuildContext context) {
    return ExpandableFab(
      iconOpen: const Icon(Icons.add),
      children: [
        ExpandableFabChild(
          icon: const Icon(Icons.arrow_downward_outlined),
          label: label(text: strings.expense),
          onPressed: goExpenseFormPage,
        ),
        ExpandableFabChild(
          icon: const Icon(Icons.arrow_upward_outlined),
          label: label(text: strings.income),
          onPressed: goIncomeFormPage,
        ),
        ExpandableFabChild(
          icon: const Icon(Icons.credit_card_outlined),
          label: label(text: strings.cardExpense),
          onPressed: goCreditCardExpenseFormPage,
        ),
        ExpandableFabChild(
          icon: const Icon(Icons.move_up_outlined),
          label: label(text: strings.transfer),
          onPressed: goTransferFormPage,
        ),
        ExpandableFabChild(
          icon: const Icon(Icons.shopping_bag_outlined),
          label: label(text: 'Planejar despesa'),
          onPressed: goPurchasePlanningPage,
        ),
      ],
    );
  }

  Future<void> goExpenseFormPage() => context.pushNamedWithAd(ExpenseFormPage.route);

  Future<void> goIncomeFormPage() => context.pushNamedWithAd(IncomeFormPage.route);

  Future<void> goTransferFormPage() => context.pushNamedWithAd(TransferFormPage.route);

  Future<void> goCreditCardExpenseFormPage() => context.pushNamedWithAd(CreditCardExpenseFormPage.route);

  Future<void> goPurchasePlanningPage() => context.pushNamed(PurchasePlanningPage.route);

  Widget label({required String text}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: textTheme.labelMedium?.copyWith(color: colorScheme.onPrimaryContainer),
      ),
    );
  }
}
