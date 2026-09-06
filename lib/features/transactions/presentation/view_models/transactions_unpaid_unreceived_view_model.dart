import 'package:collection/collection.dart';
import 'package:rallet/features/account/domain/entities/account_entity.dart';
import 'package:rallet/features/account/domain/use_cases/i_account_find.dart';
import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/card_cash_advance/domain/use_cases/i_card_cash_advance.dart';
import 'package:rallet/features/category/domain/entities/category_entity.dart';
import 'package:rallet/features/category/domain/enums/category_type_enum.dart';
import 'package:rallet/features/category/domain/use_cases/i_category_find.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_find.dart';
import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';
import 'package:rallet/features/purchase_planning/domain/use_cases/i_purchase_planning.dart';
import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/entities/i_transaction_entity.dart';
import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/domain/enums/recurrence_scope_enum.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_expense_save.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_income_save.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_transaction_delete.dart';
import 'package:rallet/features/transactions/domain/use_cases/i_transaction_find.dart';
import 'package:rallet/shared/extensions/date_time_extension.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/presentation/commands/command.dart';
import 'package:flutter/foundation.dart';

class TransactionsUnpaidUnreceivedViewModel extends ChangeNotifier {
  final ITransactionFind _transactionFind;
  final ITransactionDelete _transactionDelete;
  final ICategoryFind _categoryFind;
  final IAccountFind _accountFind;
  final ICreditCardFind _creditCardFind;
  final ICardCashAdvance _cashAdvance;
  final IPurchasePlanning _purchasePlanning;
  final IExpenseSave _expenseSave;
  final IIncomeSave _incomeSave;

  late final Command1<void, CategoryTypeEnum> init;

  TransactionsUnpaidUnreceivedViewModel({
    required ITransactionFind transactionFind,
    required ITransactionDelete transactionDelete,
    required ICategoryFind categoryFind,
    required IAccountFind accountFind,
    required ICreditCardFind creditCardFind,
    required ICardCashAdvance cashAdvance,
    required IPurchasePlanning purchasePlanning,
    required IExpenseSave expenseSave,
    required IIncomeSave incomeSave,
  })  : _transactionFind = transactionFind,
        _transactionDelete = transactionDelete,
        _categoryFind = categoryFind,
        _accountFind = accountFind,
        _creditCardFind = creditCardFind,
        _cashAdvance = cashAdvance,
        _purchasePlanning = purchasePlanning,
        _expenseSave = expenseSave,
        _incomeSave = incomeSave {
    init = Command1(_init);
  }

  CategoryTypeEnum? _type;

  DateTime _selectedMonth = DateTime.now().getInitialMonth();
  DateTime get selectedMonth => _selectedMonth;

  List<ITransactionEntity> _transactions = [];
  List<ITransactionEntity> get transactions => _transactions;

  List<CreditCardBillEntity> _bills = [];
  List<CreditCardBillEntity> get bills => _bills;

  List<CardCashAdvancePlanEntity> _plans = [];
  List<CardCashAdvancePlanEntity> get plans => _plans;

  List<PlannedPurchaseEntity> _plannedExpenses = [];
  List<PlannedPurchaseEntity> get plannedExpenses => _plannedExpenses;

  List<CreditCardEntity> _creditCards = [];

  List<CategoryEntity> _categories = [];
  List<CategoryEntity> get categories => _categories;

  List<AccountEntity> _accounts = [];
  List<AccountEntity> get accounts => _accounts;

  double get totalPaidOrReceived => transactions
      .map((e) => isPaidOrReceived(e) ? e.amount : 0.0)
      .sum
      .toDouble()
      .toRound(2);

  double get totalPayableOrReceivable {
    final double transactionTotal = transactions
        .map((e) => isPaidOrReceived(e) ? 0.0 : e.amount)
        .sum
        .toDouble();

    final double billTotal = _type == CategoryTypeEnum.expense
        ? -bills
            .map((bill) => bill.billAmount > 0 ? bill.billAmount : 0.0)
            .sum
            .toDouble()
        : 0.0;

    final double planTotal = _type == CategoryTypeEnum.expense
        ? -plans.map((plan) => plan.amountCharged).sum.toDouble()
        : plans.map((plan) => plan.amountReceived).sum.toDouble();

    final double plannedExpenseTotal = _type == CategoryTypeEnum.expense
        ? -_plannedExpenses
            .map(_plannedExpenseAmountInSelectedMonth)
            .sum
            .toDouble()
        : 0.0;

    return (transactionTotal + billTotal + planTotal + plannedExpenseTotal)
        .toRound(2);
  }

  Future<void> _init(CategoryTypeEnum type) async {
    _type = type;
    await _loadSelectedMonth();
  }

  void setSelectedMonth(DateTime month) {
    _selectedMonth = month.getInitialMonth();
    notifyListeners();
  }

  Future<void> previousMonth() async {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    notifyListeners();
    await _loadSelectedMonth();
  }

  Future<void> nextMonth() async {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    notifyListeners();
    await _loadSelectedMonth();
  }

  Future<void> goCurrentMonth() async {
    _selectedMonth = DateTime.now().getInitialMonth();
    notifyListeners();
    await _loadSelectedMonth();
  }

