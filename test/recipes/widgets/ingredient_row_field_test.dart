import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:membar/recipes/recipes.dart';

import '../../helpers/helpers.dart';

void main() {
  group('IngredientRowField', () {
    late TextEditingController name;
    late TextEditingController quantity;
    late TextEditingController unit;

    setUp(() {
      name = TextEditingController(text: 'Gin');
      quantity = TextEditingController(text: '2');
      unit = TextEditingController(text: 'oz');
      addTearDown(name.dispose);
      addTearDown(quantity.dispose);
      addTearDown(unit.dispose);
    });

    Future<void> pumpRow(
      WidgetTester tester, {
      VoidCallback onRemove = _noop,
    }) => tester.pumpApp(
      IngredientRowField(
        name: name,
        quantity: quantity,
        unit: unit,
        onRemove: onRemove,
      ),
    );

    testWidgets('renders each controller behind its own label', (tester) async {
      await pumpRow(tester);

      expect(find.text('Ingredient'), findsOneWidget);
      expect(find.text('Quantity'), findsOneWidget);
      expect(find.text('Unit'), findsOneWidget);
      expect(find.text('Gin'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('oz'), findsOneWidget);
    });

    testWidgets('writes typed text back to the controller', (tester) async {
      await pumpRow(tester);

      await tester.enterText(find.byType(EditableText).first, 'Campari');

      expect(name.text, 'Campari');
    });

    testWidgets('calls onRemove when the remove action is tapped', (
      tester,
    ) async {
      var removed = 0;
      await pumpRow(tester, onRemove: () => removed++);

      await tester.tap(find.bySemanticsLabel('Remove ingredient'));
      await tester.pumpAndSettle();

      expect(removed, 1);
    });
  });
}

void _noop() {}
