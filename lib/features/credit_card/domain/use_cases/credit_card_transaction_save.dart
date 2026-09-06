import 'package:rallet/features/ad/domain/use_cases/i_ad_access.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_bill_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_transaction_entity.dart';
import 'package:rallet/features/credit_card/domain/enums/installment_scope_enum.dart';
import 'package:rallet/features/credit_card/domain/repositories/i_credit_card_bill_repository.dart';
import 'package:rallet/features/credit_card/domain/repositories/i_credit_card_repository.dart';
import 'package:rallet/features/credit_card/domain/repositories/i_credit_card_transaction_repository.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_bill_dates.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_transaction_save.dart';
import 'package:rallet/shared/exceptions/exceptions.dart';
import 'package:rallet/shared/extensions/date_time_extension.dart';
import 'package:rallet/shared/presentation/ui/app_locale.dart';
import 'package:uuid/uuid.dart';

class CreditCardTransactionSave implements ICreditCardTransactionSave {
  final ICreditCardBillDates _creditCardBillDates;
  final ICreditCardRepository _repository;
  final ICreditCardBillRepository _creditCardBillRepository;
  final ICreditCardTransactionRepository _creditCardTransactionRepository;
  final IAdAccess _adAccess;

  CreditCardTransactionSave({
    required ICreditCardBillDates creditCardBillDates,
    required ICreditCardRepository repository,
    required ICreditCardBillRepository creditCardBillRepository,
    required ICreditCardTransactionRepository creditCardTransactionRepository,
    required IAdAccess adAccess,
  })  : _creditCardBillDates = creditCardBillDates,
        _repository = repository,
        _creditCardBillRepository = creditCardBillRepository,
        _creditCardTransactionRepository = creditCardTransactionRepository,
        _adAccess = adAccess;

  @override
  Future<CreditCardTransactionEntity> save(
    CreditCardTransactionEntity entity, {
    int installmentCount = 1,
    InstallmentScopeEnum installmentScope = InstallmentScopeEnum.single,
  }) async {
    _validate(entity);

    final CreditCardEntity? creditCard = await _repository.findById(entity.idCreditCard!);
    if (creditCard == null) throw ValidationException(R.strings.creditCardNotFound);

    if (!entity.isNew && installmentScope != InstallmentScopeEnum.single) {
      final List<CreditCardTransactionEntity> series =
          await _creditCardTransactionRepository.findInstallments(entity);
      if (series.length > 1) {
        final result = await _saveInstallmentSeries(
          entity,
          series,
          installmentScope,
        );
        await _adAccess.consumeUse();
        return result;
      }
    }

    if (!entity.isNew || installmentCount <= 1) {
      if (!entity.isNew && entity.isInstallment) {
        final int number = entity.installmentNumber!;
        final int total = entity.installmentCount!;
        entity.description = '${_stripInstallmentSuffix(entity.description)} ($number/$total)';
      }

      final CreditCardTransactionEntity result = await _saveOne(entity, creditCard);
      await _adAccess.consumeUse();
      return result;
    }

    if (installmentCount < 2 || installmentCount > 24) {
      throw ValidationException('A quantidade de parcelas deve estar entre 2 e 24.');
    }

    final int totalCents = (entity.amount * 100).round();
    if (totalCents < installmentCount) {
      throw ValidationException(
        'O valor total é muito baixo para essa quantidade de parcelas.',
      );
    }

    final int baseInstallmentCents = totalCents ~/ installmentCount;
    final int remainderCents = totalCents % installmentCount;
    final int principalTotalCents =
        ((entity.plannedPurchasePrincipal ?? 0) * 100).round();
    final int basePrincipalCents = principalTotalCents ~/ installmentCount;
    final int principalRemainderCents = principalTotalCents % installmentCount;
    final String installmentGroupId = const Uuid().v1();
    final String baseDescription = _stripInstallmentSuffix(entity.description);

    CreditCardTransactionEntity? firstSaved;

    for (int index = 0; index < installmentCount; index++) {
      final int installmentCents =
          baseInstallmentCents + (index < remainderCents ? 1 : 0);

      final CreditCardTransactionEntity installment = CreditCardTransactionEntity(
        id: null,
        createdAt: null,
        deletedAt: null,
        description: '$baseDescription (${index + 1}/$installmentCount)',
        amount: installmentCents / 100,
        date: entity.date.addMonths(index),
        idCategory: entity.idCategory,
        idCreditCard: entity.idCreditCard,
        idCreditCardBill: null,
        observation: entity.observation,
        installmentGroupId: installmentGroupId,
        installmentNumber: index + 1,
        installmentCount: installmentCount,
        cashAdvancePlanId: entity.cashAdvancePlanId,
        cashAdvancePrincipal: entity.cashAdvancePrincipal,
        plannedPurchaseId: entity.plannedPurchaseId,
        plannedPurchasePrincipal: entity.plannedPurchasePrincipal == null
            ? null
            : (basePrincipalCents +
                    (index < principalRemainderCents ? 1 : 0)) /
                100,
      );

      final CreditCardTransactionEntity saved = await _saveOne(installment, creditCard);
      firstSaved ??= saved;
    }

    await _adAccess.consumeUse();

    return firstSaved!;
  }

