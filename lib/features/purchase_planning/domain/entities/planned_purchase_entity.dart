import 'package:rallet/shared/domain/entities/entity.dart';
import 'package:rallet/shared/extensions/date_time_extension.dart';
import 'package:rallet/shared/extensions/double_extension.dart';

enum PlannedPurchasePaymentType {
  cash,
  creditCardSingle,
  creditCardInstallments,
}

class PlannedPurchaseInstallmentEntity {
  final int number;
  final DateTime dueDate;
  final double amount;

  const PlannedPurchaseInstallmentEntity({
    required this.number,
    required this.dueDate,
    required this.amount,
  });
}

class PlannedPurchaseEntity extends Entity {
  String description;
  double amount;
  DateTime plannedDate;
  double reserveAmount;
  PlannedPurchasePaymentType paymentType;
  String? idCreditCard;
  int installmentCount;
  double totalCharged;
  DateTime? firstBillDueDate;
  String? idCategory;
  String? idAccount;
  String? observation;

  PlannedPurchaseEntity({
    required super.id,
    required super.createdAt,
    required super.deletedAt,
    required this.description,
    required this.amount,
    required this.plannedDate,
    this.reserveAmount = 0,
    this.paymentType = PlannedPurchasePaymentType.cash,
    this.idCreditCard,
    this.installmentCount = 1,
    double? totalCharged,
    this.firstBillDueDate,
    this.idCategory,
    this.idAccount,
    this.observation,
  }) : totalCharged = totalCharged ?? amount;

  bool get isCreditCard => paymentType != PlannedPurchasePaymentType.cash;
  bool get isInstallment => paymentType == PlannedPurchasePaymentType.creditCardInstallments;
  double get financialCost =>
      (totalCharged - amount).clamp(0, double.infinity).toDouble().toRound(2);

  double get installmentAverage =>
      (totalCharged / installmentCount.clamp(1, 24)).toRound(2);

  List<double> _splitMoney(double total) {
    final int count = installmentCount.clamp(1, 24).toInt();
    final int totalCents = (total * 100).round();
    final int base = totalCents ~/ count;
    int remainder = totalCents - (base * count);
    return List.generate(count, (index) {
      final int cents = base + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder--;
      return cents / 100.0;
    });
  }

  double get principalCharged => (totalCharged - financialCost).toRound(2);

  List<double> get installmentAmounts => _splitMoney(totalCharged);
  List<double> get principalInstallmentAmounts => _splitMoney(principalCharged);
  List<double> get financialCostInstallmentAmounts => _splitMoney(financialCost);

  List<PlannedPurchaseInstallmentEntity> get installmentSchedule {
    if (!isCreditCard || firstBillDueDate == null) return const [];
    final values = installmentAmounts;
    return List.generate(values.length, (index) {
      final base = firstBillDueDate!;
      final dueDate = base.addMonths(index);
      return PlannedPurchaseInstallmentEntity(
        number: index + 1,
        dueDate: dueDate,
        amount: values[index],
      );
    });
  }

  double amountDueInPeriod(DateTime start, DateTime end) {
    if (!isCreditCard) {
      return (!plannedDate.isBefore(start) && !plannedDate.isAfter(end))
          ? amount.abs().toRound(2)
          : 0;
    }
    return installmentSchedule
        .where((item) => !item.dueDate.isBefore(start) && !item.dueDate.isAfter(end))
        .fold(0.0, (total, item) => total + item.amount)
        .toRound(2);
  }

  double principalDueInPeriod(DateTime start, DateTime end) {
    if (!isCreditCard) return amountDueInPeriod(start, end);
    if (firstBillDueDate == null) return 0;
    final values = principalInstallmentAmounts;
    double total = 0;
    for (int index = 0; index < values.length; index++) {
      final base = firstBillDueDate!;
      final dueDate = base.addMonths(index);
      if (!dueDate.isBefore(start) && !dueDate.isAfter(end)) total += values[index];
    }
    return total.toRound(2);
  }

  double financialCostDueInPeriod(DateTime start, DateTime end) {
    if (!isCreditCard || financialCost <= 0 || firstBillDueDate == null) return 0;
    final values = financialCostInstallmentAmounts;
    double total = 0;
    for (int index = 0; index < values.length; index++) {
      final base = firstBillDueDate!;
      final dueDate = base.addMonths(index);
      if (!dueDate.isBefore(start) && !dueDate.isAfter(end)) total += values[index];
    }
    return total.toRound(2);
  }

  PlannedPurchaseEntity clone() => PlannedPurchaseEntity(
        id: id,
        createdAt: createdAt,
        deletedAt: deletedAt,
        description: description,
        amount: amount,
        plannedDate: plannedDate,
        reserveAmount: reserveAmount,
        paymentType: paymentType,
        idCreditCard: idCreditCard,
        installmentCount: installmentCount,
        totalCharged: totalCharged,
        firstBillDueDate: firstBillDueDate,
        idCategory: idCategory,
        idAccount: idAccount,
        observation: observation,
      );

  void normalizeMoney() {
    amount = amount.abs().toRound(2);
    reserveAmount = reserveAmount.abs().toRound(2);
    totalCharged = totalCharged.abs().toRound(2);
    installmentCount = installmentCount.clamp(1, 24).toInt();
    if (!isCreditCard) {
      idCreditCard = null;
      installmentCount = 1;
      totalCharged = amount;
      firstBillDueDate = null;
    }
  }
}