  Future<void> refresh() => _loadSelectedMonth();

  Future<void> _loadSelectedMonth() async {
    final CategoryTypeEnum? type = _type;
    if (type == null) return;

    final DateTime startMonth = _selectedMonth.getInitialMonth();
    final DateTime nextMonth = startMonth.addMonths(1);
    final DateTime endMonth = nextMonth.subtract(const Duration(microseconds: 1));
    final DateTime currentMonth = DateTime.now().getInitialMonth();
    final bool isCurrent = startMonth.year == currentMonth.year && startMonth.month == currentMonth.month;

    bool belongsToSelectedMonth(DateTime date) {
      if (isCurrent) return date.isBefore(nextMonth);
      return !date.isBefore(startMonth) && date.isBefore(nextMonth);
    }

    final results = await Future.wait<dynamic>([
      _transactionFind.findUnpaidUnreceived(type: type),
      _categoryFind.findAll(deleted: true),
      _accountFind.findAll(deleted: true),
      _creditCardFind.findAll(),
      _cashAdvance.findPlanned(),
      _purchasePlanning.findAll(),
      if (type == CategoryTypeEnum.expense)
        (isCurrent
            ? _creditCardFind.findBillsByPeriod(DateTime(1970, 1, 1), endMonth)
            : _creditCardFind.findBillsByPeriod(startMonth, endMonth)),
    ]);

    _transactions = (results[0] as List)
        .cast<ITransactionEntity>()
        .where((transaction) => belongsToSelectedMonth(transaction.date))
        .toList();
    _categories = (results[1] as List).cast<CategoryEntity>();
    _accounts = (results[2] as List).cast<AccountEntity>();
    _creditCards = (results[3] as List).cast<CreditCardEntity>();

    final List<CardCashAdvancePlanEntity> allPlans =
        (results[4] as List).cast<CardCashAdvancePlanEntity>();
    _plans = allPlans.where((plan) {
      final DateTime reference = type == CategoryTypeEnum.expense
          ? plan.billDueDate
          : plan.plannedDate;
      return belongsToSelectedMonth(reference);
    }).toList();

    final List<PlannedPurchaseEntity> allPlannedExpenses =
        (results[5] as List).cast<PlannedPurchaseEntity>();
    _plannedExpenses = type == CategoryTypeEnum.expense
        ? allPlannedExpenses
            .where((plan) => _plannedExpenseAmountInSelectedMonth(plan) > 0)
            .toList()
        : [];

    if (type == CategoryTypeEnum.expense) {
      _bills = (results[6] as List)
          .cast<CreditCardBillEntity>()
          .where((bill) => bill.billAmount > 0)
          .toList();
    } else {
      _bills = [];
    }

    notifyListeners();
  }

  double _plannedExpenseAmountInSelectedMonth(PlannedPurchaseEntity plan) {
    final DateTime start = _selectedMonth.getInitialMonth();
    final DateTime next = start.addMonths(1);
    final DateTime current = DateTime.now().getInitialMonth();
    final bool isCurrent =
        start.year == current.year && start.month == current.month;

    if (!plan.isCreditCard) {
      final bool belongs = isCurrent
          ? plan.plannedDate.isBefore(next)
          : !plan.plannedDate.isBefore(start) && plan.plannedDate.isBefore(next);
      return belongs ? plan.amount.abs().toRound(2) : 0;
    }

    return plan.installmentSchedule
        .where((installment) => isCurrent
            ? installment.dueDate.isBefore(next)
            : !installment.dueDate.isBefore(start) &&
                installment.dueDate.isBefore(next))
        .fold(0.0, (total, installment) => total + installment.amount.abs())
        .toRound(2);
  }

  double plannedExpenseAmount(PlannedPurchaseEntity plan) =>
      _plannedExpenseAmountInSelectedMonth(plan);

  CreditCardEntity creditCardForBill(CreditCardBillEntity bill) =>
      _creditCards.firstWhere((card) => card.id == bill.idCreditCard);

  CreditCardEntity creditCardForPlan(CardCashAdvancePlanEntity plan) =>
      _creditCards.firstWhere((card) => card.id == plan.idCreditCard);

  AccountEntity accountForPlan(CardCashAdvancePlanEntity plan) =>
      _accounts.firstWhere((account) => account.id == plan.idAccount);

  Future<void> realizePlan(CardCashAdvancePlanEntity plan) async {
    await _cashAdvance.realize(plan);
    await _loadSelectedMonth();
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

    await _loadSelectedMonth();
  }

  Future<void> deleteTransactions(
    List<ITransactionEntity> value, {
    RecurrenceScopeEnum recurrenceScope = RecurrenceScopeEnum.single,
  }) async {
    await _transactionDelete.deleteTransactions(
      value,
      recurrenceScope: recurrenceScope,
    );
    _transactions = transactions
        .where((e) => !value.any((t) => t.id == e.id))
        .toList();
    notifyListeners();
  }

  void setTransactions(List<ITransactionEntity> value) {
    _transactions = value;
    notifyListeners();
  }

  bool isPaidOrReceived(ITransactionEntity transaction) =>
      transaction is ExpenseEntity
          ? transaction.paid
          : (transaction as IncomeEntity).received;
}