  Future<CreditCardTransactionEntity> _saveInstallmentSeries(
    CreditCardTransactionEntity edited,
    List<CreditCardTransactionEntity> series,
    InstallmentScopeEnum scope,
  ) async {
    final CreditCardTransactionEntity current = series.firstWhere(
      (item) => item.id == edited.id,
      orElse: () => edited,
    );

    final int currentNumber =
        current.installmentNumber ?? _parseInstallmentNumber(current.description) ?? 1;
    final int total =
        current.installmentCount ?? _parseInstallmentCount(current.description) ?? series.length;
    final String baseDescription = _stripInstallmentSuffix(edited.description);
    final String groupId =
        current.installmentGroupId ?? edited.installmentGroupId ?? const Uuid().v1();

    // Compras criadas na v5 não tinham identificador de grupo. Ao fazer a
    // primeira alteração em lote, gravamos o mesmo identificador em todas as
    // parcelas para que as próximas operações sejam exatas.
    if (series.any((item) => item.installmentGroupId == null)) {
      for (final item in series) {
        item.installmentGroupId = groupId;
        item.installmentNumber ??= _parseInstallmentNumber(item.description);
        item.installmentCount ??= _parseInstallmentCount(item.description) ?? total;
        if (item.id != edited.id && !_isTarget(item, currentNumber, scope)) {
          await _creditCardTransactionRepository.save(item);
        }
      }
    }

    CreditCardTransactionEntity? editedSaved;

    for (final occurrence in series) {
      if (!_isTarget(occurrence, currentNumber, scope)) continue;

      final int number =
          occurrence.installmentNumber ?? _parseInstallmentNumber(occurrence.description) ?? currentNumber;
      final int monthOffset = number - currentNumber;
      final CreditCardTransactionEntity copy =
          occurrence.id == edited.id ? edited : occurrence.clone();

      copy.description = '$baseDescription ($number/$total)';
      copy.amount = edited.amount;
      copy.date = edited.date.addMonths(monthOffset);
      copy.idCategory = edited.idCategory;
      copy.idCreditCard = edited.idCreditCard;
      copy.observation = edited.observation;
      copy.installmentGroupId = groupId;
      copy.installmentNumber = number;
      copy.installmentCount = total;
      copy.plannedPurchaseId = edited.plannedPurchaseId ?? occurrence.plannedPurchaseId;
      copy.plannedPurchasePrincipal =
          edited.plannedPurchasePrincipal ?? occurrence.plannedPurchasePrincipal;

      final CreditCardEntity? card = await _repository.findById(copy.idCreditCard!);
      if (card == null) throw ValidationException(R.strings.creditCardNotFound);

      final CreditCardTransactionEntity saved = await _saveOne(copy, card);
      if (saved.id == edited.id) editedSaved = saved;
    }

    return editedSaved ?? edited;
  }

