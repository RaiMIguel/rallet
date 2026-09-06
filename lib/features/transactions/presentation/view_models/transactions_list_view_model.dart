import 'package:rallet/features/account/domain/entities/account_entity.dart';
import 'package:rallet/features/account/domain/use_cases/i_account_find.dart';
import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/card_cash_advance/domain/use_cases/i_card_cash_advance.dart';
import 'package:rallet/features/category/domain/entities/category_entity.dart';
import 'package:rallet/features/category/domain/enums/category_type_enum.dart';
import 'package:rallet/features/category/domain/use_cases/i_category_find.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_find.dart';
import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';
import 'package:rallet/features/purchase_planning/domain/use_cases/i_purchase_planning.dart';
import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/entities/i_transaction_entity.dart';
import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/domain/entities/transfer_entity.dart';
import 'package:rallet/features/transactions/domain/entities/transactions_by_period_entity.dart';
import 'package:rallet/features/transactions/domain/enums/recurrence_scope_enum.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_expense_save.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_income_save.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_transaction_delete.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_transaction_find.dart';
import 'package:rallet/shared/extensions/date_time_extension.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/presentation/commands/command.dart';
import 'package:flutter/foundation.dart';

enum TransactionStatusFilter { all, realized, pending, planned }

typedef InitParams = ({DateTime startDate, DateTime endDate, Set<CategoryTypeEnum?> filterType});
typedef FindByPeriodParams = ({DateTime startDate, DateTime endDate});
typedef DeleteTransactionsParams = ({List<ITransactionEntity> transactions, RecurrenceScopeEnum recurrenceScope});

class TransactionsListViewModel extends ChangeNotifier {
  final ITransactionFind _transactionFind;
  final ICategoryFind _categoryFind;
  final IAccountFind _accountFind;
  final IExpenseSave _expenseSave;
  final IIncomeSave _incomeSave;
  final IPurchasePlanning _purchasePlanning;
  final ICreditCardFind _creditCardFind;
  final ICardCashAdvance _cashAdvance;

  late final Command1<void, InitParams> init;
  late final Command1<void, FindByPeriodParams> findByPeriod;
  late final Command1<void, DeleteTransactionsParams> deleteTransactions;

  TransactionsListViewModel({
    required ITransactionFind transactionFind,
    required ITransactionDelete transactionDelete,
    required ICategoryFind categoryFind,
    required IAccountFind accountFind,
    required IExpenseSave expenseSave,
    required IIncomeSave incomeSave,
    required IPurchasePlanning purchasePlanning,
    required ICreditCardFind creditCardFind,
    required ICardCashAdvance cashAdvance,
  })  : _transactionFind = transactionFind,
        _categoryFind = categoryFind,
        _accountFind = accountFind,
        _expenseSave = expenseSave,
        _incomeSave = incomeSave,
        _purchasePlanning = purchasePlanning,
        _creditCardFind = creditCardFind,
        _cashAdvance = cashAdvance {
    init = Command1(_init);
    findByPeriod = Command1(_findByPeriod);
    deleteTransactions = Command1((params) => transactionDelete.deleteTransactions(
          params.transactions,
          recurrenceScope: params.recurrenceScope,
        ));
  }

  DateTime _startDate = DateTime.now().getInitialMonth();

  DateTime get startDate => _startDate;

  DateTime _endDate = DateTime.now().getFinalMonth();

  DateTime get endDate => _endDate;

  List<CategoryEntity> _categories = [];

  List<CategoryEntity> get categories => _categories;

  List<AccountEntity> _accounts = [];

  List<AccountEntity> get accounts => _accounts;

  List<CreditCardBillEntity> _forecastBills = [];
  List<CreditCardBillEntity> get forecastBills =>
      _statusFilter == TransactionStatusFilter.all ||
              _statusFilter == TransactionStatusFilter.pending
          ? _forecastBills
          : const [];

  List<CardCashAdvancePlanEntity> _forecastCashAdvancePlans = [];
  List<CardCashAdvancePlanEntity> get forecastCashAdvancePlans =>
      _statusFilter == TransactionStatusFilter.all ||
              _statusFilter == TransactionStatusFilter.planned
          ? _forecastCashAdvancePlans
          : const [];

