import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

class _MockRecipesBloc extends MockBloc<RecipesEvent, RecipesState>
    implements RecipesBloc {}

void main() {
  group('RecipeEditorPage', () {
    late RecipesBloc recipesBloc;
    late StreamController<RecipesState> states;

    final negroni = Recipe(
      id: 'recipe-negroni',
      libraryId: cocktailsLibrary.id,
      name: 'Negroni',
      ingredients: [Ingredient(name: 'Gin', quantity: '1', unit: 'oz')],
      steps: const ['Stir with ice.'],
      tags: const ['Bitter'],
      notes: 'Equal parts.',
      fieldValues: const {
        'field-glassware': 'Rocks',
        'field-garnish': 'Orange peel',
      },
    );

    setUpAll(
      () => registerFallbackValue(const RecipesSubscriptionRequested()),
    );

    setUp(() {
      recipesBloc = _MockRecipesBloc();
      states = StreamController<RecipesState>.broadcast();
      addTearDown(states.close);
      whenListen(
        recipesBloc,
        states.stream,
        initialState: RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary],
          recipes: [negroni],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
    });

    Future<void> pumpEditor(
      WidgetTester tester, {
      Library? library,
      Recipe? recipe,
    }) => tester.pumpApp(
      RecipeEditorPage(library: library ?? cocktailsLibrary, recipe: recipe),
      recipesBloc: recipesBloc,
    );

    /// Pumps the editor on a pushed route, so popping it can be observed.
    Future<void> pushEditor(
      WidgetTester tester, {
      Library? library,
      Recipe? recipe,
    }) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => FButton(
            onPress: () => RecipeEditorPage.open(
              context,
              library ?? cocktailsLibrary,
              recipe: recipe,
            ),
            child: const Text('Open'),
          ),
        ),
        recipesBloc: recipesBloc,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    /// The editable behind the field labelled [label]. `enterText` needs the
    /// [EditableText], not the label that names it.
    Finder fieldNamed(String label) => find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byType(FTextFormField),
      ),
      matching: find.byType(EditableText),
    );

    /// Scrolls [finder] into view before tapping it: the form is taller than
    /// the test view, so most of its controls start off-screen.
    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> tapSave(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('Save recipe'));
      await tester.pumpAndSettle();
    }

    /// The recipe carried by the save event the editor dispatched.
    Recipe savedRecipe() {
      final events = verify(() => recipesBloc.add(captureAny())).captured;
      return events.whereType<RecipesRecipeSaved>().single.recipe;
    }

    testWidgets('renders one control per schema field, in schema order', (
      tester,
    ) async {
      await pumpEditor(tester);

      expect(find.text('New recipe'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Glassware')).dy,
        lessThan(tester.getTopLeft(find.text('Garnish')).dy),
      );
      // Glassware is a Select and Garnish a Text field.
      expect(
        find.byWidgetPredicate((it) => it is FSelect<String>),
        findsOneWidget,
      );
    });

    testWidgets('renders a control per field of a schema with no Select', (
      tester,
    ) async {
      await pumpEditor(tester, library: coffeeLibrary);

      expect(find.text('Dose (g)'), findsOneWidget);
      expect(find.text('Tasting notes'), findsOneWidget);
      expect(
        find.byWidgetPredicate((it) => it is FSelect<String>),
        findsNothing,
      );
    });

    testWidgets('does not render the library switcher', (tester) async {
      await pumpEditor(tester);

      expect(find.byType(LibrarySwitcher), findsNothing);
    });

    testWidgets('blocks a blank name with an inline error', (tester) async {
      await pumpEditor(tester);

      await tapSave(tester);

      expect(find.text('Enter a name.'), findsOneWidget);
      verifyNever(() => recipesBloc.add(any(that: isA<RecipesRecipeSaved>())));
    });

    testWidgets('saves the recipe the form describes', (tester) async {
      await pumpEditor(tester);

      await tester.enterText(fieldNamed('Name'), 'Martini');
      await tapSave(tester);

      final recipe = savedRecipe();
      expect(recipe.name, 'Martini');
      expect(recipe.libraryId, cocktailsLibrary.id);
    });

    testWidgets('pre-fills every core field and every schema field', (
      tester,
    ) async {
      await pumpEditor(tester, recipe: negroni);

      expect(find.text('Edit recipe'), findsOneWidget);
      expect(find.text('Negroni'), findsOneWidget);
      expect(find.text('Gin'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('oz'), findsOneWidget);
      expect(find.text('Stir with ice.'), findsOneWidget);
      expect(find.text('Equal parts.'), findsOneWidget);
      expect(find.text('Orange peel'), findsOneWidget);
      expect(find.text('Rocks'), findsOneWidget);
      expect(find.text('Bitter'), findsOneWidget);
    });

    group('schema values', () {
      final requiredGarnish = FieldDefinition(
        id: 'field-garnish',
        label: 'Garnish',
        type: FieldType.text,
        required: true,
      );
      final requiredLibrary = Library(
        id: cocktailsLibrary.id,
        name: 'Cocktails',
        fields: [requiredGarnish],
      );

      testWidgets('blocks a save on a blank required field', (tester) async {
        await pumpEditor(tester, library: requiredLibrary);
        await tester.enterText(fieldNamed('Name'), 'Martini');

        await tapSave(tester);

        expect(find.text('This field is required.'), findsOneWidget);
        verifyNever(
          () => recipesBloc.add(any(that: isA<RecipesRecipeSaved>())),
        );
      });

      testWidgets('omits a blank field rather than storing an empty string', (
        tester,
      ) async {
        await pumpEditor(tester);

        await tester.enterText(fieldNamed('Name'), 'Martini');
        await tapSave(tester);

        expect(savedRecipe().fieldValues, isEmpty);
      });

      testWidgets('stores what the user typed, parsed for its type', (
        tester,
      ) async {
        await pumpEditor(tester, library: coffeeLibrary);

        await tester.enterText(fieldNamed('Name'), 'Pour-over');
        await tester.enterText(fieldNamed('Dose (g)'), '1,234');
        await tapSave(tester);

        expect(savedRecipe().numberValue('field-dose'), 1234);
      });

      testWidgets('drops a field the user cleared', (tester) async {
        await pumpEditor(tester, recipe: negroni);

        await tester.enterText(fieldNamed('Garnish'), '');
        await tapSave(tester);

        expect(savedRecipe().fieldValues.containsKey('field-garnish'), isFalse);
      });

      testWidgets('keeps a value whose field the schema no longer declares', (
        tester,
      ) async {
        await pumpEditor(
          tester,
          recipe: Recipe(
            id: 'recipe-negroni',
            libraryId: cocktailsLibrary.id,
            name: 'Negroni',
            fieldValues: const {'field-that-was-deleted': 'Still here'},
          ),
        );

        await tapSave(tester);

        expect(
          savedRecipe().fieldValues['field-that-was-deleted'],
          'Still here',
        );
      });

      testWidgets('keeps a Select value the option list no longer offers', (
        tester,
      ) async {
        await pumpEditor(
          tester,
          recipe: Recipe(
            id: 'recipe-negroni',
            libraryId: cocktailsLibrary.id,
            name: 'Negroni',
            fieldValues: const {'field-glassware': 'Tiki mug'},
          ),
        );

        await tapSave(tester);

        expect(savedRecipe().fieldValues['field-glassware'], 'Tiki mug');
      });
    });

    group('ingredients and steps', () {
      testWidgets('strips rows the user left blank', (tester) async {
        await pumpEditor(tester);

        await tester.enterText(fieldNamed('Name'), 'Martini');
        await tapVisible(tester, find.text('Add ingredient'));
        await tapVisible(tester, find.text('Add step'));
        await tapSave(tester);

        final recipe = savedRecipe();
        expect(recipe.ingredients, isEmpty);
        expect(recipe.steps, isEmpty);
      });

      testWidgets('keeps the rows the user filled in', (tester) async {
        await pumpEditor(tester);

        await tester.enterText(fieldNamed('Name'), 'Martini');
        await tapVisible(tester, find.text('Add ingredient'));
        await tester.enterText(fieldNamed('Ingredient'), 'Gin');
        await tester.enterText(fieldNamed('Quantity'), '2');
        await tester.enterText(fieldNamed('Unit'), 'oz');
        await tapVisible(tester, find.text('Add step'));
        await tester.enterText(fieldNamed('Step 1'), 'Stir.');
        await tapSave(tester);

        final recipe = savedRecipe();
        expect(recipe.ingredients, [
          Ingredient(name: 'Gin', quantity: '2', unit: 'oz'),
        ]);
        expect(recipe.steps, ['Stir.']);
      });

      testWidgets(
        'disposes the controllers of a removed row',
        (tester) async {
          await pumpEditor(tester);

          await tapVisible(tester, find.text('Add ingredient'));
          await tapVisible(tester, find.text('Add step'));
          await tapVisible(tester, find.bySemanticsLabel('Remove ingredient'));
          await tapVisible(tester, find.bySemanticsLabel('Remove step'));

          expect(find.byType(IngredientRowField), findsNothing);
          expect(find.byType(StepRowField), findsNothing);
        },
        experimentalLeakTesting: LeakTesting.settings.withTrackedAll(),
      );
    });

    group('tags', () {
      testWidgets('adds a typed tag to the selection', (tester) async {
        await pumpEditor(tester);

        await tester.enterText(fieldNamed('Name'), 'Martini');
        await tester.enterText(fieldNamed('New tag'), '  Stirred  ');
        await tapVisible(tester, find.text('Add tag'));
        await tapSave(tester);

        expect(savedRecipe().tags, ['Stirred']);
      });

      testWidgets('folds a re-typed tag into the one already selected', (
        tester,
      ) async {
        await pumpEditor(tester, recipe: negroni);

        await tester.enterText(fieldNamed('New tag'), 'BITTER');
        await tapVisible(tester, find.text('Add tag'));
        await tapSave(tester);

        expect(savedRecipe().tags, ['Bitter']);
      });

      testWidgets('adds the typed tag when the field is submitted', (
        tester,
      ) async {
        await pumpEditor(tester);

        await tester.enterText(fieldNamed('Name'), 'Martini');
        await tester.enterText(fieldNamed('New tag'), 'Stirred');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await tapSave(tester);

        expect(savedRecipe().tags, ['Stirred']);
      });

      testWidgets('ignores a blank tag', (tester) async {
        await pumpEditor(tester);

        await tester.enterText(fieldNamed('Name'), 'Martini');
        await tester.enterText(fieldNamed('New tag'), '   ');
        await tapVisible(tester, find.text('Add tag'));
        await tapSave(tester);

        expect(savedRecipe().tags, isEmpty);
      });
    });

    group('validation feedback', () {
      final tallLibrary = Library(
        id: cocktailsLibrary.id,
        name: 'Cocktails',
        fields: [
          for (var i = 1; i <= 10; i++)
            FieldDefinition(
              id: 'field-$i',
              label: 'Field $i',
              type: FieldType.text,
              required: i == 10,
            ),
        ],
      );

      testWidgets('scrolls the first invalid field into view', (tester) async {
        await pumpEditor(
          tester,
          library: tallLibrary,
          recipe: Recipe(
            id: 'recipe-negroni',
            libraryId: cocktailsLibrary.id,
            name: 'Negroni',
          ),
        );

        // The default 800x600 test view: the tenth field starts well below it.
        expect(tester.getTopLeft(find.text('Field 10')).dy, greaterThan(600.0));

        await tapSave(tester);

        expect(tester.getTopLeft(find.text('Field 10')).dy, lessThan(600.0));
        expect(find.text('This field is required.'), findsOneWidget);
      });
    });

    group('save outcome', () {
      testWidgets('pops once the save succeeds', (tester) async {
        await pushEditor(tester);

        await tester.enterText(fieldNamed('Name'), 'Martini');
        await tapSave(tester);

        // The bloc reports the save in flight before it reports the outcome.
        states.add(
          const RecipesState(
            mutation: RecipesMutation.recipeSaved,
            mutationStatus: RecipesMutationStatus.loading,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(RecipeEditorPage), findsOneWidget);

        states.add(
          const RecipesState(
            mutation: RecipesMutation.recipeSaved,
            mutationStatus: RecipesMutationStatus.success,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RecipeEditorPage), findsNothing);
      });

      testWidgets('keeps the user on the editor and reports a failed save', (
        tester,
      ) async {
        await pushEditor(tester);

        await tester.enterText(fieldNamed('Name'), 'Martini');
        await tapSave(tester);

        states.add(
          const RecipesState(
            mutation: RecipesMutation.recipeSaved,
            mutationStatus: RecipesMutationStatus.failure,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RecipeEditorPage), findsOneWidget);
        expect(find.text('Your recipe could not be saved.'), findsOneWidget);
      });

      testWidgets('ignores the outcome of another kind of mutation', (
        tester,
      ) async {
        await pushEditor(tester);

        // One bloc backs all three screens, so a delete or a library switch
        // reaching the editor must not pop it.
        states.add(
          const RecipesState(
            mutation: RecipesMutation.recipeDeleted,
            mutationStatus: RecipesMutationStatus.success,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RecipeEditorPage), findsOneWidget);
      });
    });

    group('leaving the editor', () {
      Future<void> tapBack(WidgetTester tester) async {
        await tester.tap(find.byType(FHeaderAction).first);
        await tester.pumpAndSettle();
      }

      testWidgets('leaves an untouched recipe without prompting', (
        tester,
      ) async {
        await pushEditor(tester, recipe: negroni);

        await tapBack(tester);

        expect(find.text('Discard changes?'), findsNothing);
        expect(find.byType(RecipeEditorPage), findsNothing);
      });

      testWidgets('prompts before discarding an edited recipe', (tester) async {
        await pushEditor(tester, recipe: negroni);

        await tester.enterText(fieldNamed('Name'), 'Negroni Sbag');
        await tapBack(tester);

        expect(find.text('Discard changes?'), findsOneWidget);
        expect(
          find.text('Your changes to this recipe have not been saved.'),
          findsOneWidget,
        );
      });

      testWidgets('prompts with add-mode wording for a new recipe', (
        tester,
      ) async {
        await pushEditor(tester);

        await tester.enterText(fieldNamed('Name'), 'Martini');
        await tapBack(tester);

        expect(
          find.text('This recipe has not been saved yet.'),
          findsOneWidget,
        );
      });

      testWidgets('stays on the editor when the prompt is dismissed', (
        tester,
      ) async {
        await pushEditor(tester);

        await tester.enterText(fieldNamed('Name'), 'Martini');
        await tapBack(tester);
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();

        expect(find.byType(RecipeEditorPage), findsOneWidget);
      });

      testWidgets('leaves when the prompt is confirmed', (tester) async {
        await pushEditor(tester);

        await tester.enterText(fieldNamed('Name'), 'Martini');
        await tapBack(tester);
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();

        expect(find.byType(RecipeEditorPage), findsNothing);
      });
    });

    testWidgets('route re-provides the bloc to the pushed page', (
      tester,
    ) async {
      await pushEditor(tester);

      final context = tester.element(find.byType(RecipeEditorPage));
      expect(context.read<RecipesBloc>(), same(recipesBloc));
    });
  });
}
