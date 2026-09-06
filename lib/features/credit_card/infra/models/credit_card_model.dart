import 'package:rallet/features/credit_card/domain/enums/brand_card_enum.dart';
import 'package:rallet/shared/infra/models/model.dart';

class CreditCardModel extends Model {
  final String description;
  final double amountLimit;
  final double? safetyLimit;
  final int billClosingDay;
  final int billDueDay;
  final CardBrandEnum brand;
  final String idAccount;

  double amountLimitUtilized;

  CreditCardModel({
    required super.id,
    required super.createdAt,
    required super.deletedAt,
    required this.description,
    required this.amountLimit,
    required this.safetyLimit,
    required this.billClosingDay,
    required this.billDueDay,
    required this.brand,
    required this.idAccount,
    required this.amountLimitUtilized,
  });

  @override
  CreditCardModel clone() {
    return CreditCardModel(
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
      amountLimitUtilized: amountLimitUtilized,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      ...baseMap(),
      'description': description,
      'amount_limit': amountLimit,
      'safety_limit': safetyLimit,
      'bill_closing_day': billClosingDay,
      'bill_due_day': billDueDay,
      'brand': brand.value,
      'id_account': idAccount,
    };
  }
}
