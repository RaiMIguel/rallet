import 'package:collection/collection.dart';
import 'package:rallet/features/account/domain/entities/account_entity.dart';
import 'package:rallet/features/account/domain/use_cases/i_account_find.dart';
import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/card_cash_advance/domain/use_cases/i_card_cash_advance.dart';
import 'package:rallet/features/config/domain/use_cases/i_config_find.dart';
import 'package:rallet/features/config/domain/use_cases/i_config_save.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_find.dart';
import 'package:rallet/features/home/domain/entities/financial_radar_entity.dart';
import 'package:rallet/features/credit_card/domain/services/credit_card_limit_projection.dart';
import 'package:rallet/features/home/domain/entities/home_credit_card_month_entity.dart';
import 'package:rallet/features/home/domain/entities/home_monthly_balance_entity.dart';
import 'package:rallet/features/home/domain/entities/home_monthly_economy_entity.dart';
import 'package:rallet/features/home/domain/entities/home_balance_evolution_entity.dart';
import 'package:rallet/features/home/domain/use_cases/i_home_monthly_balance.dart';
import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';
import 'package:rallet/features/purchase_planning/domain/use_cases/i_purchase_planning.dart';
import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/entities/i_transaction_entity.dart';
import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/domain/entities/transactions_by_period_entity.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_transaction_find.dart';
import 'package:rallet/shared/extensions/date_time_extension.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/presentation/commands/command.dart';
import 'package:flutter/foundation.dart';

typedef ResultMonthlyTransaction = ({
  double amountsIncome,
  double amountsExpense,
});

typedef ResultTransactionsUnpaidUnreceived = ({
  double amountsIncome,
  double amountsExpense,
});

class HomeViewModel extends ChangeNotifier {
  final IAccountFind _accountFind;
  final ICardCashAdvance _cashAdvance;
  final IPurchasePlanning _purchasePlanning;
  final ICreditCardFind _creditCardFind;
  final ITransactionFind _transactionFind;
  final IHomeMonthlyBalance _monthlyBalance;
  final IConfigFind _configFind;
  final IConfigSave _configSave;

  late final Command0<double> loadAccountsBalance;

  late final Command0<double> loadInitialBalance;

  late final Command0<double> loadSelectedBalance;

  late final Command0<List<HomeCreditCardMonthEntity>>
      loadSelectedMonthCreditCards;

  late final Command0<List<CreditCardBillEntity>>
      loadSelectedMonthBills;

  late final Command0<List<HomeMonthlyBalanceEntity>>
      loadMonthlyBalance;

  late final Command0<HomeMonthlyEconomyEntity>
      loadMonthlyEconomy;

  late final Command0<FinancialRadarEntity>
      loadFinancialRadar;

  late final Command0<List<HomeBalanceEvolutionEntity>>
      loadBalanceEvolution;

  late final Command0<ResultMonthlyTransaction>
      loadMonthlyTransaction;

  late final Command0<ResultTransactionsUnpaidUnreceived>
      loadTransactionsUnpaidUnreceived;

  late final Command0<ResultTransactionsUnpaidUnreceived>
      loadSelectedMonthTransactions;

  HomeViewModel({
    required IAccountFind accountFind,
    required ICardCashAdvance cashAdvance,
    required IPurchasePlanning purchasePlanning,
    required ICreditCardFind creditCardFind,
    required ITransactionFind transactionFind,
    required IHomeMonthlyBalance monthlyBalance,
    required IConfigFind configFind,
    required IConfigSave configSave,
  })  : _accountFind = accountFind,
        _cashAdvance = cashAdvance,
        _purchasePlanning = purchasePlanning,
        _creditCardFind = creditCardFind,
        _transactionFind = transactionFind,
        _monthlyBalance = monthlyBalance,
        _configFind = configFind,
        _configSave = configSave {
    _radarMonths = _configFind.findRadarMonths();

    loadAccountsBalance = Command0(
      _accountFind.findAccountsBalance,
    );

    loadInitialBalance = Command0(
      _loadInitialBalance,
    );

    loadSelectedBalance = Command0(
      _loadSelectedBalance,
    );

    loadSelectedMonthCreditCards = Command0(
      _loadSelectedMonthCreditCards,
    );

    loadSelectedMonthBills = Command0(
      _loadSelectedMonthBills,
    );

    loadMonthlyBalance = Command0(
      _loadMonthlyBalance,
    );

    loadMonthlyEconomy = Command0(
      _loadMonthlyEconomy,
    );

    loadFinancialRadar = Command0(
      _loadFinancialRadar,
    );

    loadBalanceEvolution = Command0(
      _loadBalanceEvolution,
    );

    loadMonthlyTransaction = Command0(
      _loadMonthlyTransaction,
    );

    loadTransactionsUnpaidUnreceived = Command0(
      _loadTransactionsUnpaidUnreceived,
    );

    loadSelectedMonthTransactions = Command0(
      _loadSelectedMonthTransactions,
    );
  }

  bool _hideAmounts = false;

  bool get hideAmounts => _hideAmounts;

  late int _radarMonths;

  int get radarMonths => _radarMonths;

  Future<void> setRadarMonths(int months) async {
    final int normalized = months.clamp(1, 24).toInt();
    if (_radarMonths == normalized) return;
    _radarMonths = normalized;
    await _configSave.saveRadarMonths(normalized);
    notifyListeners();
    await loadFinancialRadar.execute();
  }

  DateTime _selectedMonth =
      DateTime.now().getInitialMonth();

  DateTime get selectedMonth => _selectedMonth;

  bool get isSelectedMonthCurrent {
    final DateTime now = DateTime.now();

    return _selectedMonth.year == now.year &&
        _selectedMonth.month == now.month;
  }

  bool get isSelectedMonthPast {
    final DateTime currentMonth =
        DateTime.now().getInitialMonth();

    return _selectedMonth.isBefore(currentMonth);
  }

