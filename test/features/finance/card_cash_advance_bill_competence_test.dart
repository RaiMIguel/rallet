import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/card_cash_advance/domain/enums/card_cash_advance_status_enum.dart';
import 'package:rallet/features/card_cash_advance/domain/repositories/i_card_cash_advance_repository.dart';
import 'package:rallet/features/card_cash_advance/domain/use_cases/card_cash_advance.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/features/credit_card/domain/repositories/i_credit_card_bill_repository.dart';
import 'package:rallet/features/credit_card/domain/repositories/i_credit_card_transaction_repository.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_bill_dates.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_find.dart';
import 'package:rallet/features/statement/domain/entities/statement_entity.dart';
import 'package:rallet/features/statement/domain/repositories/i_statement_repository.dart';
import 'package:rallet/shared/domain/repositories/i_local_db_transaction_repository.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local_transaction.dart';
import 'package:rallet/shared/presentation/notifiers/event_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('competência do custo do crédito via cartão', () {
    test('operação realizada acompanha o vencimento atual da fatura vinculada',
        () async {
      final storedDueDate = DateTime(2026, 9, 10, 23, 59, 59, 999);
      final currentDueDate = DateTime(2026, 10, 10, 23, 59, 59, 999);

      final plan = _plan(
        status: CardCashAdvanceStatusEnum.realized,
        billDueDate: storedDueDate,
        transactionId: 'tx-1',
      );
      final transaction = _transaction(id: 'tx-1', billId: 'bill-1');
      final bill = _bill(id: 'bill-1', dueDate: currentDueDate);

      final useCase = CardCashAdvance(
        repository: _CashAdvanceRepository(plan),
        creditCardFind: _CreditCardFind(),
        billDates: _BillDates(),
        creditCardTransactionRepository:
            _CreditCardTransactionRepository(transaction),
        creditCardBillRepository: _CreditCardBillRepository(bill),
        statementRepository: _StatementRepository(),
        localDBTransactionRepository: _LocalDbTransactionRepository(),
        eventNotifier: EventNotifier(),
      );

      final result = await useCase.findById(plan.id);

      expect(result, isNotNull);
      expect(result!.billDueDate, currentDueDate);
      // A sincronização é de leitura: não cria nem altera outra movimentação.
      expect(plan.billDueDate, storedDueDate);
    });

    test('planejamento ainda não realizado mantém a competência planejada',
        () async {
      final plannedDueDate = DateTime(2026, 9, 10, 23, 59, 59, 999);
      final plan = _plan(
        status: CardCashAdvanceStatusEnum.planned,
        billDueDate: plannedDueDate,
        transactionId: null,
      );

      final useCase = CardCashAdvance(
        repository: _CashAdvanceRepository(plan),
        creditCardFind: _CreditCardFind(),
        billDates: _BillDates(),
        creditCardTransactionRepository:
            _CreditCardTransactionRepository(null),
        creditCardBillRepository: _CreditCardBillRepository(null),
        statementRepository: _StatementRepository(),
        localDBTransactionRepository: _LocalDbTransactionRepository(),
        eventNotifier: EventNotifier(),
      );

      final result = await useCase.findById(plan.id);
      expect(result!.billDueDate, plannedDueDate);
    });

    test('repara movimentação de crédito removida sem duplicar a entrada na conta',
        () async {
      final dueDate = DateTime(2026, 10, 10, 23, 59, 59, 999);
      final plan = _plan(
        status: CardCashAdvanceStatusEnum.realized,
        billDueDate: DateTime(2026, 9, 10, 23, 59, 59, 999),
        transactionId: 'tx-1',
      );
      final deletedTransaction = _transaction(id: 'tx-1', billId: 'bill-1')
        ..deletedAt = DateTime(2026, 9, 3);
      final transactionRepository = _CreditCardTransactionRepository(
        null,
        deletedTransaction: deletedTransaction,
      );
      final statementRepository = _StatementRepository(
        StatementEntity(
          id: 'statement-1',
          createdAt: DateTime(2026, 9, 1),
          deletedAt: null,
          amount: 500,
          date: DateTime(2026, 9, 1),
          idAccount: 'account-1',
          idExpense: null,
          idIncome: null,
          idTransfer: null,
        ),
      );

      final useCase = CardCashAdvance(
        repository: _CashAdvanceRepository(plan),
        creditCardFind: _CreditCardFind(),
        billDates: _BillDates(),
        creditCardTransactionRepository: transactionRepository,
        creditCardBillRepository:
            _CreditCardBillRepository(_bill(id: 'bill-1', dueDate: dueDate)),
        statementRepository: statementRepository,
        localDBTransactionRepository: _LocalDbTransactionRepository(),
        eventNotifier: EventNotifier(),
      );

      expect(await useCase.hasMissingLinkedTransaction(plan), isTrue);

      final repaired = await useCase.repairMissingLinkedTransaction(plan);

      expect(transactionRepository.savedTransaction, isNotNull);
      expect(transactionRepository.savedTransaction!.id, 'tx-1');
      expect(transactionRepository.savedTransaction!.deletedAt, isNull);
      expect(transactionRepository.savedTransaction!.cashAdvancePlanId, plan.id);
      expect(transactionRepository.savedTransaction!.cashAdvancePrincipal, 500);
      expect(repaired.billDueDate, dueDate);
      expect(await useCase.hasMissingLinkedTransaction(plan), isFalse);
      // A entrada na conta já existia e não é salva novamente durante o reparo.
      expect(statementRepository.saveCalls, 0);
    });
  });
}

