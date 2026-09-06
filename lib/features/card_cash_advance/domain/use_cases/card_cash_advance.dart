import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/card_cash_advance/domain/enums/card_cash_advance_status_enum.dart';
import 'package:rallet/features/card_cash_advance/domain/repositories/i_card_cash_advance_repository.dart';
import 'package:rallet/features/card_cash_advance/domain/use_cases/i_card_cash_advance.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/shared/domain/repositories/i_local_db_transaction_repository.dart';
import 'package:rallet/features/credit_card/domain/repositories/i_credit_card_transaction_repository.dart';
import 'package:rallet/features/credit_card/domain/repositories/i_credit_card_bill_repository.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_bill_dates.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_find.dart';
import 'package:rallet/features/statement/domain/entities/statement_entity.dart';
import 'package:rallet/features/statement/domain/repositories/i_statement_repository.dart';
import 'package:rallet/shared/classes/constants.dart';
import 'package:rallet/shared/exceptions/exceptions.dart';
import 'package:rallet/shared/presentation/notifiers/event_notifier.dart';

class CardCashAdvance implements ICardCashAdvance {
  final ICardCashAdvanceRepository _repository;
  final ICreditCardFind _creditCardFind;
  final ICreditCardBillDates _billDates;
  final ICreditCardTransactionRepository _creditCardTransactionRepository;
  final ICreditCardBillRepository _creditCardBillRepository;
  final IStatementRepository _statementRepository;
  final ILocalDBTransactionRepository _localDBTransactionRepository;
  final EventNotifier _eventNotifier;

  CardCashAdvance({
    required ICardCashAdvanceRepository repository,
    required ICreditCardFind creditCardFind,
    required ICreditCardBillDates billDates,
    required ICreditCardTransactionRepository creditCardTransactionRepository,
    required ICreditCardBillRepository creditCardBillRepository,
    required IStatementRepository statementRepository,
    required ILocalDBTransactionRepository localDBTransactionRepository,
    required EventNotifier eventNotifier,
  })  : _repository = repository,
        _creditCardFind = creditCardFind,
        _billDates = billDates,
        _creditCardTransactionRepository = creditCardTransactionRepository,
        _creditCardBillRepository = creditCardBillRepository,
        _statementRepository = statementRepository,
        _localDBTransactionRepository = localDBTransactionRepository,
        _eventNotifier = eventNotifier;

  @override
  Future<CardCashAdvancePlanEntity> savePlan(CardCashAdvancePlanEntity entity) async {
    if (!entity.isPlanned) {
      throw ValidationException('Uma operação já realizada não pode ser alterada como planejamento.');
    }

    _validate(entity);
    final card = await _creditCardFind.findById(entity.idCreditCard);
    if (card == null) throw ValidationException('Cartão não encontrado.');

    final dates = _billDates.generateDates(
      closingDay: card.billClosingDay,
      dueDay: card.billDueDay,
      baseDate: entity.plannedDate,
    );
    entity.billDueDate = dates.dueDate;

    final saved = await _repository.save(entity);
    _eventNotifier.notify(EventType.cashAdvance);
    return saved;
  }

