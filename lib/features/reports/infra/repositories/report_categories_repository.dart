import 'package:collection/collection.dart';
import 'package:rallet/features/card_cash_advance/domain/enums/card_cash_advance_status_enum.dart';
import 'package:rallet/features/card_cash_advance/infra/data_sources/i_card_cash_advance_local_data_source.dart';
import 'package:rallet/features/category/domain/enums/category_type_enum.dart';
import 'package:rallet/features/category/helpers/factories/category_factory.dart';
import 'package:rallet/features/category/infra/data_sources/i_category_local_data_source.dart';
import 'package:rallet/features/category/infra/models/category_model.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/features/credit_card/helpers/factories/credit_card_transaction_factory.dart';
import 'package:rallet/features/credit_card/infra/data_sources/i_credit_card_bill_local_data_source.dart';
import 'package:rallet/features/credit_card/infra/models/credit_card_bill_model.dart';
import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';
import 'package:rallet/features/purchase_planning/infra/data_sources/i_purchase_planning_local_data_source.dart';
import 'package:rallet/features/reports/domain/entities/report_category_entity.dart';
import 'package:rallet/features/reports/domain/repositories/i_report_categories_repository.dart';
import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/entities/i_transaction_entity.dart';
import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/helpers/factories/expense_factory.dart';
import 'package:rallet/features/transactions/helpers/factories/income_factory.dart';
import 'package:rallet/features/transactions/infra/data_sources/i_expense_local_data_source.dart';
import 'package:rallet/features/transactions/infra/data_sources/i_income_local_data_source.dart';
import 'package:rallet/features/transactions/infra/models/expense_model.dart';
import 'package:rallet/features/transactions/infra/models/income_model.dart';
import 'package:rallet/shared/classes/constants.dart';
import 'package:rallet/shared/extensions/double_extension.dart';

class ReportCategoriesRepository implements IReportCategoriesRepository {
  final IExpenseLocalDataSource _expenseLocalDataSource;
  final IIncomeLocalDataSource _incomeLocalDataSource;
  final ICreditCardBillLocalDataSource _creditCardBillLocalDataSource;
  final ICardCashAdvanceLocalDataSource _cardCashAdvanceLocalDataSource;
  final IPurchasePlanningLocalDataSource _purchasePlanningLocalDataSource;
  final ICategoryLocalDataSource _categoriesLocalDataSource;

  ReportCategoriesRepository({
    required IExpenseLocalDataSource expenseLocalDataSource,
    required IIncomeLocalDataSource incomeLocalDataSource,
    required ICreditCardBillLocalDataSource creditCardBillLocalDataSource,
    required ICardCashAdvanceLocalDataSource cardCashAdvanceLocalDataSource,
    required IPurchasePlanningLocalDataSource purchasePlanningLocalDataSource,
    required ICategoryLocalDataSource categoriesLocalDataSource,
  })  : _expenseLocalDataSource = expenseLocalDataSource,
        _incomeLocalDataSource = incomeLocalDataSource,
        _creditCardBillLocalDataSource = creditCardBillLocalDataSource,
        _cardCashAdvanceLocalDataSource = cardCashAdvanceLocalDataSource,
        _purchasePlanningLocalDataSource = purchasePlanningLocalDataSource,
        _categoriesLocalDataSource = categoriesLocalDataSource;

