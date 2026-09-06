import 'package:rallet/features/ad/domain/use_cases/i_ad_access.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/features/credit_card/domain/enums/installment_scope_enum.dart';
import 'package:rallet/features/credit_card/domain/repositories/i_credit_card_transaction_repository.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_transaction_delete.dart';
import 'package:rallet/features/statement/domain/repositories/i_statement_repository.dart';
import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/repositories/i_expense_repository.dart';
import 'package:rallet/shared/domain/repositories/i_local_db_transaction_repository.dart';
import 'package:rallet/shared/exceptions/exceptions.dart';

class CreditCardTransactionDelete implements ICreditCardTransactionDelete {
  final ICreditCardTransactionRepository _repository;
  final IExpenseRepository _expenseRepository;
  final IStatementRepository _statementRepository;
  final ILocalDBTransactionRepository _localDBTransactionRepository;
  final IAdAccess _adAccess;

  CreditCardTransactionDelete({
    required ICreditCardTransactionRepository repository,
    required IExpenseRepository expenseRepository,
    required IStatementRepository statementRepository,
    required ILocalDBTransactionRepository localDBTransactionRepository,
    required IAdAccess adAccess,
  })  : _repository = repository,
        _expenseRepository = expenseRepository,
        _statementRepository = statementRepository,
        _localDBTransactionRepository = localDBTransactionRepository,
        _adAccess = adAccess;

  @override
  Future<void> delete(CreditCardTransactionEntity entity) => _delete([entity]);

  @override
  Future<void> deleteMany(List<CreditCardTransactionEntity> entities) => _delete(entities);

  @override
  Future<void> deleteInstallments(
    CreditCardTransactionEntity entity,
    InstallmentScopeEnum scope,
  ) async {
    final List<CreditCardTransactionEntity> series =
        await _repository.findInstallments(entity);

    if (series.length <= 1 || scope == InstallmentScopeEnum.single) {
      await _delete([entity]);
      return;
    }

    final CreditCardTransactionEntity current = series.firstWhere(
      (item) => item.id == entity.id,
      orElse: () => entity,
    );
    final int currentNumber =
        current.installmentNumber ?? _parseInstallmentNumber(current.description) ?? 1;

    final List<CreditCardTransactionEntity> targets = scope == InstallmentScopeEnum.all
        ? series
        : series.where((item) {
            final int number =
                item.installmentNumber ?? _parseInstallmentNumber(item.description) ?? currentNumber;
            return number >= currentNumber;
          }).toList();

    await _delete(targets);
  }

  int? _parseInstallmentNumber(String description) {
    final match = RegExp(r'\((\d+)\/(\d+)\)\s*$').firstMatch(description.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  Future<void> _delete(List<CreditCardTransactionEntity> entities) async {
    final bool hasCashAdvanceLinked = entities.any(
      (entity) => entity.cashAdvancePlanId?.isNotEmpty == true,
    );
    if (hasCashAdvanceLinked) {
      throw ValidationException(
        'Esta movimentação pertence a uma operação de crédito via cartão. Abra a operação original para desfazer ou ajustar sem quebrar o vínculo financeiro.',
      );
    }

    final List<ExpenseEntity> expenses = await _expenseRepository.findByIdCreditCardTransaction(
      entities.map((e) => e.id).toList(),
    );

    await _localDBTransactionRepository.openTransaction((txn) async {
      await Future.wait([
        _repository.deleteMany(entities, txn: txn),
        _expenseRepository.deleteMany(expenses, txn: txn),
        _statementRepository.deleteByIdsExpense(
          expenses.map((e) => e.id).toList(),
          txn: txn,
        ),
      ]);
    });

    await _adAccess.consumeUse();
  }
}
