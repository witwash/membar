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
  group('LibraryEditorSheet', () {
    late RecipesBloc recipesBloc;
    late StreamController<RecipesState> states;

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
      whenListen(recipesBloc, states.stream, initialState: initialState);
    });

    Future<void> openSheet(WidgetTester tester, {Library? library}) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => FButton(
            onPress: () => LibraryEditorSheet.show(context, library: library),
            child: const Text('Open'),
          ),
        ),
        recipesBloc: recipesBloc,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    final nameField = find.descendant(
      of: find.ancestor(
        of: find.text('Name'),
        matching: find.byType(FTextFormField),
      ),
      matching: find.byType(EditableText),
    );

    final templateSelect = find.byWidgetPredicate(
      (widget) => widget is FSelect,
    );

    Future<void> tap(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    Future<void> startFrom(WidgetTester tester, String template) async {
      await tester.tap(templateSelect);
      await tester.pumpAndSettle();
      await tap(tester, template);
    }

    RecipesLibrarySaved savedEvent() {
      final events = verify(() => recipesBloc.add(captureAny())).captured;
      return events.whereType<RecipesLibrarySaved>().single;
    }

    void expectNothingSaved() => verifyNever(
      () => recipesBloc.add(any(that: isA<RecipesLibrarySaved>())),
    );

    List<String> labelsOf(Library library) => [
      for (final field in library.fields) field.label,
    ];

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

    group('create', () {
      testWidgets('starts with no name and the blank template', (tester) async {
        await openSheet(tester);

        expect(find.text('New library'), findsOneWidget);
        expect(tester.widget<EditableText>(nameField).controller.text, isEmpty);
        expect(
          find.descendant(of: templateSelect, matching: find.text('Blank')),
          findsOneWidget,
        );
      });

      testWidgets('keeps the name empty whatever template is chosen', (
        tester,
      ) async {
        await openSheet(tester);

        await startFrom(tester, 'Cocktails');

        expect(tester.widget<EditableText>(nameField).controller.text, isEmpty);
      });

      testWidgets('refuses a blank name', (tester) async {
        await openSheet(tester);

        await tester.enterText(nameField, ' ');
        await tap(tester, 'Create library');

        expect(find.text('Enter a name.'), findsOneWidget);
        expectNothingSaved();
      });

      testWidgets('refuses a name another library carries, ignoring case', (
        tester,
      ) async {
        await openSheet(tester);

        await tester.enterText(nameField, ' COFFEE ');
        await tap(tester, 'Create library');

        expect(
          find.text('Another library is already called Coffee.'),
          findsOneWidget,
        );
        expectNothingSaved();
      });

      testWidgets('creates a library with no fields from the blank template', (
        tester,
      ) async {
        await openSheet(tester);

        await tester.enterText(nameField, ' Tea ');
        await tap(tester, 'Create library');

        final event = savedEvent();
        expect(event.library.name, 'Tea');
        expect(event.library.fields, isEmpty);
        expect(event.optionRenames, isEmpty);
        expect(
          initialState.libraries.map((library) => library.id),
          isNot(contains(event.library.id)),
        );
      });

      testWidgets("creates a library with the coffee template's fields under "
          'the typed name', (tester) async {
        await openSheet(tester);

        await tester.enterText(nameField, 'Tea');
        await startFrom(tester, 'Coffee');
        await tap(tester, 'Create library');

        final library = savedEvent().library;
        expect(library.name, 'Tea');
        expect(labelsOf(library), labelsOf(const LibraryTemplates().coffee()));
      });

      testWidgets("creates a library with the cocktails template's fields "
          'under the typed name', (tester) async {
        await openSheet(tester);

        await tester.enterText(nameField, 'Mocktails');
        await startFrom(tester, 'Cocktails');
        await tap(tester, 'Create library');

        final library = savedEvent().library;
        expect(library.name, 'Mocktails');
        expect(
          labelsOf(library),
          labelsOf(const LibraryTemplates().cocktails()),
        );
      });
    });

    group('rename', () {
      testWidgets('starts from the library as it is, offering no template', (
        tester,
      ) async {
        await openSheet(tester, library: cocktailsLibrary);

        expect(find.text('Rename library'), findsOneWidget);
        expect(
          tester.widget<EditableText>(nameField).controller.text,
          'Cocktails',
        );
        expect(templateSelect, findsNothing);
      });

      testWidgets('saves the new name under the same id and fields', (
        tester,
      ) async {
        await openSheet(tester, library: cocktailsLibrary);

        await tester.enterText(nameField, 'Drinks');
        await tap(tester, 'Save changes');

        expect(
          savedEvent(),
          RecipesLibrarySaved(
            Library(
              id: cocktailsLibrary.id,
              name: 'Drinks',
              fields: cocktailsLibrary.fields,
            ),
          ),
        );
      });

      testWidgets("accepts the library's own name", (tester) async {
        await openSheet(tester, library: cocktailsLibrary);

        await tester.enterText(nameField, 'COCKTAILS');
        await tap(tester, 'Save changes');

        expect(savedEvent().library.name, 'COCKTAILS');
      });

      testWidgets('refuses a rename onto another library', (tester) async {
        await openSheet(tester, library: cocktailsLibrary);

        await tester.enterText(nameField, 'coffee');
        await tap(tester, 'Save changes');

        expect(
          find.text('Another library is already called Coffee.'),
          findsOneWidget,
        );
        expectNothingSaved();
      });
    });

    group('save outcome', () {
      testWidgets('closes once the save succeeds', (tester) async {
        await openSheet(tester, library: cocktailsLibrary);

        await tap(tester, 'Save changes');
        await emit(tester, RecipesMutationStatus.loading);
        expect(find.byType(LibraryEditorSheet), findsOneWidget);
        await emit(tester, RecipesMutationStatus.success);

        expect(find.byType(LibraryEditorSheet), findsNothing);
      });

      testWidgets('disables saving while the save is in flight', (
        tester,
      ) async {
        await openSheet(tester, library: cocktailsLibrary);

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
        await openSheet(tester, library: cocktailsLibrary);

        await emit(tester, RecipesMutationStatus.success);

        expect(find.byType(LibraryEditorSheet), findsOneWidget);
      });

      testWidgets('stays open with a banner and the typed values on failure', (
        tester,
      ) async {
        await openSheet(tester);

        await tester.enterText(nameField, 'Tea');
        await startFrom(tester, 'Coffee');
        await tap(tester, 'Create library');
        await emit(tester, RecipesMutationStatus.failure);

        expect(find.byType(LibraryEditorSheet), findsOneWidget);
        expect(find.text('Your library could not be saved.'), findsOneWidget);
        expect(find.text('Tea'), findsOneWidget);
        expect(
          find.descendant(of: templateSelect, matching: find.text('Coffee')),
          findsOneWidget,
        );
      });

      testWidgets('clears the banner when the save is retried', (tester) async {
        await openSheet(tester, library: cocktailsLibrary);
        await tap(tester, 'Save changes');
        await emit(tester, RecipesMutationStatus.failure);

        await tap(tester, 'Save changes');

        expect(find.text('Your library could not be saved.'), findsNothing);
      });
    });

    testWidgets('closes without saving when cancelled', (tester) async {
      await openSheet(tester);

      await tap(tester, 'Cancel');

      expect(find.byType(LibraryEditorSheet), findsNothing);
      expectNothingSaved();
    });

    testWidgets(
      'disposes its controller when it closes',
      (tester) async {
        await openSheet(tester, library: cocktailsLibrary);

        await tap(tester, 'Cancel');

        expect(find.byType(LibraryEditorSheet), findsNothing);
      },
      experimentalLeakTesting: LeakTesting.settings.withTrackedAll(),
    );

    testWidgets('re-provides the bloc to the sheet', (tester) async {
      await openSheet(tester);

      final context = tester.element(find.byType(LibraryEditorSheet));
      expect(context.read<RecipesBloc>(), same(recipesBloc));
    });
  });
}
