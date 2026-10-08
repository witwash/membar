import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/libraries/libraries.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:membar/ui/ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

class _MockRecipesBloc extends MockBloc<RecipesEvent, RecipesState>
    implements RecipesBloc {}

void main() {
  group('LibrariesView', () {
    late RecipesBloc recipesBloc;
    late StreamController<RecipesState> states;

    Recipe recipeIn(Library library, String name) =>
        Recipe(id: name, libraryId: library.id, name: name);

    // Coffee first: the screen keeps stored order, which is not alphabetical.
    final loaded = RecipesState(
      status: RecipesStatus.success,
      libraries: [coffeeLibrary, cocktailsLibrary],
      recipes: [
        recipeIn(cocktailsLibrary, 'Negroni'),
        recipeIn(cocktailsLibrary, 'Martini'),
      ],
      activeLibraryId: cocktailsLibrary.id,
    );

    final onlyCocktails = loaded.copyWith(libraries: [cocktailsLibrary]);

    setUpAll(
      () => registerFallbackValue(const RecipesSubscriptionRequested()),
    );

    setUp(() {
      recipesBloc = _MockRecipesBloc();
      states = StreamController<RecipesState>.broadcast();
      addTearDown(states.close);
    });

    Future<void> pumpView(WidgetTester tester, RecipesState state) async {
      whenListen(recipesBloc, states.stream, initialState: state);
      await tester.pumpApp(const LibrariesView(), recipesBloc: recipesBloc);
    }

    Future<void> emit(WidgetTester tester, RecipesState state) async {
      when(() => recipesBloc.state).thenReturn(state);
      states.add(state);
      await tester.pumpAndSettle();
    }

    Future<void> tapAction(WidgetTester tester, String label) async {
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pumpAndSettle();
    }

    Finder tileOf(String name) =>
        find.ancestor(of: find.text(name), matching: find.byType(FTile));

    testWidgets('lists every library in stored order', (tester) async {
      await pumpView(tester, loaded);

      expect(find.text('Libraries'), findsOneWidget);
      final names = tester
          .widgetList<FTile>(find.byType(FTile))
          .map(
            (tile) => tester
                .widget<Text>(
                  find
                      .descendant(
                        of: find.byWidget(tile),
                        matching: find.byType(Text),
                      )
                      .first,
                )
                .data,
          );
      expect(names, ['Coffee', 'Cocktails']);
    });

    testWidgets('states how many fields and recipes each library has', (
      tester,
    ) async {
      final tea = Library(id: 'library-tea', name: 'Tea', fields: [doseField]);
      final blank = Library(id: 'library-blank', name: 'Blank');
      await pumpView(
        tester,
        loaded.copyWith(
          libraries: [...loaded.libraries, tea, blank],
          recipes: [...loaded.recipes, recipeIn(tea, 'Sencha')],
        ),
      );

      expect(
        find.descendant(
          of: tileOf('Cocktails'),
          matching: find.text('2 fields · 2 recipes'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tileOf('Coffee'),
          matching: find.text('2 fields · No recipes'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tileOf('Tea'),
          matching: find.text('1 field · 1 recipe'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tileOf('Blank'),
          matching: find.text('No fields · No recipes'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('follows the bloc when a library is added', (tester) async {
      await pumpView(tester, loaded);

      await emit(
        tester,
        loaded.copyWith(
          libraries: [
            ...loaded.libraries,
            Library(id: 'library-tea', name: 'Tea'),
          ],
        ),
      );

      expect(tileOf('Tea'), findsOneWidget);
    });

    testWidgets('pops from the back action', (tester) async {
      whenListen(recipesBloc, states.stream, initialState: loaded);
      await tester.pumpApp(
        Builder(
          builder: (context) => FButton(
            onPress: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider.value(
                  value: recipesBloc,
                  child: const LibrariesView(),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
        recipesBloc: recipesBloc,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FHeaderAction).first);
      await tester.pumpAndSettle();

      expect(find.byType(LibrariesView), findsNothing);
    });

    testWidgets('opens the sheet on a new library from the add action', (
      tester,
    ) async {
      await pumpView(tester, loaded);

      await tapAction(tester, 'Add library');

      expect(
        tester
            .widget<LibraryEditorSheet>(find.byType(LibraryEditorSheet))
            .library,
        isNull,
      );
    });

    testWidgets('opens the sheet on a library from its rename action', (
      tester,
    ) async {
      await pumpView(tester, loaded);

      await tapAction(tester, 'Rename Coffee');

      expect(
        tester
            .widget<LibraryEditorSheet>(find.byType(LibraryEditorSheet))
            .library,
        coffeeLibrary,
      );
    });

    group('fields', () {
      testWidgets('opens the fields of a tapped library with the bloc '
          're-provided', (tester) async {
        await pumpView(tester, loaded);

        await tester.tap(find.text('Coffee'));
        await tester.pumpAndSettle();

        final fields = find.byType(LibraryFieldsView);
        expect(
          tester.widget<LibraryFieldsView>(fields).libraryId,
          coffeeLibrary.id,
        );
        expect(tester.element(fields).read<RecipesBloc>(), same(recipesBloc));
      });

      testWidgets('clears the refusal once a library is opened', (
        tester,
      ) async {
        await pumpView(tester, onlyCocktails);
        await tapAction(tester, 'Delete Cocktails');

        await tester.tap(find.text('Cocktails'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(FHeaderAction).first);
        await tester.pumpAndSettle();

        expect(find.byType(LibrariesView), findsOneWidget);
        expect(find.byType(FailureBanner), findsNothing);
      });
    });

    group('delete', () {
      testWidgets('opens the delete sheet on the library', (tester) async {
        await pumpView(tester, loaded);

        await tapAction(tester, 'Delete Coffee');

        expect(
          tester
              .widget<LibraryDeleteSheet>(find.byType(LibraryDeleteSheet))
              .library,
          coffeeLibrary,
        );
        expect(find.byType(FailureBanner), findsNothing);
      });

      testWidgets('is refused for the only library, saying why, without '
          'opening the sheet', (tester) async {
        await pumpView(tester, onlyCocktails);

        await tapAction(tester, 'Delete Cocktails');

        expect(
          find.text(
            'Cocktails is your only library, so it cannot be deleted. '
            'Create another library first.',
          ),
          findsOneWidget,
        );
        expect(find.byType(LibraryDeleteSheet), findsNothing);
        verifyNever(() => recipesBloc.add(any()));
      });

      testWidgets('clears the refusal once a library is being added', (
        tester,
      ) async {
        await pumpView(tester, onlyCocktails);
        await tapAction(tester, 'Delete Cocktails');

        await tapAction(tester, 'Add library');

        expect(find.byType(FailureBanner), findsNothing);
      });

      testWidgets('clears the refusal once a second library can take over', (
        tester,
      ) async {
        await pumpView(tester, onlyCocktails);
        await tapAction(tester, 'Delete Cocktails');
        await emit(tester, loaded);

        await tapAction(tester, 'Delete Cocktails');

        expect(find.byType(LibraryDeleteSheet), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(LibrariesView),
            matching: find.byType(FailureBanner),
          ),
          findsNothing,
        );
      });
    });
  });
}
