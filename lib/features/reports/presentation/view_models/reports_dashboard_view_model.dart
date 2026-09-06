import 'package:collection/collection.dart';
import 'package:rallet/features/account/domain/use_cases/i_account_find.dart';
import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/card_cash_advance/domain/use_cases/i_card_cash_advance.dart';
import 'package:rallet/features/category/domain/entities/category_entity.dart';
import 'package:rallet/features/category/domain/enums/category_type_enum.dart';
import 'package:rallet/features/category/domain/use_cases/i_category_find.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_find.dart';
import 'package:rallet/features/config/domain/use_cases/i_config_find.dart';
import 'package:rallet/features/config/domain/use_cases/i_config_save.dart';
import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';
import 'package:rallet/features/purchase_planning/domain/use_cases/i_purchase_planning.dart';
import 'package:rallet/features/reports/domain/entities/report_category_entity.dart';
import 'package:rallet/features/reports/domain/entities/report_financial_explanation_entity.dart';
import 'package:rallet/features/reports/domain/entities/reports_dashboard_entity.dart';
import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/entities/i_transaction_entity.dart';
import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/domain/entities/transfer_entity.dart';
import 'package:rallet/features/transactions/domain/entities/transactions_by_period_entity.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_transaction_find.dart';
import 'package:rallet/shared/classes/constants.dart';
import 'package:rallet/shared/extensions/date_time_extension.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/presentation/commands/command.dart';
import 'package:flutter/foundation.dart';

class ReportsDashboardViewModel extends ChangeNotifier {
  final ITransactionFind _transactionFind;
  final ICreditCardFind _creditCardFind;
  final IAccountFind _accountFind;
  final ICategoryFind _categoryFind;
  final ICardCashAdvance _cashAdvance;
  final IPurchasePlanning _purchasePlanning;
  final IConfigFind _configFind;
  final IConfigSave _configSave;

  late final Command0<ReportsDashboardEntity> loadDashboard;

  DateTime _selectedMonth = DateTime.now().getInitialMonth();
  DateTime get selectedMonth => _selectedMonth;

  late int _greenPathMonths;
  int get greenPathMonths => _greenPathMonths;

  ReportsDashboardViewModel({
    required ITransactionFind transactionFind,
    required ICreditCardFind creditCardFind,
    required IAccountFind accountFind,
    required ICategoryFind categoryFind,
    required ICardCashAdvance cashAdvance,
    required IPurchasePlanning purchasePlanning,
    required IConfigFind configFind,
    required IConfigSave configSave,
  })  : _transactionFind = transactionFind,
        _creditCardFind = creditCardFind,
        _accountFind = accountFind,
        _categoryFind = categoryFind,
        _cashAdvance = cashAdvance,
        _purchasePlanning = purchasePlanning,
        _configFind = configFind,
        _configSave = configSave {
    _greenPathMonths = _configFind.findGreenPathMonths();
    loadDashboard = Command0(_load);
  }

  Future<void> initialize({DateTime? initialMonth}) {
    if (initialMonth != null) {
      _selectedMonth = initialMonth.getInitialMonth();
      notifyListeners();
    }
    return loadDashboard.execute();
  }

  Future<void> setGreenPathMonths(int months) async {
    final int normalized = months <= 6 ? 6 : months <= 12 ? 12 : 24;
    if (_greenPathMonths == normalized) return;
    _greenPathMonths = normalized;
    await _configSave.saveGreenPathMonths(normalized);
    notifyListeners();
    await loadDashboard.execute();
  }

  Future<void> previousMonth() async {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    notifyListeners();
    await loadDashboard.execute();
  }

  Future<void> nextMonth() async {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    notifyListeners();
    await loadDashboard.execute();
  }

  Future<void> goCurrentMonth() async {
    _selectedMonth = DateTime.now().getInitialMonth();
    notifyListeners();
    await loadDashboard.execute();
  }

  DateTime _monthStart(DateTime date) => DateTime(date.year, date.month, 1);

