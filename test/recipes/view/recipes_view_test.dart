import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/ingredients/ingredients.dart';
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
  group('RecipesView', () {
    late RecipesBloc recipesBloc;

    final negroni = Recipe(
      id: 'recipe-negroni',
      libraryId: cocktailsLibrary.id,
      name: 'Negroni',
      tags: const ['Bitter', 'Stirred'],
    );
    final daiquiri = Recipe(
      id: 'recipe-daiquiri',
      libraryId: cocktailsLibrary.id,
      name: 'Daiquiri',
    );

    setUp(() {
      recipesBloc = _MockRecipesBloc();
    });

    void mockState(RecipesState state) {
      whenListen(
        recipesBloc,
        const Stream<RecipesState>.empty(),
        initialState: state,
      );
    }

    Future<void> pumpView(WidgetTester tester) => tester.pumpApp(
      const RecipesView(),
      recipesBloc: recipesBloc,
    );

    testWidgets('renders a progress indicator before the first snapshot', (
      tester,
    ) async {
      mockState(const RecipesState());
      await pumpView(tester);

      expect(find.byType(FProgress), findsOneWidget);
      expect(find.text('Recipes'), findsOneWidget);
    });

    testWidgets('renders a progress indicator when no library is active', (
      tester,
    ) async {
      mockState(
        RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary],
          activeLibraryId: 'library-that-does-not-exist',
        ),
      );
      await pumpView(tester);

      expect(find.byType(FProgress), findsOneWidget);
    });

    testWidgets('renders a failure message when the subscription fails', (
      tester,
    ) async {
      mockState(const RecipesState(status: RecipesStatus.failure));
      await pumpView(tester);

      expect(find.text('Your recipes could not be loaded.'), findsOneWidget);
    });

    testWidgets('renders the library switcher for the active library', (
      tester,
    ) async {
      mockState(
        RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary, coffeeLibrary],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
      await pumpView(tester);

      expect(find.byType(LibrarySwitcher), findsOneWidget);
      expect(find.text('Cocktails'), findsOneWidget);
    });

    testWidgets('renders one tile per visible recipe, alphabetically', (
      tester,
    ) async {
      mockState(
        RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary],
          recipes: [negroni, daiquiri],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
      await pumpView(tester);

      final tiles = tester.widgetList<RecipeTile>(find.byType(RecipeTile));
      expect(
        tiles.map((tile) => tile.recipe.name),
        orderedEquals(['Daiquiri', 'Negroni']),
      );
    });

    testWidgets('names the active library in the empty state', (tester) async {
      mockState(
        RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
      await pumpView(tester);

      expect(find.text('No recipes in Cocktails yet'), findsOneWidget);
      expect(find.byType(RecipeTile), findsNothing);
    });

    testWidgets('distinguishes no search results from an empty library', (
      tester,
    ) async {
      mockState(
        RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary],
          recipes: [negroni],
          activeLibraryId: cocktailsLibrary.id,
          searchTerm: 'martini',
        ),
      );
      await pumpView(tester);

      expect(find.text('No matching recipes'), findsOneWidget);
      expect(find.text('No recipes in Cocktails yet'), findsNothing);
    });

    testWidgets('hides the tag filter when the library has no tags', (
      tester,
    ) async {
      mockState(
        RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary],
          recipes: [daiquiri],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
      await pumpView(tester);

      expect(find.text('Filter by tag'), findsNothing);
    });

    testWidgets("offers the active library's tags and toggles one", (
      tester,
    ) async {
      mockState(
        RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary],
          recipes: [negroni],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
      await pumpView(tester);

      expect(find.text('Filter by tag'), findsOneWidget);
      expect(find.text('Bitter'), findsOneWidget);

      await tester.tap(find.text('Stirred'));
      await tester.pumpAndSettle();

      verify(
        () => recipesBloc.add(const RecipesTagFilterToggled('Stirred')),
      ).called(1);
    });

    testWidgets('dispatches the search term as it is typed', (tester) async {
      mockState(
        RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary],
          recipes: [negroni],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
      await pumpView(tester);

      await tester.enterText(find.byType(FTextField), 'neg');

      verify(
        () => recipesBloc.add(const RecipesSearchTermChanged('neg')),
      ).called(1);
    });

    testWidgets('reports a library switch that did not take effect', (
      tester,
    ) async {
      mockState(
        RecipesState(
          status: RecipesStatus.success,
          mutation: RecipesMutation.librarySelected,
          mutationStatus: RecipesMutationStatus.failure,
          libraries: [cocktailsLibrary, coffeeLibrary],
          recipes: [negroni],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
      await pumpView(tester);

      expect(find.text('That library could not be opened.'), findsOneWidget);
      expect(find.text('Cocktails'), findsOneWidget);
    });

    testWidgets('reports nothing when another mutation failed', (tester) async {
      mockState(
        RecipesState(
          status: RecipesStatus.success,
          mutation: RecipesMutation.recipeSaved,
          mutationStatus: RecipesMutationStatus.failure,
          libraries: [cocktailsLibrary],
          recipes: [negroni],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
      await pumpView(tester);

      expect(find.text('That library could not be opened.'), findsNothing);
    });

    testWidgets('opens the editor from the header action', (tester) async {
      mockState(
        RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary],
          recipes: [negroni],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
      await pumpView(tester);

      await tester.tap(find.bySemanticsLabel('Add recipe'));
      await tester.pumpAndSettle();

      expect(find.byType(RecipeEditorPage), findsOneWidget);
    });

    testWidgets('opens the ingredients screen from the header action', (
      tester,
    ) async {
      mockState(
        RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
      await pumpView(tester);

      await tester.tap(find.bySemanticsLabel('Manage ingredients'));
      await tester.pumpAndSettle();

      expect(find.byType(IngredientsPage), findsOneWidget);
    });

    testWidgets('offers an Add button on an empty library', (tester) async {
      mockState(
        RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
      await pumpView(tester);

      await tester.tap(find.widgetWithText(FButton, 'Add recipe'));
      await tester.pumpAndSettle();

      expect(find.byType(RecipeEditorPage), findsOneWidget);
    });

    testWidgets('offers no Add button when a filter emptied the list', (
      tester,
    ) async {
      mockState(
        RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary],
          recipes: [negroni],
          activeLibraryId: cocktailsLibrary.id,
          searchTerm: 'martini',
        ),
      );
      await pumpView(tester);

      expect(find.widgetWithText(FButton, 'Add recipe'), findsNothing);
    });

    testWidgets('shows a newly saved recipe without a restart', (tester) async {
      final states = StreamController<RecipesState>.broadcast();
      addTearDown(states.close);
      whenListen(
        recipesBloc,
        states.stream,
        initialState: RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
      await pumpView(tester);
      expect(find.byType(RecipeTile), findsNothing);

      states.add(
        RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary],
          recipes: [negroni],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Negroni'), findsOneWidget);
    });

    testWidgets('opens the details screen for a tapped recipe', (tester) async {
      mockState(
        RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary],
          recipes: [negroni],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
      await pumpView(tester);

      await tester.tap(find.text('Negroni'));
      await tester.pumpAndSettle();

      expect(find.byType(RecipeDetailsPage), findsOneWidget);
    });
    group('starter catalog', () {
      late StarterRecipesRepository starterRecipesRepository;

      final blankLibrary = Library(
        id: 'library-blank',
        name: 'Blank',
        ingredientLibraryId: cocktailsPantry.id,
      );

      setUp(() {
        starterRecipesRepository = _MockStarterRecipesRepository();
        when(
          () => starterRecipesRepository.load(LibraryTemplate.cocktails),
        ).thenAnswer(
          (_) async => const StarterSet(ingredients: [], recipes: []),
        );
      });

      Future<void> pumpWithCatalog(WidgetTester tester) => tester.pumpApp(
        const RecipesView(),
        recipesBloc: recipesBloc,
        starterRecipesRepository: starterRecipesRepository,
      );

      void expectCatalogPushed(WidgetTester tester) {
        final page = find.byType(StarterCatalogPage);
        expect(page, findsOneWidget);
        expect(
          ModalRoute.of(tester.element(page))?.settings.name,
          'starter-catalog',
        );
      }

      testWidgets('opens the catalog from the header action', (tester) async {
        mockState(
          RecipesState(
            status: RecipesStatus.success,
            libraries: [cocktailsLibrary],
            recipes: [negroni],
            activeLibraryId: cocktailsLibrary.id,
          ),
        );
        await pumpWithCatalog(tester);

        await tester.tap(find.bySemanticsLabel('Browse starter recipes'));
        await tester.pumpAndSettle();

        expectCatalogPushed(tester);
      });

      testWidgets('opens the catalog from the empty state', (tester) async {
        mockState(
          RecipesState(
            status: RecipesStatus.success,
            libraries: [cocktailsLibrary],
            activeLibraryId: cocktailsLibrary.id,
          ),
        );
        await pumpWithCatalog(tester);

        await tester.tap(
          find.widgetWithText(FButton, 'Browse starter recipes'),
        );
        await tester.pumpAndSettle();

        expectCatalogPushed(tester);
      });

      testWidgets('opens the Coffee catalog from a Coffee library', (
        tester,
      ) async {
        when(
          () => starterRecipesRepository.load(LibraryTemplate.coffee),
        ).thenAnswer(
          (_) async => const StarterSet(ingredients: [], recipes: []),
        );
        mockState(
          RecipesState(
            status: RecipesStatus.success,
            libraries: [coffeeLibrary],
            recipes: [
              Recipe(
                id: 'recipe-v60',
                libraryId: coffeeLibrary.id,
                name: 'V60',
              ),
            ],
            activeLibraryId: coffeeLibrary.id,
          ),
        );
        await pumpWithCatalog(tester);

        await tester.tap(find.bySemanticsLabel('Browse starter recipes'));
        await tester.pumpAndSettle();

        expectCatalogPushed(tester);
        expect(
          tester
              .widget<StarterCatalogPage>(find.byType(StarterCatalogPage))
              .template,
          LibraryTemplate.coffee,
        );
      });

      testWidgets('offers no empty-state button once the library has recipes', (
        tester,
      ) async {
        mockState(
          RecipesState(
            status: RecipesStatus.success,
            libraries: [cocktailsLibrary],
            recipes: [negroni],
            activeLibraryId: cocktailsLibrary.id,
            searchTerm: 'martini',
          ),
        );
        await pumpView(tester);

        expect(
          find.widgetWithText(FButton, 'Browse starter recipes'),
          findsNothing,
        );
      });

      testWidgets('offers no catalog in a library without a template', (
        tester,
      ) async {
        mockState(
          RecipesState(
            status: RecipesStatus.success,
            libraries: [blankLibrary],
            activeLibraryId: blankLibrary.id,
          ),
        );
        await pumpView(tester);

        expect(find.bySemanticsLabel('Browse starter recipes'), findsNothing);
        expect(find.text('Browse starter recipes'), findsNothing);
        expect(find.widgetWithText(FButton, 'Add recipe'), findsOneWidget);
      });
    });
  });
}
