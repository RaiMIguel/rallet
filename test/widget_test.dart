import 'package:rallet/shared/presentation/ui/components/calculation_info_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CalculationInfoButton opens the calculation details sheet', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CalculationInfoButton(
            title: 'Saldo previsto',
            description: 'Composição usada pelo Rallet.',
            items: ['Saldo atual', 'Receitas previstas', 'Despesas previstas'],
            formula: 'saldo + entradas - saídas',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Saldo previsto'), findsOneWidget);
    expect(find.text('Composição usada pelo Rallet.'), findsOneWidget);
    expect(find.text('saldo + entradas - saídas'), findsOneWidget);
  });
}
