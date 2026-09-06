
import 'package:rallet/features/credit_card/domain/entities/credit_card_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_with_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/features/credit_card/domain/enums/brand_card_enum.dart';
import 'package:rallet/features/credit_card/domain/repositories/i_credit_card_bill_repository.dart';
import 'package:rallet/features/credit_card/domain/repositories/i_credit_card_repository.dart';
import 'package:rallet/features/credit_card/domain/repositories/i_credit_card_transaction_repository.dart';
import 'package:rallet/features/credit_card/domain/use_cases/credit_card_bill_save.dart';
import 'package:rallet/features/statement/domain/entities/statement_entity.dart';
import 'package:rallet/features/statement/domain/repositories/i_statement_repository.dart';
import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/entities/transaction_by_text_entity.dart';
import 'package:rallet/features/transactions/domain/repositories/i_expense_repository.dart';
import 'package:rallet/shared/domain/repositories/i_local_db_transaction_repository.dart';
import 'package:rallet/shared/exceptions/exceptions.dart';
import 'package:rallet/shared/infra/data_sources/database_local/database_operation.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local_batch.dart';
import 'package:rallet/shared/infra/data_sources/database_local/i_database_local_transaction.dart';
import 'package:rallet/shared/presentation/ui/app_locale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await AppLocale().load();
  });

  test('throws when payment exceeds the outstanding bill amount', () async {
    final creditCard = CreditCardEntity(
      id: 'credit-card-1',
      createdAt: null,
      deletedAt: null,
      description: 'Visa',
      amountLimit: 5000,
      billClosingDay: 10,
      billDueDay: 20,
      brand: CardBrandEnum.visa,
      idAccount: 'account-1',
      descriptionAccount: 'Main account',
      financialInstitutionAccount: null,
      amountLimitUtilized: 0,
    );

    final bill = CreditCardBillEntity(
      id: 'bill-1',
      createdAt: null,
      deletedAt: null,
      billClosingDate: DateTime.now().subtract(const Duration(days: 2)),
      billDueDate: DateTime.now().add(const Duration(days: 6)),
      idCreditCard: creditCard.id,
      transactions: [
        CreditCardTransactionEntity(
          id: 'tx-1',
          createdAt: null,
          deletedAt: null,
          description: 'Groceries',
          amount: 400,
          date: DateTime.now().subtract(const Duration(days: 10)),
          idCategory: 'cat-1',
          idCreditCard: creditCard.id,
          idCreditCardBill: 'bill-1',
          observation: null,
        ),
      ],
    );

    final useCase = CreditCardBillSave(
      repository: _FakeCreditCardBillRepository(),
      creditCardTransactionRepository: _FakeCreditCardTransactionRepository(),
      creditCardRepository: _FakeCreditCardRepository(creditCard),
      expenseRepository: _FakeExpenseRepository(),
      statementRepository: _FakeStatementRepository(),
      localDBTransactionRepository: _FakeLocalDBTransactionRepository(),
    );

    expect(
      () => useCase.payBill(
        creditCardBill: bill,
        payValue: 500,
        idAccount: 'account-1',
      ),
      throwsA(isA<ValidationException>()),
    );
  });
}

class _FakeCreditCardBillRepository implements ICreditCardBillRepository {
  @override
  Future<CreditCardBillEntity> save(CreditCardBillEntity entity) async => entity;

  @override
  Future<void> saveMany(List<CreditCardBillEntity> bills, {ITransactionExecutor? txn}) async {}

  @override
  Future<CreditCardBillEntity> saveOnlyBill(CreditCardBillEntity entity, {ITransactionExecutor? txn}) async => entity;

  @override
  Future<CreditCardBillEntity?> findById(String id) async => null;

  @override
  Future<List<CreditCardBillEntity>> findByIds(List<String> ids) async => const [];

  @override
  Future<CreditCardBillEntity?> findFirstAfterDate({required DateTime date, required String idCreditCard}) async => null;

  @override
  Future<List<CreditCardBillEntity>> findAllAfterDate({required DateTime date, required String idCreditCard, ITransactionExecutor? txn}) async => const [];

  @override
  Future<CreditCardBillEntity?> findFirstInPeriod({required DateTime startDate, required DateTime endDate, required String idCreditCard}) async => null;

  @override
  Future<List<CreditCardBillEntity>> findByPeriod({required DateTime startDate, required DateTime endDate, required String idCreditCard}) async => const [];
}

class _FakeCreditCardRepository implements ICreditCardRepository {
  final CreditCardEntity _creditCard;

  _FakeCreditCardRepository(this._creditCard);

  @override
  Future<CreditCardEntity> save(CreditCardEntity entity, {ITransactionExecutor? txn}) async => entity;

  @override
  Future<void> delete(CreditCardEntity entity) async {}

  @override
  Future<List<CreditCardEntity>> findAll() async => [_creditCard];

