import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/libraries/libraries.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  group('OptionRowControllers', () {
    test('primes the controller from the stored option and remembers it', () {
      final controllers = OptionRowControllers(0, original: 'Coupe');
      addTearDown(controllers.dispose);

      expect(controllers.id, 0);
      expect(controllers.text.text, 'Coupe');
      expect(controllers.original, 'Coupe');
    });

    test('starts blank with no original for a row added in the sheet', () {
      final controllers = OptionRowControllers(3);
      addTearDown(controllers.dispose);

      expect(controllers.text.text, isEmpty);
      expect(controllers.original, isNull);
    });

    test('keeps the original when the text is retyped', () {
      final controllers = OptionRowControllers(0, original: 'Coupe');
      addTearDown(controllers.dispose);

      controllers.text.text = 'Coupe glass';

      expect(controllers.original, 'Coupe');
    });
  });

  group('optionEdits', () {
    ({String? original, String text}) row(String? original, String text) =>
        (original: original, text: text);

    FieldDefinition select(List<String> options) => FieldDefinition(
      id: 'field-select',
      label: 'Select',
      type: FieldType.select,
      options: options,
    );

    // The table's third column: what the model says the edit removes, given
    // the options and renames the rows amount to.
    Set<String> removedFrom(
      List<String> stored,
      ({List<String> options, Map<String, String> renames}) edits,
    ) => select(
      stored,
    ).optionsRemovedBy(select(edits.options), renames: edits.renames);

    test('reports nothing for rows left as they were stored', () {
      final edits = optionEdits([row('Coupe', 'Coupe'), row('Rocks', 'Rocks')]);

      expect(edits.options, ['Coupe', 'Rocks']);
      expect(edits.renames, isEmpty);
    });

    test('renames a retyped option', () {
      final edits = optionEdits([
        row('Coupe', 'Coupe glass'),
        row('Rocks', 'Rocks'),
      ]);

      expect(edits.options, ['Coupe glass', 'Rocks']);
      expect(edits.renames, {'Coupe': 'Coupe glass'});
      expect(removedFrom(['Coupe', 'Rocks'], edits), isEmpty);
    });

    test('renames an option retyped in a different case', () {
      final edits = optionEdits([row('dry', 'Dry')]);

      expect(edits.options, ['Dry']);
      expect(edits.renames, {'dry': 'Dry'});
      expect(removedFrom(['dry'], edits), isEmpty);
    });

    test('renames both ways when two options are swapped', () {
      final edits = optionEdits([row('A', 'B'), row('B', 'A')]);

      expect(edits.options, ['B', 'A']);
      expect(edits.renames, {'A': 'B', 'B': 'A'});
      expect(removedFrom(['A', 'B'], edits), isEmpty);
    });

    test('merges when a row is deleted and another is retyped as it', () {
      final edits = optionEdits([row('A', 'B')]);

      expect(edits.options, ['B']);
      expect(edits.renames, {'A': 'B'});
      expect(removedFrom(['A', 'B'], edits), isEmpty);
    });

    test('renames a retyped row and leaves a new row reusing its text '
        'unrenamed', () {
      final edits = optionEdits([row('A', 'C'), row(null, 'A')]);

      expect(edits.options, ['C', 'A']);
      expect(edits.renames, {'A': 'C'});
      expect(removedFrom(['A'], edits), isEmpty);
    });

    test('removes a deleted row without renaming anything', () {
      final edits = optionEdits([row('Coupe', 'Coupe')]);

      expect(edits.options, ['Coupe']);
      expect(edits.renames, isEmpty);
      expect(removedFrom(['Coupe', 'Flute'], edits), {'Flute'});
    });

    test('removes a blanked row rather than renaming it to nothing', () {
      final edits = optionEdits([row('Coupe', 'Coupe'), row('Flute', '  ')]);

      expect(edits.options, ['Coupe']);
      expect(edits.renames, isEmpty);
      expect(removedFrom(['Coupe', 'Flute'], edits), {'Flute'});
    });

    test('drops a new row left blank', () {
      final edits = optionEdits([row('Coupe', 'Coupe'), row(null, '')]);

      expect(edits.options, ['Coupe']);
      expect(edits.renames, isEmpty);
      expect(removedFrom(['Coupe'], edits), isEmpty);
    });

    test('trims each option before comparing it with its original', () {
      final edits = optionEdits([row('Coupe', ' Coupe '), row(null, ' Nick ')]);

      expect(edits.options, ['Coupe', 'Nick']);
      expect(edits.renames, isEmpty);
    });
  });

  group('OptionRowField', () {
    late OptionRowControllers controllers;

    setUp(() {
      controllers = OptionRowControllers(0, original: 'Coupe');
      addTearDown(controllers.dispose);
    });

    Future<void> pumpRow(
      WidgetTester tester, {
      VoidCallback onRemove = _noop,
    }) => tester.pumpApp(
      OptionRowField(number: 3, controllers: controllers, onRemove: onRemove),
    );

    testWidgets('labels the row with its position', (tester) async {
      await pumpRow(tester);

      expect(find.text('Option 3'), findsOneWidget);
      expect(find.text('Coupe'), findsOneWidget);
    });

    testWidgets('writes typed text back to the controller', (tester) async {
      await pumpRow(tester);

      await tester.enterText(find.byType(EditableText), 'Coupe glass');

      expect(controllers.text.text, 'Coupe glass');
    });

    testWidgets('calls onRemove when the remove action, labelled with the '
        'position, is tapped', (tester) async {
      var removed = 0;
      await pumpRow(tester, onRemove: () => removed++);

      await tester.tap(find.bySemanticsLabel('Remove option 3'));
      await tester.pumpAndSettle();

      expect(removed, 1);
    });
  });
}

void _noop() {}
