import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/libraries/libraries.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

class _MockRecipesBloc extends MockBloc<RecipesEvent, RecipesState>
    implements RecipesBloc {}

void main() {
  group('LibraryDeleteSheet', () {
    late RecipesBloc recipesBloc;
    late StreamController<RecipesState> states;

    // Its ingredient library resolves to nothing.
    final teaLibrary = Library(
      id: 'library-tea',
      name: 'Tea',
      ingredientLibraryId: 'ingredient-library-gone',
    );

    Recipe recipeIn(Library library, String name) =>
        Recipe(id: name, libraryId: library.id, name: name);

    final initialState = RecipesState(
      status: RecipesStatus.success,
      libraries: [cocktailsLibrary, coffeeLibrary, teaLibrary],
      ingredientLibraries: [cocktailsPantry, coffeeShelf],
      ingredients: [ginIngredient, sugarIngredient, cinnamonIngredient],
      recipes: [
        recipeIn(cocktailsLibrary, 'Negroni'),
        recipeIn(cocktailsLibrary, 'Martini'),
        recipeIn(coffeeLibrary, 'Flat white'),
      ],
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

    Future<void> openSheet(WidgetTester tester, Library library) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => FButton(
            onPress: () => LibraryDeleteSheet.show(context, library: library),
            child: const Text('Open'),
          ),
        ),
        recipesBloc: recipesBloc,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    void expectNothingDeleted() => verifyNever(
      () => recipesBloc.add(any(that: isA<RecipesLibraryDeleted>())),
    );

    FButton deleteButton(WidgetTester tester) => tester.widget<FButton>(
      find.ancestor(of: find.text('Delete'), matching: find.byType(FButton)),
    );

    Future<void> emit(
      WidgetTester tester,
      RecipesMutationStatus status,
    ) async {
      states.add(
        initialState.copyWith(
          mutation: RecipesMutation.libraryDeleted,
          mutationStatus: status,
        ),
      );
      await tester.pumpAndSettle();
    }

    group('recipe count', () {
      testWidgets('states how many recipes go with the library', (
        tester,
      ) async {
        await openSheet(tester, cocktailsLibrary);

        expect(find.text('Delete Cocktails?'), findsOneWidget);
        expect(
          find.text(
            'Its 2 recipes will be deleted with it. This cannot be undone.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('has its own wording for one recipe', (tester) async {
        await openSheet(tester, coffeeLibrary);

        expect(
          find.text(
            'Its 1 recipe will be deleted with it. This cannot be undone.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('has its own wording for no recipes', (tester) async {
        await openSheet(tester, teaLibrary);

        expect(
          find.text(
            'This library has no recipes. Deleting it cannot be undone.',
          ),
          findsOneWidget,
        );
      });
    });

    group('ingredients', () {
      testWidgets('states that its ingredient library is kept, offering no '
          'choice', (tester) async {
        await openSheet(tester, cocktailsLibrary);

        expect(
          find.text('Its ingredients stay in Cocktails pantry.'),
          findsOneWidget,
        );
        expect(find.byType(FSelect<String>), findsNothing);
      });

      testWidgets('are not mentioned when its ingredient library is gone', (
        tester,
      ) async {
        await openSheet(tester, teaLibrary);

        expect(find.textContaining('Its ingredients'), findsNothing);
      });
    });

    group('dispatch', () {
      testWidgets('names the next library when deleting the first', (
        tester,
      ) async {
        await openSheet(tester, cocktailsLibrary);

        await tap(tester, 'Delete');

        verify(
          () => recipesBloc.add(
            RecipesLibraryDeleted(
              cocktailsLibrary.id,
              successorId: coffeeLibrary.id,
            ),
          ),
        ).called(1);
      });

      testWidgets('names the first library when deleting a later one', (
        tester,
      ) async {
        await openSheet(tester, teaLibrary);

        await tap(tester, 'Delete');

        verify(
          () => recipesBloc.add(
            RecipesLibraryDeleted(
              teaLibrary.id,
              successorId: cocktailsLibrary.id,
            ),
          ),
        ).called(1);
      });
    });

    group('delete outcome', () {
      testWidgets('closes once the delete succeeds', (tester) async {
        await openSheet(tester, cocktailsLibrary);

        await tap(tester, 'Delete');
        await emit(tester, RecipesMutationStatus.loading);
        expect(find.byType(LibraryDeleteSheet), findsOneWidget);
        await emit(tester, RecipesMutationStatus.success);

        expect(find.byType(LibraryDeleteSheet), findsNothing);
      });

      testWidgets('keeps stating what it deleted while it closes', (
        tester,
      ) async {
        await openSheet(tester, cocktailsLibrary);
        await tap(tester, 'Delete');

        final deleted = initialState.copyWith(
          libraries: [coffeeLibrary, teaLibrary],
          recipes: [recipeIn(coffeeLibrary, 'Flat white')],
          activeLibraryId: coffeeLibrary.id,
          mutation: RecipesMutation.libraryDeleted,
          mutationStatus: RecipesMutationStatus.success,
        );
        when(() => recipesBloc.state).thenReturn(deleted);
        states.add(deleted);
        await tester.pump();
        await tester.pump();

        expect(
          find.text(
            'Its 2 recipes will be deleted with it. This cannot be undone.',
          ),
          findsOneWidget,
        );
        await tester.pumpAndSettle();
        expect(find.byType(LibraryDeleteSheet), findsNothing);
      });

      testWidgets('disables Delete while the delete is in flight', (
        tester,
      ) async {
        await openSheet(tester, cocktailsLibrary);

        await tap(tester, 'Delete');
        await emit(tester, RecipesMutationStatus.loading);

        expect(deleteButton(tester).onPress, isNull);
      });

      testWidgets('ignores a success it did not start', (tester) async {
        await openSheet(tester, cocktailsLibrary);

        await emit(tester, RecipesMutationStatus.success);

        expect(find.byType(LibraryDeleteSheet), findsOneWidget);
      });

      testWidgets('stays open behind a banner with Delete enabled on failure', (
        tester,
      ) async {
        await openSheet(tester, cocktailsLibrary);

        await tap(tester, 'Delete');
        await emit(tester, RecipesMutationStatus.failure);

        expect(find.byType(LibraryDeleteSheet), findsOneWidget);
        expect(find.text('Your library could not be deleted.'), findsOneWidget);
        expect(deleteButton(tester).onPress, isNotNull);
      });

      testWidgets('clears the banner when the delete is retried', (
        tester,
      ) async {
        await openSheet(tester, cocktailsLibrary);
        await tap(tester, 'Delete');
        await emit(tester, RecipesMutationStatus.failure);

        await tap(tester, 'Delete');

        expect(find.text('Your library could not be deleted.'), findsNothing);
      });
    });

    testWidgets('closes without deleting when cancelled', (tester) async {
      await openSheet(tester, cocktailsLibrary);

      await tap(tester, 'Cancel');

      expect(find.byType(LibraryDeleteSheet), findsNothing);
      expectNothingDeleted();
    });

    testWidgets('re-provides the bloc to the sheet', (tester) async {
      await openSheet(tester, cocktailsLibrary);

      final context = tester.element(find.byType(LibraryDeleteSheet));
      expect(context.read<RecipesBloc>(), same(recipesBloc));
    });
  });
}
