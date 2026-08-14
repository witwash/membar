import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:membar/recipes/recipes.dart';

import '../../helpers/helpers.dart';

void main() {
  group('StepRowField', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController(text: 'Stir with ice.');
      addTearDown(controller.dispose);
    });

    Future<void> pumpRow(
      WidgetTester tester, {
      VoidCallback onRemove = _noop,
    }) => tester.pumpApp(
      StepRowField(number: 2, controller: controller, onRemove: onRemove),
    );

    testWidgets('labels the row with its position', (tester) async {
      await pumpRow(tester);

      expect(find.text('Step 2'), findsOneWidget);
      expect(find.text('Stir with ice.'), findsOneWidget);
    });

    testWidgets('writes typed text back to the controller', (tester) async {
      await pumpRow(tester);

      await tester.enterText(find.byType(EditableText), 'Shake hard.');

      expect(controller.text, 'Shake hard.');
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
