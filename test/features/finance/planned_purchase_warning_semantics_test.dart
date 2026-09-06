import 'package:rallet/features/purchase_planning/domain/entities/purchase_simulation_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Aviso prévio de planejamento', () {
    test('saldo negativo é identificado como alerta do Radar', () {
      final option = PurchaseSimulationOptionEntity(
        date: DateTime(2026, 10, 10),
        balanceAfterPurchase: 100,
        minimumBalanceAfterPurchase: -150,
        minimumBalanceDate: DateTime(2026, 10, 20),
        safe: false,
        firstNegativeBalanceDate: DateTime(2026, 10, 20),
        balanceAtFirstNegativeDate: -20,
      );

      expect(option.generatesRadarAlert, isTrue);
    });

    test('falta de limite contratual é identificada como alerta do Radar', () {
      final option = PurchaseSimulationOptionEntity(
        date: DateTime(2026, 10, 10),
        balanceAfterPurchase: 300,
        minimumBalanceAfterPurchase: 200,
        minimumBalanceDate: DateTime(2026, 10, 10),
        safe: false,
        cardLimitSafe: false,
        firstCardLimitRiskDate: DateTime(2026, 10, 10),
        cardLimitShortage: 70,
      );

      expect(option.generatesRadarAlert, isTrue);
    });

    test('apenas margem mínima não finge ser alerta principal do Radar', () {
      final option = PurchaseSimulationOptionEntity(
        date: DateTime(2026, 10, 10),
        balanceAfterPurchase: 250,
        minimumBalanceAfterPurchase: 100,
        minimumBalanceDate: DateTime(2026, 10, 25),
        safe: false,
      );

      expect(option.generatesRadarAlert, isFalse);
    });
  });
}