CardCashAdvancePlanEntity _plan({
  required CardCashAdvanceStatusEnum status,
  required DateTime billDueDate,
  required String? transactionId,
}) {
  return CardCashAdvancePlanEntity(
    id: 'cash-1',
    createdAt: DateTime(2026, 9, 1),
    deletedAt: null,
    description: 'Crédito teste',
    idAccount: 'account-1',
    idCreditCard: 'card-1',
    amountReceived: 500,
    amountCharged: 550,
    plannedDate: DateTime(2026, 9, 1),
    billDueDate: billDueDate,
    status: status,
    realizedAt:
        status == CardCashAdvanceStatusEnum.realized ? DateTime(2026, 9, 1) : null,
    idStatement:
        status == CardCashAdvanceStatusEnum.realized ? 'statement-1' : null,
    idCreditCardTransaction: transactionId,
  );
}

CreditCardTransactionEntity _transaction({
  required String id,
  required String? billId,
}) {
  return CreditCardTransactionEntity(
    id: id,
    createdAt: DateTime(2026, 9, 1),
    deletedAt: null,
    description: 'Crédito via cartão',
    amount: 550,
    date: DateTime(2026, 9, 1),
    idCategory: null,
    idCreditCard: 'card-1',
    idCreditCardBill: billId,
    observation: null,
    cashAdvancePlanId: 'cash-1',
    cashAdvancePrincipal: 500,
  );
}

CreditCardBillEntity _bill({required String id, required DateTime dueDate}) {
  return CreditCardBillEntity(
    id: id,
    createdAt: DateTime(2026, 9, 1),
    deletedAt: null,
    billClosingDate: DateTime(dueDate.year, dueDate.month - 1, 30),
    billDueDate: dueDate,
    idCreditCard: 'card-1',
    transactions: const [],
  );
}

class _CashAdvanceRepository implements ICardCashAdvanceRepository {
  final CardCashAdvancePlanEntity plan;
  _CashAdvanceRepository(this.plan);

  @override
  Future<CardCashAdvancePlanEntity?> findById(String id,
          {ITransactionExecutor? txn}) async =>
      id == plan.id ? plan : null;

  @override
  Future<List<CardCashAdvancePlanEntity>> findAll(
          {bool deleted = false, ITransactionExecutor? txn}) async =>
      [plan];

  @override
  Future<List<CardCashAdvancePlanEntity>> findPlanned(
          {ITransactionExecutor? txn}) async =>
      plan.isPlanned ? [plan] : [];

  @override
  Future<CardCashAdvancePlanEntity> save(CardCashAdvancePlanEntity entity,
          {ITransactionExecutor? txn}) async =>
      entity;

  @override
  Future<void> delete(CardCashAdvancePlanEntity entity,
      {ITransactionExecutor? txn}) async {}
}

class _CreditCardTransactionRepository
    implements ICreditCardTransactionRepository {
  CreditCardTransactionEntity? transaction;
  final CreditCardTransactionEntity? deletedTransaction;
  CreditCardTransactionEntity? savedTransaction;

  _CreditCardTransactionRepository(
    this.transaction, {
    this.deletedTransaction,
  });

  @override
  Future<CreditCardTransactionEntity?> findById(String id,
          {ITransactionExecutor? txn}) async =>
      transaction?.id == id ? transaction : null;

  @override
  Future<CreditCardTransactionEntity?> findByIdIncludingDeleted(
    String id, {
    ITransactionExecutor? txn,
  }) async {
    if (transaction?.id == id) return transaction;
    return deletedTransaction?.id == id ? deletedTransaction : null;
  }

  @override
  Future<CreditCardTransactionEntity> save(
    CreditCardTransactionEntity entity, {
    ITransactionExecutor? txn,
  }) async {
    savedTransaction = entity.clone();
    transaction = entity.clone();
    return entity;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CreditCardBillRepository implements ICreditCardBillRepository {
  final CreditCardBillEntity? bill;
  _CreditCardBillRepository(this.bill);

  @override
  Future<CreditCardBillEntity?> findById(String id) async =>
      bill?.id == id ? bill : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CreditCardFind implements ICreditCardFind {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BillDates implements ICreditCardBillDates {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StatementRepository implements IStatementRepository {
  final StatementEntity? statement;
  int saveCalls = 0;

  _StatementRepository([this.statement]);

  @override
  Future<StatementEntity?> findById(String id) async =>
      statement?.id == id ? statement : null;

  @override
  Future<StatementEntity> save(StatementEntity entity,
      {ITransactionExecutor? txn}) async {
    saveCalls++;
    return entity;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LocalDbTransactionRepository implements ILocalDBTransactionRepository {
  @override
  Future<T> openTransaction<T>(ActionTxn<T> action) => action(_FakeTxn());
}

class _FakeTxn implements ITransactionExecutor {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