  @override
  Future<List<ReportCategoryEntity>> findByPeriod({
    required DateTime? startDate,
    required DateTime? endDate,
    required CategoryTypeEnum type,
  }) async {
    final List<String> transactionWhere = [];
    final List<dynamic> transactionWhereArgs = [];

    if (startDate != null) {
      transactionWhere.add('date >= ?');
      transactionWhereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      transactionWhere.add('date <= ?');
      transactionWhereArgs.add(endDate.toIso8601String());
    }

    final List<ITransactionEntity> transactions = [];

    if (type == CategoryTypeEnum.expense) {
      // 1) Despesas comuns continuam pela própria data do lançamento.
      final List<String> expenseWhere = [
        ...transactionWhere,
        'id_credit_card IS NULL',
      ];

      final List<ExpenseModel> expenses = await _expenseLocalDataSource.findAll(
        where: expenseWhere.join(' AND '),
        whereArgs: [...transactionWhereArgs],
      );
      transactions.addAll(expenses.map((e) => ExpenseFactory.toEntity(e)));

      // 2) Cartão é contabilizado pela competência da fatura: vencimento.
      // Isso faz o detalhamento fechar com o Resumo do mês.
      final List<String> billWhere = [];
      final List<dynamic> billWhereArgs = [];
      if (startDate != null) {
        billWhere.add('bill_due_date >= ?');
        billWhereArgs.add(startDate.toIso8601String());
      }
      if (endDate != null) {
        billWhere.add('bill_due_date <= ?');
        billWhereArgs.add(endDate.toIso8601String());
      }

      final List<CreditCardBillModel> bills =
          await _creditCardBillLocalDataSource.findAll(
        where: billWhere.isEmpty ? null : billWhere.join(' AND '),
        whereArgs: billWhereArgs,
      );

      for (final CreditCardBillModel bill in bills) {
        for (final model in bill.transactions.where((tx) => tx.amount > 0)) {
          final CreditCardTransactionEntity entity =
              CreditCardTransactionFactory.toEntity(model);

          final double amount = model.cashAdvancePlanId == null
              ? model.amount.abs().toRound(2)
              : (model.amount.abs() - (model.cashAdvancePrincipal ?? 0))
                  .clamp(0, double.infinity)
                  .toDouble()
                  .toRound(2);

          if (amount <= 0) continue;

          entity
            ..amount = -amount
            ..date = bill.billDueDate;
          transactions.add(entity);
        }
      }

      // 3) Planejamentos ainda não viraram transação real de cartão. Mesmo
      // assim o juros/taxa é um custo considerado no cenário atual do usuário.
      final List<String> planWhere = ['status = ?'];
      final List<dynamic> planWhereArgs = [
        CardCashAdvanceStatusEnum.planned.value,
      ];
      if (startDate != null) {
        planWhere.add('bill_due_date >= ?');
        planWhereArgs.add(startDate.toIso8601String());
      }
      if (endDate != null) {
        planWhere.add('bill_due_date <= ?');
        planWhereArgs.add(endDate.toIso8601String());
      }

      final plans = await _cardCashAdvanceLocalDataSource.findAll(
        where: planWhere.join(' AND '),
        whereArgs: planWhereArgs,
      );

      for (final plan in plans) {
        final double financialCost =
            (plan.amountCharged - plan.amountReceived)
                .clamp(0, double.infinity)
                .toDouble()
                .toRound(2);
        if (financialCost <= 0) continue;

        transactions.add(
          CreditCardTransactionEntity(
            id: plan.id,
            createdAt: plan.createdAt,
            deletedAt: null,
            description: 'Juros planejados • ${plan.description}',
            amount: -financialCost,
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

      // 4) Despesas planejadas participam do cenário na categoria escolhida.
      // À vista usa a data prevista; cartão usa o vencimento de cada parcela.
      final purchases = await _purchasePlanningLocalDataSource.findAll();

      for (final model in purchases) {
        final purchase = PlannedPurchaseEntity(
          id: model.id,
          createdAt: model.createdAt,
          deletedAt: model.deletedAt,
          description: model.description,
          amount: model.amount,
          plannedDate: model.plannedDate,
          reserveAmount: model.reserveAmount,
          paymentType: model.paymentType,
          idCreditCard: model.idCreditCard,
          installmentCount: model.installmentCount,
          totalCharged: model.totalCharged,
          firstBillDueDate: model.firstBillDueDate,
          idCategory: model.idCategory,
          idAccount: model.idAccount,
          observation: model.observation,
        );

        if (purchase.isCreditCard) {
          final principalValues = purchase.principalInstallmentAmounts;
          final costValues = purchase.financialCostInstallmentAmounts;
          final schedule = purchase.installmentSchedule;
          for (int index = 0; index < schedule.length; index++) {
            final installment = schedule[index];
            if (startDate != null && installment.dueDate.isBefore(startDate)) continue;
            if (endDate != null && installment.dueDate.isAfter(endDate)) continue;
            final double principal = principalValues[index];
            final double cost = costValues[index];
            if (principal > 0) {
              transactions.add(
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
              transactions.add(
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
          if (startDate != null && purchase.plannedDate.isBefore(startDate)) continue;
          if (endDate != null && purchase.plannedDate.isAfter(endDate)) continue;
          transactions.add(
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

      transactions.sortBy((e) => e.date);
    } else {
      final List<IncomeModel> incomes = await _incomeLocalDataSource.findAll(
        where: transactionWhere.isEmpty ? null : transactionWhere.join(' AND '),
        whereArgs: transactionWhereArgs,
      );

      transactions.addAll(incomes.map((e) => IncomeFactory.toEntity(e)));
    }

    if (transactions.isEmpty) return [];

    String? categoryId(ITransactionEntity entity) {
      if (entity is ExpenseEntity) return entity.idCategory;
      if (entity is CreditCardTransactionEntity) return entity.idCategory;
      return (entity as IncomeEntity).idCategory;
    }

    final List<String> ids = transactions
        .map(categoryId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (ids.isEmpty) return [];

    final List<CategoryModel> categories = await _categoriesLocalDataSource.findAll(
      where: 'id IN (${ids.map((_) => '?').join(', ')})',
      whereArgs: ids,
      deleted: true,
    );

    final Map<String, List<ITransactionEntity>> group = groupBy(
      transactions.where((e) => categoryId(e)?.isNotEmpty == true),
      (e) => categoryId(e)!,
    );

    final List<ReportCategoryEntity> result = [];

    group.forEach((key, value) {
      final CategoryModel? category =
          categories.firstWhereOrNull((e) => e.id == key);
      if (category == null) return;

      result.add(
        ReportCategoryEntity(
          category: CategoryFactory.toEntity(category),
          transactions: value,
        ),
      );
    });

    return result.sortedBy((e) => e.category.description);
  }
}
