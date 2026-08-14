import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

class _MockRecipesBloc extends MockBloc<RecipesEvent, RecipesState>
    implements RecipesBloc {}

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
  });
}
