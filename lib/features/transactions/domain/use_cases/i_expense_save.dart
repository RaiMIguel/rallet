import 'package:rallet/features/transactions/domain/entities/expense_entity.dart';
import 'package:rallet/features/transactions/domain/enums/recurrence_scope_enum.dart';

abstract interface class IExpenseSave {
  Future<ExpenseEntity> save(
    ExpenseEntity entity, {
    RecurrenceScopeEnum recurrenceScope = RecurrenceScopeEnum.single,
    DateTime? recurrenceReferenceDate,
  });

  Future<void> savePaid({required bool paid, required String id});
}
