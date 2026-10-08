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
  group('LibraryFieldsView', () {
    late RecipesBloc recipesBloc;
    late StreamController<RecipesState> states;

    final abvField = FieldDefinition(
      id: 'field-abv',
      label: 'ABV',
      type: FieldType.number,
      unit: '%',
      required: true,
    );

    final ratingField = FieldDefinition(
      id: 'field-rating',
      label: 'Rating',
      type: FieldType.number,
    );

    final styleField = FieldDefinition(
      id: 'field-style',
      label: 'Style',
      type: FieldType.select,
      options: const ['Stirred'],
    );

    final blankLibrary = Library(id: 'library-blank', name: 'Tea');

    Recipe recipeWith(String name, Map<String, Object?> fieldValues) => Recipe(
      id: name,
      libraryId: cocktailsLibrary.id,
      name: name,
      fieldValues: fieldValues,
    );

    final loaded = RecipesState(
      status: RecipesStatus.success,
      libraries: [cocktailsLibrary, coffeeLibrary, blankLibrary],
      recipes: [
        recipeWith('Negroni', {garnishField.id: 'Orange peel'}),
        recipeWith('Martini', {
          garnishField.id: 'Olive',
          glasswareField.id: 'Coupe',
        }),
        recipeWith('Highball', const {}),
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
    });

    Future<void> pumpView(
      WidgetTester tester, {
      RecipesState? state,
      String? libraryId,
    }) async {
      whenListen(recipesBloc, states.stream, initialState: state ?? loaded);
      await tester.pumpApp(
        LibraryFieldsView(libraryId: libraryId ?? cocktailsLibrary.id),
        recipesBloc: recipesBloc,
      );
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

    Future<void> tapInDialog(WidgetTester tester, String label) async {
      await tester.tap(
        find.descendant(of: find.byType(FDialog), matching: find.text(label)),
      );
      await tester.pumpAndSettle();
    }

    Finder tileOf(String label) =>
        find.ancestor(of: find.text(label), matching: find.byType(FTile));

    Finder inView(Finder finder) =>
        find.descendant(of: find.byType(LibraryFieldsView), matching: finder);

    FieldEditorSheet sheet(WidgetTester tester) =>
        tester.widget<FieldEditorSheet>(find.byType(FieldEditorSheet));

    testWidgets("lists the library's fields in schema order under its name", (
      tester,
    ) async {
      await pumpView(tester);

      expect(find.text('Cocktails'), findsOneWidget);
      final labels = tester
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
      expect(labels, ['Glassware', 'Garnish']);
    });

    testWidgets('describes each field by its type, what narrows it and '
        'whether it is required', (tester) async {
      final library = Library(
        id: 'library-all',
        name: 'Everything',
        fields: [
          glasswareField,
          styleField,
          garnishField,
          tastingNotesField,
          abvField,
          ratingField,
        ],
      );
      await pumpView(
        tester,
        state: loaded.copyWith(libraries: [library]),
        libraryId: library.id,
      );

      String subtitleOf(String label) => tester
          .widget<Text>(
            find
                .descendant(of: tileOf(label), matching: find.byType(Text))
                .at(1),
          )
          .data!;

      expect(subtitleOf('Glassware'), 'Choice · 2 options');
      expect(subtitleOf('Style'), 'Choice · 1 option');
      expect(subtitleOf('Garnish'), 'Text');
      expect(subtitleOf('Tasting notes'), 'Long text');
      expect(subtitleOf('ABV'), 'Number · % · Required');
      expect(subtitleOf('Rating'), 'Number');
    });

    testWidgets('follows the bloc when a field is added', (tester) async {
      await pumpView(tester);

      await emit(
        tester,
        loaded.copyWith(
          libraries: [
            Library(
              id: cocktailsLibrary.id,
              name: cocktailsLibrary.name,
              fields: [...cocktailsLibrary.fields, abvField],
            ),
            coffeeLibrary,
            blankLibrary,
          ],
        ),
      );

      expect(tileOf('ABV'), findsOneWidget);
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
                  child: LibraryFieldsView(libraryId: cocktailsLibrary.id),
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

      expect(find.byType(LibraryFieldsView), findsNothing);
    });

    testWidgets('renders only the back action for a library that is gone', (
      tester,
    ) async {
      await pumpView(tester, libraryId: 'library-gone');

      expect(find.byType(FHeaderAction), findsOneWidget);
      expect(find.byType(FTile), findsNothing);
      expect(find.text('No fields yet'), findsNothing);
    });

    group('sheet', () {
      testWidgets('opens on a new field from the add action', (tester) async {
        await pumpView(tester);

        await tapAction(tester, 'Add field');

        expect(sheet(tester).library, cocktailsLibrary);
        expect(sheet(tester).field, isNull);
      });

      testWidgets('opens on a tapped field', (tester) async {
        await pumpView(tester);

        await tester.tap(find.text('Garnish'));
        await tester.pumpAndSettle();

        expect(sheet(tester).library, cocktailsLibrary);
        expect(sheet(tester).field, garnishField);
      });

      testWidgets('raises no banner beneath it when its save fails', (
        tester,
      ) async {
        await pumpView(tester);
        await tester.tap(find.text('Garnish'));
        await tester.pumpAndSettle();

        await emit(
          tester,
          loaded.copyWith(
            mutation: RecipesMutation.librarySaved,
            mutationStatus: RecipesMutationStatus.failure,
          ),
        );

        expect(find.text('Your field could not be saved.'), findsOneWidget);
        expect(find.text('Your field could not be deleted.'), findsNothing);
        expect(
          find.byType(FailureBanner),
          findsOneWidget,
          reason: 'only the sheet reports its own save',
        );
      });
    });

    group('empty state', () {
      testWidgets('explains itself for a library with no fields', (
        tester,
      ) async {
        await pumpView(tester, libraryId: blankLibrary.id);

        expect(find.text('Tea'), findsOneWidget);
        expect(find.text('No fields yet'), findsOneWidget);
        expect(
          find.text(
            'Fields are what every recipe in this library records, such as a '
            'glass or a brew time.',
          ),
          findsOneWidget,
        );
        expect(find.byType(FTile), findsNothing);
      });

      testWidgets('opens the sheet on a new field from its button', (
        tester,
      ) async {
        await pumpView(tester, libraryId: blankLibrary.id);

        await tester.tap(find.widgetWithText(FButton, 'Add field'));
        await tester.pumpAndSettle();

        expect(sheet(tester).library, blankLibrary);
        expect(sheet(tester).field, isNull);
      });

      testWidgets('shows the empty state once the last field is gone', (
        tester,
      ) async {
        final single = Library(
          id: 'library-single',
          name: 'Single',
          fields: [garnishField],
        );
        await pumpView(
          tester,
          state: loaded.copyWith(libraries: [single]),
          libraryId: single.id,
        );

        await emit(
          tester,
          loaded.copyWith(
            libraries: [Library(id: single.id, name: single.name)],
            mutation: RecipesMutation.fieldDeleted,
            mutationStatus: RecipesMutationStatus.success,
          ),
        );

        expect(find.text('No fields yet'), findsOneWidget);
        expect(find.byType(FailureBanner), findsNothing);
      });
    });

    group('delete', () {
      testWidgets('states how many recipes carry a value before dispatching', (
        tester,
      ) async {
        await pumpView(tester);

        await tapAction(tester, 'Delete Garnish');

        expect(find.text('Delete Garnish?'), findsOneWidget);
        expect(
          find.text(
            '2 recipes have a value for this field. They will be cleared, and '
            'this cannot be undone.',
          ),
          findsOneWidget,
        );
        verifyNever(() => recipesBloc.add(any()));

        await tapInDialog(tester, 'Delete');

        verify(
          () => recipesBloc.add(
            RecipesFieldDeleted(
              libraryId: cocktailsLibrary.id,
              fieldId: garnishField.id,
            ),
          ),
        ).called(1);
      });

      testWidgets('has its own wording for one recipe', (tester) async {
        await pumpView(tester);

        await tapAction(tester, 'Delete Glassware');

        expect(
          find.text(
            '1 recipe has a value for this field. It will be cleared, and this '
            'cannot be undone.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('has its own wording for no recipes, and still dispatches', (
        tester,
      ) async {
        await pumpView(tester, libraryId: coffeeLibrary.id);

        await tapAction(tester, 'Delete Dose');

        expect(
          find.text('No recipe has a value for this field.'),
          findsOneWidget,
        );

        await tapInDialog(tester, 'Delete');

        verify(
          () => recipesBloc.add(
            RecipesFieldDeleted(
              libraryId: coffeeLibrary.id,
              fieldId: doseField.id,
            ),
          ),
        ).called(1);
      });

      testWidgets('does nothing when the confirmation is cancelled', (
        tester,
      ) async {
        await pumpView(tester);

        await tapAction(tester, 'Delete Garnish');
        await tapInDialog(tester, 'Cancel');

        expect(find.byType(FDialog), findsNothing);
        verifyNever(() => recipesBloc.add(any()));
      });

      testWidgets('reports a failed delete', (tester) async {
        await pumpView(tester);

        await emit(
          tester,
          loaded.copyWith(
            mutation: RecipesMutation.fieldDeleted,
            mutationStatus: RecipesMutationStatus.failure,
          ),
        );

        expect(
          inView(find.text('Your field could not be deleted.')),
          findsOneWidget,
        );
      });

      testWidgets('clears the banner when a delete is dispatched again', (
        tester,
      ) async {
        await pumpView(tester);
        await emit(
          tester,
          loaded.copyWith(
            mutation: RecipesMutation.fieldDeleted,
            mutationStatus: RecipesMutationStatus.failure,
          ),
        );

        await tapAction(tester, 'Delete Garnish');
        await tapInDialog(tester, 'Delete');

        expect(find.byType(FailureBanner), findsNothing);
      });

      testWidgets('drops the field once the delete succeeds', (tester) async {
        await pumpView(tester);

        await emit(
          tester,
          loaded.copyWith(
            libraries: [
              Library(
                id: cocktailsLibrary.id,
                name: cocktailsLibrary.name,
                fields: [glasswareField],
              ),
              coffeeLibrary,
              blankLibrary,
            ],
            mutation: RecipesMutation.fieldDeleted,
            mutationStatus: RecipesMutationStatus.success,
          ),
        );

        expect(tileOf('Garnish'), findsNothing);
        expect(find.byType(FailureBanner), findsNothing);
      });
    });
  });
}
