import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:membar/starter_catalog/starter_catalog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';
import 'package:starter_recipes_repository/starter_recipes_repository.dart';

import '../../helpers/helpers.dart';

class _MockRecipesBloc extends MockBloc<RecipesEvent, RecipesState>
    implements RecipesBloc {}

class _MockStarterRecipesRepository extends Mock
    implements StarterRecipesRepository {}

void main() {
  group('StarterCatalogPage', () {
    late RecipesBloc recipesBloc;
    late StarterRecipesRepository repository;
    late StreamController<RecipesState> states;

    const cocktailSet = StarterSet(
      ingredients: [
        StarterIngredient(
          key: 'gin',
          name: 'Gin',
          defaultUnit: StandardUnit.ml,
        ),
        StarterIngredient(
          key: 'campari',
          name: 'Campari',
          defaultUnit: StandardUnit.ml,
        ),
        StarterIngredient(
          key: 'vermouth',
          name: 'Sweet vermouth',
          defaultUnit: StandardUnit.ml,
        ),
        StarterIngredient(
          key: 'orange',
          name: 'Orange peel',
          defaultUnit: StandardUnit.piece,
        ),
        StarterIngredient(
          key: 'rum',
          name: 'White rum',
          defaultUnit: StandardUnit.ml,
        ),
      ],
      recipes: [
        StarterRecipe(
          key: 'negroni',
          name: 'Negroni',
          rows: [
            StarterRow(ingredient: 'gin', ml: '30', oz: '1'),
            StarterRow(ingredient: 'campari', ml: '30', oz: '1'),
            StarterRow(ingredient: 'vermouth', ml: '30', oz: '1'),
            StarterRow(
              ingredient: 'orange',
              quantity: '1',
              unit: StandardUnit.piece,
            ),
          ],
        ),
        StarterRecipe(
          key: 'daiquiri',
          name: 'Daiquiri',
          rows: [StarterRow(ingredient: 'rum', ml: '60', oz: '2')],
        ),
      ],
    );
    const coffeeSet = StarterSet(
      ingredients: [],
      recipes: [
        StarterRecipe(
          key: 'latte',
          name: 'Latte',
          fields: {'Brew method': 'Espresso'},
        ),
      ],
    );
    final storedNegroni = Recipe(
      id: 'recipe-negroni',
      libraryId: cocktailsLibrary.id,
      name: 'negroni',
    );
    final baseState = RecipesState(
      status: RecipesStatus.success,
      libraries: [cocktailsLibrary, coffeeLibrary],
      activeLibraryId: cocktailsLibrary.id,
    );

    setUpAll(
      () => registerFallbackValue(const RecipesSubscriptionRequested()),
    );

    setUp(() {
      recipesBloc = _MockRecipesBloc();
      repository = _MockStarterRecipesRepository();
      states = StreamController<RecipesState>.broadcast();
      addTearDown(states.close);
      when(
        () => repository.load(LibraryTemplate.cocktails),
      ).thenAnswer((_) async => cocktailSet);
      when(
        () => repository.load(LibraryTemplate.coffee),
      ).thenAnswer((_) async => coffeeSet);
    });

    void mockState(RecipesState state) =>
        whenListen(recipesBloc, states.stream, initialState: state);

    Future<void> openCatalog(
      WidgetTester tester, {
      Library? library,
      bool settle = true,
    }) async {
      final target = library ?? cocktailsLibrary;
      await tester.pumpApp(
        Builder(
          builder: (context) => FButton(
            onPress: () => Navigator.of(context).push(
              StarterCatalogPage.route(
                bloc: recipesBloc,
                library: target,
                template: target.template!,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
        recipesBloc: recipesBloc,
        starterRecipesRepository: repository,
      );
      await tester.tap(find.text('Open'));
      if (settle) await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label).last);
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    FButton buttonLabelled(WidgetTester tester, String label) =>
        tester.widget<FButton>(
          find.ancestor(of: find.text(label), matching: find.byType(FButton)),
        );

    final measureSelect = find.byWidgetPredicate(
      (widget) => widget is FSelect<MeasureSystem>,
    );

    final searchField = find.descendant(
      of: find.ancestor(
        of: find.text('Search starter recipes'),
        matching: find.byType(FTextField),
      ),
      matching: find.byType(EditableText),
    );

    RecipesStarterRecipesImported dispatched() =>
        verify(() => recipesBloc.add(captureAny())).captured.single
            as RecipesStarterRecipesImported;

    testWidgets('pushes a route named starter-catalog', (tester) async {
      mockState(baseState);
      await openCatalog(tester);

      final route = ModalRoute.of(
        tester.element(find.byType(StarterCatalogPage)),
      );
      expect(route?.settings.name, 'starter-catalog');
      expect(find.text('Starter recipes'), findsOneWidget);
    });

    testWidgets('renders a progress indicator while the set loads', (
      tester,
    ) async {
      final pending = Completer<StarterSet>();
      when(
        () => repository.load(LibraryTemplate.cocktails),
      ).thenAnswer((_) => pending.future);
      mockState(baseState);
      await openCatalog(tester, settle: false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FProgress), findsOneWidget);
    });

    testWidgets('renders a failure message when the set fails to load', (
      tester,
    ) async {
      when(
        () => repository.load(LibraryTemplate.cocktails),
      ).thenAnswer((_) => Future.error(const FormatException('bad bundle')));
      mockState(baseState);
      await openCatalog(tester);

      expect(
        find.text('The starter recipes could not be loaded.'),
        findsOneWidget,
      );
      expect(find.text('Import'), findsNothing);
    });

    testWidgets(
      'renders each cocktail with its first three ingredients and the '
      'measures selector',
      (tester) async {
        mockState(baseState);
        await openCatalog(tester);

        expect(find.text('Negroni'), findsOneWidget);
        expect(find.text('Gin, Campari, Sweet vermouth'), findsOneWidget);
        expect(find.text('White rum'), findsOneWidget);
        expect(measureSelect, findsOneWidget);
      },
    );

    testWidgets('renders each coffee with its brew method and no measures', (
      tester,
    ) async {
      mockState(baseState.copyWith(activeLibraryId: coffeeLibrary.id));
      await openCatalog(tester, library: coffeeLibrary);

      expect(find.text('Latte'), findsOneWidget);
      expect(find.text('Espresso'), findsOneWidget);
      expect(measureSelect, findsNothing);
    });

    testWidgets('reads each row as one label', (tester) async {
      mockState(baseState.copyWith(recipes: [storedNegroni]));
      await openCatalog(tester);

      expect(
        tester.getSemantics(find.text('Negroni')).label,
        'Negroni, Gin, Campari, Sweet vermouth, In library',
      );
      expect(
        tester.getSemantics(find.text('Daiquiri')).label,
        'Daiquiri, White rum',
      );
    });

    testWidgets('badges only the recipes the library already holds', (
      tester,
    ) async {
      mockState(baseState.copyWith(recipes: [storedNegroni]));
      await openCatalog(tester);

      expect(find.text('In library'), findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Negroni'),
            matching: find.byType(FTile),
          ),
          matching: find.text('In library'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('reports a search that matches nothing', (tester) async {
      mockState(baseState);
      await openCatalog(tester);

      await tester.enterText(searchField, 'martini');
      await tester.pumpAndSettle();

      expect(
        find.text('No starter recipes match your search.'),
        findsOneWidget,
      );
      expect(find.text('Select all'), findsNothing);
    });

    testWidgets('counts selections the search hides', (tester) async {
      mockState(baseState);
      await openCatalog(tester);
      expect(buttonLabelled(tester, 'Import').onPress, isNull);

      await tap(tester, 'Negroni');
      await tester.enterText(searchField, 'daiq');
      await tester.pumpAndSettle();
      expect(find.text('Negroni'), findsNothing);
      expect(find.text('Import 1'), findsOneWidget);

      await tap(tester, 'Daiquiri');
      expect(find.text('Import 2'), findsOneWidget);

      await tap(tester, 'Import 2');

      expect(dispatched().names, const {
        'negroni': 'Negroni',
        'daiquiri': 'Daiquiri',
      });
    });

    testWidgets('toggles a recipe on and off from its checkbox', (
      tester,
    ) async {
      mockState(baseState);
      await openCatalog(tester);
      final checkbox = find.descendant(
        of: find.ancestor(
          of: find.text('Negroni'),
          matching: find.byType(FTile),
        ),
        matching: find.byType(FCheckbox),
      );

      await tester.tapAt(tester.getCenter(checkbox));
      await tester.pumpAndSettle();
      expect(find.text('Import 1'), findsOneWidget);

      await tester.tapAt(tester.getCenter(checkbox));
      await tester.pumpAndSettle();
      expect(find.text('Import'), findsOneWidget);
    });

    testWidgets('selects every visible row, then deselects them', (
      tester,
    ) async {
      mockState(baseState);
      await openCatalog(tester);

      await tap(tester, 'Select all');
      expect(find.text('Import 2'), findsOneWidget);
      expect(find.text('Deselect all'), findsOneWidget);

      await tap(tester, 'Deselect all');
      expect(find.text('Import'), findsOneWidget);
    });

    testWidgets(
      'imports picks without clashes under their own names, in the chosen '
      'system',
      (tester) async {
        mockState(baseState);
        await openCatalog(tester);

        await tap(tester, 'Daiquiri');
        await tester.tap(measureSelect);
        await tester.pumpAndSettle();
        await tap(tester, 'oz');
        await tap(tester, 'Import 1');

        expect(find.byType(StarterRenameSheet), findsNothing);
        expect(
          dispatched(),
          RecipesStarterRecipesImported(
            libraryId: cocktailsLibrary.id,
            set: cocktailSet,
            names: const {'daiquiri': 'Daiquiri'},
            system: MeasureSystem.imperial,
          ),
        );
      },
    );

    testWidgets('imports a clash under the name the rename sheet gives it', (
      tester,
    ) async {
      mockState(baseState.copyWith(recipes: [storedNegroni]));
      await openCatalog(tester);

      await tap(tester, 'Select all');
      await tap(tester, 'Import 2');
      expect(find.byType(StarterRenameSheet), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byType(StarterRenameSheet),
          matching: find.byType(EditableText),
        ),
        'Negroni (mine)',
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Import');

      expect(
        dispatched(),
        RecipesStarterRecipesImported(
          libraryId: cocktailsLibrary.id,
          set: cocktailSet,
          names: const {
            'negroni': 'Negroni (mine)',
            'daiquiri': 'Daiquiri',
          },
          system: MeasureSystem.metric,
        ),
      );
    });

    testWidgets('leaves a skipped clash out of the import', (tester) async {
      mockState(baseState.copyWith(recipes: [storedNegroni]));
      await openCatalog(tester);

      await tap(tester, 'Select all');
      await tap(tester, 'Import 2');
      await tap(tester, 'Skip');
      await tap(tester, 'Import');

      expect(dispatched().names, const {'daiquiri': 'Daiquiri'});
    });

    testWidgets('dispatches nothing when the rename sheet is cancelled', (
      tester,
    ) async {
      mockState(baseState.copyWith(recipes: [storedNegroni]));
      await openCatalog(tester);

      await tap(tester, 'Negroni');
      await tap(tester, 'Import 1');
      await tap(tester, 'Cancel');

      expect(find.byType(StarterRenameSheet), findsNothing);
      verifyNever(() => recipesBloc.add(any()));
    });

    testWidgets('pops once the import goes through', (tester) async {
      mockState(baseState);
      await openCatalog(tester);

      await tap(tester, 'Daiquiri');
      await tap(tester, 'Import 1');
      states.add(
        baseState.copyWith(
          mutation: RecipesMutation.starterRecipesImported,
          mutationStatus: RecipesMutationStatus.success,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StarterCatalogPage), findsNothing);
    });

    testWidgets('reports a failed import and keeps the selection', (
      tester,
    ) async {
      mockState(baseState);
      await openCatalog(tester);

      await tap(tester, 'Daiquiri');
      await tap(tester, 'Import 1');
      states.add(
        baseState.copyWith(
          mutation: RecipesMutation.starterRecipesImported,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StarterCatalogPage), findsOneWidget);
      expect(
        find.text('The starter recipes could not be imported.'),
        findsOneWidget,
      );
      expect(find.text('Import 1'), findsOneWidget);
    });

    testWidgets('clears the failure banner when the import is retried', (
      tester,
    ) async {
      mockState(baseState);
      await openCatalog(tester);
      await tap(tester, 'Daiquiri');
      await tap(tester, 'Import 1');
      states.add(
        baseState.copyWith(
          mutation: RecipesMutation.starterRecipesImported,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
      await tester.pumpAndSettle();

      await tap(tester, 'Import 1');

      expect(
        find.text('The starter recipes could not be imported.'),
        findsNothing,
      );
      verify(() => recipesBloc.add(any())).called(2);
    });

    testWidgets('reopens the rename sheet with original names after a '
        'failed import', (tester) async {
      final failed = baseState.copyWith(recipes: [storedNegroni]);
      mockState(failed);
      await openCatalog(tester);
      await tap(tester, 'Negroni');
      await tap(tester, 'Import 1');
      await tester.enterText(
        find.descendant(
          of: find.byType(StarterRenameSheet),
          matching: find.byType(EditableText),
        ),
        'Negroni (mine)',
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Import');
      states.add(
        failed.copyWith(
          mutation: RecipesMutation.starterRecipesImported,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
      await tester.pumpAndSettle();

      await tap(tester, 'Import 1');

      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(StarterRenameSheet),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.text, 'Negroni');
    });

    testWidgets('disables Import while an import is in flight', (
      tester,
    ) async {
      mockState(baseState);
      await openCatalog(tester);

      await tap(tester, 'Daiquiri');
      states.add(
        baseState.copyWith(
          mutation: RecipesMutation.starterRecipesImported,
          mutationStatus: RecipesMutationStatus.loading,
        ),
      );
      await tester.pumpAndSettle();

      expect(buttonLabelled(tester, 'Import 1').onPress, isNull);
    });

    testWidgets('pops from the back action', (tester) async {
      mockState(baseState);
      await openCatalog(tester);

      await tester.tap(find.byType(FHeaderAction));
      await tester.pumpAndSettle();

      expect(find.byType(StarterCatalogPage), findsNothing);
    });
  });
}
