import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:membar/ingredients/ingredients.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

class _MockRecipesBloc extends MockBloc<RecipesEvent, RecipesState>
    implements RecipesBloc {}

void main() {
  group('IngredientEditorSheet', () {
    late RecipesBloc recipesBloc;
    late StreamController<RecipesState> states;

    final initialState = RecipesState(
      status: RecipesStatus.success,
      libraries: [coffeeLibrary, cocktailsLibrary],
      ingredients: [ginIngredient, sugarIngredient, cinnamonIngredient],
      activeLibraryId: cocktailsLibrary.id,
    );

    setUpAll(
      () => registerFallbackValue(const RecipesSubscriptionRequested()),
    );

    setUp(() {
      recipesBloc = _MockRecipesBloc();
      states = StreamController<RecipesState>.broadcast();
      addTearDown(states.close);
      whenListen(recipesBloc, states.stream, initialState: initialState);
    });

    Future<void> openSheet(
      WidgetTester tester, {
      CatalogIngredient? entry,
    }) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => FButton(
            onPress: () => IngredientEditorSheet.show(
              context,
              entry: entry ?? ginIngredient,
            ),
            child: const Text('Open'),
          ),
        ),
        recipesBloc: recipesBloc,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    Finder fieldNamed(String label) => find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byType(FTextFormField),
      ),
      matching: find.byType(EditableText),
    );

    final standardUnitSelect = find.byWidgetPredicate(
      (widget) => widget is FSelect<StandardUnit>,
    );

    Future<void> tap(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    CatalogIngredient savedEntry() {
      final events = verify(() => recipesBloc.add(captureAny())).captured;
      return events.whereType<RecipesIngredientSaved>().single.ingredient;
    }

    void expectNothingSaved() => verifyNever(
      () => recipesBloc.add(any(that: isA<RecipesIngredientSaved>())),
    );

    Future<void> emit(
      WidgetTester tester,
      RecipesMutationStatus status,
    ) async {
      states.add(
        initialState.copyWith(
          mutation: RecipesMutation.ingredientSaved,
          mutationStatus: status,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('starts from the entry as it is', (tester) async {
      await openSheet(tester);

      expect(find.text('Edit ingredient'), findsOneWidget);
      expect(find.text('Gin'), findsOneWidget);
      expect(find.text('ml'), findsOneWidget);
      final checkboxes = tester.widgetList<FCheckbox>(find.byType(FCheckbox));
      expect(
        [for (final box in checkboxes) ((box.label! as Text).data, box.value)],
        [('Cocktails', true), ('Coffee', false)],
      );
    });

    testWidgets('starts a custom unit in the custom field', (tester) async {
      await openSheet(tester, entry: cinnamonIngredient);

      expect(standardUnitSelect, findsNothing);
      expect(find.text('pinch'), findsOneWidget);
    });

    testWidgets('saves a rename under the same id', (tester) async {
      await openSheet(tester);

      await tester.enterText(fieldNamed('Name'), 'London Dry Gin');
      await tap(tester, 'Save changes');

      expect(
        savedEntry(),
        CatalogIngredient(
          id: ginIngredient.id,
          name: 'London Dry Gin',
          defaultUnit: ginIngredient.defaultUnit,
          libraryIds: ginIngredient.libraryIds,
        ),
      );
    });

    testWidgets('accepts a rename that only changes case', (tester) async {
      await openSheet(tester);

      await tester.enterText(fieldNamed('Name'), 'GIN');
      await tap(tester, 'Save changes');

      expect(savedEntry().name, 'GIN');
    });

    testWidgets('refuses a rename onto another entry, ignoring case', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.enterText(fieldNamed('Name'), ' SUGAR ');
      await tap(tester, 'Save changes');

      expect(
        find.text('Another ingredient is already called sugar.'),
        findsOneWidget,
      );
      expectNothingSaved();
    });

    testWidgets('refuses a blank name', (tester) async {
      await openSheet(tester);

      await tester.enterText(fieldNamed('Name'), ' ');
      await tap(tester, 'Save changes');

      expect(find.text('Enter a name.'), findsOneWidget);
      expectNothingSaved();
    });

    testWidgets('saves a standard unit picked from the list', (tester) async {
      await openSheet(tester);

      await tester.tap(standardUnitSelect);
      await tester.pumpAndSettle();
      await tap(tester, 'oz');
      await tap(tester, 'Save changes');

      expect(savedEntry().defaultUnit, const KnownUnit(StandardUnit.oz));
    });

    testWidgets('saves a custom unit typed in place of the list', (
      tester,
    ) async {
      await openSheet(tester);

      await tap(tester, 'Custom…');
      await tester.enterText(fieldNamed('Custom unit'), ' pour ');
      await tap(tester, 'Save changes');

      expect(savedEntry().defaultUnit, CustomUnit('pour'));
    });

    testWidgets('saves no unit for a blank custom unit', (tester) async {
      await openSheet(tester);

      await tap(tester, 'Custom…');
      await tap(tester, 'Save changes');

      expect(savedEntry().defaultUnit, isNull);
    });

    testWidgets('saves no unit when a custom entry swaps to an empty list', (
      tester,
    ) async {
      await openSheet(tester, entry: cinnamonIngredient);

      await tap(tester, 'Standard units');
      expect(standardUnitSelect, findsOneWidget);
      await tap(tester, 'Save changes');

      expect(savedEntry().defaultUnit, isNull);
    });

    testWidgets('saves an edited library set', (tester) async {
      await openSheet(tester);

      await tap(tester, 'Coffee');
      await tap(tester, 'Save changes');

      expect(savedEntry().libraryIds, {
        cocktailsLibrary.id,
        coffeeLibrary.id,
      });
    });

    testWidgets('refuses an empty library set', (tester) async {
      await openSheet(tester);

      await tap(tester, 'Cocktails');
      expect(find.text('Choose at least one library.'), findsOneWidget);
      await tap(tester, 'Save changes');

      expectNothingSaved();
      expect(find.byType(IngredientEditorSheet), findsOneWidget);
    });

    group('save outcome', () {
      testWidgets('closes once the save succeeds', (tester) async {
        await openSheet(tester);

        await tap(tester, 'Save changes');
        await emit(tester, RecipesMutationStatus.loading);
        expect(find.byType(IngredientEditorSheet), findsOneWidget);
        await emit(tester, RecipesMutationStatus.success);

        expect(find.byType(IngredientEditorSheet), findsNothing);
      });

      testWidgets('disables saving while the save is in flight', (
        tester,
      ) async {
        await openSheet(tester);

        await tap(tester, 'Save changes');
        await emit(tester, RecipesMutationStatus.loading);

        final save = tester.widget<FButton>(
          find.ancestor(
            of: find.text('Save changes'),
            matching: find.byType(FButton),
          ),
        );
        expect(save.onPress, isNull);
      });

      testWidgets('ignores a success it did not start', (tester) async {
        await openSheet(tester);

        await emit(tester, RecipesMutationStatus.success);

        expect(find.byType(IngredientEditorSheet), findsOneWidget);
      });

      testWidgets('stays open with a banner and the typed values on failure', (
        tester,
      ) async {
        await openSheet(tester);

        await tester.enterText(fieldNamed('Name'), 'Old Tom');
        await tap(tester, 'Save changes');
        await emit(tester, RecipesMutationStatus.failure);

        expect(find.byType(IngredientEditorSheet), findsOneWidget);
        expect(find.text('Your changes could not be saved.'), findsOneWidget);
        expect(find.text('Old Tom'), findsOneWidget);
      });
    });

    testWidgets('closes without saving when cancelled', (tester) async {
      await openSheet(tester);

      await tap(tester, 'Cancel');

      expect(find.byType(IngredientEditorSheet), findsNothing);
      expectNothingSaved();
    });

    testWidgets(
      'disposes its controllers when it closes',
      (tester) async {
        await openSheet(tester, entry: cinnamonIngredient);

        await tap(tester, 'Cancel');

        expect(find.byType(IngredientEditorSheet), findsNothing);
      },
      experimentalLeakTesting: LeakTesting.settings.withTrackedAll(),
    );

    testWidgets('re-provides the bloc to the sheet', (tester) async {
      await openSheet(tester);

      final context = tester.element(find.byType(IngredientEditorSheet));
      expect(context.read<RecipesBloc>(), same(recipesBloc));
    });
  });
}
