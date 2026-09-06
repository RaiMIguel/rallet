import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/statement/domain/entities/statement_entity.dart';
import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/domain/entities/transfer_entity.dart';

enum AccountHistoryOriginType {
  initialBalance,
  income,
  expense,
  transfer,
  cardCashAdvance,
  balanceAdjustment,
  unknown,
}

/// Uma linha do extrato interno do Rallet.
///
/// A movimentação não é duplicada: este objeto é apenas uma visão de um
/// StatementEntity já existente e mantém referência para a origem real que
/// controla a edição.
class AccountHistoryItemEntity {
  final StatementEntity statement;
  final AccountHistoryOriginType originType;
  final String title;
  final String? subtitle;
  final double balanceAfter;
  final ExpenseEntity? expense;
  final IncomeEntity? income;
  final TransferEntity? transfer;
  final CardCashAdvancePlanEntity? cashAdvance;

  const AccountHistoryItemEntity({
    required this.statement,
    required this.originType,
    required this.title,
    required this.subtitle,
    required this.balanceAfter,
    this.expense,
    this.income,
    this.transfer,
    this.cashAdvance,
  });

  double get amount => statement.amount;
  DateTime get date => statement.date;
  bool get isIncome => amount >= 0;
  bool get hasEditableOrigin =>
      expense != null || income != null || transfer != null || cashAdvance != null;
}