  List<CreditCardEntity> _creditCards = [];
  List<CreditCardEntity> get creditCards => _creditCards;

  CreditCardEntity? creditCardById(String id) =>
      _creditCards.where((card) => card.id == id).firstOrNull;

  AccountEntity? accountById(String id) =>
      _accounts.where((account) => account.id == id).firstOrNull;

  List<CardCashAdvancePlanEntity> _realizedCashAdvances = [];
  List<CardCashAdvancePlanEntity> _plannedLinkedCashAdvances = [];

  /// Entradas futuras de crédito via cartão. Elas aparecem na visão de Receitas
  /// como movimentação vinculada prevista, mas continuam fora do total de
  /// receitas porque crédito não é renda.
  List<CardCashAdvancePlanEntity> get plannedLinkedCashAdvances {
    if (_filterType.firstOrNull == CategoryTypeEnum.expense) return const [];
    if (_statusFilter != TransactionStatusFilter.all &&
        _statusFilter != TransactionStatusFilter.planned) {
      return const [];
    }
    return _plannedLinkedCashAdvances;
  }

  /// Operações de crédito que movimentaram uma conta de verdade. Elas aparecem
  /// em Transações apenas como uma visão vinculada, sem virar IncomeEntity e
  /// sem inflar a receita mensal.
  List<CardCashAdvancePlanEntity> get realizedCashAdvances {
    // Crédito via cartão é uma entrada real na conta, mas não é receita
    // econômica. Por isso ele aparece tanto em "Todas" quanto em "Receitas"
    // como movimentação vinculada, sem entrar no total de receitas.
    if (_filterType.firstOrNull == CategoryTypeEnum.expense) return const [];
    if (_statusFilter != TransactionStatusFilter.all &&
        _statusFilter != TransactionStatusFilter.realized) {
      return const [];
    }
    return _realizedCashAdvances;
  }

  TransactionStatusFilter _statusFilter = TransactionStatusFilter.all;
  TransactionStatusFilter get statusFilter => _statusFilter;

  Set<CategoryTypeEnum?> _filterType = {null};

  Set<CategoryTypeEnum?> get filterType => _filterType;

  TransactionsByPeriodEntity _transactionsByPeriod = TransactionsByPeriodEntity(transactions: []);

  TransactionsByPeriodEntity get transactionsByPeriod => _transactionsByPeriod;

  List<PlannedPurchaseEntity> _plannedExpenses = [];

  /// Despesas ainda planejadas que afetam o período selecionado. Elas são
  /// exibidas separadas para não parecerem lançamentos já realizados.
  List<PlannedPurchaseEntity> get plannedExpenses {
    if (_filterType.firstOrNull == CategoryTypeEnum.income) return const [];
    if (_statusFilter != TransactionStatusFilter.all &&
        _statusFilter != TransactionStatusFilter.planned) {
      return const [];
    }
    return _plannedExpenses;
  }

  double get plannedExpensesAmount => _plannedExpenses
      .fold(0.0, (total, plan) => total + plan.amountDueInPeriod(_startDate, _endDate));

  bool get selectedPeriodUsesForecast {
    final DateTime currentMonth = DateTime.now().getInitialMonth();
    return !_startDate.isBefore(currentMonth);
  }

  bool get selectedPeriodIsPast => !selectedPeriodUsesForecast;

  double get monthlyIncomeRealized =>
      _transactionsByPeriod.amountsIncome.toRound(2);

  double get monthlyExpenseRealized =>
      _transactionsByPeriod.amountsExpense.toRound(2);

  /// Receita prevista = receitas cadastradas para o mês, realizadas ou ainda
  /// a receber. Entradas de crédito via cartão continuam fora daqui porque
  /// crédito não é renda no modelo financeiro do Rallet.
  double get monthlyIncomeForecast => _transactionsByPeriod.transactions
      .whereType<IncomeEntity>()
      .fold(0.0, (total, income) => total + income.amount)
      .toRound(2);

  /// Despesas comuns do mês. Pagamentos de fatura são excluídos porque a
  /// despesa econômica do cartão é apurada pela própria fatura, evitando
  /// contar a mesma saída duas vezes.
  double get monthlyRegisteredExpensesForecast => _transactionsByPeriod
      .transactions
      .whereType<ExpenseEntity>()
      .where((expense) => expense.idCreditCard == null)
      .fold(0.0, (total, expense) => total + expense.amount.abs())
      .toRound(2);