  bool get isSelectedMonthFuture {
    final DateTime currentMonth =
        DateTime.now().getInitialMonth();

    return _selectedMonth.isAfter(currentMonth);
  }

  void toggleHideAmounts() {
    _configSave.saveHideAmounts(!_hideAmounts);

    _hideAmounts = !_hideAmounts;

    notifyListeners();
  }

  Future<void> initialize() async {
    _hideAmounts = _configFind.findHideAmounts();
    _selectedMonth = DateTime.now().getInitialMonth();

    await load();
  }

  Future<void> load() async {
    await Future.wait([
      loadAccountsBalance.execute(),
      loadInitialBalance.execute(),
      loadSelectedBalance.execute(),
      loadSelectedMonthCreditCards.execute(),
      loadSelectedMonthBills.execute(),
      loadBalanceEvolution.execute(),
      loadMonthlyEconomy.execute(),
      loadFinancialRadar.execute(),
      loadTransactionsUnpaidUnreceived.execute(),
      loadSelectedMonthTransactions.execute(),
    ]);
  }

  Future<void> previousMonth() async {
    _selectedMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month - 1,
      1,
    );

    notifyListeners();

    await _reloadSelectedMonth();
  }

  Future<void> nextMonth() async {
    _selectedMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      1,
    );

    notifyListeners();

    await _reloadSelectedMonth();
  }

  Future<void> goCurrentMonth() async {
    _selectedMonth =
        DateTime.now().getInitialMonth();

    notifyListeners();

    await _reloadSelectedMonth();
  }

  Future<void> resetToCurrentMonth() async {
    _selectedMonth = DateTime.now().getInitialMonth();
    notifyListeners();
    await load();
  }

  Future<void> _reloadSelectedMonth() async {
    await Future.wait([
      loadInitialBalance.execute(),
      loadSelectedBalance.execute(),
      loadSelectedMonthCreditCards.execute(),
      loadSelectedMonthBills.execute(),
      loadSelectedMonthTransactions.execute(),
      loadTransactionsUnpaidUnreceived.execute(),
      loadBalanceEvolution.execute(),
      loadMonthlyEconomy.execute(),
    ]);
  }

  DateTime _nextMonth(DateTime month) {
    return DateTime(
      month.year,
      month.month + 1,
      1,
    );
  }

  Future<double> _loadInitialBalance() async {
    final DateTime month = _selectedMonth;

    return _calculateInitialBalance(month);
  }

  Future<double> _calculateInitialBalance(
    DateTime month,
  ) async {
    final DateTime currentMonth =
        DateTime.now().getInitialMonth();

    /*
     * Mês atual ou passado:
     * podemos descobrir o saldo real que existia
     * antes do primeiro dia daquele mês.
     */
    if (!month.isAfter(currentMonth)) {
      return _accountFind.findAccountsBalanceUntilDate(
        month.getInitialMonth(),
      );
    }

    /*
     * Mês futuro:
     * começa no saldo real de hoje e vai projetando
     * mês por mês até chegar ao mês selecionado.
     */
    double balance =
        await _accountFind.findAccountsBalance();

    DateTime monthCursor = currentMonth;

    while (monthCursor.isBefore(month)) {
      final ResultTransactionsUnpaidUnreceived pending =
          await _findPendingForProjection(
        monthCursor,
      );

      final List<CreditCardBillEntity> bills =
          await _findBillsForProjection(
        monthCursor,
      );

      final double billsAmount = bills
          .map(
            (bill) =>
                bill.billAmount > 0
                    ? bill.billAmount
                    : 0,
          )
          .sum
          .toDouble()
          .toRound(2);

      balance = (
        balance +
        pending.amountsIncome +
        pending.amountsExpense -
        billsAmount
      ).toRound(2);

      monthCursor = _nextMonth(monthCursor);
    }

    return balance.toRound(2);
  }

  Future<double> _loadSelectedBalance() async {
    final DateTime month = _selectedMonth;
    final DateTime currentMonth =
        DateTime.now().getInitialMonth();

    /*
     * Mês passado:
     * saldo real ao final daquele mês.
     *
     * Nosso método usa "< data",
     * então passamos o primeiro dia do mês seguinte.
     */
    if (month.isBefore(currentMonth)) {
      return _accountFind.findAccountsBalanceUntilDate(
        _nextMonth(month),
      );
    }

    /*
     * Mês atual:
     * saldo real das contas agora.
     */
    if (month.year == currentMonth.year &&
        month.month == currentMonth.month) {
      return _accountFind.findAccountsBalance();
    }

    /*
     * Mês futuro:
     * ainda não existe um "saldo real".
     * Portanto, o ponto de partida dele é
     * o saldo previsto ao início daquele mês.
     */
    return _calculateInitialBalance(month);
  }

  double get initialBalance {
    return loadInitialBalance.result ??
        loadInitialBalance.previous?.result ??
        0;
  }

  double get currentBalance {
    return loadSelectedBalance.result ??
        loadSelectedBalance.previous?.result ??
        loadAccountsBalance.result ??
        loadAccountsBalance.previous?.result ??
        0;
  }

  double get selectedMonthPendingIncome {
    final pending =
        loadSelectedMonthTransactions.result ??
        loadSelectedMonthTransactions.previous?.result;

    return pending?.amountsIncome ?? 0;
  }

  double get selectedMonthPendingExpense {
    final pending =
        loadSelectedMonthTransactions.result ??
        loadSelectedMonthTransactions.previous?.result;

    return pending?.amountsExpense ?? 0;
  }

  double get selectedMonthBillsAmount {
    final bills =
        loadSelectedMonthBills.result ??
        loadSelectedMonthBills.previous?.result ??
        [];

    return bills
        .map(
          (bill) =>
              bill.billAmount > 0
                  ? bill.billAmount
                  : 0,
        )
        .sum
        .toDouble()
        .toRound(2);
  }

  double get forecastBalance {
    /*
     * Para mês passado, usamos o saldo real
     * que existia no fechamento.
     *
     * Não temos como reconstruir com precisão
     * quais lançamentos ainda estavam pendentes
     * naquele momento histórico.
     */
    if (isSelectedMonthPast) {
      return currentBalance.toRound(2);
    }

    return (
      currentBalance +
      selectedMonthPendingIncome +
      selectedMonthPendingExpense -
      selectedMonthBillsAmount
    ).toRound(2);
  }

  Future<ResultTransactionsUnpaidUnreceived>
      _loadSelectedMonthTransactions() async {
    final DateTime month = _selectedMonth;

    if (month.isBefore(
      DateTime.now().getInitialMonth(),
    )) {
      return (
        amountsIncome: 0.0,
        amountsExpense: 0.0,
      );
    }

    return _findPendingForProjection(month);
  }

  Future<ResultTransactionsUnpaidUnreceived>
      _findPendingForProjection(
    DateTime month,
  ) async {
    final List<ITransactionEntity> transactions =
        await _transactionFind.findUnpaidUnreceived();

    final DateTime currentMonth =
        DateTime.now().getInitialMonth();

    final DateTime startMonth =
        month.getInitialMonth();

    final DateTime startNextMonth =
        _nextMonth(startMonth);

    final Iterable<ITransactionEntity>
        transactionsFiltered;

    /*
     * No mês atual também consideramos pendências
     * vencidas de meses anteriores.
     *
     * Elas ainda precisam sair/entrar no caixa.
     */
    if (month.year == currentMonth.year &&
        month.month == currentMonth.month) {
      transactionsFiltered =
          transactions.where(
        (transaction) =>
            transaction.date.isBefore(
              startNextMonth,
            ),
      );
    } else {
      /*
       * Nos meses futuros entram somente
       * os lançamentos daquele mês.
       */
      transactionsFiltered =
          transactions.where(
        (transaction) =>
            !transaction.date.isBefore(
              startMonth,
            ) &&
            transaction.date.isBefore(
              startNextMonth,
            ),
      );
    }

    final List<CardCashAdvancePlanEntity> planned = await _cashAdvance.findPlanned();
    final Iterable<CardCashAdvancePlanEntity> plannedForMonth = planned.where((plan) {
      final DateTime reference = plan.plannedDate;
      if (month.year == currentMonth.year && month.month == currentMonth.month) {
        return reference.isBefore(startNextMonth);
      }
      return !reference.isBefore(startMonth) && reference.isBefore(startNextMonth);
    });

    final Iterable<CardCashAdvancePlanEntity> plannedChargesForMonth = planned.where((plan) {
      final DateTime reference = plan.billDueDate;
      if (month.year == currentMonth.year && month.month == currentMonth.month) {
        return reference.isBefore(startNextMonth);
      }
      return !reference.isBefore(startMonth) && reference.isBefore(startNextMonth);
    });

    return (
      amountsIncome: (
        transactionsFiltered
            .map(
              (transaction) =>
                  transaction is IncomeEntity && !transaction.received
                      ? transaction.amount
                      : 0,
            )
            .sum
            .toDouble() +
        plannedForMonth.map((plan) => plan.amountReceived).sum.toDouble()
      ).toRound(2),
      amountsExpense: (
        transactionsFiltered
            .map(
              (transaction) =>
                  transaction is ExpenseEntity && !transaction.paid
                      ? transaction.amount
                      : 0,
            )
            .sum
            .toDouble() -
        plannedChargesForMonth.map((plan) => plan.amountCharged).sum.toDouble()
      ).toRound(2),
    );
  }

  Future<List<HomeCreditCardMonthEntity>>
      _loadSelectedMonthCreditCards() async {
    final DateTime start = _selectedMonth.getInitialMonth();
    final DateTime end = _selectedMonth.getFinalMonth();

    final results = await Future.wait<dynamic>([
      _creditCardFind.findAll(),
      _creditCardFind.findAllBillsByPeriod(start, end),
      _cashAdvance.findPlanned(),
      _purchasePlanning.findAll(),
    ]);

    final cards = (results[0] as List).cast<CreditCardEntity>();
    final bills = (results[1] as List).cast<CreditCardBillEntity>();
    final plannedAdvances = (results[2] as List).cast<CardCashAdvancePlanEntity>();
    final plannedPurchases = (results[3] as List).cast<PlannedPurchaseEntity>();

    return cards.map((card) {
      final CreditCardBillEntity? bill = bills
          .where((item) => item.idCreditCard == card.id)
          .firstOrNull;

      final double plannedAdvancesAmount = plannedAdvances
          .where((plan) =>
              plan.idCreditCard == card.id &&
              !plan.billDueDate.isBefore(start) &&
              !plan.billDueDate.isAfter(end))
          .fold(0.0, (total, plan) => total + plan.amountCharged.abs());

      final double plannedPurchasesAmount = plannedPurchases
          .where((plan) => plan.isCreditCard && plan.idCreditCard == card.id)
          .fold(0.0, (total, plan) =>
              total + plan.amountDueInPeriod(start, end).abs());

      // Para mês passado mostramos o gasto histórico da fatura; para mês atual
      // e futuro interessa o saldo/valor já comprometido que ainda compõe a
      // previsão. Planejamentos entram à parte e nunca são gravados aqui.
      final double billAmount = isSelectedMonthPast
          ? (bill?.totalSpent ?? 0)
          : ((bill?.billAmount ?? 0) > 0 ? bill!.billAmount : 0);

      return HomeCreditCardMonthEntity(
        creditCard: card,
        bill: bill,
        billAmount: billAmount.toRound(2),
        plannedAmount:
            (plannedAdvancesAmount + plannedPurchasesAmount).toRound(2),
      );
    }).toList();
  }

  Future<List<CreditCardBillEntity>>
      _loadSelectedMonthBills() async {
    final DateTime month = _selectedMonth;

    if (month.isBefore(
      DateTime.now().getInitialMonth(),
    )) {
      return [];
    }

    return _findBillsForProjection(month);
  }

  Future<List<CreditCardBillEntity>>
      _findBillsForProjection(
    DateTime month,
  ) async {
    final DateTime currentMonth =
        DateTime.now().getInitialMonth();

    /*
     * Para o mês atual também pegamos faturas
     * vencidas anteriormente que continuam
     * com saldo em aberto.
     */
    if (month.year == currentMonth.year &&
        month.month == currentMonth.month) {
      return _creditCardFind.findBillsByPeriod(
        DateTime(1970, 1, 1),
        month.getFinalMonth(),
      );
    }

    /*
     * Para meses futuros, somente faturas
     * cujo vencimento pertence ao mês.
     */
    return _creditCardFind.findBillsByPeriod(
      month.getInitialMonth(),
      month.getFinalMonth(),
    );
  }

  Future<List<HomeBalanceEvolutionEntity>>
      _loadBalanceEvolution() async {
    final DateTime month = _selectedMonth.getInitialMonth();
    final DateTime endMonth = month.getFinalMonth();
    final DateTime currentMonth = DateTime.now().getInitialMonth();
    final DateTime now = DateTime.now();

    final double startBalance = await _calculateInitialBalance(month);
    final bool past = month.isBefore(currentMonth);
    final bool current = month.year == currentMonth.year && month.month == currentMonth.month;
    final double realBalanceAtCutoff =
        past || current ? await _loadSelectedBalance() : startBalance;

    final TransactionsByPeriodEntity transactions =
        await _transactionFind.findByPeriod(month, endMonth);

    final accounts = await _accountFind.findAll(deleted: true);
    final Set<String> includedAccounts = accounts
        .where((account) => account.includeTotalBalance)
        .map((account) => account.id)
        .toSet();

    final Map<int, double> actualByDay = {};

    for (final transaction in transactions.transactions) {
      double amount = 0;
      String? idAccount;

      if (transaction is IncomeEntity && transaction.received) {
        amount = transaction.amount;
        idAccount = transaction.idAccount;
      } else if (transaction is ExpenseEntity && transaction.paid) {
        amount = transaction.amount;
        idAccount = transaction.idAccount;
      }

      if (idAccount == null || !includedAccounts.contains(idAccount)) continue;
      actualByDay.update(
        transaction.date.day,
        (value) => value + amount,
        ifAbsent: () => amount,
      );
    }

    final int actualCutoffDay = past
        ? endMonth.day
        : current
            ? now.day.clamp(1, endMonth.day).toInt()
            : 0;

    final Map<int, double> projectedByDay = {};

    if (!past) {
      final List<ITransactionEntity> pending =
          await _transactionFind.findUnpaidUnreceived();

      for (final transaction in pending) {
        String? idAccount;
        double amount = 0;

        if (transaction is IncomeEntity && !transaction.received) {
          idAccount = transaction.idAccount;
          amount = transaction.amount;
        } else if (transaction is ExpenseEntity && !transaction.paid) {
          idAccount = transaction.idAccount;
          amount = transaction.amount;
        }

        if (idAccount == null || !includedAccounts.contains(idAccount)) continue;

        final bool belongsToMonth =
            !transaction.date.isBefore(month) && transaction.date.isBefore(_nextMonth(month));
        final bool overdueForCurrent = current && transaction.date.isBefore(month);
        if (!belongsToMonth && !overdueForCurrent) continue;

        int day = transaction.date.day;
        if (current && day <= actualCutoffDay) {
          day = (actualCutoffDay + 1).clamp(1, endMonth.day).toInt();
        }

        projectedByDay.update(
          day,
          (value) => value + amount,
          ifAbsent: () => amount,
        );
      }

      final List<CreditCardBillEntity> bills = await _findBillsForProjection(month);
      for (final bill in bills) {
        if (bill.billAmount <= 0) continue;

        int day = bill.billDueDate.day.clamp(1, endMonth.day).toInt();
        if (current && (bill.billDueDate.isBefore(month) || day <= actualCutoffDay)) {
          day = (actualCutoffDay + 1).clamp(1, endMonth.day).toInt();
        }

        projectedByDay.update(
          day,
          (value) => value - bill.billAmount,
          ifAbsent: () => -bill.billAmount,
        );
      }
    }

    final List<HomeBalanceEvolutionEntity> result = [];
    double balance = startBalance;

    for (int day = 1; day <= endMonth.day; day++) {
      final bool projected = day > actualCutoffDay;

      if (!projected) {
        balance += actualByDay[day] ?? 0;
        if (current && day == actualCutoffDay) {
          // Faz a curva encontrar exatamente o saldo real exibido no card.
          balance = realBalanceAtCutoff;
        }
        if (past && day == endMonth.day) {
          balance = realBalanceAtCutoff;
        }
      } else {
        balance += projectedByDay[day] ?? 0;
      }

      result.add(
        HomeBalanceEvolutionEntity(
          date: DateTime(month.year, month.month, day),
          balance: balance.toRound(2),
          projected: projected,
        ),
      );
    }

    return result;
  }

  Future<FinancialRadarEntity> _loadFinancialRadar() async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    // Horizonte configurável em meses-calendário completos, contando o mês atual.
    final DateTime horizonEnd = DateTime(
      today.year,
      today.month + _radarMonths,
      0,
      23,
      59,
      59,
      999,
    );

    final results = await Future.wait<dynamic>([
      _accountFind.findAccountsBalance(),
      _accountFind.findAll(deleted: true),
      _transactionFind.findUnpaidUnreceived(),
      _creditCardFind.findBillsByPeriod(
        DateTime(1970, 1, 1),
        DateTime(
          horizonEnd.year,
          horizonEnd.month,
          horizonEnd.day,
          23,
          59,
          59,
          999,
        ),
      ),
      _creditCardFind.findAll(),
      _cashAdvance.findPlanned(),
      _purchasePlanning.findAll(),
    ]);

    final double currentBalance = results[0] as double;
    final List<AccountEntity> accounts =
        (results[1] as List).cast<AccountEntity>();
    final List<ITransactionEntity> pending =
        (results[2] as List).cast<ITransactionEntity>();
    final List<CreditCardBillEntity> bills =
        (results[3] as List).cast<CreditCardBillEntity>();
    final List<CreditCardEntity> creditCards =
        (results[4] as List).cast<CreditCardEntity>();
    final List<CardCashAdvancePlanEntity> plannedOperations =
        (results[5] as List).cast<CardCashAdvancePlanEntity>();
    final List<PlannedPurchaseEntity> plannedPurchases =
        (results[6] as List).cast<PlannedPurchaseEntity>();

    final Set<String> includedAccounts = accounts
        .where((account) => account.includeTotalBalance)
        .map((account) => account.id)
        .toSet();

    DateTime normalizeDate(DateTime date) =>
        DateTime(date.year, date.month, date.day);

    DateTime projectionDate(DateTime date) {
      final DateTime normalized = normalizeDate(date);
      return normalized.isBefore(today) ? today : normalized;
    }

    // Uma única linha temporal de limite é usada pelo Radar para cartões,
    // despesas planejadas e crédito via cartão. Um planejamento que não cabe
    // no limite contratual não é tratado como uma operação garantida.
    final CreditCardLimitProjectionResult limitProjection =
        CreditCardLimitProjection.calculate(
      today: today,
      horizonEnd: horizonEnd,
      cards: creditCards,
      bills: bills,
      cashAdvancePlans: plannedOperations,
      plannedPurchases: plannedPurchases,
    );

    final List<FinancialRadarEventEntity> events = [];

    for (final ITransactionEntity transaction in pending) {
      final DateTime date = projectionDate(transaction.date);
      if (date.isAfter(horizonEnd)) continue;

      if (transaction is IncomeEntity && !transaction.received) {
        if (transaction.idAccount != null &&
            !includedAccounts.contains(transaction.idAccount)) {
          continue;
        }

        events.add(
          FinancialRadarEventEntity(
            id: transaction.id,
            description: transaction.description,
            date: date,
            amount: transaction.amount,
            type: FinancialRadarEventType.income,
            origin: transaction,
          ),
        );
      } else if (transaction is ExpenseEntity &&
          !transaction.paid &&
          transaction.idCreditCard == null) {
        if (transaction.idAccount != null &&
            !includedAccounts.contains(transaction.idAccount)) {
          continue;
        }

        events.add(
          FinancialRadarEventEntity(
            id: transaction.id,
            description: transaction.description,
            date: date,
            amount: -transaction.amount.abs(),
            type: FinancialRadarEventType.expense,
            origin: transaction,
          ),
        );
      }
    }

    for (final CreditCardBillEntity bill in bills) {
      if (bill.billAmount <= 0) continue;

      final DateTime date = projectionDate(bill.billDueDate);
      if (date.isAfter(horizonEnd)) continue;

      final CreditCardEntity? card = creditCards.firstWhereOrNull(
        (creditCard) => creditCard.id == bill.idCreditCard,
      );

      events.add(
        FinancialRadarEventEntity(
          id: bill.id,
          description: card == null
              ? 'Fatura do cartão'
              : 'Fatura ${card.description}',
          date: date,
          amount: -bill.billAmount.abs(),
          type: FinancialRadarEventType.creditCardBill,
          origin: FinancialRadarBillOrigin(bill: bill, creditCard: card),
        ),
      );
    }

    for (final CardCashAdvancePlanEntity plan in plannedOperations) {
      // O Radar é um cenário: mesmo quando o limite projetado é insuficiente,
      // o planejamento continua na linha do tempo. A inviabilidade aparece como
      // alerta para o usuário ajustar data/valor/cartão sem o Rallet esconder o plano.
      final limitResult = limitProjection.cashAdvancePlans[plan.id];
      final bool limitFeasible = limitResult?.feasible ?? true;

      final CreditCardEntity? card = creditCards.firstWhereOrNull(
        (creditCard) => creditCard.id == plan.idCreditCard,
      );
      final String cardName = card?.description ?? 'cartão';
      final String? limitWarning = limitFeasible
          ? null
          : 'Limite insuficiente no cartão $cardName para esse compromisso nesse dia.';
      final String? limitDetails = limitResult == null || limitFeasible
          ? null
          : 'Limite disponível antes da operação: ${limitResult.availableBefore.money}. '
              'Compromisso planejado: ${limitResult.requiredAmount.money}. '
              'Faltariam ${limitResult.shortage.money}.';

      if (includedAccounts.contains(plan.idAccount)) {
        final DateTime inflowDate = projectionDate(plan.plannedDate);
        if (!inflowDate.isAfter(horizonEnd)) {
          events.add(
            FinancialRadarEventEntity(
              id: '${plan.id}-in',
              description: 'Crédito planejado • $cardName',
              date: inflowDate,
              amount: plan.amountReceived,
              type: FinancialRadarEventType.plannedCashAdvanceIncome,
              origin: plan,
              warningMessage: limitWarning,
              warningDetails: limitDetails,
            ),
          );
        }
      }

      final DateTime chargeDate = projectionDate(plan.billDueDate);
      if (!chargeDate.isAfter(horizonEnd)) {
        events.add(
          FinancialRadarEventEntity(
            id: '${plan.id}-out',
            description: 'Crédito planejado na fatura • $cardName',
            date: chargeDate,
            amount: -plan.amountCharged.abs(),
            type: FinancialRadarEventType.plannedCashAdvanceCharge,
            origin: plan,
          ),
        );
      }
    }

    for (final PlannedPurchaseEntity purchase in plannedPurchases) {
      if (purchase.isCreditCard) {
        final limitResult = limitProjection.plannedPurchases[purchase.id];
        final bool limitFeasible = limitResult?.feasible ?? true;
        final CreditCardEntity? card = creditCards.firstWhereOrNull(
          (creditCard) => creditCard.id == purchase.idCreditCard,
        );
        final String cardName = card?.description ?? 'cartão';

        // A compra compromete o limite na data em que está planejada, enquanto
        // o caixa só é afetado pelas faturas. Quando não couber, criamos um item
        // explicativo sem alterar o caixa para que o alerta apareça na data real
        // do problema e o planejamento continue intacto.
        if (!limitFeasible && limitResult != null) {
          events.add(
            FinancialRadarEventEntity(
              id: '${purchase.id}-limit',
              description: 'Despesa planejada • ${purchase.description}',
              date: projectionDate(limitResult.date),
              amount: -purchase.totalCharged.abs(),
              type: FinancialRadarEventType.cardLimitCommitment,
              origin: purchase,
              affectsCashFlow: false,
              warningMessage:
                  'Limite insuficiente no cartão $cardName para esse compromisso nesse dia.',
              warningDetails:
                  'Limite disponível antes da compra: ${limitResult.availableBefore.money}. '
                  'Total que compromete o limite: ${limitResult.requiredAmount.money}. '
                  'Faltariam ${limitResult.shortage.money}.',
            ),
          );
        }

        for (final installment in purchase.installmentSchedule) {
          final DateTime dueDate = projectionDate(installment.dueDate);
          if (dueDate.isAfter(horizonEnd)) continue;
          events.add(
            FinancialRadarEventEntity(
              id: '${purchase.id}-installment-${installment.number}',
              description:
                  'Despesa planejada • ${purchase.description} (${installment.number}/${purchase.installmentCount})',
              date: dueDate,
              amount: -installment.amount.abs(),
              type: FinancialRadarEventType.plannedPurchase,
              origin: purchase,
            ),
          );
        }
      } else {
        if (purchase.idAccount != null &&
            !includedAccounts.contains(purchase.idAccount)) {
          continue;
        }
        final DateTime purchaseDate = projectionDate(purchase.plannedDate);
        if (purchaseDate.isAfter(horizonEnd)) continue;
        events.add(
          FinancialRadarEventEntity(
            id: purchase.id,
            description: 'Despesa planejada • ${purchase.description}',
            date: purchaseDate,
            amount: -purchase.amount.abs(),
            type: FinancialRadarEventType.plannedPurchase,
            origin: purchase,
          ),
        );
      }
    }

    events.sort((a, b) {
      final int dateComparison = a.date.compareTo(b.date);
      if (dateComparison != 0) return dateComparison;
      return b.amount.compareTo(a.amount);
    });

    final Map<DateTime, List<FinancialRadarEventEntity>> eventsByDay = {};
    for (final event in events) {
      eventsByDay.putIfAbsent(event.date, () => []).add(event);
    }

    final List<DateTime> dates = eventsByDay.keys.toList()..sort();
    final List<FinancialAlertEntity> alerts = [];

    double projectedBalance = currentBalance.toRound(2);
    double minimumBalance = projectedBalance;
    DateTime minimumBalanceDate = today;

    DateTime segmentStart = today;
    DateTime? riskStartDate;
    DateTime? worstDate;
    double? worstBalance;

    if (projectedBalance < 0) {
      riskStartDate = today;
      worstDate = today;
      worstBalance = projectedBalance;
    }

    List<FinancialRadarEventEntity> eventsUntil(
      DateTime start,
      DateTime end,
    ) {
      return events
          .where(
            (event) =>
                !event.date.isBefore(start) && !event.date.isAfter(end),
          )
          .toList();
    }

    void finishAlert(DateTime? recoveryDate) {
      if (riskStartDate == null || worstDate == null || worstBalance == null) {
        return;
      }

      alerts.add(
        FinancialAlertEntity(
          periodStart: segmentStart,
          riskStartDate: riskStartDate!,
          worstDate: worstDate!,
          recoveryDate: recoveryDate,
          shortage: (-worstBalance!).toRound(2),
          lowestBalance: worstBalance!.toRound(2),
          events: eventsUntil(segmentStart, worstDate!),
        ),
      );

      riskStartDate = null;
      worstDate = null;
      worstBalance = null;
    }

    final Map<String, ({String message, String details})> cashWarnings = {};

    for (final DateTime date in dates) {
      final List<FinancialRadarEventEntity> dayEvents = eventsByDay[date]!;
      double runningInDay = projectedBalance;
      bool warningAddedForDay = false;

      for (final event in dayEvents) {
        if (!event.affectsCashFlow) continue;
        final double before = runningInDay;
        runningInDay = (runningInDay + event.cashFlowAmount).toRound(2);

        if (!warningAddedForDay &&
            event.isCharge &&
            before >= 0 &&
            runningInDay < 0) {
          cashWarnings[event.id] = (
            message: 'Saldo insuficiente para pagamentos nesse dia.',
            details:
                'Saldo antes deste compromisso: ${before.money}. '
                'Pagamento considerado: ${event.amount.abs().money}. '
                'Saldo projetado após o movimento: ${runningInDay.money}. '
                'Faltariam ${(-runningInDay).money}.',
          );
          warningAddedForDay = true;
        }
      }

      projectedBalance = runningInDay.toRound(2);

      if (projectedBalance < minimumBalance) {
        minimumBalance = projectedBalance;
        minimumBalanceDate = date;
      }

      if (projectedBalance < 0) {
        riskStartDate ??= date;

        if (worstBalance == null || projectedBalance < worstBalance!) {
          worstBalance = projectedBalance;
          worstDate = date;
        }
      } else if (riskStartDate != null) {
        finishAlert(date);
        segmentStart = date.add(const Duration(days: 1));
      }
    }

    if (riskStartDate != null) {
      finishAlert(null);
    }

    final List<CreditCardSafetyAlertEntity> cardLimitAlerts = [];

    for (final cardProjection in limitProjection.cards) {
      final infeasiblePlans = cardProjection.infeasiblePlans;
      final bool currentBankLimitExceeded =
          cardProjection.currentUtilized > cardProjection.amountLimit + 0.0001;
      final bool bankLimitExceeded =
          infeasiblePlans.isNotEmpty || currentBankLimitExceeded;
      final bool hasPersonalSafety =
          cardProjection.safetyLimit != null && cardProjection.safetyLimit! > 0;
      final double safetyLimit = cardProjection.effectiveSafetyLimit;
      final double ratio = cardProjection.maximumSafetyRatio;

      // Sem falta de limite contratual, só exibimos alerta percentual quando o
      // usuário configurou um limite de segurança pessoal.
      if (!bankLimitExceeded && (!hasPersonalSafety || ratio < .70)) continue;

      final mostCriticalPlan = infeasiblePlans.isEmpty
          ? null
          : (infeasiblePlans.toList()
            ..sort((a, b) => b.shortage.compareTo(a.shortage)))
              .first;

      final CreditCardSafetyAlertLevel level = bankLimitExceeded
          ? CreditCardSafetyAlertLevel.exceeded
          : cardProjection.maximumProjectedUtilized > safetyLimit
              ? CreditCardSafetyAlertLevel.exceeded
              : ratio >= .90
                  ? CreditCardSafetyAlertLevel.critical
                  : CreditCardSafetyAlertLevel.attention;

      cardLimitAlerts.add(
        CreditCardSafetyAlertEntity(
          idCreditCard: cardProjection.idCreditCard,
          cardDescription: cardProjection.cardDescription,
          amountLimit: cardProjection.amountLimit,
          safetyLimit: safetyLimit,
          utilized: cardProjection.currentUtilized,
          plannedAmount: (cardProjection.maximumProjectedUtilized -
                  cardProjection.currentUtilized)
              .clamp(0, double.infinity)
              .toDouble()
              .toRound(2),
          level: level,
          riskDate:
              mostCriticalPlan?.date ?? cardProjection.maximumUtilizedDate,
          availableBeforeRisk: mostCriticalPlan?.availableBefore ??
              (currentBankLimitExceeded ? cardProjection.amountLimit : null),
          requiredAmountAtRisk: mostCriticalPlan?.requiredAmount ??
              (currentBankLimitExceeded ? cardProjection.currentUtilized : null),
          riskDescription: mostCriticalPlan?.description ??
              (currentBankLimitExceeded ? 'Uso atual do cartão' : null),
          bankLimitExceeded: bankLimitExceeded,
        ),
      );
    }

    cardLimitAlerts.sort((a, b) {
      if (a.bankLimitExceeded != b.bankLimitExceeded) {
        return a.bankLimitExceeded ? -1 : 1;
      }
      return b.safetyRatio.compareTo(a.safetyRatio);
    });

    final List<FinancialRadarEventEntity> decoratedEvents = events.map((event) {
      final warning = cashWarnings[event.id];
      if (warning == null) return event;
      return event.copyWith(
        warningMessage: warning.message,
        warningDetails: warning.details,
      );
    }).toList();

    return FinancialRadarEntity(
      generatedAt: now,
      horizonEnd: horizonEnd,
      currentBalance: currentBalance.toRound(2),
      minimumProjectedBalance: minimumBalance.toRound(2),
      minimumBalanceDate: minimumBalanceDate,
      alerts: alerts,
      cardLimitAlerts: cardLimitAlerts,
      events: decoratedEvents,
      plannedPurchases: plannedPurchases,
    );
  }

  Future<HomeMonthlyEconomyEntity> _loadMonthlyEconomy() async {
    final DateTime month = _selectedMonth.getInitialMonth();
    final DateTime endMonth = month.getFinalMonth();

    final results = await Future.wait<dynamic>([
      _transactionFind.findByPeriod(month, endMonth),
      _creditCardFind.findAllBillsByPeriod(month, endMonth),
      _cashAdvance.findPlanned(),
      _purchasePlanning.findAll(),
    ]);

    final TransactionsByPeriodEntity transactions =
        results[0] as TransactionsByPeriodEntity;
    final List<CreditCardBillEntity> bills =
        (results[1] as List).cast<CreditCardBillEntity>();
    final List<CardCashAdvancePlanEntity> plannedOperations =
        (results[2] as List).cast<CardCashAdvancePlanEntity>();
    final List<PlannedPurchaseEntity> plannedPurchases =
        (results[3] as List).cast<PlannedPurchaseEntity>();

    /*
     * "Economia mensal" trabalha com valores considerados para o mês,
     * não somente com o que já foi efetivado.
     *
     * Assim, uma receita/despesa pendente de outubro entra em outubro.
     * O mesmo vale para recorrências já geradas.
     */
    final double incomes = transactions.transactions
        .whereType<IncomeEntity>()
        .map((income) => income.amount)
        .sum
        .toDouble()
        .toRound(2);

    /*
     * Pagamentos de fatura geram uma ExpenseEntity ligada ao cartão.
     * Não somamos essa despesa aqui porque a própria fatura é considerada
     * pelo vencimento logo abaixo. Isso evita dupla contagem.
     */
    final double regularExpenses = transactions.transactions
        .whereType<ExpenseEntity>()
        .where((expense) => expense.idCreditCard == null)
        .map((expense) => expense.amount.abs())
        .sum
        .toDouble()
        .toRound(2);

    /*
     * Para a economia do mês usamos o total de compras das faturas cujo
     * vencimento pertence ao mês selecionado. Inclui faturas abertas e
     * já pagas, portanto o histórico continua coerente.
     */
    double creditCardPurchases = 0;
    double realizedFinancialCosts = 0;

    for (final CreditCardTransactionEntity transaction
        in bills.expand((bill) => bill.transactions).where((tx) => tx.amount > 0)) {
      final double reportAmount =
          _reportableCreditCardExpense(transaction).toRound(2);
      if (transaction.cashAdvancePlanId != null) {
        realizedFinancialCosts += reportAmount;
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
      } else {
        creditCardPurchases += reportAmount;
      }
    }

    creditCardPurchases = creditCardPurchases.toRound(2);
    realizedFinancialCosts = realizedFinancialCosts.toRound(2);

    final double plannedFinancialCosts = plannedOperations
        .where(
          (plan) =>
              !plan.billDueDate.isBefore(month) &&
              !plan.billDueDate.isAfter(endMonth),
        )
        .fold(0.0, (total, plan) => total + plan.financialCost)
        .toRound(2);

    final double plannedPurchaseExpenses = plannedPurchases
        .fold(0.0, (total, purchase) =>
            total + purchase.principalDueInPeriod(month, endMonth))
        .toRound(2);

    final double plannedPurchaseFinancialCosts = plannedPurchases
        .fold(0.0, (total, purchase) =>
            total + purchase.financialCostDueInPeriod(month, endMonth))
        .toRound(2);

    final double allPlannedFinancialCosts =
        (plannedFinancialCosts + plannedPurchaseFinancialCosts).toRound(2);

    return HomeMonthlyEconomyEntity(
      incomes: incomes,
      expenses: (
        regularExpenses +
        creditCardPurchases +
        realizedFinancialCosts +
        allPlannedFinancialCosts +
        plannedPurchaseExpenses
      ).toRound(2),
      regularExpenses: regularExpenses,
      creditCardPurchases: creditCardPurchases,
      realizedFinancialCosts: realizedFinancialCosts,
      plannedFinancialCosts: allPlannedFinancialCosts,
      plannedPurchases: plannedPurchaseExpenses,
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

  Future<List<HomeMonthlyBalanceEntity>>
      _loadMonthlyBalance() async {
    final DateTime now = DateTime.now();

    final DateTime startMonth =
        now.subtractMonths(5).getInitialMonth();

    final DateTime endMonth =
        now.getFinalMonth();

    final List<HomeMonthlyBalanceEntity> results =
        await _monthlyBalance.findMonthlyBalances(
      startDate: startMonth,
      endDate: endMonth,
    );

    List<HomeMonthlyBalanceEntity> monthlyBalances = [];

    for (int i = 0; i < 6; i++) {
      final DateTime date =
          i == 0
              ? now
              : now.subtractMonths(i);

      monthlyBalances.add(
        results.firstWhere(
          (e) =>
              e.date.year == date.year &&
              e.date.month == date.month,
          orElse: () =>
              HomeMonthlyBalanceEntity(
            date: date.getInitialMonth(),
            balance: 0,
          ),
        ),
      );
    }

    return monthlyBalances.reversed.toList();
  }

  Future<ResultMonthlyTransaction>
      _loadMonthlyTransaction() async {
    final DateTime dateNow = DateTime.now();

    final TransactionsByPeriodEntity transactions =
        await _transactionFind.findByPeriod(
      dateNow.getInitialMonth(),
      dateNow.getFinalMonth(),
    );

    return (
      amountsIncome: transactions.amountsIncome,
      amountsExpense: transactions.amountsExpense,
    );
  }

  Future<ResultTransactionsUnpaidUnreceived>
      _loadTransactionsUnpaidUnreceived() async {
    final DateTime month = _selectedMonth.getInitialMonth();
    final DateTime nextMonth = _nextMonth(month);
    final DateTime currentMonth = DateTime.now().getInitialMonth();
    final bool isCurrent = month.year == currentMonth.year &&
        month.month == currentMonth.month;

    bool belongsToMonth(DateTime date) => isCurrent
        ? date.isBefore(nextMonth)
        : !date.isBefore(month) && date.isBefore(nextMonth);

    final results = await Future.wait<dynamic>([
      _transactionFind.findUnpaidUnreceived(),
      _findBillsForProjection(month),
      _cashAdvance.findPlanned(),
      _purchasePlanning.findAll(),
    ]);

    final List<ITransactionEntity> pending =
        (results[0] as List).cast<ITransactionEntity>();
    final List<CreditCardBillEntity> openBills =
        (results[1] as List).cast<CreditCardBillEntity>();
    final List<CardCashAdvancePlanEntity> plannedCredits =
        (results[2] as List).cast<CardCashAdvancePlanEntity>();
    final List<PlannedPurchaseEntity> plannedPurchases =
        (results[3] as List).cast<PlannedPurchaseEntity>();

    final double pendingIncomes = pending
        .whereType<IncomeEntity>()
        .where((income) => !income.received && belongsToMonth(income.date))
        .fold(0.0, (total, income) => total + income.amount.abs());

    final double plannedCreditReceipts = plannedCredits
        .where((plan) => belongsToMonth(plan.linkedEntryDate))
        .fold(0.0, (total, plan) => total + plan.amountReceived.abs());

    final double pendingExpenses = pending
        .whereType<ExpenseEntity>()
        .where((expense) =>
            !expense.paid &&
            expense.idCreditCard == null &&
            belongsToMonth(expense.date))
        .fold(0.0, (total, expense) => total + expense.amount.abs());

    final double openBillsAmount = openBills
        .where((bill) => bill.billAmount > 0)
        .fold(0.0, (total, bill) => total + bill.billAmount.abs());

    final double plannedCreditCharges = plannedCredits
        .where((plan) => belongsToMonth(plan.billDueDate))
        .fold(0.0, (total, plan) => total + plan.amountCharged.abs());

    double plannedExpenses = 0;
    for (final PlannedPurchaseEntity plan in plannedPurchases) {
      if (!plan.isCreditCard) {
        if (belongsToMonth(plan.plannedDate)) {
          plannedExpenses += plan.amount.abs();
        }
        continue;
      }
      plannedExpenses += plan.installmentSchedule
          .where((installment) => belongsToMonth(installment.dueDate))
          .fold(0.0, (total, installment) => total + installment.amount.abs());
    }

    return (
      amountsIncome:
          (pendingIncomes + plannedCreditReceipts).toRound(2),
      amountsExpense: -(
        pendingExpenses +
        openBillsAmount +
        plannedCreditCharges +
        plannedExpenses
      ).toRound(2),
    );
  }
}
