import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  group('IngredientRowControllers', () {
    test('primes each controller from the ingredient it was given', () {
      final controllers = IngredientRowControllers(
        0,
        ingredient: Ingredient(name: 'Gin', quantity: '2', unit: 'oz'),
      );
      addTearDown(controllers.dispose);

      expect(controllers.name.text, 'Gin');
      expect(controllers.quantity.text, '2');
      expect(controllers.unit.text, 'oz');
      expect(controllers.state, ['Gin', '2', 'oz']);
    });

    test('starts blank when there is no ingredient yet', () {
      final controllers = IngredientRowControllers(0);
      addTearDown(controllers.dispose);

      expect(controllers.ingredient, isNull);
      expect(controllers.state, ['', '', '']);
    });

    test(
      'reads a row with no name as no ingredient, whatever else it holds',
      () {
        final controllers = IngredientRowControllers(0);
        addTearDown(controllers.dispose);
        controllers.quantity.text = '2';

        expect(controllers.ingredient, isNull);
      },
    );

    test('builds the ingredient the row describes', () {
      final controllers = IngredientRowControllers(0);
      addTearDown(controllers.dispose);
      controllers.name.text = ' Gin ';
      controllers.quantity.text = '2';

      expect(
        controllers.ingredient,
        Ingredient(name: 'Gin', quantity: '2'),
      );
    });
  });

  group('IngredientRowField', () {
    late IngredientRowControllers controllers;

    setUp(() {
      controllers = IngredientRowControllers(
        0,
        ingredient: Ingredient(name: 'Gin', quantity: '2', unit: 'oz'),
      );
      addTearDown(controllers.dispose);
    });

    Future<void> pumpRow(
      WidgetTester tester, {
      VoidCallback onRemove = _noop,
    }) => tester.pumpApp(
      IngredientRowField(controllers: controllers, onRemove: onRemove),
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

      expect(controllers.name.text, 'Campari');
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