  double _monthlyCreditCardPurchasesForecast = 0;
  double get monthlyCreditCardPurchasesForecast =>
      _monthlyCreditCardPurchasesForecast;

  double _monthlyRealizedFinancialCostsForecast = 0;
  double get monthlyRealizedFinancialCostsForecast =>
      _monthlyRealizedFinancialCostsForecast;

  double _monthlyPlannedFinancialCostsForecast = 0;
  double get monthlyPlannedFinancialCostsForecast =>
      _monthlyPlannedFinancialCostsForecast;

  double _monthlyPlannedPurchasesForecast = 0;
  double get monthlyPlannedPurchasesForecast =>
      _monthlyPlannedPurchasesForecast;

  /// Mantido para a lista de compromissos previstos. Não é usado diretamente
  /// no balanço econômico, pois pagar uma fatura não cria uma nova despesa.
  double get monthlyOpenBillsForecast => _forecastBills
      .where((bill) => bill.billAmount > 0)
      .fold(0.0, (total, bill) => total + bill.billAmount.abs())
      .toRound(2);

  double get monthlyPlannedCreditChargesForecast =>
      _forecastCashAdvancePlans
          .fold(0.0, (total, plan) => total + plan.amountCharged.abs())
          .toRound(2);

  /// Para mês atual/futuro, o resumo segue a mesma semântica econômica usada
  /// na Home: despesa comum + compras no cartão + custos financeiros +
  /// planejamentos. Pagamento da fatura e principal de crédito não são
  /// contados novamente como despesa/receita.
  double get monthlyExpenseForecast => -(
        monthlyRegisteredExpensesForecast +
        monthlyCreditCardPurchasesForecast +
        monthlyRealizedFinancialCostsForecast +
        monthlyPlannedFinancialCostsForecast +
        monthlyPlannedPurchasesForecast
      ).toRound(2);

  double get monthlyIncomeForSummary => selectedPeriodUsesForecast
      ? monthlyIncomeForecast
      : monthlyIncomeRealized;

  double get monthlyExpenseForSummary => selectedPeriodUsesForecast
      ? monthlyExpenseForecast
      : monthlyExpenseRealized;

  double get monthlyBalanceForSummary =>
      (monthlyIncomeForSummary + monthlyExpenseForSummary).toRound(2);

  List<ITransactionEntity> get transactions {
    Iterable<ITransactionEntity> values = _transactionsByPeriod.transactions;

    if (_filterType.firstOrNull == CategoryTypeEnum.expense) {
      values = values.whereType<ExpenseEntity>();
    } else if (_filterType.firstOrNull == CategoryTypeEnum.income) {
      values = values.whereType<IncomeEntity>();
    }

    switch (_statusFilter) {
      case TransactionStatusFilter.realized:
        values = values.where((transaction) =>
            transaction is TransferEntity ||
            (transaction is ExpenseEntity && transaction.paid) ||
            (transaction is IncomeEntity && transaction.received));
        break;
      case TransactionStatusFilter.pending:
        values = values.where((transaction) =>
            (transaction is ExpenseEntity && !transaction.paid) ||
            (transaction is IncomeEntity && !transaction.received));
        break;
      case TransactionStatusFilter.planned:
        // Planejamentos são exibidos em blocos próprios, nunca transformados em
        // transações reais apenas para atender ao filtro.
        values = const <ITransactionEntity>[];
        break;
      case TransactionStatusFilter.all:
        break;
    }

    return values.toList();
  }

  double _periodBalanceBase = 0;
  double get periodBalanceBase => _periodBalanceBase;

  double _periodPendingIncome = 0;
  double get periodPendingIncome => _periodPendingIncome;

  double _periodPendingExpense = 0;
  double get periodPendingExpense => _periodPendingExpense;

  double _periodBillsAmount = 0;
  double get periodBillsAmount => _periodBillsAmount;

  double _periodClosingBalance = 0;
  double get periodClosingBalance => _periodClosingBalance;

