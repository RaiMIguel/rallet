import 'package:rallet/features/card_cash_advance/domain/entities/card_cash_advance_plan_entity.dart';
import 'package:rallet/features/card_cash_advance/domain/enums/card_cash_advance_status_enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Movimentações vinculadas futuras', () {
    test('crédito planejado usa a data prevista como mês da entrada vinculada', () {
      final plan = _plan(
        status: CardCashAdvanceStatusEnum.planned,
        plannedDate: DateTime(2026, 10, 15),
      );

      expect(plan.linkedEntryDate, DateTime(2026, 10, 15));
      expect(
        plan.linkedEntryBelongsToPeriod(
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 31, 23, 59, 59),
        ),
        isTrue,
      );
      expect(
        plan.linkedEntryBelongsToPeriod(
          DateTime(2026, 11, 1),
          DateTime(2026, 11, 30, 23, 59, 59),
        ),
        isFalse,
      );
    });

    test('crédito realizado usa a data real, sem duplicar pela data planejada', () {
      final plan = _plan(
        status: CardCashAdvanceStatusEnum.realized,
        plannedDate: DateTime(2026, 10, 15),
        realizedAt: DateTime(2026, 10, 12),
      );

      expect(plan.linkedEntryDate, DateTime(2026, 10, 12));
    });
  });
}

CardCashAdvancePlanEntity _plan({
  required CardCashAdvanceStatusEnum status,
  required DateTime plannedDate,
  DateTime? realizedAt,
}) {
  return CardCashAdvancePlanEntity(
    id: 'credit-1',
    createdAt: DateTime(2026, 9, 1),
    deletedAt: null,
    description: 'Crédito teste',
    idAccount: 'account-1',
    idCreditCard: 'card-1',
    amountReceived: 500,
    amountCharged: 550,
    plannedDate: plannedDate,
    billDueDate: DateTime(2026, 11, 10),
    status: status,
    realizedAt: realizedAt,
    idStatement: null,
    idCreditCardTransaction: null,
  );
}
