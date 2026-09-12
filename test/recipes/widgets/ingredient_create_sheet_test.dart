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
  group('IngredientCreateSheet', () {
    late RecipesBloc recipesBloc;
    late StreamController<RecipesState> states;

    final initialState = RecipesState(
      status: RecipesStatus.success,
      libraries: [cocktailsLibrary, coffeeLibrary],
      ingredients: [ginIngredient, cinnamonIngredient],
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

    /// Opens the sheet on [name] and returns a function reading what it
    /// resolved to once it has closed.
    Future<CatalogIngredient? Function()> openSheet(
      WidgetTester tester, {
      String name = 'Bourbon',
    }) async {
      CatalogIngredient? result;
      await tester.pumpApp(
        Builder(
          builder: (context) => FButton(
            onPress: () async =>
                result = await IngredientCreateSheet.show(context, name: name),
            child: const Text('Open'),
          ),
        ),
        recipesBloc: recipesBloc,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      return () => result;
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
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    CatalogIngredient savedEntry() {
      final events = verify(() => recipesBloc.add(captureAny())).captured;
      return events.whereType<RecipesIngredientSaved>().single.ingredient;
    }

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

    testWidgets('prefills the name with what was typed into the row', (
      tester,
    ) async {
      await openSheet(tester);

      expect(find.text('New ingredient'), findsOneWidget);
      expect(find.text('Bourbon'), findsOneWidget);
    });

    testWidgets('blocks a blank name with an inline error', (tester) async {
      await openSheet(tester, name: '');

      await tap(tester, 'Save ingredient');

      expect(find.text('Enter a name.'), findsOneWidget);
      verifyNever(
        () => recipesBloc.add(any(that: isA<RecipesIngredientSaved>())),
      );
    });

    testWidgets('saves an entry scoped to the library being browsed', (
      tester,
    ) async {
      await openSheet(tester);

      await tap(tester, 'Save ingredient');

      final entry = savedEntry();
      expect(entry.name, 'Bourbon');
      expect(entry.defaultUnit, isNull);
      expect(entry.libraryIds, {cocktailsLibrary.id});
    });

    testWidgets('saves the standard unit picked from the list', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.tap(standardUnitSelect);
      await tester.pumpAndSettle();
      await tap(tester, 'oz');
      await tap(tester, 'Save ingredient');

      expect(savedEntry().defaultUnit, const KnownUnit(StandardUnit.oz));
    });

    testWidgets('saves a custom unit typed in place of the list', (
      tester,
    ) async {
      await openSheet(tester);

      await tap(tester, 'Custom…');
      expect(standardUnitSelect, findsNothing);
      await tester.enterText(fieldNamed('Custom unit'), ' pour ');
      await tap(tester, 'Save ingredient');

      expect(savedEntry().defaultUnit, CustomUnit('pour'));
    });

    testWidgets('saves no unit for a blank custom unit', (tester) async {
      await openSheet(tester);

      await tap(tester, 'Custom…');
      await tap(tester, 'Save ingredient');

      expect(savedEntry().defaultUnit, isNull);
    });

    testWidgets('swaps the custom unit back for the list', (tester) async {
      await openSheet(tester);

      await tap(tester, 'Custom…');
      await tap(tester, 'Standard units');

      expect(standardUnitSelect, findsOneWidget);
      expect(find.text('Custom unit'), findsNothing);
    });

    group('save outcome', () {
      testWidgets('returns the saved entry once the save succeeds', (
        tester,
      ) async {
        final result = await openSheet(tester);

        await tap(tester, 'Save ingredient');
        await emit(tester, RecipesMutationStatus.loading);
        expect(find.byType(IngredientCreateSheet), findsOneWidget);
        await emit(tester, RecipesMutationStatus.success);

        expect(find.byType(IngredientCreateSheet), findsNothing);
        expect(result(), savedEntry());
      });

      testWidgets('disables saving while the save is in flight', (
        tester,
      ) async {
        await openSheet(tester);

        await tap(tester, 'Save ingredient');
        await emit(tester, RecipesMutationStatus.loading);

        final save = tester.widget<FButton>(
          find.ancestor(
            of: find.text('Save ingredient'),
            matching: find.byType(FButton),
          ),
        );
        expect(save.onPress, isNull);
      });

      testWidgets('ignores a success it did not start', (tester) async {
        await openSheet(tester);

        await emit(tester, RecipesMutationStatus.success);

        expect(find.byType(IngredientCreateSheet), findsOneWidget);
      });

      testWidgets('stays open with a banner and the typed values on failure', (
        tester,
      ) async {
        await openSheet(tester);

        await tap(tester, 'Custom…');
        await tester.enterText(fieldNamed('Custom unit'), 'pour');
        await tap(tester, 'Save ingredient');
        await emit(tester, RecipesMutationStatus.failure);

        expect(find.byType(IngredientCreateSheet), findsOneWidget);
        expect(
          find.text('Your ingredient could not be saved.'),
          findsOneWidget,
        );
        expect(find.text('Bourbon'), findsOneWidget);
        expect(find.text('pour'), findsOneWidget);
      });
    });

    group('a name the catalog already holds', () {
      testWidgets('shows the existing entry and its unit before saving', (
        tester,
      ) async {
        await openSheet(tester, name: 'gin');

        expect(
          find.text('Gin is already in your catalog, so it will be reused.'),
          findsOneWidget,
        );
        expect(find.text('ml'), findsOneWidget);
        final select = tester.widget<FSelect<StandardUnit>>(
          standardUnitSelect,
        );
        expect(select.enabled, isFalse);
      });

      testWidgets('switches the unit as the name is typed onto an entry', (
        tester,
      ) async {
        await openSheet(tester, name: 'Cinnamon stick');
        expect(find.text('pinch'), findsNothing);

        await tester.enterText(fieldNamed('Name'), 'cinnamon');
        await tester.pumpAndSettle();

        expect(find.text('pinch'), findsOneWidget);
        expect(find.text('Custom unit'), findsOneWidget);
      });

      testWidgets('reuses an entry in this library without saving', (
        tester,
      ) async {
        final result = await openSheet(tester, name: 'GIN');

        await tap(tester, 'Save ingredient');

        expect(result(), ginIngredient);
        verifyNever(() => recipesBloc.add(any()));
      });

      testWidgets('reuses an entry from another library and widens it', (
        tester,
      ) async {
        final result = await openSheet(tester, name: 'cinnamon');

        await tap(tester, 'Save ingredient');

        expect(result(), cinnamonIngredient);
        verify(
          () => recipesBloc.add(
            RecipesIngredientScopeWidened(
              cinnamonIngredient.id,
              cocktailsLibrary.id,
            ),
          ),
        ).called(1);
        verifyNever(
          () => recipesBloc.add(any(that: isA<RecipesIngredientSaved>())),
        );
      });
    });

    testWidgets('returns nothing when cancelled', (tester) async {
      final result = await openSheet(tester);

      await tap(tester, 'Cancel');

      expect(find.byType(IngredientCreateSheet), findsNothing);
      expect(result(), isNull);
    });

    testWidgets(
      'disposes its controllers when it closes',
      (tester) async {
        await openSheet(tester);

        await tap(tester, 'Custom…');
        await tap(tester, 'Cancel');

        expect(find.byType(IngredientCreateSheet), findsNothing);
      },
      experimentalLeakTesting: LeakTesting.settings.withTrackedAll(),
    );

    testWidgets('re-provides the bloc to the sheet', (tester) async {
      await openSheet(tester);

      final context = tester.element(find.byType(IngredientCreateSheet));
      expect(context.read<RecipesBloc>(), same(recipesBloc));
    });
  });
}