  // Resumos de caixa da aba Receitas/Despesas. Diferem dos totais econômicos:
  // A receber/A pagar representam valores ainda pendentes de movimentar caixa
  // no mês selecionado. Crédito planejado entra aqui como caixa, mas continua
  // fora de Receita; pagamento/fatura entra em A pagar sem virar nova despesa.
  double _monthlyPendingIncomeReceivable = 0;
  double get monthlyPendingIncomeReceivable => _monthlyPendingIncomeReceivable;

  double _monthlyPlannedCreditReceivable = 0;
  double get monthlyPlannedCreditReceivable => _monthlyPlannedCreditReceivable;

  double get monthlyReceivableForSummary =>
      (_monthlyPendingIncomeReceivable + _monthlyPlannedCreditReceivable)
          .toRound(2);

  double _monthlyPendingExpensesPayable = 0;
  double get monthlyPendingExpensesPayable => _monthlyPendingExpensesPayable;

  double _monthlyOpenBillsPayable = 0;
  double get monthlyOpenBillsPayable => _monthlyOpenBillsPayable;

  double _monthlyPlannedCreditChargesPayable = 0;
  double get monthlyPlannedCreditChargesPayable =>
      _monthlyPlannedCreditChargesPayable;

  double _monthlyPlannedExpensesPayable = 0;
  double get monthlyPlannedExpensesPayable => _monthlyPlannedExpensesPayable;

  double get monthlyPayableForSummary => (
        _monthlyPendingExpensesPayable +
        _monthlyOpenBillsPayable +
        _monthlyPlannedCreditChargesPayable +
        _monthlyPlannedExpensesPayable
      ).toRound(2);

  /// Alias mantido para compatibilidade com componentes antigos. Agora aponta
  /// para o saldo contextual do mês, e não para a soma global de extratos.
  double get monthlyBalanceCumulative => periodClosingBalance;

  Future<void> _init(InitParams params) async {
    _filterType = params.filterType;
    _startDate = params.startDate;
    _endDate = params.endDate;

    await Future.wait([
      _categoryFind.findAll(deleted: true).then((value) => _categories = value),
      _accountFind.findAll(deleted: true).then((value) => _accounts = value),
      _findByPeriod((startDate: params.startDate, endDate: params.endDate)),
    ]);
  }

  Future<void> _findByPeriod(FindByPeriodParams params) async {
    _startDate = params.startDate;
    _endDate = params.endDate;

    final results = await Future.wait<dynamic>([
      _transactionFind.findByPeriod(startDate, endDate),
      _purchasePlanning.findAll(),
      _creditCardFind.findBillsByPeriod(startDate, endDate),
      _cashAdvance.findAll(),
      _creditCardFind.findAll(),
      _creditCardFind.findAllBillsByPeriod(startDate, endDate),
      _transactionFind.findUnpaidUnreceived(),
    ]);

    _transactionsByPeriod = results[0] as TransactionsByPeriodEntity;
    final List<PlannedPurchaseEntity> allPlannedPurchases =
        (results[1] as List).cast<PlannedPurchaseEntity>();
    _plannedExpenses = allPlannedPurchases
        .cast<PlannedPurchaseEntity>()
        .where((plan) => plan.amountDueInPeriod(startDate, endDate) > 0)
        .toList()
      ..sort((a, b) => a.plannedDate.compareTo(b.plannedDate));

    _forecastBills = (results[2] as List)
        .cast<CreditCardBillEntity>()
        .where((bill) => bill.billAmount > 0)
        .toList()
      ..sort((a, b) => a.billDueDate.compareTo(b.billDueDate));

    final List<CardCashAdvancePlanEntity> allCashAdvances =
        (results[3] as List).cast<CardCashAdvancePlanEntity>();
    _forecastCashAdvancePlans = allCashAdvances
        .where((plan) =>
            plan.isPlanned &&
            !plan.billDueDate.isBefore(startDate) &&
            !plan.billDueDate.isAfter(endDate))
        .toList()
      ..sort((a, b) => a.billDueDate.compareTo(b.billDueDate));

    _realizedCashAdvances = allCashAdvances.where((plan) {
      if (!plan.isRealized) return false;
      return plan.linkedEntryBelongsToPeriod(startDate, endDate);
    }).toList()
      ..sort((a, b) =>
          b.linkedEntryDate.compareTo(a.linkedEntryDate));

    _plannedLinkedCashAdvances = allCashAdvances.where((plan) {
      if (!plan.isPlanned) return false;
      return plan.linkedEntryBelongsToPeriod(startDate, endDate);
    }).toList()
      ..sort((a, b) => a.plannedDate.compareTo(b.plannedDate));

    _creditCards = (results[4] as List).cast<CreditCardEntity>();

    final List<CreditCardBillEntity> allBillsForPeriod =
        (results[5] as List).cast<CreditCardBillEntity>();

    _calculateMonthlyEconomicForecast(
      bills: allBillsForPeriod,
      plannedOperations: allCashAdvances.where((plan) => plan.isPlanned).toList(),
      plannedPurchases: allPlannedPurchases,
    );

    final List<ITransactionEntity> pendingTransactions =
        (results[6] as List).cast<ITransactionEntity>();
    _calculateMonthlyReceivableAndPayable(
      pendingTransactions: pendingTransactions,
      plannedOperations: allCashAdvances.where((plan) => plan.isPlanned).toList(),
      plannedPurchases: allPlannedPurchases,
    );

    await _loadPeriodBalanceProjection(_startDate.getInitialMonth());
  }

