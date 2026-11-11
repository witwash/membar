import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:membar/starter_catalog/starter_catalog.dart';
import 'package:recipes_repository/recipes_repository.dart';
import 'package:starter_recipes_repository/starter_recipes_repository.dart';

import '../../helpers/helpers.dart';

class _MockRecipesBloc extends MockBloc<RecipesEvent, RecipesState>
    implements RecipesBloc {}

void main() {
  group('StarterRenameSheet', () {
    late RecipesBloc recipesBloc;

    const negroni = StarterRecipe(key: 'negroni', name: 'Negroni');
    const manhattan = StarterRecipe(key: 'manhattan', name: 'Manhattan');
    const daiquiri = StarterRecipe(key: 'daiquiri', name: 'Daiquiri');

    setUp(() {
      recipesBloc = _MockRecipesBloc();
      whenListen(
        recipesBloc,
        const Stream<RecipesState>.empty(),
        initialState: RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary],
          recipes: [
            for (final (index, name) in [
              'Negroni',
              'Manhattan',
              'Sazerac',
            ].indexed)
              Recipe(
                id: 'recipe-$index',
                libraryId: cocktailsLibrary.id,
                name: name,
              ),
          ],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
    });

    /// Opens the sheet and returns a function reading what it resolved to
    /// once it has closed.
    Future<Map<String, String?>? Function()> openSheet(
      WidgetTester tester, {
      List<StarterRecipe> clashes = const [negroni, manhattan],
      List<StarterRecipe> others = const [daiquiri],
    }) async {
      Map<String, String?>? result;
      await tester.pumpApp(
        Builder(
          builder: (context) => FButton(
            onPress: () async => result = await StarterRenameSheet.show(
              context,
              library: cocktailsLibrary,
              clashes: clashes,
              others: others,
            ),
            child: const Text('Open'),
          ),
        ),
        recipesBloc: recipesBloc,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      return () => result;
    }

    Finder fieldFor(String recipe) => find.descendant(
      of: find.ancestor(
        of: find.text('New name for $recipe'),
        matching: find.byType(FTextFormField),
      ),
      matching: find.byType(EditableText),
    );

    Future<void> rename(WidgetTester tester, String recipe, String to) async {
      await tester.enterText(fieldFor(recipe), to);
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label).first);
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
    }

    FButton importButton(WidgetTester tester) => tester.widget<FButton>(
      find.ancestor(of: find.text('Import'), matching: find.byType(FButton)),
    );

    testWidgets('prefills each row with its name and focuses the first', (
      tester,
    ) async {
      await openSheet(tester);

      expect(
        tester.widget<EditableText>(fieldFor('Negroni')).controller.text,
        'Negroni',
      );
      expect(
        tester.widget<EditableText>(fieldFor('Manhattan')).controller.text,
        'Manhattan',
      );
      expect(
        tester.widget<EditableText>(fieldFor('Negroni')).focusNode.hasFocus,
        isTrue,
      );
    });

    testWidgets('refuses a name the library already holds, ignoring case', (
      tester,
    ) async {
      await openSheet(tester);

      expect(
        find.text('Another recipe here is already called Negroni.'),
        findsOneWidget,
      );

      await rename(tester, 'Negroni', 'sazerac');

      expect(
        find.text('Another recipe here is already called Sazerac.'),
        findsOneWidget,
      );
      expect(importButton(tester).onPress, isNull);
    });

    testWidgets('refuses a blank name', (tester) async {
      await openSheet(tester);

      await rename(tester, 'Negroni', '  ');

      expect(find.text('Enter a name, or skip this recipe.'), findsOneWidget);
    });

    testWidgets('refuses a name another pick is imported under', (
      tester,
    ) async {
      await openSheet(tester);

      await rename(tester, 'Negroni', 'daiquiri');
      await rename(tester, 'Manhattan', 'Rob Roy');

      expect(
        find.text('Another recipe you are importing has this name.'),
        findsOneWidget,
      );

      await rename(tester, 'Negroni', 'rob roy ');

      expect(
        find.text('Another recipe you are importing has this name.'),
        findsNWidgets(2),
      );
      expect(importButton(tester).onPress, isNull);
    });

    testWidgets('leaves a skipped row out of validation and duplicates', (
      tester,
    ) async {
      await openSheet(tester);
      await rename(tester, 'Negroni', 'Rob Roy');
      await rename(tester, 'Manhattan', 'Rob Roy');

      await tap(tester, 'Skip');

      expect(find.text('Undo skip'), findsOneWidget);
      expect(
        find.text('Another recipe you are importing has this name.'),
        findsNothing,
      );
      expect(importButton(tester).onPress, isNotNull);
    });

    testWidgets('puts an undone skip back into validation', (tester) async {
      await openSheet(tester);
      await tap(tester, 'Skip');
      expect(
        find.text('Another recipe here is already called Negroni.'),
        findsNothing,
      );

      await tap(tester, 'Undo skip');

      expect(
        find.text('Another recipe here is already called Negroni.'),
        findsOneWidget,
      );
    });

    testWidgets('resolves to the renames, with null for a skipped row', (
      tester,
    ) async {
      final result = await openSheet(tester);
      await rename(tester, 'Negroni', ' Negroni (mine) ');
      await tester.tap(find.text('Skip').last);
      await tester.pumpAndSettle();

      await tap(tester, 'Import');

      expect(find.byType(StarterRenameSheet), findsNothing);
      expect(result(), {'negroni': 'Negroni (mine)', 'manhattan': null});
    });

    testWidgets('can skip every clash when other picks remain', (
      tester,
    ) async {
      final result = await openSheet(tester);

      await tap(tester, 'Skip all');
      await tap(tester, 'Import');

      expect(result(), {'negroni': null, 'manhattan': null});
    });

    testWidgets('disables Import once Skip all leaves nothing to import', (
      tester,
    ) async {
      await openSheet(tester, others: const []);

      await tap(tester, 'Skip all');

      expect(find.text('Undo skip'), findsNWidgets(2));
      expect(importButton(tester).onPress, isNull);
    });

    testWidgets('resolves to null when cancelled', (tester) async {
      final result = await openSheet(tester);
      await rename(tester, 'Negroni', 'Negroni (mine)');

      await tap(tester, 'Cancel');

      expect(find.byType(StarterRenameSheet), findsNothing);
      expect(result(), isNull);
    });
  });
}
