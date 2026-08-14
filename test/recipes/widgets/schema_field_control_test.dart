import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  group('SchemaFieldControl', () {
    final numberFormat = NumberFormat.decimalPattern('en');

    /// Pumps the control [field] calls for, primed from [recipe], and returns
    /// its controller and the key that validates the surrounding form.
    Future<(SchemaFieldController, GlobalKey<FormState>)> pumpControl(
      WidgetTester tester,
      FieldDefinition field, {
      Recipe? recipe,
    }) async {
      final controller = SchemaFieldController(
        field: field,
        numberFormat: numberFormat,
        recipe: recipe,
      );
      addTearDown(controller.dispose);

      final formKey = GlobalKey<FormState>();
      // Sized to its content and pinned to the top, so a tap on a control
      // lands on the control rather than on the empty screen below it.
      await tester.pumpApp(
        Align(
          alignment: Alignment.topLeft,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [SchemaFieldControl(controller: controller)],
            ),
          ),
        ),
      );
      return (controller, formKey);
    }

    group('text', () {
      final field = FieldDefinition(
        id: 'field-garnish',
        label: 'Garnish',
        type: FieldType.text,
      );

      testWidgets('pre-fills the value the recipe already holds', (
        tester,
      ) async {
        final (controller, _) = await pumpControl(
          tester,
          field,
          recipe: Recipe(
            libraryId: 'library-cocktails',
            name: 'Negroni',
            fieldValues: const {'field-garnish': 'Orange peel'},
          ),
        );

        expect(find.text('Garnish'), findsOneWidget);
        expect(find.text('Orange peel'), findsOneWidget);
        expect(controller.value, 'Orange peel');
      });

      testWidgets('reads a blank field as no value at all', (tester) async {
        final (controller, _) = await pumpControl(tester, field);

        await tester.enterText(find.byType(EditableText), '   ');

        expect(controller.value, isNull);
      });

      testWidgets('trims what the user typed', (tester) async {
        final (controller, _) = await pumpControl(tester, field);

        await tester.enterText(find.byType(EditableText), '  Lemon twist ');

        expect(controller.value, 'Lemon twist');
      });

      testWidgets('accepts a blank optional field', (tester) async {
        final (_, formKey) = await pumpControl(tester, field);

        expect(formKey.currentState!.validate(), isTrue);
      });

      testWidgets('rejects a blank required field', (tester) async {
        final (_, formKey) = await pumpControl(
          tester,
          FieldDefinition(
            id: 'field-garnish',
            label: 'Garnish',
            type: FieldType.text,
            required: true,
          ),
        );

        expect(formKey.currentState!.validate(), isFalse);
        // forui swaps the error widget in a frame later, from a post-frame
        // callback on the field's states controller.
        await tester.pumpAndSettle();
        expect(find.text('This field is required.'), findsOneWidget);
      });
    });

    group('longText', () {
      final field = FieldDefinition(
        id: 'field-tasting-notes',
        label: 'Tasting notes',
        type: FieldType.longText,
      );

      testWidgets('renders a multi-line control', (tester) async {
        await pumpControl(tester, field);

        final textField = tester.widget<FTextFormField>(
          find.byType(FTextFormField),
        );
        expect(textField.minLines, 3);
        expect(textField.maxLines, 5);
      });

      testWidgets('keeps the newlines the user typed', (tester) async {
        final (controller, _) = await pumpControl(tester, field);

        await tester.enterText(find.byType(EditableText), 'Stone fruit\nCocoa');

        expect(controller.value, 'Stone fruit\nCocoa');
      });
    });

    group('number', () {
      final field = FieldDefinition(
        id: 'field-dose',
        label: 'Dose',
        type: FieldType.number,
        unit: 'g',
      );
      final requiredField = FieldDefinition(
        id: 'field-dose',
        label: 'Dose',
        type: FieldType.number,
        required: true,
      );

      testWidgets('renders its unit alongside the label', (tester) async {
        await pumpControl(tester, field);

        expect(find.text('Dose (g)'), findsOneWidget);
      });

      testWidgets('renders a label without a unit when it has none', (
        tester,
      ) async {
        await pumpControl(tester, requiredField);

        expect(find.text('Dose'), findsOneWidget);
      });

      testWidgets('renders a whole number without a trailing zero', (
        tester,
      ) async {
        await pumpControl(
          tester,
          field,
          recipe: Recipe(
            libraryId: 'library-coffee',
            name: 'Morning cup',
            fieldValues: const {'field-dose': 92.0},
          ),
        );

        expect(find.text('92'), findsOneWidget);
        expect(find.text('92.0'), findsNothing);
      });

      testWidgets('parses a grouped entry through the locale, not by '
          'replacing separators', (tester) async {
        final (controller, _) = await pumpControl(tester, field);

        await tester.enterText(find.byType(EditableText), '1,234');

        expect(controller.value, 1234);
      });

      testWidgets('parses a decimal entry', (tester) async {
        final (controller, _) = await pumpControl(tester, field);

        await tester.enterText(find.byType(EditableText), '18.5');

        expect(controller.value, 18.5);
      });

      testWidgets('accepts 0 for a required field: required means present, '
          'not truthy', (tester) async {
        final (controller, formKey) = await pumpControl(tester, requiredField);

        await tester.enterText(find.byType(EditableText), '0');

        expect(formKey.currentState!.validate(), isTrue);
        expect(controller.value, 0);
      });

      testWidgets('rejects a blank required field', (tester) async {
        final (_, formKey) = await pumpControl(tester, requiredField);

        expect(formKey.currentState!.validate(), isFalse);
        // forui swaps the error widget in a frame later, from a post-frame
        // callback on the field's states controller.
        await tester.pumpAndSettle();
        expect(find.text('This field is required.'), findsOneWidget);
      });

      testWidgets('accepts a blank optional field', (tester) async {
        final (controller, formKey) = await pumpControl(tester, field);

        expect(formKey.currentState!.validate(), isTrue);
        expect(controller.value, isNull);
      });

      testWidgets('rejects text with an error distinct from the '
          'required-field one', (tester) async {
        final (controller, formKey) = await pumpControl(tester, field);

        await tester.enterText(find.byType(EditableText), 'lots');

        expect(formKey.currentState!.validate(), isFalse);
        // forui swaps the error widget in a frame later, from a post-frame
        // callback on the field's states controller.
        await tester.pumpAndSettle();
        expect(find.text('Enter a number.'), findsOneWidget);
        expect(find.text('This field is required.'), findsNothing);
        expect(controller.value, isNull);
      });

      testWidgets('rejects a non-finite entry', (tester) async {
        final (controller, formKey) = await pumpControl(tester, field);

        await tester.enterText(find.byType(EditableText), 'Infinity');

        expect(formKey.currentState!.validate(), isFalse);
        expect(controller.value, isNull);
      });
    });

    group('select', () {
      // FSelect is abstract and its factory builds a private subclass, so the
      // widget cannot be found by its type.
      final selectFinder = find.byWidgetPredicate(
        (it) => it is FSelect<String>,
      );
      final field = FieldDefinition(
        id: 'field-glassware',
        label: 'Glassware',
        type: FieldType.select,
        options: const ['Coupe', 'Rocks'],
      );
      final requiredField = FieldDefinition(
        id: 'field-glassware',
        label: 'Glassware',
        type: FieldType.select,
        required: true,
        options: const ['Coupe', 'Rocks'],
      );

      testWidgets("offers exactly the schema's option list", (tester) async {
        await pumpControl(tester, field);

        await tester.tap(selectFinder);
        await tester.pumpAndSettle();

        expect(find.text('Coupe'), findsOneWidget);
        expect(find.text('Rocks'), findsOneWidget);
      });

      testWidgets('selects the option the user taps', (tester) async {
        final (controller, _) = await pumpControl(tester, field);

        await tester.tap(selectFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rocks').last);
        await tester.pumpAndSettle();

        expect(controller.value, 'Rocks');
      });

      testWidgets('pre-selects the stored option', (tester) async {
        final (controller, _) = await pumpControl(
          tester,
          field,
          recipe: Recipe(
            libraryId: 'library-cocktails',
            name: 'Negroni',
            fieldValues: const {'field-glassware': 'Rocks'},
          ),
        );

        expect(controller.value, 'Rocks');
      });

      testWidgets('shows no selection for a value the schema no longer '
          'offers', (tester) async {
        final (controller, _) = await pumpControl(
          tester,
          field,
          recipe: Recipe(
            libraryId: 'library-cocktails',
            name: 'Negroni',
            fieldValues: const {'field-glassware': 'Tiki mug'},
          ),
        );

        expect(controller.value, isNull);
        expect(find.text('Tiki mug'), findsNothing);
      });

      testWidgets('rejects a required field with nothing selected', (
        tester,
      ) async {
        final (_, formKey) = await pumpControl(tester, requiredField);

        expect(formKey.currentState!.validate(), isFalse);
        // forui swaps the error widget in a frame later, from a post-frame
        // callback on the field's states controller.
        await tester.pumpAndSettle();
        expect(find.text('This field is required.'), findsOneWidget);
      });

      testWidgets('accepts an optional field with nothing selected', (
        tester,
      ) async {
        final (_, formKey) = await pumpControl(tester, field);

        expect(formKey.currentState!.validate(), isTrue);
      });

      /// Re-taps the option already selected, which clears it only on a
      /// toggleable — that is, optional — select.
      Future<void> tapRocksTwice(WidgetTester tester) async {
        for (var i = 0; i < 2; i++) {
          await tester.tap(selectFinder);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Rocks').last);
          await tester.pumpAndSettle();
        }
      }

      testWidgets('lets an optional selection be cleared', (tester) async {
        final (controller, _) = await pumpControl(tester, field);

        await tapRocksTwice(tester);

        expect(controller.value, isNull);
      });

      testWidgets('keeps a required selection: clearing it could only produce '
          'a value the form refuses to save', (tester) async {
        final (controller, _) = await pumpControl(tester, requiredField);

        await tapRocksTwice(tester);

        expect(controller.value, 'Rocks');
      });
    });
  });
}