  bool _isTarget(
    CreditCardTransactionEntity item,
    int currentNumber,
    InstallmentScopeEnum scope,
  ) {
    if (scope == InstallmentScopeEnum.all) return true;
    final int number =
        item.installmentNumber ?? _parseInstallmentNumber(item.description) ?? currentNumber;
    return number >= currentNumber;
  }

  Future<CreditCardTransactionEntity> _saveOne(
    CreditCardTransactionEntity entity,
    CreditCardEntity creditCard,
  ) async {
    CreditCardBillEntity? originalBill;

    if (!entity.isNew) {
      final CreditCardTransactionEntity? original =
          await _creditCardTransactionRepository.findById(entity.id);

      if (original?.idCreditCardBill != null) {
        originalBill = await _creditCardBillRepository.findById(
          original!.idCreditCardBill!,
        );

        if (originalBill == null) {
          throw ValidationException(R.strings.creditCardBillNotFound);
        }
      }
    }

    final dates = _creditCardBillDates.generateDates(
      closingDay: creditCard.billClosingDay,
      dueDay: creditCard.billDueDay,
      baseDate: entity.date,
    );

    /*
     * Correções de valor/descrição/categoria em uma compra já lançada devem
     * continuar possíveis mesmo depois do fechamento da fatura. Se a edição
     * ainda pertence à mesma fatura e ao mesmo cartão, apenas atualizamos a
     * transação existente. Mover uma compra para outra fatura fechada continua
     * protegido pela regra normal abaixo.
     */
    final bool staysInOriginalBill = originalBill != null &&
        originalBill.idCreditCard == creditCard.id &&
        originalBill.billClosingDate.year == dates.closingDate.year &&
        originalBill.billClosingDate.month == dates.closingDate.month;

    if (staysInOriginalBill) {
      entity.idCreditCardBill = originalBill.id;
      return _creditCardTransactionRepository.save(entity);
    }

    CreditCardBillEntity? bill =
        await _creditCardBillRepository.findFirstAfterDate(
      date: entity.date,
      idCreditCard: creditCard.id,
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
        idCreditCard: creditCard.id,
        transactions: [],
      );
    }

    if (bill.billClosingDate.isBefore(DateTime.now())) {
      throw ValidationException(R.strings.billClosedInDateTransaction);
    }

    entity.idCreditCardBill = bill.id;
    bill.transactions.add(entity);

    if (bill.isNew) {
      final CreditCardBillEntity billResult =
          await _creditCardBillRepository.save(bill);
      return billResult.transactions
          .firstWhere((transaction) => transaction.id == entity.id);
    }

    return _creditCardTransactionRepository.save(entity);
  }

  String _stripInstallmentSuffix(String description) =>
      description.replaceFirst(RegExp(r'\s*\(\d+\/\d+\)\s*$'), '').trim();

  int? _parseInstallmentNumber(String description) {
    final match = RegExp(r'\((\d+)\/(\d+)\)\s*$').firstMatch(description.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  int? _parseInstallmentCount(String description) {
    final match = RegExp(r'\((\d+)\/(\d+)\)\s*$').firstMatch(description.trim());
    return match == null ? null : int.tryParse(match.group(2)!);
  }

  void _validate(CreditCardTransactionEntity entity) {
    if (entity.description.trim().isEmpty) throw ValidationException(R.strings.uninformedDescription);
    if (entity.amount <= 0) throw ValidationException(R.strings.greaterThanZero);
    if (entity.idCategory == null) throw ValidationException(R.strings.uninformedCategory);
    if (entity.idCreditCard == null) throw ValidationException(R.strings.uninformedCreditCard);
  }
}
