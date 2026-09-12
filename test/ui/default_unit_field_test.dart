import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:membar/ui/ui.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../helpers/helpers.dart';

void main() {
  group('DefaultUnitController', () {
    DefaultUnitController build([Unit? initial]) {
      final controller = DefaultUnitController(initial);
      addTearDown(controller.dispose);
      return controller;
    }

    test('chooses no unit by default', () {
      final controller = build();

      expect(controller.custom, isFalse);
      expect(controller.standardUnit, isNull);
      expect(controller.unit, isNull);
    });

    test('starts from a standard unit', () {
      final controller = build(const KnownUnit(StandardUnit.oz));

      expect(controller.custom, isFalse);
      expect(controller.unit, const KnownUnit(StandardUnit.oz));
    });

    test('starts from a custom unit in the custom field', () {
      final controller = build(CustomUnit('pinch'));

      expect(controller.custom, isTrue);
      expect(controller.customLabel.text, 'pinch');
      expect(controller.unit, CustomUnit('pinch'));
    });

    test('reads the control that is shown', () {
      final controller = build(const KnownUnit(StandardUnit.ml))
        ..customLabel.text = ' pour ';

      expect(controller.unit, const KnownUnit(StandardUnit.ml));
      controller.toggleCustom();
      expect(controller.unit, CustomUnit('pour'));
    });

    test('reads a blank custom label as no unit', () {
      final controller = build()..toggleCustom();

      expect(controller.unit, isNull);
    });

    test('notifies when the choice changes', () {
      final controller = build();
      var notified = 0;
      controller
        ..addListener(() => notified++)
        ..standardUnit = StandardUnit.dash
        ..toggleCustom();

      expect(notified, 2);
    });
  });

  group('DefaultUnitField', () {
    final standardUnitSelect = find.byWidgetPredicate(
      (widget) => widget is FSelect<StandardUnit>,
    );

    Future<void> pumpField(WidgetTester tester, Widget field) =>
        tester.pumpApp(SingleChildScrollView(child: field));

    testWidgets('picks a standard unit from the list', (tester) async {
      final controller = DefaultUnitController();
      addTearDown(controller.dispose);
      await pumpField(tester, DefaultUnitField(controller: controller));

      await tester.tap(standardUnitSelect);
      await tester.pumpAndSettle();
      await tester.tap(find.text('cl'));
      await tester.pumpAndSettle();

      expect(controller.unit, const KnownUnit(StandardUnit.cl));
    });

    testWidgets('swaps the list for a custom field and back', (tester) async {
      final controller = DefaultUnitController();
      addTearDown(controller.dispose);
      await pumpField(tester, DefaultUnitField(controller: controller));

      await tester.tap(find.text('Custom…'));
      await tester.pumpAndSettle();
      expect(standardUnitSelect, findsNothing);
      expect(find.text('Custom unit'), findsOneWidget);

      await tester.tap(find.text('Standard units'));
      await tester.pumpAndSettle();
      expect(standardUnitSelect, findsOneWidget);
    });

    group('while locked', () {
      testWidgets('shows a locked standard unit, disabled', (tester) async {
        final controller = DefaultUnitController(CustomUnit('pour'));
        addTearDown(controller.dispose);
        await pumpField(
          tester,
          DefaultUnitField(
            controller: controller,
            locked: true,
            lockedUnit: const KnownUnit(StandardUnit.ml),
          ),
        );

        expect(find.text('ml'), findsOneWidget);
        expect(
          tester.widget<FSelect<StandardUnit>>(standardUnitSelect).enabled,
          isFalse,
        );
        final toggle = tester.widget<FButton>(
          find.ancestor(
            of: find.text('Custom…'),
            matching: find.byType(FButton),
          ),
        );
        expect(toggle.onPress, isNull);
      });

      testWidgets('shows a locked custom unit in a disabled field', (
        tester,
      ) async {
        final controller = DefaultUnitController();
        addTearDown(controller.dispose);
        await pumpField(
          tester,
          DefaultUnitField(
            controller: controller,
            locked: true,
            lockedUnit: CustomUnit('pinch'),
          ),
        );

        expect(standardUnitSelect, findsNothing);
        expect(find.text('pinch'), findsOneWidget);
        expect(
          tester.widget<FTextFormField>(find.byType(FTextFormField)).enabled,
          isFalse,
        );
      });

      testWidgets('shows an empty list for an entry with no unit', (
        tester,
      ) async {
        final controller = DefaultUnitController(
          const KnownUnit(StandardUnit.oz),
        );
        addTearDown(controller.dispose);
        await pumpField(
          tester,
          DefaultUnitField(controller: controller, locked: true),
        );

        expect(find.text('oz'), findsNothing);
      });
    });

    testWidgets(
      'leaves nothing behind once its controller is disposed',
      (tester) async {
        final controller = DefaultUnitController(CustomUnit('pinch'));
        await pumpField(tester, DefaultUnitField(controller: controller));
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
      experimentalLeakTesting: LeakTesting.settings.withTrackedAll(),
    );
  });
}
