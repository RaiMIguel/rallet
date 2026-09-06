import 'package:rallet/features/account/domain/entities/account_entity.dart';
import 'package:rallet/features/account/domain/use_cases/i_account_find.dart';
import 'package:rallet/features/category/domain/entities/category_entity.dart';
import 'package:rallet/features/category/domain/enums/category_type_enum.dart';
import 'package:rallet/features/category/domain/use_cases/i_category_find.dart';
import 'package:rallet/features/credit_card/domain/entities/credit_card_entity.dart';
import 'package:rallet/features/credit_card/domain/use_cases/i_credit_card_find.dart';
import 'package:rallet/features/purchase_planning/domain/entities/planned_purchase_entity.dart';
import 'package:rallet/features/purchase_planning/domain/entities/purchase_simulation_entity.dart';
import 'package:rallet/features/purchase_planning/domain/use_cases/i_purchase_planning.dart';
import 'package:flutter/foundation.dart';

class PurchasePlanningViewModel extends ChangeNotifier {
  final IPurchasePlanning _purchasePlanning;
  final ICreditCardFind _creditCardFind;
  final ICategoryFind _categoryFind;
  final IAccountFind _accountFind;

  PurchasePlanningViewModel({
    required IPurchasePlanning purchasePlanning,
    required ICreditCardFind creditCardFind,
    required ICategoryFind categoryFind,
    required IAccountFind accountFind,
  })  : _purchasePlanning = purchasePlanning,
        _creditCardFind = creditCardFind,
        _categoryFind = categoryFind,
        _accountFind = accountFind;

  PlannedPurchaseEntity? plan;
  PurchaseSimulationEntity? simulation;
  List<CreditCardEntity> creditCards = [];
  List<CategoryEntity> categories = [];
  List<AccountEntity> accounts = [];
  bool loading = false;
  String? error;

  void load(PlannedPurchaseEntity? existing) {
    plan = existing?.clone();
    simulation = null;
    error = null;
    Future(() async {
      try {
        final results = await Future.wait<dynamic>([
          _creditCardFind.findAll(),
          _categoryFind.findAll(type: CategoryTypeEnum.expense, deleted: true),
          _accountFind.findAll(deleted: true),
        ]);
        creditCards = (results[0] as List).cast<CreditCardEntity>()
            .where((card) => card.deletedAt == null)
            .toList();
        categories = (results[1] as List).cast<CategoryEntity>()
            .where((category) => category.deletedAt == null)
            .toList();
        accounts = (results[2] as List).cast<AccountEntity>()
            .where((account) => account.deletedAt == null)
            .toList();
      } catch (_) {
        creditCards = [];
        categories = [];
        accounts = [];
      }
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> simulate({
    required double amount,
    required DateTime desiredDate,
    required double reserveAmount,
    required PlannedPurchasePaymentType paymentType,
    String? idCreditCard,
    String? idAccount,
    required int installmentCount,
    required double totalCharged,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      simulation = await _purchasePlanning.simulate(
        amount: amount,
        desiredDate: desiredDate,
        reserveAmount: reserveAmount,
        paymentType: paymentType,
        idCreditCard: idCreditCard,
        idAccount: idAccount,
        installmentCount: installmentCount,
        totalCharged: totalCharged,
        editingPlanId: plan?.id,
      );
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> save({
    required String description,
    required double amount,
    required DateTime plannedDate,
    required double reserveAmount,
    required PlannedPurchasePaymentType paymentType,
    String? idCreditCard,
    String? idCategory,
    String? idAccount,
    String? observation,
    required int installmentCount,
    required double totalCharged,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final entity = plan ?? PlannedPurchaseEntity(
        id: null,
        createdAt: null,
        deletedAt: null,
        description: description,
        amount: amount,
        plannedDate: plannedDate,
        reserveAmount: reserveAmount,
      );
      entity
        ..description = description
        ..amount = amount
        ..plannedDate = plannedDate
        ..reserveAmount = reserveAmount
        ..paymentType = paymentType
        ..idCreditCard = idCreditCard
        ..idCategory = idCategory
        ..idAccount = idAccount
        ..observation = observation?.trim()
        ..installmentCount = installmentCount
        ..totalCharged = totalCharged;
      plan = await _purchasePlanning.save(entity);
      return true;
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> realizeCreditCardPurchase() async {
    final current = plan;
    if (current == null || !current.isCreditCard) return false;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _purchasePlanning.realizeCreditCardPurchase(current);
      return true;
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> delete() async {
    final current = plan;
    if (current == null || current.isNew) return false;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _purchasePlanning.delete(current);
      return true;
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