  @override
  Future<CardCashAdvancePlanEntity> realize(
    CardCashAdvancePlanEntity entity,
  ) async {
    if (!entity.isPlanned) return entity;
    _validate(entity);

    if (!entity.isNew) {
      final CardCashAdvancePlanEntity? persisted =
          await _repository.findById(entity.id);
      if (persisted?.isRealized == true) return persisted!;
      if (persisted != null &&
          (persisted.idStatement != null ||
              persisted.idCreditCardTransaction != null)) {
        throw ValidationException(
          'Este planejamento possui vínculos financeiros incompletos. Faça um backup e revise a operação antes de tentar realizá-la novamente.',
        );
      }
    }

    // O planejamento precisa existir antes da operação composta para que todas
    // as movimentações derivadas apontem para uma única origem.
    if (entity.isNew) {
      entity = await savePlan(entity);
    }

    // Defesa contra duplicidade inclusive para bases que possam ter ficado com
    // uma transação órfã após uma interrupção em versões anteriores.
    final existingTransaction = await _creditCardTransactionRepository
        .findByCashAdvancePlanId(entity.id);
    if (existingTransaction != null) {
      throw ValidationException(
        'Já existe uma movimentação de cartão vinculada a este planejamento. O Rallet não criará outra operação duplicada.',
      );
    }

    final card = await _creditCardFind.findById(entity.idCreditCard);
    if (card == null) throw ValidationException('Cartão não encontrado.');

    final DateTime operationDate = DateTime.now();
    final dates = _billDates.generateDates(
      closingDay: card.billClosingDay,
      dueDay: card.billDueDay,
      baseDate: operationDate,
    );
    entity.billDueDate = dates.dueDate;

    CreditCardBillEntity? bill =
        await _creditCardBillRepository.findFirstAfterDate(
      date: operationDate,
      idCreditCard: card.id,
    );

    if (bill == null ||
        bill.billClosingDate.year != dates.closingDate.year ||
        bill.billClosingDate.month != dates.closingDate.month) {
      bill = CreditCardBillEntity(
        id: null,
        createdAt: null,
        deletedAt: null,
        billClosingDate: dates.closingDate,
        billDueDate: dates.dueDate,
        idCreditCard: card.id,
        transactions: [],
      );
    }

    if (bill.billClosingDate.isBefore(DateTime.now())) {
      throw ValidationException(
        'A fatura correspondente à data desta operação já está fechada.',
      );
    }

    final CardCashAdvancePlanEntity saved =
        await _localDBTransactionRepository.openTransaction((txn) async {
      CreditCardBillEntity targetBill = bill!;
      if (targetBill.isNew) {
        targetBill = await _creditCardBillRepository.saveOnlyBill(
          targetBill,
          txn: txn,
        );
      }

      final transaction = await _creditCardTransactionRepository.save(
        CreditCardTransactionEntity(
          id: null,
          createdAt: null,
          deletedAt: null,
          description: entity.description.trim().isEmpty
              ? 'Crédito via cartão'
              : entity.description.trim(),
          amount: entity.amountCharged,
          date: operationDate,
          idCategory: categoryOthersUuidExpense,
          idCreditCard: entity.idCreditCard,
          idCreditCardBill: targetBill.id,
          observation:
              'Crédito recebido: ${entity.amountReceived.toStringAsFixed(2)} | custo financeiro previsto: ${entity.financialCost.toStringAsFixed(2)}',
          installmentGroupId: null,
          installmentNumber: null,
          installmentCount: null,
          cashAdvancePlanId: entity.id,
          cashAdvancePrincipal: entity.amountReceived,
        ),
        txn: txn,
      );

      // A entrada aumenta o saldo da conta, mas NÃO cria IncomeEntity.
      final statement = await _statementRepository.save(
        StatementEntity(
          id: null,
          createdAt: null,
          deletedAt: null,
          amount: entity.amountReceived,
          date: operationDate,
          idAccount: entity.idAccount,
          idExpense: null,
          idIncome: null,
          idTransfer: null,
        ),
        txn: txn,
      );

      entity.status = CardCashAdvanceStatusEnum.realized;
      entity.realizedAt = operationDate;
      entity.idStatement = statement.id;
      entity.idCreditCardTransaction = transaction.id;

      return _repository.save(entity, txn: txn);
    });

    _eventNotifier.notify(EventType.cashAdvance);
    _eventNotifier.notify(EventType.creditCard);
    _eventNotifier.notify(EventType.account);
    return saved;
  }

