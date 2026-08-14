import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:membar/recipes/recipes.dart';

import '../../helpers/helpers.dart';

void main() {
  group('StepRowControllers', () {
    test('primes the controller from the step it was given', () {
      final controllers = StepRowControllers(0, step: 'Stir with ice.');
      addTearDown(controllers.dispose);

      expect(controllers.text.text, 'Stir with ice.');
      expect(controllers.step, 'Stir with ice.');
    });

    test('reads a blank row as no step', () {
      final controllers = StepRowControllers(0, step: '   ');
      addTearDown(controllers.dispose);

      expect(controllers.step, isNull);
    });

    test('trims the step it describes', () {
      final controllers = StepRowControllers(0, step: '  Shake hard. ');
      addTearDown(controllers.dispose);

      expect(controllers.step, 'Shake hard.');
    });
  });

  group('StepRowField', () {
    late StepRowControllers controllers;

    setUp(() {
      controllers = StepRowControllers(0, step: 'Stir with ice.');
      addTearDown(controllers.dispose);
    });

    Future<void> pumpRow(
      WidgetTester tester, {
      VoidCallback onRemove = _noop,
    }) => tester.pumpApp(
      StepRowField(number: 2, controllers: controllers, onRemove: onRemove),
    );

    testWidgets('labels the row with its position', (tester) async {
      await pumpRow(tester);

      expect(find.text('Step 2'), findsOneWidget);
      expect(find.text('Stir with ice.'), findsOneWidget);
    });

    testWidgets('writes typed text back to the controller', (tester) async {
      await pumpRow(tester);

      await tester.enterText(find.byType(EditableText), 'Shake hard.');

      expect(controllers.text.text, 'Shake hard.');
    });

    testWidgets('calls onRemove when the remove action is tapped', (
      tester,
    ) async {
      var removed = 0;
      await pumpRow(tester, onRemove: () => removed++);

      await tester.tap(find.bySemanticsLabel('Remove step'));
      await tester.pumpAndSettle();

      expect(removed, 1);
    });
  });
}

void _noop() {}
