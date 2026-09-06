import 'package:rallet/features/account/domain/enums/financial_institution_enum.dart';
import 'package:rallet/features/credit_card/domain/enums/brand_card_enum.dart';
import 'package:rallet/shared/domain/entities/entity.dart';

class CreditCardEntity extends Entity {
  String description;
  double amountLimit;
  double? safetyLimit;
  int billClosingDay;
  int billDueDay;
  CardBrandEnum? brand;

  String? idAccount;
  String descriptionAccount;
  FinancialInstitutionEnum? financialInstitutionAccount;

  final double amountLimitUtilized;

  CreditCardEntity({
    required super.id,
    required super.createdAt,
    required super.deletedAt,
    required this.description,
    required this.amountLimit,
    this.safetyLimit,
    required this.billClosingDay,
    required this.billDueDay,
    required this.brand,
    required this.idAccount,
    required this.descriptionAccount,
    required this.financialInstitutionAccount,
    required this.amountLimitUtilized,
  });

  CreditCardEntity clone() {
    return CreditCardEntity(
      id: id,
      createdAt: createdAt,
      deletedAt: deletedAt,
      description: description,
      amountLimit: amountLimit,
      safetyLimit: safetyLimit,
      billClosingDay: billClosingDay,
      billDueDay: billDueDay,
      brand: brand,
      idAccount: idAccount,
      descriptionAccount: descriptionAccount,
      financialInstitutionAccount: financialInstitutionAccount,
      amountLimitUtilized: amountLimitUtilized,
    );
  }
}