  void _calculateMonthlyEconomicForecast({
    required List<CreditCardBillEntity> bills,
    required List<CardCashAdvancePlanEntity> plannedOperations,
    required List<PlannedPurchaseEntity> plannedPurchases,
  }) {
    double creditCardPurchases = 0;
    double realizedFinancialCosts = 0;

    for (final CreditCardTransactionEntity transaction in bills
        .expand((bill) => bill.transactions)
        .where((transaction) => transaction.amount > 0)) {
      final double amount = transaction.amount.abs().toRound(2);

      if (transaction.cashAdvancePlanId != null) {
        final double principal = transaction.cashAdvancePrincipal ?? 0;
        realizedFinancialCosts += (amount - principal)
            .clamp(0, double.infinity)
            .toDouble();
        continue;
      }

      if (transaction.plannedPurchaseId != null) {
        final double principal =
            (transaction.plannedPurchasePrincipal ?? amount)
                .clamp(0, amount)
                .toDouble();
        creditCardPurchases += principal;
        realizedFinancialCosts += (amount - principal)
            .clamp(0, double.infinity)
            .toDouble();
        continue;
      }

      creditCardPurchases += amount;
    }

    _monthlyCreditCardPurchasesForecast = creditCardPurchases.toRound(2);
    _monthlyRealizedFinancialCostsForecast =
        realizedFinancialCosts.toRound(2);

    _monthlyPlannedFinancialCostsForecast = plannedOperations
        .where((plan) =>
            !plan.billDueDate.isBefore(_startDate) &&
            !plan.billDueDate.isAfter(_endDate))
        .fold(0.0, (total, plan) => total + plan.financialCost)
        .toRound(2);

    final double plannedPrincipal = plannedPurchases
        .fold(0.0, (total, purchase) =>
            total + purchase.principalDueInPeriod(_startDate, _endDate));
    final double plannedCosts = plannedPurchases
        .fold(0.0, (total, purchase) =>
            total + purchase.financialCostDueInPeriod(_startDate, _endDate));

    _monthlyPlannedPurchasesForecast = plannedPrincipal.toRound(2);
    _monthlyPlannedFinancialCostsForecast =
        (_monthlyPlannedFinancialCostsForecast + plannedCosts).toRound(2);
  }