  @override
  Future<CreditCardEntity?> findById(String id, {bool deleted = false, ITransactionExecutor? txn}) async => _creditCard;

  @override
  Future<List<CreditCardWithBillEntity>> findCreditCardsWithBill() async => const [];

  @override
  Future<List<CreditCardBillEntity>> findBillsByPeriod(DateTime startDate, DateTime endDate) async => const [];

  @override
  Future<List<CreditCardBillEntity>> findAllBillsByPeriod(DateTime startDate, DateTime endDate) async => const [];

  @override
  Future<CreditCardEntity?> findByIdAccount(String id) async => _creditCard;
}

class _FakeCreditCardTransactionRepository implements ICreditCardTransactionRepository {
  @override
  Future<List<CreditCardTransactionEntity>> findInstallments(
    CreditCardTransactionEntity entity, {
    ITransactionExecutor? txn,
  }) async => const [];

  @override
  Future<CreditCardTransactionEntity?> findById(String id, {ITransactionExecutor? txn}) async => null;

  @override
  Future<CreditCardTransactionEntity?> findByIdIncludingDeleted(
    String id, {
    ITransactionExecutor? txn,
  }) async => null;

  @override
  Future<CreditCardTransactionEntity?> findByCashAdvancePlanId(
    String cashAdvancePlanId, {
    ITransactionExecutor? txn,
  }) async => null;

  @override
  Future<CreditCardTransactionEntity> save(CreditCardTransactionEntity entity, {ITransactionExecutor? txn}) async => entity;

  @override
  Future<void> saveMany(List<CreditCardTransactionEntity> transactions, {ITransactionExecutor? txn}) async {}

  @override
  Future<void> delete(CreditCardTransactionEntity entity, {ITransactionExecutor? txn}) async {}

  @override
  Future<void> deleteMany(List<CreditCardTransactionEntity> entities, {ITransactionExecutor? txn}) async {}
}

class _FakeExpenseRepository implements IExpenseRepository {
  @override
  Future<List<ExpenseEntity>> saveMany(
    List<ExpenseEntity> entities, {
    ITransactionExecutor? txn,
  }) async => entities;

  @override
  Future<ExpenseEntity> save(ExpenseEntity entity, {ITransactionExecutor? txn}) async => entity;

  @override
  Future<void> delete(ExpenseEntity entity, {ITransactionExecutor? txn}) async {}

  @override
  Future<void> deleteMany(List<ExpenseEntity> entities, {ITransactionExecutor? txn}) async {}

  @override
  Future<List<ExpenseEntity>> findByPeriod(DateTime startDate, DateTime endDate) async => const [];

  @override
  Future<List<TransactionByTextEntity>> findByText(String text) async => const [];

  @override
  Future<List<ExpenseEntity>> findByIdCreditCardTransaction(List<String> ids) async => const [];

  @override
  Future<List<ExpenseEntity>> findUnpaid() async => const [];

  @override
  Future<List<ExpenseEntity>> findByRecurrenceId(String recurrenceId) async => const [];

  @override
  Future<ExpenseEntity?> findById(String id) async => null;
}

class _FakeStatementRepository implements IStatementRepository {
  @override
  Future<StatementEntity> save(StatementEntity entity, {ITransactionExecutor? txn}) async => entity;

  @override
  Future<StatementEntity?> findById(String id) async => null;

  @override
  Future<List<StatementEntity>> findByAccount(String idAccount) async => const [];

  @override
  Future<StatementEntity?> findByIdExpense(String id) async => null;

  @override
  Future<StatementEntity?> findByIdIncome(String id) async => null;

  @override
  Future<List<StatementEntity>> findByIdTransfer(String id) async => const [];

  @override
  Future<void> delete(StatementEntity entity, {ITransactionExecutor? txn}) async {}

  @override
  Future<void> deleteByIdExpense(String id, {ITransactionExecutor? txn}) async {}

  @override
  Future<void> deleteByIdsExpense(List<String> ids, {ITransactionExecutor? txn}) async {}

  @override
  Future<void> deleteByIdIncome(String id, {ITransactionExecutor? txn}) async {}

  @override
  Future<void> deleteByIdTransfer(String id, {ITransactionExecutor? txn}) async {}
}

class _FakeLocalDBTransactionRepository implements ILocalDBTransactionRepository {
  @override
  Future<T> openTransaction<T>(ActionTxn<T> action) async => action(_FakeTransactionExecutor());
}

class _FakeTransactionExecutor implements ITransactionExecutor {
  @override
  IDatabaseLocalBatch batch() => throw UnimplementedError();

  @override
  Future<int> insert(String table, Map<String, dynamic> values) async => 0;

  @override
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  }) async => 0;

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async => 0;

  @override
  Future<void> execute(String sql, [List<dynamic>? arguments]) async {}

  @override
  Future<dynamic> raw(
    String sql,
    DatabaseOperation operation, [
    List<dynamic>? arguments,
  ]) async => null;

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async => const [];
}