  @override
  Future<CardCashAdvancePlanEntity> undoRealization(
    CardCashAdvancePlanEntity entity,
  ) async {
    final CardCashAdvancePlanEntity persisted =
        await _repository.findById(entity.id) ??
            (throw ValidationException('Operação de crédito não encontrada.'));

    if (!persisted.isRealized) return persisted;
    if (persisted.idStatement == null ||
        persisted.idCreditCardTransaction == null) {
      throw ValidationException(
        'Não é possível desfazer esta operação porque os vínculos originais não estão completos.',
      );
    }

    final statement = await _statementRepository.findById(persisted.idStatement!);
    final transaction = await _creditCardTransactionRepository
        .findById(persisted.idCreditCardTransaction!);

    if (statement == null || transaction == null) {
      throw ValidationException(
        'A movimentação vinculada não foi encontrada. O Rallet não fará uma reversão parcial.',
      );
    }

    if (transaction.idCreditCardBill != null) {
      final bill =
          await _creditCardBillRepository.findById(transaction.idCreditCardBill!);
      final bool hasPayment =
          bill?.transactions.any((item) => item.amount < 0) ?? false;
      if (hasPayment) {
        throw ValidationException(
          'A fatura desta operação já possui pagamento. Para preservar saldo e limite, ajuste a fatura antes de desfazer o crédito.',
        );
      }
    }

    persisted.status = CardCashAdvanceStatusEnum.planned;
    persisted.realizedAt = null;
    persisted.idStatement = null;
    persisted.idCreditCardTransaction = null;

    final card = await _creditCardFind.findById(persisted.idCreditCard);
    if (card == null) throw ValidationException('Cartão não encontrado.');
    final dates = _billDates.generateDates(
      closingDay: card.billClosingDay,
      dueDay: card.billDueDay,
      baseDate: persisted.plannedDate,
    );
    persisted.billDueDate = dates.dueDate;

    final CardCashAdvancePlanEntity saved =
        await _localDBTransactionRepository.openTransaction((txn) async {
      await _statementRepository.delete(statement, txn: txn);
      await _creditCardTransactionRepository.delete(transaction, txn: txn);
      return _repository.save(persisted, txn: txn);
    });

    _eventNotifier.notify(EventType.cashAdvance);
    _eventNotifier.notify(EventType.creditCard);
    _eventNotifier.notify(EventType.account);
    return saved;
  }

  @override
  Future<bool> hasMissingLinkedTransaction(
    CardCashAdvancePlanEntity entity,
  ) async {
    final CardCashAdvancePlanEntity persisted =
        await _repository.findById(entity.id) ?? entity;

    if (!persisted.isRealized ||
        persisted.idCreditCardTransaction == null) {
      return false;
    }

    final active = await _creditCardTransactionRepository.findById(
      persisted.idCreditCardTransaction!,
    );
    return active == null;
  }

  @override
  Future<CardCashAdvancePlanEntity> repairMissingLinkedTransaction(
    CardCashAdvancePlanEntity entity,
  ) async {
    final CardCashAdvancePlanEntity persisted =
        await _repository.findById(entity.id) ??
            (throw ValidationException('Operação de crédito não encontrada.'));

    if (!persisted.isRealized) {
      throw ValidationException(
        'Somente uma operação já realizada pode ter o vínculo reparado.',
      );
    }
    if (persisted.idStatement == null ||
        persisted.idCreditCardTransaction == null) {
      throw ValidationException(
        'Esta operação não possui informações suficientes para reparar o vínculo automaticamente.',
      );
    }

    final statement =
        await _statementRepository.findById(persisted.idStatement!);
    if (statement == null) {
      throw ValidationException(
        'A entrada original na conta também não foi encontrada. O Rallet não fará um reparo parcial.',
      );
    }

    final String transactionId = persisted.idCreditCardTransaction!;
    final active =
        await _creditCardTransactionRepository.findById(transactionId);
    if (active != null) {
      return _withCurrentBillDueDate(persisted);
    }

    final deleted = await _creditCardTransactionRepository
        .findByIdIncludingDeleted(transactionId);
    if (deleted == null || deleted.deletedAt == null) {
      throw ValidationException(
        'A movimentação removida não pôde ser recuperada automaticamente. Nenhum valor foi alterado.',
      );
    }

    if (deleted.cashAdvancePlanId != null &&
        deleted.cashAdvancePlanId != persisted.id) {
      throw ValidationException(
        'A movimentação removida pertence a outra operação. O Rallet não fará o reparo.',
      );
    }
    if (deleted.idCreditCard != persisted.idCreditCard ||
        (deleted.amount - persisted.amountCharged).abs() > 0.011) {
      throw ValidationException(
        'A movimentação removida não corresponde aos valores desta operação. O Rallet não fará o reparo.',
      );
    }
    if (deleted.idCreditCardBill == null) {
      throw ValidationException(
        'A fatura original da movimentação não pôde ser identificada.',
      );
    }

    final bill =
        await _creditCardBillRepository.findById(deleted.idCreditCardBill!);
    if (bill == null) {
      throw ValidationException(
        'A fatura original também não foi encontrada. O Rallet não recriará uma fatura em outra competência automaticamente.',
      );
    }

    final restored = deleted.clone()
      ..deletedAt = null
      ..cashAdvancePlanId = persisted.id
      ..cashAdvancePrincipal = persisted.amountReceived;

    await _localDBTransactionRepository.openTransaction((txn) async {
      await _creditCardTransactionRepository.save(restored, txn: txn);
    });

    _eventNotifier.notify(EventType.cashAdvance);
    _eventNotifier.notify(EventType.creditCard);
    _eventNotifier.notify(EventType.account);

    return _withCurrentBillDueDate(persisted);
  }