  void _calculateMonthlyReceivableAndPayable({
    required List<ITransactionEntity> pendingTransactions,
    required List<CardCashAdvancePlanEntity> plannedOperations,
    required List<PlannedPurchaseEntity> plannedPurchases,
  }) {
    bool belongsToSelectedPeriod(DateTime date) =>
        !date.isBefore(_startDate) && !date.isAfter(_endDate);

    _monthlyPendingIncomeReceivable = pendingTransactions
        .whereType<IncomeEntity>()
        .where((income) => !income.received && belongsToSelectedPeriod(income.date))
        .fold(0.0, (total, income) => total + income.amount.abs())
        .toRound(2);

    // Crédito via cartão é entrada de caixa a receber, mas não é receita.
    _monthlyPlannedCreditReceivable = plannedOperations
        .where((plan) => plan.linkedEntryBelongsToPeriod(_startDate, _endDate))
        .fold(0.0, (total, plan) => total + plan.amountReceived.abs())
        .toRound(2);

    // Despesas pendentes comuns. Lançamentos ligados ao cartão ficam de fora
    // porque o saldo aberto da fatura é somado separadamente.
    _monthlyPendingExpensesPayable = pendingTransactions
        .whereType<ExpenseEntity>()
        .where((expense) =>
            !expense.paid &&
            expense.idCreditCard == null &&
            belongsToSelectedPeriod(expense.date))
        .fold(0.0, (total, expense) => total + expense.amount.abs())
        .toRound(2);

    _monthlyOpenBillsPayable = _forecastBills
        .where((bill) => bill.billAmount > 0)
        .fold(0.0, (total, bill) => total + bill.billAmount.abs())
        .toRound(2);

    // Operações de crédito ainda planejadas não fazem parte de uma fatura real
    // e por isso a cobrança prevista é mostrada separadamente.
    _monthlyPlannedCreditChargesPayable = plannedOperations
        .where((plan) => belongsToSelectedPeriod(plan.billDueDate))
        .fold(0.0, (total, plan) => total + plan.amountCharged.abs())
        .toRound(2);

    // Planejamentos são compromissos futuros de caixa, inclusive parcelas no
    // cartão. Eles permanecem separados das despesas já realizadas.
    _monthlyPlannedExpensesPayable = plannedPurchases
        .fold(0.0, (total, purchase) =>
            total + purchase.amountDueInPeriod(_startDate, _endDate))
        .toRound(2);
  }

  DateTime _nextMonth(DateTime month) =>
      DateTime(month.year, month.month + 1, 1);

  Future<void> _loadPeriodBalanceProjection(DateTime month) async {
    final DateTime currentMonth = DateTime.now().getInitialMonth();

    if (month.isBefore(currentMonth)) {
      _periodBalanceBase = await _accountFind.findAccountsBalanceUntilDate(month);
      _periodPendingIncome = 0;
      _periodPendingExpense = 0;
      _periodBillsAmount = 0;
      _periodClosingBalance = await _accountFind
          .findAccountsBalanceUntilDate(_nextMonth(month));
      _periodClosingBalance = _periodClosingBalance.toRound(2);
      return;
    }

    _periodBalanceBase = month.year == currentMonth.year &&
            month.month == currentMonth.month
        ? await _accountFind.findAccountsBalance()
        : await _calculateProjectedOpeningBalance(month);

    final projection = await _findPendingForProjection(month);
    final bills = await _findBillsForProjection(month);

    _periodPendingIncome = projection.amountsIncome.toRound(2);
    _periodPendingExpense = projection.amountsExpense.toRound(2);
    _periodBillsAmount = bills
        .where((bill) => bill.billAmount > 0)
        .fold(0.0, (total, bill) => total + bill.billAmount)
        .toRound(2);

    _periodClosingBalance = (
      _periodBalanceBase +
      _periodPendingIncome +
      _periodPendingExpense -
      _periodBillsAmount
    ).toRound(2);
  }

  Future<double> _calculateProjectedOpeningBalance(DateTime month) async {
    final DateTime currentMonth = DateTime.now().getInitialMonth();
    double balance = await _accountFind.findAccountsBalance();
    DateTime cursor = currentMonth;

    while (cursor.isBefore(month)) {
      final projection = await _findPendingForProjection(cursor);
      final bills = await _findBillsForProjection(cursor);
      final double billsAmount = bills
          .where((bill) => bill.billAmount > 0)
          .fold(0.0, (total, bill) => total + bill.billAmount)
          .toRound(2);

      balance = (
        balance +
        projection.amountsIncome +
        projection.amountsExpense -
        billsAmount
      ).toRound(2);

      cursor = _nextMonth(cursor);
    }

    return balance.toRound(2);
  }

