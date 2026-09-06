import 'package:rallet/features/transactions/domain/entities/income_entity.dart';
import 'package:rallet/features/transactions/domain/enums/recurrence_scope_enum.dart';

abstract interface class IIncomeSave {
  Future<IncomeEntity> save(
    IncomeEntity entity, {
    RecurrenceScopeEnum recurrenceScope = RecurrenceScopeEnum.single,
    DateTime? recurrenceReferenceDate,
  });

  Future<void> saveReceived({required bool received, required String id});
}