  DateTime _monthEnd(DateTime date) =>
      DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);

  String _monthYear(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<ReportsDashboardEntity> _load() async {
    final DateTime month = _selectedMonth;
    final List<CategoryEntity> expenseCategoriesAvailable =
        await _categoryFind.findAll(
      type: CategoryTypeEnum.expense,
      deleted: true,
    );

    // Usamos todas as operações para conseguir explicar no relatório tanto
    // custos planejados quanto custos já realizados. Para projeções futuras,
    // somente as que continuam planejadas devem ser acrescentadas.
    final List<CardCashAdvancePlanEntity> allCashAdvanceOperations =
        await _cashAdvance.findAll();
    final List<CardCashAdvancePlanEntity> plannedOperations =
        allCashAdvanceOperations.where((plan) => plan.isPlanned).toList();
    final List<PlannedPurchaseEntity> allPlannedPurchases =
        await _purchasePlanning.findAll();

    final _MonthReportData current = await _loadMonthData(
      month,
      expenseCategoriesAvailable,
      allCashAdvanceOperations,
      allPlannedPurchases,
    );

    final DateTime previousMonth = DateTime(month.year, month.month - 1, 1);
    final _MonthReportData previous = await _loadMonthData(
      previousMonth,
      expenseCategoriesAvailable,
      allCashAdvanceOperations,
      allPlannedPurchases,
    );

    final List<ReportMonthlyPoint> evolution = [];
    for (int i = 5; i >= 0; i--) {
      final DateTime cursor = DateTime(month.year, month.month - i, 1);
      final _MonthReportData data = await _loadMonthData(
        cursor,
        expenseCategoriesAvailable,
        allCashAdvanceOperations,
        allPlannedPurchases,
      );
      evolution.add(
        ReportMonthlyPoint(
          month: cursor,
          expenses: data.expenses,
        ),
      );
    }

    final List<ITransactionEntity> pending =
        await _transactionFind.findUnpaidUnreceived();

    final List<ReportFutureCommitment> commitments = [];
    final DateTime commitmentStart = DateTime.now().getInitialMonth();

    for (int i = 0; i < 4; i++) {
      final DateTime cursor =
          DateTime(commitmentStart.year, commitmentStart.month + i, 1);
      final DateTime end = _monthEnd(cursor);

      double amount = pending
          .whereType<ExpenseEntity>()
          .where(
            (expense) =>
                expense.idCreditCard == null &&
                !expense.date.isBefore(cursor) &&
                !expense.date.isAfter(end),
          )
          .map((expense) => expense.amount.abs())
          .sum
          .toDouble();

      // Aqui interessa o que AINDA falta pagar, por isso usamos saldo aberto
      // da fatura, e não o total histórico de compras.
      final List<CreditCardBillEntity> openBills =
          await _creditCardFind.findBillsByPeriod(cursor, end);

      amount += openBills
          .where((bill) => bill.billAmount > 0)
          .map((bill) => bill.billAmount)
          .sum
          .toDouble();

      // Planejamento ainda não é dívida real e portanto não está em uma fatura.
      // Acrescentamos a cobrança prevista separadamente.
      amount += plannedOperations
          .where(
            (plan) =>
                !plan.billDueDate.isBefore(cursor) &&
                !plan.billDueDate.isAfter(end),
          )
          .fold(0.0, (total, plan) => total + plan.amountCharged);

      // Despesas planejadas ainda não são despesas reais, mas são compromissos
      // assumidos pelo usuário e por isso participam da visão futura.
      amount += allPlannedPurchases
          .fold(0.0, (total, purchase) =>
              total + purchase.amountDueInPeriod(cursor, end));

      commitments.add(
        ReportFutureCommitment(
          month: cursor,
          amount: amount.toRound(2),
        ),
      );
    }

    // A pagar e Relatórios respondem perguntas diferentes. Esta composição
    // replica a lógica de caixa da tela A pagar para tornar a diferença
    // explícita sem transformar principal de crédito/pagamento de fatura em
    // nova despesa econômica.
    final DateTime cashStart = month.getInitialMonth();
    final DateTime cashNext = cashStart.addMonths(1);
    final DateTime cashEnd = cashNext.subtract(const Duration(microseconds: 1));
    final DateTime currentMonth = DateTime.now().getInitialMonth();
    final bool cashIsCurrent = cashStart.year == currentMonth.year &&
        cashStart.month == currentMonth.month;

    bool belongsToCashMonth(DateTime date) => cashIsCurrent
        ? date.isBefore(cashNext)
        : !date.isBefore(cashStart) && date.isBefore(cashNext);

    final List<IncomeEntity> pendingIncomeItemsSource = pending
        .whereType<IncomeEntity>()
        .where((income) => !income.received && belongsToCashMonth(income.date))
        .toList();
    final double pendingIncomes = pendingIncomeItemsSource
        .fold(0.0, (total, income) => total + income.amount.abs())
        .toRound(2);

    final List<ExpenseEntity> pendingExpenseItemsSource = pending
        .whereType<ExpenseEntity>()
        .where((expense) =>
            !expense.paid &&
            expense.idCreditCard == null &&
            belongsToCashMonth(expense.date))
        .toList();
    final double pendingExpenses = pendingExpenseItemsSource
        .fold(0.0, (total, expense) => total + expense.amount.abs())
        .toRound(2);

    final List<CreditCardBillEntity> cashBills = cashIsCurrent
        ? await _creditCardFind.findBillsByPeriod(DateTime(1970, 1, 1), cashEnd)
        : await _creditCardFind.findBillsByPeriod(cashStart, cashEnd);
    final List<CreditCardBillEntity> openCashBills =
        cashBills.where((bill) => bill.billAmount > 0).toList();
    final double openBillsAmount = openCashBills
        .fold(0.0, (total, bill) => total + bill.billAmount.abs())
        .toRound(2);

    final List<CardCashAdvancePlanEntity> plannedCreditChargeItems =
        plannedOperations
            .where((plan) => belongsToCashMonth(plan.billDueDate))
            .toList();
    final double plannedCreditCharges = plannedCreditChargeItems
        .fold(0.0, (total, plan) => total + plan.amountCharged.abs())
        .toRound(2);

    final List<CardCashAdvancePlanEntity> plannedCreditReceiptItems =
        plannedOperations
            .where((plan) => belongsToCashMonth(plan.linkedEntryDate))
            .toList();
    final double plannedCreditReceipts = plannedCreditReceiptItems
        .fold(0.0, (total, plan) => total + plan.amountReceived.abs())
        .toRound(2);

    final List<ReportAuditItem> cashReceivableItems = [
      ...pendingIncomeItemsSource.map(
        (income) => ReportAuditItem(
          id: '${income.id}-cash-receivable',
          description: income.description.trim().isEmpty
              ? 'Receita a receber'
              : income.description.trim(),
          date: income.date,
          amount: income.amount.abs().toRound(2),
          reason:
              'É uma receita econômica que ainda não entrou no caixa. Por isso aparece em A receber e também participa do resultado econômico do mês.',
          treatment: ReportAuditTreatment.economicIncome,
          caseType: ReportAuditCase.pendingIncome,
        ),
      ),
      ...plannedCreditReceiptItems.map(
        (plan) => ReportAuditItem(
          id: '${plan.id}-cash-receivable',
          description: plan.description.trim().isEmpty
              ? 'Crédito via cartão a receber'
              : 'Crédito a receber • ${plan.description.trim()}',
          date: plan.linkedEntryDate,
          amount: plan.amountReceived.abs().toRound(2),
          reason:
              'Origem: vínculo de crédito. A entrada de ${plan.amountReceived.abs().toRound(2).money} está prevista para ${_dateLabel(plan.linkedEntryDate)}, mas ela cria uma obrigação de ${plan.amountCharged.abs().toRound(2).money} na fatura com vencimento em ${_dateLabel(plan.billDueDate)} (${_monthYear(plan.billDueDate)}). O principal não é renda no mês da entrada; na competência da fatura, somente juros e taxas (${plan.financialCost.toRound(2).money}) são nova despesa econômica.',
          treatment: ReportAuditTreatment.cashInflowNotIncome,
          caseType: ReportAuditCase.cardCreditPrincipal,
          planned: true,
          originLabel: 'Vínculo de crédito • entrada prevista em ${_dateLabel(plan.linkedEntryDate)}',
          relatedDateLabel: 'Fatura/obrigação',
          relatedDate: plan.billDueDate,
        ),
      ),
    ]..sort((a, b) => a.date.compareTo(b.date));

    final List<ReportAuditItem> cashPayableItems = [
      ...pendingExpenseItemsSource.map(
        (expense) => ReportAuditItem(
          id: '${expense.id}-cash-payable',
          description: expense.description.trim().isEmpty
              ? 'Despesa a pagar'
              : expense.description.trim(),
          date: expense.date,
          amount: expense.amount.abs().toRound(2),
          reason:
              'É uma despesa econômica ainda não paga. Portanto aparece tanto entre as despesas do período quanto em A pagar.',
          treatment: ReportAuditTreatment.economicExpense,
          caseType: ReportAuditCase.pendingExpense,
        ),
      ),
      ...openCashBills.map(
        (bill) => ReportAuditItem(
          id: '${bill.id}-open-bill',
          description: 'Fatura do cartão em aberto',
          date: bill.billDueDate,
          amount: bill.billAmount.abs().toRound(2),
          reason:
              'É uma obrigação real de caixa. O pagamento da fatura não vira uma nova despesa: as compras e custos que formaram a fatura já são reconhecidos economicamente na competência correta.',
          treatment: ReportAuditTreatment.cashOutflowNotNewExpense,
          caseType: ReportAuditCase.openBill,
        ),
      ),
      ...plannedCreditChargeItems.map(
        (plan) => ReportAuditItem(
          id: '${plan.id}-planned-charge',
          description: plan.description.trim().isEmpty
              ? 'Cobrança prevista de crédito via cartão'
              : 'Cobrança prevista • ${plan.description.trim()}',
          date: plan.billDueDate,
          amount: plan.amountCharged.abs().toRound(2),
          reason:
              'Esta cobrança de ${plan.amountCharged.abs().toRound(2).money} vem do vínculo de crédito cuja entrada de ${plan.amountReceived.abs().toRound(2).money} está prevista para ${_dateLabel(plan.linkedEntryDate)}. A obrigação vence em ${_dateLabel(plan.billDueDate)}. O principal apenas devolve o crédito recebido; somente juros e taxas (${plan.financialCost.toRound(2).money}) são nova despesa econômica da competência da fatura.',
          treatment: ReportAuditTreatment.cashOutflowNotNewExpense,
          caseType: ReportAuditCase.plannedCardCharge,
          planned: true,
          originLabel: 'Origem: crédito vinculado de ${plan.amountReceived.abs().toRound(2).money}',
          relatedDateLabel: 'Entrada vinculada',
          relatedDate: plan.linkedEntryDate,
        ),
      ),
    ];

    double plannedExpensesCash = 0;
    for (final PlannedPurchaseEntity plan in allPlannedPurchases) {
      if (!plan.isCreditCard) {
        if (belongsToCashMonth(plan.plannedDate)) {
          final double amount = plan.amount.abs().toRound(2);
          plannedExpensesCash += amount;
          cashPayableItems.add(
            ReportAuditItem(
              id: '${plan.id}-planned-cash-payable',
              description: 'Planejamento • ${plan.description}',
              date: plan.plannedDate,
              amount: amount,
              reason:
                  'É uma despesa planejada para sair do caixa neste período. Ela também participa da projeção econômica porque representa um custo esperado.',
              treatment: ReportAuditTreatment.economicExpense,
              caseType: ReportAuditCase.plannedExpense,
              planned: true,
            ),
          );
        }
        continue;
      }

      final installments = plan.installmentSchedule
          .where((installment) => belongsToCashMonth(installment.dueDate))
          .toList();
      for (final installment in installments) {
        final double amount = installment.amount.abs().toRound(2);
        plannedExpensesCash += amount;
        cashPayableItems.add(
          ReportAuditItem(
            id: '${plan.id}-installment-${installment.number}-cash-payable',
            description:
                'Planejamento • ${plan.description} (${installment.number}/${plan.installmentCount})',
            date: installment.dueDate,
            amount: amount,
            reason:
                'É uma parcela planejada que exigirá caixa neste período. O principal da compra e eventual custo financeiro também aparecem separadamente na composição econômica.',
            treatment: ReportAuditTreatment.economicExpense,
            caseType: ReportAuditCase.plannedExpense,
            planned: true,
          ),
        );
      }
    }
    plannedExpensesCash = plannedExpensesCash.toRound(2);
    cashPayableItems.sort((a, b) => a.date.compareTo(b.date));

    final cashCommitments = ReportCashCommitmentComposition(
      pendingExpenses: pendingExpenses,
      openBills: openBillsAmount,
      plannedCreditCharges: plannedCreditCharges,
      plannedExpenses: plannedExpensesCash,
    );

    final double cashReceivable =
        (pendingIncomes + plannedCreditReceipts).toRound(2);

    // Para o diagnóstico, reconstruímos pagamentos de fatura a partir da
    // própria fatura. Assim conseguimos dizer se o dinheiro saiu neste mês
    // para quitar uma competência anterior, atual ou futura, em vez de mostrar
    // apenas a mensagem genérica "pagamento de fatura".
    final DateTime paymentAuditEnd = DateTime(
      cashStart.year,
      cashStart.month + 13,
      0,
      23,
      59,
      59,
      999,
    );
    final List<CreditCardBillEntity> billsForPaymentAudit =
        await _creditCardFind.findAllBillsByPeriod(
      DateTime(1970, 1, 1),
      paymentAuditEnd,
    );
    final List<ReportAuditItem> billPaymentAuditItems = [];

    String monthYear(DateTime date) =>
        "${date.month.toString().padLeft(2, '0')}/${date.year}";

    for (final CreditCardBillEntity bill in billsForPaymentAudit) {
      final DateTime billMonth =
          DateTime(bill.billDueDate.year, bill.billDueDate.month, 1);

      for (final CreditCardTransactionEntity transaction
          in bill.transactions.where((item) => item.amount < 0)) {
        if (transaction.date.isBefore(cashStart) ||
            !transaction.date.isBefore(cashNext)) {
          continue;
        }

        final String competence = monthYear(bill.billDueDate);
        final String description;
        final String reason;

        if (billMonth.isBefore(cashStart)) {
          description = 'Pagamento de fatura de $competence';
          reason =
              'Este pagamento saiu do caixa em ${monthYear(transaction.date)}, mas quita uma fatura cuja competência é $competence. Por isso ele reduz o saldo agora sem virar uma nova despesa deste mês: as compras e custos dessa fatura já foram reconhecidos na competência $competence.';
        } else if (billMonth.isAfter(cashStart)) {
          description = 'Pagamento antecipado de fatura de $competence';
          reason =
              'Este pagamento saiu do caixa antes da competência $competence. Ele altera o saldo agora, mas não cria uma nova despesa econômica neste mês; as compras e custos continuam atribuídos à competência da fatura.';
        } else {
          description = 'Pagamento da fatura de $competence';
          reason =
              'Este pagamento saiu do caixa neste mês, mas não é contado como uma segunda despesa. As compras e custos da fatura já compõem o resultado econômico da competência $competence.';
        }

        billPaymentAuditItems.add(
          ReportAuditItem(
            id: '${transaction.id}-bill-payment-audit',
            description: description,
            date: transaction.date,
            amount: transaction.amount.abs().toRound(2),
            reason: reason,
            treatment: ReportAuditTreatment.cashOutflowNotNewExpense,
            caseType: ReportAuditCase.billPayment,
          ),
        );
      }
    }

    final List<ReportAuditItem> linkedCreditObligationAuditItems =
        allCashAdvanceOperations
            .where((plan) =>
                !plan.billDueDate.isBefore(cashStart) &&
                plan.billDueDate.isBefore(cashNext))
            .map(
              (plan) => ReportAuditItem(
                id: '${plan.id}-linked-credit-obligation-audit',
                description: plan.description.trim().isEmpty
                    ? 'Obrigação de crédito vinculada'
                    : 'Obrigação vinculada • ${plan.description.trim()}',
                date: plan.billDueDate,
                amount: plan.amountCharged.abs().toRound(2),
                reason:
                    'Esta obrigação de ${plan.amountCharged.abs().toRound(2).money} tem origem no crédito de ${plan.amountReceived.abs().toRound(2).money} ${plan.isPlanned ? 'previsto para' : 'recebido em'} ${_dateLabel(plan.linkedEntryDate)}. A entrada pertence ao caixa de ${_monthYear(plan.linkedEntryDate)}, enquanto a obrigação está vinculada à fatura de ${_monthYear(plan.billDueDate)}. O principal não vira renda na entrada nem nova despesa no pagamento; somente ${plan.financialCost.toRound(2).money} de juros/taxas representam custo econômico.',
                treatment: ReportAuditTreatment.cashOutflowNotNewExpense,
                caseType: ReportAuditCase.cardCreditObligation,
                planned: plan.isPlanned,
                originLabel:
                    'Origem: crédito de ${plan.amountReceived.abs().toRound(2).money} em ${_dateLabel(plan.linkedEntryDate)}',
                relatedDateLabel: 'Entrada vinculada',
                relatedDate: plan.linkedEntryDate,
              ),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    bool hasEnrichedPaymentFor(ReportAuditItem fallback) =>
        billPaymentAuditItems.any(
          (item) =>
              item.date.year == fallback.date.year &&
              item.date.month == fallback.date.month &&
              item.date.day == fallback.date.day &&
              (item.amount.abs() - fallback.amount.abs()).abs() <= 0.01,
        );

    final List<ReportAuditItem> nonEconomicItemsForExplanation = [
      ...current.nonEconomicItems.where(
        (item) =>
            item.caseType != ReportAuditCase.billPayment ||
            !hasEnrichedPaymentFor(item),
      ),
      ...billPaymentAuditItems,
      ...linkedCreditObligationAuditItems,
    ]..sort((a, b) => a.date.compareTo(b.date));

    final ReportFinancialExplanationEntity financialExplanation =
        ReportFinancialExplanationEntity(
      month: month,
      economicIncomes: current.incomes,
      economicExpenses: current.expenses,
      cashReceivable: cashReceivable,
      cashPayable: cashCommitments.total,
      economicIncomeItems: current.economicIncomeItems,
      economicExpenseItems: current.economicExpenseItems,
      cashReceivableItems: cashReceivableItems,
      cashPayableItems: cashPayableItems,
      nonEconomicItems: nonEconomicItemsForExplanation,
    );

    final ReportGreenPathEntity greenPath = await _buildGreenPath(
      pending: pending,
      expenseCategoriesAvailable: expenseCategoriesAvailable,
      allCashAdvanceOperations: allCashAdvanceOperations,
      allPlannedPurchases: allPlannedPurchases,
    );

    return ReportsDashboardEntity(
      month: month,
      incomes: current.incomes,
      expenses: current.expenses,
      regularExpenses: current.regularExpenses,
      creditCardPurchases: current.creditCardPurchases,
      realizedFinancialCosts: current.realizedFinancialCosts,
      plannedFinancialCosts: current.plannedFinancialCosts,
      plannedPurchases: current.plannedPurchases,
      creditCardExpenses: current.creditCardExpenses,
      cashCommitments: cashCommitments,
      fixedExpenses: current.fixedExpenses,
      variableExpenses: current.variableExpenses,
      previousMonthExpenses: previous.expenses,
      expenseCategories: current.expenseCategories,
      evolution: evolution,
      futureCommitments: commitments,
      financialCostItems: current.financialCostItems,
      plannedExpenseItems: current.plannedExpenseItems,
      varianceItems: current.varianceItems,
      financialExplanation: financialExplanation,
      greenPath: greenPath,
    );
  }

  Future<ReportGreenPathEntity> _buildGreenPath({
    required List<ITransactionEntity> pending,
    required List<CategoryEntity> expenseCategoriesAvailable,
    required List<CardCashAdvancePlanEntity> allCashAdvanceOperations,
    required List<PlannedPurchaseEntity> allPlannedPurchases,
  }) async {
    final DateTime now = DateTime.now();
    final DateTime currentStart = DateTime(now.year, now.month, 1);
    final DateTime currentEnd = _monthEnd(currentStart);

    final double availableBalance =
        (await _accountFind.findAccountsBalance()).toRound(2);

    final List<ExpenseEntity> openPendingExpenses = pending
        .whereType<ExpenseEntity>()
        .where((expense) {
          if (expense.paid || expense.idCreditCard != null) return false;

          // Recorrências do Rallet são materializadas por vários anos. As
          // ocorrências recorrentes de meses futuros representam custo de vida
          // futuro, não uma dívida já assumida hoje. Mantemos como dívida as
          // recorrências vencidas/do mês atual e qualquer obrigação não
          // recorrente que o usuário já cadastrou, mesmo com vencimento futuro.
          if (expense.recurring && expense.date.isAfter(currentEnd)) {
            return false;
          }
          return true;
        })
        .toList();

    final double pendingExpenseDebt = openPendingExpenses
        .fold(0.0, (total, expense) => total + expense.amount.abs())
        .toRound(2);

    // Consideramos como dívida de cartão tudo que já está em faturas reais,
    // inclusive parcelas futuras já criadas. Planejamentos que ainda não
    // viraram operação real não entram aqui para não chamar intenção de dívida.
    final List<CreditCardBillEntity> allBills =
        await _creditCardFind.findAllBillsByPeriod(
      DateTime(1970, 1, 1),
      DateTime(2100, 12, 31, 23, 59, 59, 999),
    );
    final List<CreditCardBillEntity> openBills = allBills
        .where((bill) => bill.billAmount > 0.01)
        .toList()
      ..sort((a, b) => a.billDueDate.compareTo(b.billDueDate));

    final double creditCardDebt = openBills
        .fold(0.0, (total, bill) => total + bill.billAmount.abs())
        .toRound(2);

    final List<ReportGreenDebtItem> debtItems = [];

    for (final CreditCardBillEntity bill in openBills) {
      final card = await _creditCardFind.findById(
        bill.idCreditCard,
        deleted: true,
      );
      final String cardName = card?.description.trim().isNotEmpty == true
          ? card!.description.trim()
          : 'Cartão de crédito';

      final List<ReportGreenDebtComponent> components = bill.transactions
          .where((transaction) => transaction.amount > 0.01)
          .map(
            (transaction) => ReportGreenDebtComponent(
              description: transaction.description.trim().isEmpty
                  ? 'Compra no cartão'
                  : transaction.description.trim(),
              originLabel: transaction.cashAdvancePlanId != null
                  ? 'Crédito vinculado'
                  : transaction.isInstallment
                      ? 'Parcela ${transaction.installmentNumber}/${transaction.installmentCount}'
                      : transaction.plannedPurchaseId != null
                          ? 'Compra planejada realizada'
                          : 'Compra no cartão',
              amount: transaction.amount.abs().toRound(2),
            ),
          )
          .toList();

      final double alreadyPaid = bill.transactions
          .where((transaction) => transaction.amount < -0.01)
          .fold(0.0, (total, transaction) => total + transaction.amount.abs())
          .toRound(2);

      debtItems.add(
        ReportGreenDebtItem(
          id: bill.id,
          title: cardName,
          originLabel: 'Fatura de ${_monthYear(bill.billDueDate)}',
          amount: bill.billAmount.abs().toRound(2),
          dueDate: bill.billDueDate,
          kind: ReportGreenDebtKind.creditCardBill,
          alreadyPaid: alreadyPaid,
          components: components,
        ),
      );
    }

    for (final ExpenseEntity expense in openPendingExpenses) {
      debtItems.add(
        ReportGreenDebtItem(
          id: expense.id,
          title: expense.description.trim().isEmpty
              ? 'Despesa em aberto'
              : expense.description.trim(),
          originLabel:
              expense.recurring ? 'Despesa recorrente' : 'Despesa cadastrada',
          amount: expense.amount.abs().toRound(2),
          dueDate: expense.date,
          kind: ReportGreenDebtKind.pendingExpense,
          recurring: expense.recurring,
        ),
      );
    }

    debtItems.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final double openDebt =
        (pendingExpenseDebt + creditCardDebt).toRound(2);

    final List<_MonthReportData> historical = [];
    for (int i = 1; i <= 3; i++) {
      final DateTime cursor = DateTime(now.year, now.month - i, 1);
      historical.add(
        await _loadMonthData(
          cursor,
          expenseCategoriesAvailable,
          allCashAdvanceOperations,
          allPlannedPurchases,
        ),
      );
    }

    final List<_MonthReportData> expenseHistory = historical
        .where((item) =>
            (item.regularExpenses + item.creditCardPurchases) > 0.01)
        .toList();
    final List<_MonthReportData> incomeHistory =
        historical.where((item) => item.incomes > 0.01).toList();

    _MonthReportData? currentForFallback;
    Future<_MonthReportData> currentData() async {
      currentForFallback ??= await _loadMonthData(
        currentStart,
        expenseCategoriesAvailable,
        allCashAdvanceOperations,
        allPlannedPurchases,
      );
      return currentForFallback!;
    }

    double monthlyLivingCost;
    double nonCardMonthlyCost;
    int historyMonthsAnalyzed = expenseHistory.length;

    if (expenseHistory.isNotEmpty) {
      monthlyLivingCost = (expenseHistory.fold<double>(
                0,
                (total, item) =>
                    total + item.regularExpenses + item.creditCardPurchases,
              ) /
              expenseHistory.length)
          .toRound(2);
      nonCardMonthlyCost = (expenseHistory.fold<double>(
                0,
                (total, item) => total + item.regularExpenses,
              ) /
              expenseHistory.length)
          .toRound(2);
    } else {
      final _MonthReportData fallback = await currentData();
      monthlyLivingCost =
          (fallback.regularExpenses + fallback.creditCardPurchases).toRound(2);
      nonCardMonthlyCost = fallback.regularExpenses.toRound(2);
      historyMonthsAnalyzed = 0;
    }

    // Para renda, uma receita explicitamente recorrente no mês atual é uma
    // base melhor que uma média contaminada por entradas excepcionais.
    final TransactionsByPeriodEntity currentTransactions =
        await _transactionFind.findByPeriod(currentStart, currentEnd);
    final double recurringIncome = currentTransactions.transactions
        .whereType<IncomeEntity>()
        .where((income) => income.recurring)
        .fold(0.0, (total, income) => total + income.amount.abs())
        .toRound(2);

    final bool incomeBasedOnRecurring = recurringIncome > 0.01;
    final double monthlyIncome;
    if (incomeBasedOnRecurring) {
      monthlyIncome = recurringIncome;
    } else if (incomeHistory.isNotEmpty) {
      monthlyIncome = (incomeHistory.fold<double>(
                0,
                (total, item) => total + item.incomes,
              ) /
              incomeHistory.length)
          .toRound(2);
    } else {
      monthlyIncome = (await currentData()).incomes.toRound(2);
    }

    final DateTime nextMonthStart = DateTime(now.year, now.month + 1, 1);
    final DateTime nextMonthEnd = _monthEnd(nextMonthStart);
    final double nextMonthCardBill = allBills
        .where((bill) =>
            bill.billAmount > 0.01 &&
            !bill.billDueDate.isBefore(nextMonthStart) &&
            !bill.billDueDate.isAfter(nextMonthEnd))
        .fold(0.0, (total, bill) => total + bill.billAmount.abs())
        .toRound(2);

    // Projeção do caminho para o verde. A leitura usa os mesmos tipos de
    // compromisso considerados pelo Radar: pendências, faturas abertas,
    // créditos planejados e compras planejadas. Em vez de uma divisão linear,
    // caminhamos mês a mês para descobrir quando a condição de cobertura se
    // sustenta dentro do horizonte escolhido (6/12/24 meses).
    final DateTime today = DateTime(now.year, now.month, now.day);
    final Set<String> includedAccounts = (await _accountFind.findAll(deleted: true))
        .where((account) => account.includeTotalBalance)
        .map((account) => account.id)
        .toSet();

    DateTime projectionDate(DateTime date) {
      final DateTime normalized = DateTime(date.year, date.month, date.day);
      return normalized.isBefore(today) ? today : normalized;
    }

    bool belongsToMonth(DateTime date, DateTime start, DateTime end) =>
        !date.isBefore(start) && !date.isAfter(end);

    bool accountIsIncluded(String? idAccount) =>
        idAccount == null || includedAccounts.contains(idAccount);

    double projectedBalance = availableBalance;
    final List<ReportGreenProjectionPoint> projection = [];
    final List<CardCashAdvancePlanEntity> plannedCashAdvances =
        allCashAdvanceOperations.where((plan) => plan.isPlanned).toList();

    for (int index = 0; index < _greenPathMonths; index++) {
      final DateTime monthStart = DateTime(now.year, now.month + index, 1);
      final DateTime monthEnd = _monthEnd(monthStart);
      double netMovement = 0;

      for (final ITransactionEntity transaction in pending) {
        final DateTime date = projectionDate(transaction.date);
        if (!belongsToMonth(date, monthStart, monthEnd)) continue;

        if (transaction is IncomeEntity &&
            !transaction.received &&
            accountIsIncluded(transaction.idAccount)) {
          netMovement += transaction.amount.abs();
        } else if (transaction is ExpenseEntity &&
            !transaction.paid &&
            transaction.idCreditCard == null &&
            accountIsIncluded(transaction.idAccount)) {
          netMovement -= transaction.amount.abs();
        }
      }

      for (final CreditCardBillEntity bill in openBills) {
        final DateTime date = projectionDate(bill.billDueDate);
        if (belongsToMonth(date, monthStart, monthEnd)) {
          netMovement -= bill.billAmount.abs();
        }
      }

      for (final CardCashAdvancePlanEntity plan in plannedCashAdvances) {
        final DateTime inflowDate = projectionDate(plan.plannedDate);
        if (includedAccounts.contains(plan.idAccount) &&
            belongsToMonth(inflowDate, monthStart, monthEnd)) {
          netMovement += plan.amountReceived.abs();
        }

        final DateTime chargeDate = projectionDate(plan.billDueDate);
        if (belongsToMonth(chargeDate, monthStart, monthEnd)) {
          netMovement -= plan.amountCharged.abs();
        }
      }

      for (final PlannedPurchaseEntity purchase in allPlannedPurchases) {
        if (purchase.isCreditCard) {
          for (final installment in purchase.installmentSchedule) {
            final DateTime dueDate = projectionDate(installment.dueDate);
            if (belongsToMonth(dueDate, monthStart, monthEnd)) {
              netMovement -= installment.amount.abs();
            }
          }
        } else if (accountIsIncluded(purchase.idAccount)) {
          final DateTime purchaseDate = projectionDate(purchase.plannedDate);
          if (belongsToMonth(purchaseDate, monthStart, monthEnd)) {
            netMovement -= purchase.amount.abs();
          }
        }
      }

      projectedBalance = (projectedBalance + netMovement).toRound(2);

      // Dívidas reais que ainda estariam abertas após o fechamento do mês.
      double remainingDebt = debtItems
          .where((item) => item.dueDate.isAfter(monthEnd))
          .fold(0.0, (total, item) => total + item.amount.abs());

      // Um planejamento ainda não é dívida hoje, mas passa a ser compromisso
      // projetado depois da data em que o usuário pretende realizá-lo. Isso
      // impede o relatório de declarar "verde" antes de uma obrigação futura
      // que já está cadastrada no Rallet.
      for (final CardCashAdvancePlanEntity plan in plannedCashAdvances) {
        if (!plan.plannedDate.isAfter(monthEnd) && plan.billDueDate.isAfter(monthEnd)) {
          remainingDebt += plan.amountCharged.abs();
        }
      }

      for (final PlannedPurchaseEntity purchase in allPlannedPurchases) {
        if (!purchase.isCreditCard || purchase.plannedDate.isAfter(monthEnd)) {
          continue;
        }
        remainingDebt += purchase.installmentSchedule
            .where((installment) => installment.dueDate.isAfter(monthEnd))
            .fold(0.0, (total, installment) => total + installment.amount.abs());
      }

      remainingDebt = remainingDebt.toRound(2);
      final double requiredCoverage =
          (remainingDebt + monthlyLivingCost).toRound(2);

      projection.add(
        ReportGreenProjectionPoint(
          month: monthStart,
          projectedBalance: projectedBalance,
          remainingDebt: remainingDebt,
          requiredCoverage: requiredCoverage,
          netMovement: netMovement.toRound(2),
        ),
      );
    }

    return ReportGreenPathEntity(
      calculatedAt: now,
      availableBalance: availableBalance,
      openDebt: openDebt,
      creditCardDebt: creditCardDebt,
      pendingExpenseDebt: pendingExpenseDebt,
      debtItems: debtItems,
      monthlyLivingCost: monthlyLivingCost,
      monthlyIncome: monthlyIncome,
      incomeBasedOnRecurring: incomeBasedOnRecurring,
      nonCardMonthlyCost: nonCardMonthlyCost,
      nextMonthCardBill: nextMonthCardBill,
      historyMonthsAnalyzed: historyMonthsAnalyzed,
      projectionMonths: _greenPathMonths,
      projection: projection,
    );
  }

  /// Regra única do painel:
  /// - receitas normais do mês entram mesmo se ainda estiverem pendentes;
  /// - despesas normais do mês entram mesmo se ainda estiverem pendentes;
  /// - pagamentos de fatura não são somados como despesa comum;
  /// - compras de cartão entram pelo mês de vencimento da fatura;
  /// - em crédito via cartão, somente juros/taxas entram como despesa do
  ///   relatório: principal recebido não é renda nem consumo;
  /// - custos de planejamentos entram no mês da fatura prevista, identificados
  ///   separadamente para permanecerem auditáveis.
  Future<_MonthReportData> _loadMonthData(
    DateTime month,
    List<CategoryEntity> expenseCategoriesAvailable,
    List<CardCashAdvancePlanEntity> allCashAdvanceOperations,
    List<PlannedPurchaseEntity> allPlannedPurchases,
  ) async {
    final DateTime start = _monthStart(month);
    final DateTime end = _monthEnd(month);

    final results = await Future.wait<dynamic>([
      _transactionFind.findByPeriod(start, end),
      _creditCardFind.findAllBillsByPeriod(start, end),
    ]);

    final TransactionsByPeriodEntity transactions =
        results[0] as TransactionsByPeriodEntity;
    final List<CreditCardBillEntity> bills =
        (results[1] as List).cast<CreditCardBillEntity>();

    final List<IncomeEntity> incomes =
        transactions.transactions.whereType<IncomeEntity>().toList();

    // Despesas geradas pelo pagamento da fatura possuem idCreditCard.
    // Elas são excluídas porque a própria fatura já é contabilizada abaixo.
    final List<ExpenseEntity> regularExpenseTransactions = transactions
        .transactions
        .whereType<ExpenseEntity>()
        .where((expense) => expense.idCreditCard == null)
        .toList();

    final double incomesAmount = incomes
        .map((income) => income.amount)
        .sum
        .toDouble()
        .toRound(2);

    final double regularExpenses = regularExpenseTransactions
        .map((expense) => expense.amount.abs())
        .sum
        .toDouble()
        .toRound(2);

    final List<ReportAuditItem> economicIncomeItems = incomes
        .map(
          (income) => ReportAuditItem(
            id: income.id,
            description: income.description.trim().isEmpty
                ? 'Receita'
                : income.description.trim(),
            date: income.date,
            amount: income.amount.abs().toRound(2),
            reason:
                'É uma receita cadastrada para este mês. Ela aumenta o resultado econômico, esteja já recebida ou ainda pendente.',
            treatment: ReportAuditTreatment.economicIncome,
            caseType: income.received
                ? ReportAuditCase.ordinary
                : ReportAuditCase.pendingIncome,
          ),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final List<ReportAuditItem> economicExpenseItems = regularExpenseTransactions
        .map(
          (expense) => ReportAuditItem(
            id: expense.id,
            description: expense.description.trim().isEmpty
                ? 'Despesa'
                : expense.description.trim(),
            date: expense.date,
            amount: expense.amount.abs().toRound(2),
            reason:
                'Representa consumo ou custo do período. Por isso reduz o resultado econômico mesmo quando ainda está pendente de pagamento.',
            treatment: ReportAuditTreatment.economicExpense,
            caseType: expense.paid
                ? ReportAuditCase.ordinary
                : ReportAuditCase.pendingExpense,
          ),
        )
        .toList();

    final List<ReportAuditItem> nonEconomicItems = [
      ...transactions.transactions.whereType<TransferEntity>().map(
            (transfer) => ReportAuditItem(
              id: transfer.id,
              description: 'Transferência entre contas',
              date: transfer.date,
              amount: transfer.amount.abs().toRound(2),
              reason:
                  'O dinheiro apenas mudou de uma conta sua para outra. A transferência altera onde o saldo está, mas não cria receita nem despesa econômica.',
              treatment: ReportAuditTreatment.neutral,
              caseType: ReportAuditCase.transfer,
            ),
          ),
      ...transactions.transactions
          .whereType<ExpenseEntity>()
          .where((expense) => expense.idCreditCard != null)
          .map(
            (expense) => ReportAuditItem(
              id: expense.id,
              description: expense.description.trim().isEmpty
                  ? 'Pagamento de fatura'
                  : expense.description.trim(),
              date: expense.date,
              amount: expense.amount.abs().toRound(2),
              reason:
                  'É uma saída real de caixa, mas não é somada novamente como nova despesa. As compras e custos que formaram a fatura são reconhecidos na competência da própria fatura, evitando dupla contagem.',
              treatment: ReportAuditTreatment.cashOutflowNotNewExpense,
              caseType: ReportAuditCase.billPayment,
            ),
          ),
    ];

    for (final CardCashAdvancePlanEntity plan in allCashAdvanceOperations) {
      if (!plan.linkedEntryBelongsToPeriod(start, end)) continue;
      nonEconomicItems.add(
        ReportAuditItem(
          id: '${plan.id}-principal-entry',
          description: plan.description.trim().isEmpty
              ? 'Crédito recebido pelo cartão'
              : 'Crédito recebido • ${plan.description.trim()}',
          date: plan.linkedEntryDate,
          amount: plan.amountReceived.abs().toRound(2),
          reason:
              'Origem: vínculo de crédito. ${plan.amountReceived.abs().toRound(2).money} ${plan.isPlanned ? 'estão previstos para entrar' : 'entraram'} em ${_dateLabel(plan.linkedEntryDate)} e geram uma obrigação de ${plan.amountCharged.abs().toRound(2).money} na fatura com vencimento em ${_dateLabel(plan.billDueDate)} (${_monthYear(plan.billDueDate)}). O principal não é renda no mês da entrada. Quando a fatura for reconhecida/paga, o principal não vira nova despesa; somente o custo financeiro de ${plan.financialCost.toRound(2).money} afeta o resultado econômico.',
          treatment: ReportAuditTreatment.cashInflowNotIncome,
          caseType: ReportAuditCase.cardCreditPrincipal,
          planned: plan.isPlanned,
          originLabel: 'Vínculo de crédito • ${plan.isPlanned ? 'entrada prevista' : 'entrada realizada'} em ${_dateLabel(plan.linkedEntryDate)}',
          relatedDateLabel: 'Fatura/obrigação',
          relatedDate: plan.billDueDate,
        ),
      );
    }
    nonEconomicItems.sort((a, b) => a.date.compareTo(b.date));

    // Diferença planejado x realizado só existe quando o usuário informou que
    // a mudança de valor representa a realidade, e não uma correção de cadastro.
    final List<ReportVarianceItem> varianceItems = [
      ...regularExpenseTransactions
          .where((expense) =>
              expense.paid &&
              expense.trackVariance &&
              expense.expectedAmount != null &&
              expense.varianceRegisteredAt != null &&
              expense.varianceAmount.abs() > 0.004)
          .map((expense) => ReportVarianceItem(
                id: expense.id,
                description: expense.description,
                date: expense.date,
                expectedAmount: expense.expectedAmount!.abs().toRound(2),
                realizedAmount: expense.realizedAmount.toRound(2),
                difference: expense.varianceAmount.toRound(2),
                expense: true,
              )),
      ...incomes
          .where((income) =>
              income.received &&
              income.trackVariance &&
              income.expectedAmount != null &&
              income.varianceRegisteredAt != null &&
              income.varianceAmount.abs() > 0.004)
          .map((income) => ReportVarianceItem(
                id: income.id,
                description: income.description,
                date: income.date,
                expectedAmount: income.expectedAmount!.abs().toRound(2),
                realizedAmount: income.amount.abs().toRound(2),
                difference: income.varianceAmount.toRound(2),
                expense: false,
              )),
    ]..sort((a, b) => a.date.compareTo(b.date));

    double creditCardPurchases = 0;
    double realizedFinancialCosts = 0;

    for (final CreditCardBillEntity bill in bills) {
      for (final CreditCardTransactionEntity transaction
          in bill.transactions.where((tx) => tx.amount > 0)) {
        final double reportAmount =
            _reportableCreditCardExpense(transaction).toRound(2);
        if (transaction.cashAdvancePlanId != null) {
          realizedFinancialCosts += reportAmount;
          if (reportAmount > 0) {
            economicExpenseItems.add(
              ReportAuditItem(
                id: '${transaction.id}-financial-cost',
                description: 'Custo financeiro • ${transaction.description}',
                date: bill.billDueDate,
                amount: reportAmount,
                reason:
                    'No crédito recebido pelo cartão, o principal não é despesa. Somente a diferença cobrada acima do valor recebido — juros e taxas — reduz o resultado econômico.',
                treatment: ReportAuditTreatment.economicExpense,
                caseType: ReportAuditCase.creditCardPurchase,
              ),
            );
          }
        } else if (transaction.plannedPurchaseId != null) {
          final double principal =
              (transaction.plannedPurchasePrincipal ?? transaction.amount.abs())
                  .clamp(0, transaction.amount.abs())
                  .toDouble()
                  .toRound(2);
          final double cost =
              (transaction.amount.abs() - principal)
                  .clamp(0, double.infinity)
                  .toDouble()
                  .toRound(2);
          creditCardPurchases += principal;
          realizedFinancialCosts += cost;

          if (principal > 0) {
            economicExpenseItems.add(
              ReportAuditItem(
                id: '${transaction.id}-principal',
                description: transaction.description,
                date: bill.billDueDate,
                amount: principal,
                reason:
                    'É o valor principal da compra no cartão. A despesa é reconhecida na competência da fatura; pagar a fatura depois apenas quita essa obrigação e não cria outra despesa.',
                treatment: ReportAuditTreatment.economicExpense,
                caseType: ReportAuditCase.creditCardPurchase,
              ),
            );
          }
          if (cost > 0) {
            economicExpenseItems.add(
              ReportAuditItem(
                id: '${transaction.id}-installment-cost',
                description: 'Custo do parcelamento • ${transaction.description}',
                date: bill.billDueDate,
                amount: cost,
                reason:
                    'É um custo financeiro adicional da compra parcelada. Diferentemente do pagamento da fatura, esse valor é uma nova despesa econômica.',
                treatment: ReportAuditTreatment.economicExpense,
                caseType: ReportAuditCase.creditCardPurchase,
              ),
            );
          }
        } else {
          creditCardPurchases += reportAmount;
          if (reportAmount > 0) {
            economicExpenseItems.add(
              ReportAuditItem(
                id: transaction.id,
                description: transaction.description,
                date: bill.billDueDate,
                amount: reportAmount,
                reason:
                    'É uma compra no cartão. O custo é reconhecido no mês de vencimento da fatura; o pagamento da fatura não é contado novamente.',
                treatment: ReportAuditTreatment.economicExpense,
                caseType: ReportAuditCase.creditCardPurchase,
              ),
            );
          }
        }
      }
    }

    creditCardPurchases = creditCardPurchases.toRound(2);
    realizedFinancialCosts = realizedFinancialCosts.toRound(2);

    final List<CardCashAdvancePlanEntity> operationsInMonth =
        allCashAdvanceOperations
            .where(
              (plan) =>
                  !plan.billDueDate.isBefore(start) &&
                  !plan.billDueDate.isAfter(end),
            )
            .toList();

    final List<CardCashAdvancePlanEntity> plannedOperationsInMonth =
        operationsInMonth.where((plan) => plan.isPlanned).toList();

    final double plannedCashAdvanceFinancialCosts = plannedOperationsInMonth
        .fold(0.0, (total, plan) => total + plan.financialCost)
        .toRound(2);

    final List<PlannedPurchaseEntity> plannedPurchasesInMonth =
        allPlannedPurchases
            .where((purchase) => purchase.amountDueInPeriod(start, end) > 0)
            .toList();

    final List<ReportPlannedExpenseItem> plannedExpenseItems =
        plannedPurchasesInMonth.map((purchase) {
      final CategoryEntity? category = expenseCategoriesAvailable
          .firstWhereOrNull((item) => item.id == purchase.idCategory);
      final DateTime consideredDate = purchase.isCreditCard
          ? purchase.installmentSchedule
              .firstWhere((item) =>
                  !item.dueDate.isBefore(start) && !item.dueDate.isAfter(end))
              .dueDate
          : purchase.plannedDate;
      final String paymentLabel = purchase.isCreditCard
          ? (purchase.isInstallment
              ? '${purchase.installmentCount}x no cartão'
              : 'Cartão à vista')
          : 'À vista';
      return ReportPlannedExpenseItem(
        id: purchase.id,
        description: purchase.description,
        categoryName: category?.description ?? 'Sem categoria',
        paymentLabel: paymentLabel,
        amount: purchase.amountDueInPeriod(start, end).toRound(2),
        date: consideredDate,
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final double plannedPurchases = plannedPurchasesInMonth
        .fold(0.0, (total, purchase) =>
            total + purchase.principalDueInPeriod(start, end))
        .toRound(2);

    final double plannedPurchaseFinancialCosts = plannedPurchasesInMonth
        .fold(0.0, (total, purchase) =>
            total + purchase.financialCostDueInPeriod(start, end))
        .toRound(2);

    final double plannedFinancialCosts =
        (plannedCashAdvanceFinancialCosts + plannedPurchaseFinancialCosts)
            .toRound(2);

    for (final CardCashAdvancePlanEntity plan in plannedOperationsInMonth) {
      if (plan.financialCost <= 0) continue;
      economicExpenseItems.add(
        ReportAuditItem(
          id: '${plan.id}-planned-financial-cost',
          description: plan.description.trim().isEmpty
              ? 'Custo planejado de crédito via cartão'
              : 'Custo planejado • ${plan.description.trim()}',
          date: plan.billDueDate,
          amount: plan.financialCost.toRound(2),
          reason:
              'A entrada principal do crédito não é receita. Para a projeção econômica entra somente o custo previsto da operação, isto é, juros e taxas.',
          treatment: ReportAuditTreatment.economicExpense,
          caseType: ReportAuditCase.plannedCardCharge,
          planned: true,
        ),
      );
    }

    for (final PlannedPurchaseEntity purchase in plannedPurchasesInMonth) {
      final double principal = purchase.principalDueInPeriod(start, end).toRound(2);
      final double cost = purchase.financialCostDueInPeriod(start, end).toRound(2);
      final DateTime consideredDate = purchase.isCreditCard
          ? purchase.installmentSchedule
              .firstWhere((item) =>
                  !item.dueDate.isBefore(start) && !item.dueDate.isAfter(end))
              .dueDate
          : purchase.plannedDate;

      if (principal > 0) {
        economicExpenseItems.add(
          ReportAuditItem(
            id: '${purchase.id}-planned-principal-${start.year}-${start.month}',
            description: 'Planejamento • ${purchase.description}',
            date: consideredDate,
            amount: principal,
            reason:
                'É uma despesa planejada que pertence a este mês. Ela entra na visão prevista para mostrar o custo econômico esperado antes da realização.',
            treatment: ReportAuditTreatment.economicExpense,
            caseType: ReportAuditCase.plannedExpense,
            planned: true,
          ),
        );
      }
      if (cost > 0) {
        economicExpenseItems.add(
          ReportAuditItem(
            id: '${purchase.id}-planned-cost-${start.year}-${start.month}',
            description: 'Custo planejado • ${purchase.description}',
            date: consideredDate,
            amount: cost,
            reason:
                'É o custo financeiro previsto do parcelamento. Como representa juros/taxas adicionais, reduz o resultado econômico do mês.',
            treatment: ReportAuditTreatment.economicExpense,
            caseType: ReportAuditCase.plannedExpense,
            planned: true,
          ),
        );
      }
    }
    economicExpenseItems.sort((a, b) => a.date.compareTo(b.date));

    final double creditCardExpenses = (
      creditCardPurchases +
      realizedFinancialCosts +
      plannedFinancialCosts
    ).toRound(2);

    final double expenses = (regularExpenses + creditCardExpenses + plannedPurchases).toRound(2);

    double fixedExpenses = regularExpenseTransactions
        .where((expense) => expense.recurring)
        .map((expense) => expense.amount.abs())
        .sum
        .toDouble();

    final List<ITransactionEntity> consideredExpenseTransactions = [
      ...regularExpenseTransactions,
    ];

    // Planejamento ainda não gerou transação de cartão. Para que a composição
    // por categoria feche com o resumo, representamos SOMENTE o custo financeiro
    // na categoria "Outros", claramente marcado como planejamento.
    for (final CardCashAdvancePlanEntity plan in plannedOperationsInMonth) {
      if (plan.financialCost <= 0) continue;

      consideredExpenseTransactions.add(
        CreditCardTransactionEntity(
          id: plan.id,
          createdAt: plan.createdAt,
          deletedAt: null,
          description: 'Juros planejados • ${plan.description}',
          amount: -plan.financialCost.toRound(2),
          date: plan.billDueDate,
          idCategory: categoryOthersUuidExpense,
          idCreditCard: plan.idCreditCard,
          idCreditCardBill: null,
          observation: 'Planejamento de crédito via cartão',
          installmentGroupId: null,
          installmentNumber: null,
          installmentCount: null,
          cashAdvancePlanId: plan.id,
          cashAdvancePrincipal: plan.amountReceived,
        ),
      );
    }

    for (final PlannedPurchaseEntity purchase in plannedPurchasesInMonth) {
      if (purchase.isCreditCard) {
        final principalValues = purchase.principalInstallmentAmounts;
        final costValues = purchase.financialCostInstallmentAmounts;
        final schedule = purchase.installmentSchedule;
        for (int index = 0; index < schedule.length; index++) {
          final installment = schedule[index];
          if (installment.dueDate.isBefore(start) || installment.dueDate.isAfter(end)) continue;
          final double principal = principalValues[index];
          final double cost = costValues[index];
          if (principal > 0) {
            consideredExpenseTransactions.add(
              ExpenseEntity(
                id: '${purchase.id}-${installment.number}-principal',
                createdAt: purchase.createdAt,
                deletedAt: null,
                description: 'Despesa planejada • ${purchase.description} (${installment.number}/${purchase.installmentCount})',
                amount: principal,
                date: installment.dueDate,
                paid: false,
                observation: purchase.observation ?? 'Planejamento de despesa no cartão',
                idAccount: null,
                idCategory: purchase.idCategory ?? categoryOthersUuidExpense,
                idCreditCard: null,
                idCreditCardTransaction: null,
              ),
            );
          }
          if (cost > 0) {
            consideredExpenseTransactions.add(
              ExpenseEntity(
                id: '${purchase.id}-${installment.number}-cost',
                createdAt: purchase.createdAt,
                deletedAt: null,
                description: 'Juros do parcelamento • ${purchase.description}',
                amount: cost,
                date: installment.dueDate,
                paid: false,
                observation: 'Custo financeiro de despesa planejada',
                idAccount: null,
                idCategory: categoryOthersUuidExpense,
                idCreditCard: null,
                idCreditCardTransaction: null,
              ),
            );
          }
        }
      } else {
        consideredExpenseTransactions.add(
          ExpenseEntity(
            id: purchase.id,
            createdAt: purchase.createdAt,
            deletedAt: null,
            description: 'Despesa planejada • ${purchase.description}',
            amount: purchase.amount,
            date: purchase.plannedDate,
            paid: false,
            observation: purchase.observation ?? 'Planejamento de despesa',
            idAccount: purchase.idAccount,
            idCategory: purchase.idCategory ?? categoryOthersUuidExpense,
            idCreditCard: null,
            idCreditCardTransaction: null,
          ),
        );
      }
    }

    for (final CreditCardBillEntity bill in bills) {
      for (final CreditCardTransactionEntity transaction
          in bill.transactions.where((transaction) => transaction.amount > 0)) {
        final double reportAmount =
            _reportableCreditCardExpense(transaction).toRound(2);
        if (reportAmount <= 0) continue;

        final CreditCardTransactionEntity expenseTransaction =
            transaction.clone()
              ..amount = -reportAmount
              // No relatório, a competência do cartão é o vencimento da fatura.
              ..date = bill.billDueDate;

        consideredExpenseTransactions.add(expenseTransaction);

        if (transaction.isInstallment && transaction.cashAdvancePlanId == null) {
          fixedExpenses += reportAmount;
        }
      }
    }

    fixedExpenses = fixedExpenses.toRound(2);
    final double variableExpenses =
        (expenses - fixedExpenses)
            .clamp(0, double.infinity)
            .toDouble()
            .toRound(2);

    final Map<String, List<ITransactionEntity>> grouped = groupBy(
      consideredExpenseTransactions,
      (transaction) => transaction is ExpenseEntity
          ? transaction.idCategory ?? ''
          : (transaction as CreditCardTransactionEntity).idCategory ?? '',
    );

    final List<ReportCategoryEntity> expenseCategories = [];

    grouped.forEach((String idCategory, List<ITransactionEntity> values) {
      if (idCategory.isEmpty) return;

      final CategoryEntity? category = expenseCategoriesAvailable
          .firstWhereOrNull((category) => category.id == idCategory);

      if (category == null) return;

      expenseCategories.add(
        ReportCategoryEntity(
          category: category,
          transactions: values,
        ),
      );
    });

    expenseCategories.sort(
      (a, b) => b.amount.abs().compareTo(a.amount.abs()),
    );

    final List<ReportFinancialCostItem> realizedPurchaseCostItems = [];
    for (final CreditCardBillEntity bill in bills) {
      for (final CreditCardTransactionEntity transaction in
          bill.transactions.where((tx) => tx.amount > 0 && tx.plannedPurchaseId != null)) {
        final double principal =
            (transaction.plannedPurchasePrincipal ?? transaction.amount.abs())
                .clamp(0, transaction.amount.abs())
                .toDouble()
                .toRound(2);
        final double cost =
            (transaction.amount.abs() - principal)
                .clamp(0, double.infinity)
                .toDouble()
                .toRound(2);
        if (cost <= 0) continue;
        realizedPurchaseCostItems.add(
          ReportFinancialCostItem(
            id: transaction.id,
            description: 'Parcelamento • ${transaction.description}',
            amountReceived: principal,
            amountCharged: transaction.amount.abs().toRound(2),
            financialCost: cost,
            billDueDate: bill.billDueDate,
            planned: false,
            purchaseInstallment: true,
          ),
        );
      }
    }

    final List<ReportFinancialCostItem> financialCostItems = [
      ...realizedPurchaseCostItems,
      ...operationsInMonth
          .where((plan) => plan.financialCost > 0)
          .map(
            (plan) => ReportFinancialCostItem(
              id: plan.id,
              description: plan.description.trim().isEmpty
                  ? 'Crédito via cartão'
                  : plan.description.trim(),
              amountReceived: plan.amountReceived.toRound(2),
              amountCharged: plan.amountCharged.toRound(2),
              financialCost: plan.financialCost.toRound(2),
              billDueDate: plan.billDueDate,
              planned: plan.isPlanned,
            ),
          ),
      ...plannedPurchasesInMonth
          .where((purchase) => purchase.financialCostDueInPeriod(start, end) > 0)
          .map((purchase) {
            final double principal = purchase.principalDueInPeriod(start, end);
            final double cost = purchase.financialCostDueInPeriod(start, end);
            final DateTime dueDate = purchase.installmentSchedule
                .firstWhere((item) =>
                    !item.dueDate.isBefore(start) && !item.dueDate.isAfter(end))
                .dueDate;
            return ReportFinancialCostItem(
              id: '${purchase.id}-${start.year}-${start.month}',
              description: 'Parcelamento • ${purchase.description}',
              amountReceived: principal,
              amountCharged: (principal + cost).toRound(2),
              financialCost: cost,
              billDueDate: dueDate,
              planned: true,
              purchaseInstallment: true,
            );
          }),
    ]..sort((a, b) => a.billDueDate.compareTo(b.billDueDate));

    return _MonthReportData(
      incomes: incomesAmount,
      expenses: expenses,
      regularExpenses: regularExpenses,
      creditCardPurchases: creditCardPurchases,
      realizedFinancialCosts: realizedFinancialCosts,
      plannedFinancialCosts: plannedFinancialCosts,
      plannedPurchases: plannedPurchases,
      creditCardExpenses: creditCardExpenses,
      fixedExpenses: fixedExpenses,
      variableExpenses: variableExpenses,
      expenseCategories: expenseCategories,
      financialCostItems: financialCostItems,
      plannedExpenseItems: plannedExpenseItems,
      varianceItems: varianceItems,
      economicIncomeItems: economicIncomeItems,
      economicExpenseItems: economicExpenseItems,
      nonEconomicItems: nonEconomicItems,
    );
  }

  double _reportableCreditCardExpense(
    CreditCardTransactionEntity transaction,
  ) {
    if (transaction.cashAdvancePlanId == null) {
      return transaction.amount.abs().toRound(2);
    }

    final double principal = transaction.cashAdvancePrincipal ?? 0;
    return (transaction.amount.abs() - principal)
        .clamp(0, double.infinity)
        .toDouble()
        .toRound(2);
  }
}

class _MonthReportData {
  final double incomes;
  final double expenses;
  final double regularExpenses;
  final double creditCardPurchases;
  final double realizedFinancialCosts;
  final double plannedFinancialCosts;
  final double plannedPurchases;
  final double creditCardExpenses;
  final double fixedExpenses;
  final double variableExpenses;
  final List<ReportCategoryEntity> expenseCategories;
  final List<ReportFinancialCostItem> financialCostItems;
  final List<ReportPlannedExpenseItem> plannedExpenseItems;
  final List<ReportVarianceItem> varianceItems;
  final List<ReportAuditItem> economicIncomeItems;
  final List<ReportAuditItem> economicExpenseItems;
  final List<ReportAuditItem> nonEconomicItems;

  const _MonthReportData({
    required this.incomes,
    required this.expenses,
    required this.regularExpenses,
    required this.creditCardPurchases,
    required this.realizedFinancialCosts,
    required this.plannedFinancialCosts,
    required this.plannedPurchases,
    required this.creditCardExpenses,
    required this.fixedExpenses,
    required this.variableExpenses,
    required this.expenseCategories,
    required this.financialCostItems,
    required this.plannedExpenseItems,
    required this.varianceItems,
    required this.economicIncomeItems,
    required this.economicExpenseItems,
    required this.nonEconomicItems,
  });
}