  Future<({double amountsIncome, double amountsExpense})>
      _findPendingForProjection(DateTime month) async {
    final List<ITransactionEntity> transactions =
        await _transactionFind.findUnpaidUnreceived();
    final DateTime currentMonth = DateTime.now().getInitialMonth();
    final DateTime startMonth = month.getInitialMonth();
    final DateTime startNextMonth = _nextMonth(startMonth);

    final Iterable<ITransactionEntity> filtered;
    if (month.year == currentMonth.year && month.month == currentMonth.month) {
      filtered = transactions.where(
        (transaction) => transaction.date.isBefore(startNextMonth),
      );
    } else {
      filtered = transactions.where(
        (transaction) =>
            !transaction.date.isBefore(startMonth) &&
            transaction.date.isBefore(startNextMonth),
      );
    }

    final List<CardCashAdvancePlanEntity> planned =
        await _cashAdvance.findPlanned();

    final Iterable<CardCashAdvancePlanEntity> entries = planned.where((plan) {
      final DateTime date = plan.plannedDate;
      if (month.year == currentMonth.year && month.month == currentMonth.month) {
        return date.isBefore(startNextMonth);
      }
      return !date.isBefore(startMonth) && date.isBefore(startNextMonth);
    });

    final Iterable<CardCashAdvancePlanEntity> charges = planned.where((plan) {
      final DateTime date = plan.billDueDate;
      if (month.year == currentMonth.year && month.month == currentMonth.month) {
        return date.isBefore(startNextMonth);
      }
      return !date.isBefore(startMonth) && date.isBefore(startNextMonth);
    });

    return (
      amountsIncome: (
        filtered
            .whereType<IncomeEntity>()
            .where((income) => !income.received)
            .fold(0.0, (total, income) => total + income.amount) +
        entries.fold(0.0, (total, plan) => total + plan.amountReceived)
      ).toRound(2),
      amountsExpense: (
        filtered
            .whereType<ExpenseEntity>()
            .where((expense) => !expense.paid)
            .fold(0.0, (total, expense) => total + expense.amount) -
        charges.fold(0.0, (total, plan) => total + plan.amountCharged)
      ).toRound(2),
    );
  }

  Future<List<CreditCardBillEntity>>
      _findBillsForProjection(DateTime month) {
    final DateTime currentMonth = DateTime.now().getInitialMonth();

    if (month.year == currentMonth.year && month.month == currentMonth.month) {
      return _creditCardFind.findBillsByPeriod(
        DateTime(1970, 1, 1),
        month.getFinalMonth(),
      );
    }

    return _creditCardFind.findBillsByPeriod(
      month.getInitialMonth(),
      month.getFinalMonth(),
    );
  }

  Future<void> settleTransaction(
    ITransactionEntity transaction, {
    required double realizedAmount,
    required bool trackVariance,
    required DateTime realizedAt,
  }) async {
    if (transaction is ExpenseEntity && !transaction.paid) {
      final ExpenseEntity updated = transaction.clone();
      final double expected = transaction.amount.abs();
      updated.amount = realizedAmount;
      updated.paid = true;
      updated.realizedAt = realizedAt;
      if ((expected - realizedAmount).abs() > 0.004 && trackVariance) {
        updated.expectedAmount = expected;
        updated.trackVariance = true;
        updated.varianceRegisteredAt = DateTime.now();
      } else {
        updated.expectedAmount = null;
        updated.trackVariance = false;
        updated.varianceRegisteredAt = null;
      }
      await _expenseSave.save(updated);
    } else if (transaction is IncomeEntity && !transaction.received) {
      final IncomeEntity updated = transaction.clone();
      final double expected = transaction.amount.abs();
      updated.amount = realizedAmount;
      updated.received = true;
      updated.realizedAt = realizedAt;
      if ((expected - realizedAmount).abs() > 0.004 && trackVariance) {
        updated.expectedAmount = expected;
        updated.trackVariance = true;
        updated.varianceRegisteredAt = DateTime.now();
      } else {
        updated.expectedAmount = null;
        updated.trackVariance = false;
        updated.varianceRegisteredAt = null;
      }
      await _incomeSave.save(updated);
    } else {
      return;
    }

    await _findByPeriod(
      (startDate: _startDate, endDate: _endDate),
    );
    notifyListeners();
  }

  void setFilterType(Set<CategoryTypeEnum?> type) {
    _filterType = type;
    notifyListeners();
  }

  void setStatusFilter(TransactionStatusFilter status) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    notifyListeners();
  }
}
