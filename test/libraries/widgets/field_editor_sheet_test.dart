import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/libraries/libraries.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

class _MockRecipesBloc extends MockBloc<RecipesEvent, RecipesState>
    implements RecipesBloc {}

void main() {
  group('FieldEditorSheet', () {
    late RecipesBloc recipesBloc;
    late StreamController<RecipesState> states;

    Recipe recipeWith(String name, {String? glassware}) => Recipe(
      id: name,
      libraryId: cocktailsLibrary.id,
      name: name,
      fieldValues: {glasswareField.id: ?glassware},
    );

    final initialState = RecipesState(
      status: RecipesStatus.success,
      libraries: [cocktailsLibrary, coffeeLibrary],
      activeLibraryId: cocktailsLibrary.id,
    );

    setUpAll(
      () => registerFallbackValue(const RecipesSubscriptionRequested()),
    );

    setUp(() {
      recipesBloc = _MockRecipesBloc();
      states = StreamController<RecipesState>.broadcast();
      addTearDown(states.close);
    });

    Future<void> openSheet(
      WidgetTester tester, {
      Library? library,
      FieldDefinition? field,
      RecipesState? state,
    }) async {
      whenListen(
        recipesBloc,
        states.stream,
        initialState: state ?? initialState,
      );
      await tester.pumpApp(
        Builder(
          builder: (context) => FButton(
            onPress: () => FieldEditorSheet.show(
              context,
              library: library ?? cocktailsLibrary,
              field: field,
            ),
            child: const Text('Open'),
          ),
        ),
        recipesBloc: recipesBloc,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    Finder textFieldLabelled(String label) => find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byType(FTextFormField),
      ),
      matching: find.byType(EditableText),
    );

    String textIn(WidgetTester tester, String label) =>
        tester.widget<EditableText>(textFieldLabelled(label)).controller.text;

    final typeSelect = find.byWidgetPredicate(
      (widget) => widget is FSelect<FieldType>,
    );

    Future<void> tap(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    Future<void> tapAction(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.bySemanticsLabel(label));
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pumpAndSettle();
    }

    Future<void> enter(WidgetTester tester, String label, String text) async {
      await tester.ensureVisible(textFieldLabelled(label));
      await tester.enterText(textFieldLabelled(label), text);
      await tester.pumpAndSettle();
    }

    Future<void> chooseType(WidgetTester tester, String type) async {
      await tester.ensureVisible(typeSelect);
      await tester.tap(typeSelect);
      await tester.pumpAndSettle();
      await tap(tester, type);
    }

    Future<void> addOption(WidgetTester tester, int number, String text) async {
      await tap(tester, 'Add option');
      await enter(tester, 'Option $number', text);
    }

    RecipesLibrarySaved savedEvent() {
      final events = verify(() => recipesBloc.add(captureAny())).captured;
      return events.whereType<RecipesLibrarySaved>().single;
    }

    void expectNothingSaved() => verifyNever(
      () => recipesBloc.add(any(that: isA<RecipesLibrarySaved>())),
    );

    Future<void> emit(
      WidgetTester tester,
      RecipesMutationStatus status,
    ) async {
      states.add(
        initialState.copyWith(
          mutation: RecipesMutation.librarySaved,
          mutationStatus: status,
        ),
      );
      await tester.pumpAndSettle();
    }

    group('add', () {
      testWidgets('starts blank, as an optional Text field with neither a '
          'unit nor options', (tester) async {
        await openSheet(tester);

        expect(find.text('New field'), findsOneWidget);
        expect(textIn(tester, 'Label'), isEmpty);
        expect(
          find.descendant(of: typeSelect, matching: find.text('Text')),
          findsOneWidget,
        );
        expect(tester.widget<FSelect<FieldType>>(typeSelect).enabled, isTrue);
        expect(tester.widget<FCheckbox>(find.byType(FCheckbox)).value, isFalse);
        expect(find.text('Unit'), findsNothing);
        expect(find.text('Options'), findsNothing);
      });

      testWidgets('offers the types as Text, Long text, Number, Choice', (
        tester,
      ) async {
        await openSheet(tester);

        await tester.tap(typeSelect);
        await tester.pumpAndSettle();

        final offsets = [
          for (final type in ['Long text', 'Number', 'Choice'])
            tester.getCenter(find.text(type)).dy,
        ];
        expect(
          tester.getCenter(find.text('Text').last).dy,
          lessThan(offsets[0]),
        );
        expect(offsets, orderedEquals([...offsets]..sort()));
      });

      testWidgets('shows the unit for a Number only', (tester) async {
        await openSheet(tester);

        await chooseType(tester, 'Number');

        expect(find.text('Unit'), findsOneWidget);
        expect(find.text('Options'), findsNothing);

        await chooseType(tester, 'Long text');

        expect(find.text('Unit'), findsNothing);
      });

      testWidgets('shows the options for a Choice only', (tester) async {
        await openSheet(tester);

        await chooseType(tester, 'Choice');

        expect(find.text('Options'), findsOneWidget);
        expect(find.text('Add option'), findsOneWidget);
        expect(find.text('Unit'), findsNothing);

        await chooseType(tester, 'Text');

        expect(find.text('Options'), findsNothing);
      });

      testWidgets('refuses a blank label', (tester) async {
        await openSheet(tester);

        await enter(tester, 'Label', ' ');
        await tap(tester, 'Save field');

        expect(find.text('Enter a label.'), findsOneWidget);
        expectNothingSaved();
      });

      testWidgets('refuses a label another field of the library carries, '
          'ignoring case', (tester) async {
        await openSheet(tester);

        await enter(tester, 'Label', ' GARNISH ');
        await tap(tester, 'Save field');

        expect(
          find.text('Another field is already called Garnish.'),
          findsOneWidget,
        );
        expectNothingSaved();
      });

      testWidgets("accepts a label only another library's field carries", (
        tester,
      ) async {
        await openSheet(tester);

        await enter(tester, 'Label', 'Dose');
        await tap(tester, 'Save field');

        expect(savedEvent().library.fields.last.label, 'Dose');
      });

      testWidgets('appends a Text field to the library', (tester) async {
        await openSheet(tester);

        await enter(tester, 'Label', ' Strength ');
        await tap(tester, 'Save field');

        final event = savedEvent();
        final added = event.library.fields.last;
        expect(event.library.id, cocktailsLibrary.id);
        expect(event.library.name, cocktailsLibrary.name);
        expect(event.library.fields, [glasswareField, garnishField, added]);
        expect(event.optionRenames, isEmpty);
        expect(added.label, 'Strength');
        expect(added.type, FieldType.text);
        expect(added.required, isFalse);
        expect(added.options, isNull);
        expect(added.unit, isNull);
        expect(added.id, isNot(anyOf(glasswareField.id, garnishField.id)));
      });

      testWidgets('saves a Long text field', (tester) async {
        await openSheet(tester);

        await enter(tester, 'Label', 'Story');
        await chooseType(tester, 'Long text');
        await tap(tester, 'Save field');

        expect(savedEvent().library.fields.last.type, FieldType.longText);
      });

      testWidgets('saves a required Number field with its trimmed unit', (
        tester,
      ) async {
        await openSheet(tester);

        await enter(tester, 'Label', 'ABV');
        await chooseType(tester, 'Number');
        await enter(tester, 'Unit', ' % ');
        await tap(tester, 'Required');
        await tap(tester, 'Save field');

        final added = savedEvent().library.fields.last;
        expect(added.type, FieldType.number);
        expect(added.unit, '%');
        expect(added.required, isTrue);
      });

      testWidgets('saves a blank unit as none', (tester) async {
        await openSheet(tester);

        await enter(tester, 'Label', 'Rating');
        await chooseType(tester, 'Number');
        await enter(tester, 'Unit', '  ');
        await tap(tester, 'Save field');

        expect(savedEvent().library.fields.last.unit, isNull);
      });

      testWidgets('saves a Choice field with its options, trimmed and without '
          'the blank rows', (tester) async {
        await openSheet(tester);

        await enter(tester, 'Label', 'Roast');
        await chooseType(tester, 'Choice');
        await addOption(tester, 1, ' Light ');
        await addOption(tester, 2, '');
        await addOption(tester, 3, 'Dark');
        await tap(tester, 'Save field');

        final event = savedEvent();
        final added = event.library.fields.last;
        expect(added.type, FieldType.select);
        expect(added.options, ['Light', 'Dark']);
        expect(event.optionRenames, isEmpty);
      });

      testWidgets('leaves out a unit and options typed for a type that was '
          'then changed', (tester) async {
        await openSheet(tester);

        await enter(tester, 'Label', 'Strength');
        await chooseType(tester, 'Number');
        await enter(tester, 'Unit', 'g');
        await chooseType(tester, 'Choice');
        await addOption(tester, 1, 'Light');
        await chooseType(tester, 'Text');
        await tap(tester, 'Save field');

        final added = savedEvent().library.fields.last;
        expect(added.type, FieldType.text);
        expect(added.unit, isNull);
        expect(added.options, isNull);
      });

      testWidgets('refuses a Choice with no option that has text in it', (
        tester,
      ) async {
        await openSheet(tester);

        await enter(tester, 'Label', 'Roast');
        await chooseType(tester, 'Choice');
        await addOption(tester, 1, '  ');
        await tap(tester, 'Save field');

        expect(find.text('Add at least one option.'), findsOneWidget);
        expectNothingSaved();
      });

      testWidgets('refuses two options that match ignoring case', (
        tester,
      ) async {
        await openSheet(tester);

        await enter(tester, 'Label', 'Roast');
        await chooseType(tester, 'Choice');
        await addOption(tester, 1, 'Light');
        await addOption(tester, 2, ' light ');
        await tap(tester, 'Save field');

        expect(find.text('Two options are the same.'), findsOneWidget);
        expectNothingSaved();
      });

      testWidgets('announces the options error and clears it as it is '
          'corrected', (tester) async {
        await openSheet(tester);

        await enter(tester, 'Label', 'Roast');
        await chooseType(tester, 'Choice');
        await addOption(tester, 1, 'Light');
        await addOption(tester, 2, 'Light');
        await tap(tester, 'Save field');

        final error = find.text('Two options are the same.');
        expect(
          tester
              .widget<Semantics>(
                find
                    .ancestor(of: error, matching: find.byType(Semantics))
                    .first,
              )
              .properties
              .liveRegion,
          isTrue,
        );

        await enter(tester, 'Option 2', 'Dark');

        expect(error, findsNothing);
      });

      testWidgets('does not judge the options before a save is attempted', (
        tester,
      ) async {
        await openSheet(tester);

        await chooseType(tester, 'Choice');
        await addOption(tester, 1, '');

        expect(find.text('Add at least one option.'), findsNothing);
      });
    });

    group('edit', () {
      testWidgets("starts from the field's values with the type locked", (
        tester,
      ) async {
        await openSheet(tester, field: glasswareField);

        expect(find.text('Edit field'), findsOneWidget);
        expect(textIn(tester, 'Label'), 'Glassware');
        expect(
          find.descendant(of: typeSelect, matching: find.text('Choice')),
          findsOneWidget,
        );
        expect(tester.widget<FSelect<FieldType>>(typeSelect).enabled, isFalse);
        expect(
          find.text("A field's type cannot be changed once the field exists."),
          findsOneWidget,
        );
        expect(textIn(tester, 'Option 1'), 'Coupe');
        expect(textIn(tester, 'Option 2'), 'Rocks');
        expect(tester.widget<FCheckbox>(find.byType(FCheckbox)).value, isFalse);
      });

      testWidgets('offers no other type when the locked type is tapped', (
        tester,
      ) async {
        await openSheet(tester, field: glasswareField);

        await tester.tap(typeSelect, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.text('Number'), findsNothing);
      });

      testWidgets("starts from a Number field's unit and required flag", (
        tester,
      ) async {
        final abvField = FieldDefinition(
          id: 'field-abv',
          label: 'ABV',
          type: FieldType.number,
          unit: '%',
          required: true,
        );
        await openSheet(
          tester,
          library: Library(
            id: 'library-wine',
            name: 'Wine',
            fields: [abvField],
          ),
          field: abvField,
        );

        expect(textIn(tester, 'Unit'), '%');
        expect(tester.widget<FCheckbox>(find.byType(FCheckbox)).value, isTrue);
      });

      testWidgets("keeps the field's id and position when it is saved", (
        tester,
      ) async {
        await openSheet(tester, field: glasswareField);

        await enter(tester, 'Label', 'Glass');
        await tap(tester, 'Required');
        await tap(tester, 'Save field');

        expect(
          savedEvent(),
          RecipesLibrarySaved(
            Library(
              id: cocktailsLibrary.id,
              name: cocktailsLibrary.name,
              fields: [
                FieldDefinition(
                  id: glasswareField.id,
                  label: 'Glass',
                  type: FieldType.select,
                  options: const ['Coupe', 'Rocks'],
                  required: true,
                ),
                garnishField,
              ],
            ),
          ),
        );
      });

      testWidgets("accepts the field's own label", (tester) async {
        await openSheet(tester, field: garnishField);

        await enter(tester, 'Label', 'GARNISH');
        await tap(tester, 'Save field');

        expect(savedEvent().library.fields.last.label, 'GARNISH');
      });

      testWidgets('refuses a relabel onto another field', (tester) async {
        await openSheet(tester, field: garnishField);

        await enter(tester, 'Label', 'glassware');
        await tap(tester, 'Save field');

        expect(
          find.text('Another field is already called Glassware.'),
          findsOneWidget,
        );
        expectNothingSaved();
      });

      testWidgets('saves a changed unit', (tester) async {
        await openSheet(tester, library: coffeeLibrary, field: doseField);

        await enter(tester, 'Unit', 'oz');
        await tap(tester, 'Save field');

        final saved = savedEvent().library.fields.first;
        expect(saved.id, doseField.id);
        expect(saved.unit, 'oz');
      });
    });

    group('options', () {
      // Two recipes on Rocks, one on Coupe, one with no glassware at all.
      final inUse = initialState.copyWith(
        recipes: [
          recipeWith('Negroni', glassware: 'Rocks'),
          recipeWith('Old Fashioned', glassware: 'Rocks'),
          recipeWith('Martini', glassware: 'Coupe'),
          recipeWith('Highball'),
        ],
      );

      testWidgets('renumbers the rows when one is removed', (tester) async {
        await openSheet(tester, field: glasswareField);

        await tapAction(tester, 'Remove option 1');

        expect(textIn(tester, 'Option 1'), 'Rocks');
        expect(find.text('Option 2'), findsNothing);
      });

      testWidgets('dispatches the options and renames the rows amount to', (
        tester,
      ) async {
        await openSheet(tester, field: glasswareField, state: inUse);

        await enter(tester, 'Option 1', 'Coupe glass');
        await addOption(tester, 3, 'Flute');
        await tap(tester, 'Save field');

        final event = savedEvent();
        expect(event.library.fields.first.options, [
          'Coupe glass',
          'Rocks',
          'Flute',
        ]);
        expect(event.optionRenames, {
          glasswareField.id: {'Coupe': 'Coupe glass'},
        });
        expect(find.byType(FDialog), findsNothing);
      });

      testWidgets('swaps two options as two renames, asking nothing', (
        tester,
      ) async {
        await openSheet(tester, field: glasswareField, state: inUse);

        await enter(tester, 'Option 1', 'Rocks');
        await enter(tester, 'Option 2', 'Coupe');
        await tap(tester, 'Save field');

        final event = savedEvent();
        expect(event.library.fields.first.options, ['Rocks', 'Coupe']);
        expect(event.optionRenames, {
          glasswareField.id: {'Coupe': 'Rocks', 'Rocks': 'Coupe'},
        });
      });

      testWidgets('asks nothing when the removed option is used by no recipe', (
        tester,
      ) async {
        await openSheet(tester, field: glasswareField);

        await tapAction(tester, 'Remove option 2');
        await tap(tester, 'Save field');

        final event = savedEvent();
        expect(event.library.fields.first.options, ['Coupe']);
        expect(event.optionRenames, isEmpty);
      });

      testWidgets('asks before removing an option in use, stating how many '
          'recipes use it', (tester) async {
        await openSheet(tester, field: glasswareField, state: inUse);

        await tapAction(tester, 'Remove option 2');
        await tap(tester, 'Save field');

        expect(find.text('Remove options in use?'), findsOneWidget);
        expect(
          find.text(
            '2 recipes use an option you removed. Their values will be '
            'cleared, and this cannot be undone.',
          ),
          findsOneWidget,
        );
        expectNothingSaved();

        await tap(tester, 'Remove');

        expect(savedEvent().library.fields.first.options, ['Coupe']);
      });

      testWidgets('has its own wording for one recipe, and counts a blanked '
          'option as removed', (tester) async {
        await openSheet(tester, field: glasswareField, state: inUse);

        await enter(tester, 'Option 1', ' ');
        await tap(tester, 'Save field');

        expect(
          find.text(
            '1 recipe uses an option you removed. Its value will be cleared, '
            'and this cannot be undone.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('stays open with nothing dispatched when the removal is '
          'cancelled', (tester) async {
        await openSheet(tester, field: glasswareField, state: inUse);

        await tapAction(tester, 'Remove option 2');
        await tap(tester, 'Save field');
        await tester.tap(
          find.descendant(
            of: find.byType(FDialog),
            matching: find.text('Cancel'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FDialog), findsNothing);
        expect(find.byType(FieldEditorSheet), findsOneWidget);
        expect(textIn(tester, 'Option 1'), 'Coupe');
        expectNothingSaved();
      });

      testWidgets('ignores a success that arrives before the removal is '
          'confirmed', (tester) async {
        await openSheet(tester, field: glasswareField, state: inUse);

        await tapAction(tester, 'Remove option 2');
        await tap(tester, 'Save field');
        await emit(tester, RecipesMutationStatus.success);

        expect(find.byType(FieldEditorSheet), findsOneWidget);
      });
    });

    group('save outcome', () {
      testWidgets('closes once the save succeeds', (tester) async {
        await openSheet(tester, field: garnishField);

        await tap(tester, 'Save field');
        await emit(tester, RecipesMutationStatus.loading);
        expect(find.byType(FieldEditorSheet), findsOneWidget);
        await emit(tester, RecipesMutationStatus.success);

        expect(find.byType(FieldEditorSheet), findsNothing);
      });

      testWidgets('disables saving while the save is in flight', (
        tester,
      ) async {
        await openSheet(tester, field: garnishField);

        await tap(tester, 'Save field');
        await emit(tester, RecipesMutationStatus.loading);

        final save = tester.widget<FButton>(
          find.ancestor(
            of: find.text('Save field'),
            matching: find.byType(FButton),
          ),
        );
        expect(save.onPress, isNull);
      });

      testWidgets('ignores a success it did not start', (tester) async {
        await openSheet(tester, field: garnishField);

        await emit(tester, RecipesMutationStatus.success);

        expect(find.byType(FieldEditorSheet), findsOneWidget);
      });

      testWidgets('stays open behind a banner with every typed value intact '
          'on failure', (tester) async {
        await openSheet(tester);

        await enter(tester, 'Label', 'Roast');
        await chooseType(tester, 'Choice');
        await addOption(tester, 1, 'Light');
        await addOption(tester, 2, 'Dark');
        await tap(tester, 'Required');
        await tap(tester, 'Save field');
        await emit(tester, RecipesMutationStatus.failure);

        expect(find.byType(FieldEditorSheet), findsOneWidget);
        expect(find.text('Your field could not be saved.'), findsOneWidget);
        expect(textIn(tester, 'Label'), 'Roast');
        expect(
          find.descendant(of: typeSelect, matching: find.text('Choice')),
          findsOneWidget,
        );
        expect(textIn(tester, 'Option 1'), 'Light');
        expect(textIn(tester, 'Option 2'), 'Dark');
        expect(tester.widget<FCheckbox>(find.byType(FCheckbox)).value, isTrue);
      });

      testWidgets('clears the banner when the save is retried', (tester) async {
        await openSheet(tester, field: garnishField);
        await tap(tester, 'Save field');
        await emit(tester, RecipesMutationStatus.failure);

        await tap(tester, 'Save field');

        expect(find.text('Your field could not be saved.'), findsNothing);
      });
    });

    testWidgets('closes without saving when cancelled', (tester) async {
      await openSheet(tester);

      await tap(tester, 'Cancel');

      expect(find.byType(FieldEditorSheet), findsNothing);
      expectNothingSaved();
    });

    testWidgets(
      'disposes the controllers of removed rows and, when it closes, of the '
      'rows that remain',
      (tester) async {
        await openSheet(tester, field: glasswareField);

        await tapAction(tester, 'Remove option 1');
        await addOption(tester, 2, 'Flute');
        await tap(tester, 'Cancel');

        expect(find.byType(FieldEditorSheet), findsNothing);
      },
      experimentalLeakTesting: LeakTesting.settings.withTrackedAll(),
    );

    testWidgets('re-provides the bloc to the sheet', (tester) async {
      await openSheet(tester);

      final context = tester.element(find.byType(FieldEditorSheet));
      expect(context.read<RecipesBloc>(), same(recipesBloc));
    });
  });
}
