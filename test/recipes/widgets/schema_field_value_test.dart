import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  group('schemaFieldText', () {
    late BuildContext context;

    Future<void> pumpContext(WidgetTester tester) async {
      await tester.pumpApp(
        Builder(
          builder: (builderContext) {
            context = builderContext;
            return const SizedBox();
          },
        ),
      );
    }

    testWidgets('returns null when the field has no value', (tester) async {
      await pumpContext(tester);

      final recipe = Recipe(libraryId: cocktailsLibrary.id, name: 'Negroni');

      expect(schemaFieldText(context, garnishField, recipe), isNull);
      expect(schemaFieldText(context, doseField, recipe), isNull);
    });

    testWidgets('returns the trimmed text of a text field', (tester) async {
      await pumpContext(tester);

      final recipe = Recipe(
        libraryId: cocktailsLibrary.id,
        name: 'Negroni',
        fieldValues: const {'field-garnish': '  Orange peel  '},
      );

      expect(schemaFieldText(context, garnishField, recipe), 'Orange peel');
    });

    testWidgets('formats a whole number without a trailing zero', (
      tester,
    ) async {
      await pumpContext(tester);

      final recipe = Recipe(
        libraryId: coffeeLibrary.id,
        name: 'Morning cup',
        fieldValues: const {'field-dose': 92.0},
      );

      expect(schemaFieldText(context, doseField, recipe), '92');
    });

    testWidgets('groups a large number for the ambient locale', (tester) async {
      await pumpContext(tester);

      expect(formatSchemaNumber(context, 1234), '1,234');
    });
  });

  group('SchemaFieldValue', () {
    testWidgets('renders a Select value as a badge', (tester) async {
      await tester.pumpApp(
        SchemaFieldValue(field: glasswareField, value: 'Rocks'),
      );

      expect(
        find.descendant(of: find.byType(FBadge), matching: find.text('Rocks')),
        findsOneWidget,
      );
    });

    testWidgets('renders a Number alongside its unit', (tester) async {
      await tester.pumpApp(SchemaFieldValue(field: doseField, value: '18'));

      expect(find.text('18 g'), findsOneWidget);
    });

    testWidgets('renders a Number without a unit when it declares none', (
      tester,
    ) async {
      final unitless = FieldDefinition(
        id: 'field-yield',
        label: 'Yield',
        type: FieldType.number,
      );

      await tester.pumpApp(SchemaFieldValue(field: unitless, value: '2'));

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('renders text and long text inline', (tester) async {
      await tester.pumpApp(
        Column(
          children: [
            SchemaFieldValue(field: garnishField, value: 'Orange peel'),
            SchemaFieldValue(
              field: tastingNotesField,
              value: 'Stone fruit\nCocoa',
            ),
          ],
        ),
      );

      expect(find.text('Orange peel'), findsOneWidget);
      expect(find.text('Stone fruit\nCocoa'), findsOneWidget);
      expect(find.byType(FBadge), findsNothing);
    });
  });
}