  @override
  Future<void> cancel(CardCashAdvancePlanEntity entity) async {
    if (!entity.isPlanned) {
      throw ValidationException('Somente planejamentos ainda não realizados podem ser cancelados.');
    }
    await _repository.delete(entity);
    _eventNotifier.notify(EventType.cashAdvance);
  }

  @override
  Future<CardCashAdvancePlanEntity?> findById(String id) async {
    final CardCashAdvancePlanEntity? plan = await _repository.findById(id);
    if (plan == null) return null;
    return _withCurrentBillDueDate(plan);
  }

  @override
  Future<List<CardCashAdvancePlanEntity>> findPlanned() => _repository.findPlanned();

  @override
  Future<List<CardCashAdvancePlanEntity>> findAll() async {
    final List<CardCashAdvancePlanEntity> plans = await _repository.findAll();
    return Future.wait(plans.map(_withCurrentBillDueDate));
  }

  /// Para operações já realizadas, a fatura vinculada é a fonte de verdade
  /// da competência do custo financeiro. Isso evita que uma alteração posterior
  /// no vencimento/fechamento do cartão deixe o relatório preso à data que o
  /// planejamento possuía quando foi efetivado.
  ///
  /// O valor persistido em [billDueDate] continua sendo útil como fallback para
  /// bases antigas/incompletas; quando o vínculo real existe, apenas devolvemos
  /// a entidade com a data atual da fatura, sem criar outra movimentação nem
  /// alterar principal, juros ou saldo.
  Future<CardCashAdvancePlanEntity> _withCurrentBillDueDate(
    CardCashAdvancePlanEntity plan,
  ) async {
    if (!plan.isRealized || plan.idCreditCardTransaction == null) return plan;

    final CreditCardTransactionEntity? transaction =
        await _creditCardTransactionRepository.findById(
      plan.idCreditCardTransaction!,
    );
    if (transaction?.idCreditCardBill == null) return plan;

    final CreditCardBillEntity? bill =
        await _creditCardBillRepository.findById(transaction!.idCreditCardBill!);
    if (bill == null || bill.billDueDate == plan.billDueDate) return plan;

    return plan.clone()..billDueDate = bill.billDueDate;
  }

  void _validate(CardCashAdvancePlanEntity entity) {
    if (entity.idAccount.isEmpty) throw ValidationException('Selecione a conta que receberá o valor.');
    if (entity.idCreditCard.isEmpty) throw ValidationException('Selecione o cartão.');
    if (entity.amountReceived <= 0) throw ValidationException('O valor a receber deve ser maior que zero.');
    if (entity.amountCharged <= 0) throw ValidationException('O valor cobrado no cartão deve ser maior que zero.');
    if (entity.amountCharged < entity.amountReceived) {
      throw ValidationException('O valor cobrado no cartão não pode ser menor que o valor recebido.');
    }
  }
}
