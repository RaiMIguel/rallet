import 'package:rallet/features/account/domain/entities/account_entity.dart';
import 'package:rallet/features/account/domain/entities/account_history_item_entity.dart';
import 'package:rallet/features/account/domain/use_cases/i_account_delete.dart';
import 'package:rallet/features/account/helpers/account_factory.dart';
import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/card_cash_advance/domain/use_cases/i_card_cash_advance.dart';
import 'package:rallet/features/statement/domain/repositories/i_statement_repository.dart';
import 'package:rallet/features/transactions/domain/repositories/i_expense_repository.dart';
import 'package:rallet/features/transactions/domain/repositories/i_income_repository.dart';
import 'package:rallet/features/transactions/domain/repositories/i_transfer_repository.dart';
import 'package:rallet/shared/extensions/double_extension.dart';
import 'package:rallet/shared/presentation/commands/command.dart';
import 'package:flutter/foundation.dart';

class AccountDetailsViewModel extends ChangeNotifier {
  final IStatementRepository _statementRepository;
  final IExpenseRepository _expenseRepository;
  final IIncomeRepository _incomeRepository;
  final ITransferRepository _transferRepository;
  final ICardCashAdvance _cashAdvance;

  late final Command1<void, AccountEntity> delete;
  late final Command1<void, AccountEntity> loadHistory;

  AccountDetailsViewModel({
    required IAccountDelete accountDelete,
    required IStatementRepository statementRepository,
    required IExpenseRepository expenseRepository,
    required IIncomeRepository incomeRepository,
    required ITransferRepository transferRepository,
    required ICardCashAdvance cashAdvance,
  })  : _statementRepository = statementRepository,
        _expenseRepository = expenseRepository,
        _incomeRepository = incomeRepository,
        _transferRepository = transferRepository,
        _cashAdvance = cashAdvance {
    delete = Command1<void, AccountEntity>(accountDelete.delete);
    loadHistory = Command1(_loadHistory);
  }

  AccountEntity _account = AccountFactory.newEntity();
  AccountEntity get account => _account;

  List<AccountHistoryItemEntity> _history = [];
  List<AccountHistoryItemEntity> get history => _history;

  void setAccount(AccountEntity value) {
    _account = value;
    notifyListeners();
  }

  Future<void> refreshHistory() => loadHistory.execute(_account);

  Future<void> _loadHistory(AccountEntity account) async {
    _account = account;
    final statements = await _statementRepository.findByAccount(account.id);
    final List<CardCashAdvancePlanEntity> cashAdvances =
        await _cashAdvance.findAll();
    final Map<String, CardCashAdvancePlanEntity> cashByStatement = {
      for (final plan in cashAdvances)
        if (plan.idStatement != null) plan.idStatement!: plan,
    };

    final List<AccountHistoryItemEntity> chronological = [];
    double runningBalance = 0;

    for (final statement in statements) {
      runningBalance = (runningBalance + statement.amount).toRound(2);

      if (statement.id == account.idStatementInitialAmount) {
        chronological.add(
          AccountHistoryItemEntity(
            statement: statement,
            originType: AccountHistoryOriginType.initialBalance,
            title: 'Saldo inicial',
            subtitle: 'Abertura da conta no Rallet',
            balanceAfter: runningBalance,
          ),
        );
        continue;
      }

      final cashAdvance = cashByStatement[statement.id];
      if (cashAdvance != null) {
        chronological.add(
          AccountHistoryItemEntity(
            statement: statement,
            originType: AccountHistoryOriginType.cardCashAdvance,
            title: cashAdvance.description.trim().isEmpty
                ? 'Crédito via cartão'
                : cashAdvance.description,
            subtitle: 'Crédito via cartão • operação vinculada',
            balanceAfter: runningBalance,
            cashAdvance: cashAdvance,
          ),
        );
        continue;
      }

      if (statement.idExpense != null) {
        final expense =
            await _expenseRepository.findById(statement.idExpense!);
        chronological.add(
          AccountHistoryItemEntity(
            statement: statement,
            originType: AccountHistoryOriginType.expense,
            title: expense?.description ?? 'Despesa',
            subtitle: expense == null ? 'Origem indisponível' : 'Despesa realizada',
            balanceAfter: runningBalance,
            expense: expense,
          ),
        );
        continue;
      }

      if (statement.idIncome != null) {
        final income = await _incomeRepository.findById(statement.idIncome!);
        chronological.add(
          AccountHistoryItemEntity(
            statement: statement,
            originType: AccountHistoryOriginType.income,
            title: income?.description ?? 'Receita',
            subtitle: income == null ? 'Origem indisponível' : 'Receita realizada',
            balanceAfter: runningBalance,
            income: income,
          ),
        );
        continue;
      }

      if (statement.idTransfer != null) {
        final transfer =
            await _transferRepository.findById(statement.idTransfer!);
        chronological.add(
          AccountHistoryItemEntity(
            statement: statement,
            originType: AccountHistoryOriginType.transfer,
            title: 'Transferência',
            subtitle: statement.amount >= 0 ? 'Entrada por transferência' : 'Saída por transferência',
            balanceAfter: runningBalance,
            transfer: transfer,
          ),
        );
        continue;
      }

      // Statements sem vínculo com receita/despesa/transferência são gerados
      // pela conciliação manual de saldo. Isso é uma movimentação patrimonial,
      // não uma receita ou despesa do relatório.
      chronological.add(
        AccountHistoryItemEntity(
          statement: statement,
          originType: AccountHistoryOriginType.balanceAdjustment,
          title: 'Ajuste de saldo',
          subtitle: 'Conciliação manual • não entra como receita/despesa',
          balanceAfter: runningBalance,
        ),
      );
    }

    _history = chronological.reversed.toList();
    notifyListeners();
  }
}
