import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

class _MockRecipesBloc extends MockBloc<RecipesEvent, RecipesState>
    implements RecipesBloc {}

void main() {
  group('IngredientOption', () {
    test('a catalog option is equal by entry and scope', () {
      expect(
        CatalogOption(ginIngredient, inScope: true),
        CatalogOption(ginIngredient, inScope: true),
      );
      expect(
        CatalogOption(ginIngredient, inScope: true),
        isNot(CatalogOption(ginIngredient, inScope: false)),
      );
    });

    test('a create option is equal by query', () {
      expect(const CreateOption('gin'), const CreateOption('gin'));
      expect(const CreateOption('gin'), isNot(const CreateOption('rum')));
    });
  });

  group('IngredientPicker', () {
    late RecipesBloc recipesBloc;
    late FAutocompleteController name;
    late TextEditingController unit;

    final ice = CatalogIngredient(
      id: 'ingredient-ice',
      name: 'Ice',
      libraryIds: {cocktailsLibrary.id},
    );

    setUp(() {
      recipesBloc = _MockRecipesBloc();
      whenListen(
        recipesBloc,
        const Stream<RecipesState>.empty(),
        initialState: RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary, coffeeLibrary],
          ingredients: [
            ginIngredient,
            sugarIngredient,
            cinnamonIngredient,
            ice,
          ],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
      name = FAutocompleteController();
      unit = TextEditingController();
      addTearDown(name.dispose);
      addTearDown(unit.dispose);
    });

    Future<void> pumpPicker(WidgetTester tester) => tester.pumpApp(
      Column(
        children: [
          IngredientPicker(name: name, unit: unit),
        ],
      ),
      recipesBloc: recipesBloc,
    );

    Future<void> openPicker(WidgetTester tester) async {
      await tester.tap(find.byType(EditableText));
      await tester.pumpAndSettle();
    }

    Future<void> pick(WidgetTester tester, String label) async {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    double top(WidgetTester tester, String text) =>
        tester.getTopLeft(find.text(text)).dy;

    testWidgets(
      'lists entries in the library first, then the others under a heading',
      (tester) async {
        await pumpPicker(tester);

        await openPicker(tester);

        expect(top(tester, 'Gin'), lessThan(top(tester, 'Ice')));
        expect(top(tester, 'Ice'), lessThan(top(tester, 'sugar')));
        expect(
          top(tester, 'sugar'),
          lessThan(top(tester, 'From other libraries')),
        );
        expect(
          top(tester, 'From other libraries'),
          lessThan(top(tester, 'Cinnamon')),
        );
        expect(
          top(tester, 'Cinnamon'),
          lessThan(top(tester, 'New ingredient')),
        );
        expect(find.text('ml'), findsOneWidget);
      },
    );

    testWidgets('shows no heading when every entry is in the library', (
      tester,
    ) async {
      when(() => recipesBloc.state).thenReturn(
        RecipesState(
          ingredients: [ginIngredient],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
      await pumpPicker(tester);

      await openPicker(tester);

      expect(find.text('Gin'), findsOneWidget);
      expect(find.text('From other libraries'), findsNothing);
    });

    testWidgets('matches anywhere in a name, ignoring case', (tester) async {
      await pumpPicker(tester);

      await tester.enterText(find.byType(EditableText), 'NAMO');
      await tester.pumpAndSettle();

      expect(find.text('Cinnamon'), findsOneWidget);
      expect(find.text('Gin'), findsNothing);
      expect(find.text('sugar'), findsNothing);
    });

    testWidgets('offers the create action when the catalog is empty', (
      tester,
    ) async {
      when(
        () => recipesBloc.state,
      ).thenReturn(RecipesState(activeLibraryId: cocktailsLibrary.id));
      await pumpPicker(tester);

      await openPicker(tester);

      expect(find.text('New ingredient'), findsOneWidget);
      expect(find.text('No matches found.'), findsNothing);
    });

    testWidgets('picking an entry in the library fills the name and unit', (
      tester,
    ) async {
      await pumpPicker(tester);

      await openPicker(tester);
      await pick(tester, 'Gin');

      expect(name.text, 'Gin');
      expect(unit.text, 'ml');
      verifyNever(
        () => recipesBloc.add(any(that: isA<RecipesIngredientScopeWidened>())),
      );
    });

    testWidgets(
      'picking an entry from another library widens it into this one',
      (tester) async {
        await pumpPicker(tester);

        await openPicker(tester);
        await pick(tester, 'Cinnamon');

        verify(
          () => recipesBloc.add(
            RecipesIngredientScopeWidened(
              cinnamonIngredient.id,
              cocktailsLibrary.id,
            ),
          ),
        ).called(1);
        // The widen reports nothing, so whether it lands changes nothing here.
        expect(name.text, 'Cinnamon');
        expect(unit.text, 'pinch');
      },
    );

    testWidgets('keeps a unit the user typed', (tester) async {
      unit.text = 'oz';
      await pumpPicker(tester);

      await openPicker(tester);
      await pick(tester, 'Gin');

      expect(unit.text, 'oz');
    });

    testWidgets('replaces the unit the previous pick filled in', (
      tester,
    ) async {
      await pumpPicker(tester);

      await openPicker(tester);
      await pick(tester, 'Gin');
      await tester.enterText(find.byType(EditableText), '');
      await tester.pumpAndSettle();
      await pick(tester, 'sugar');

      expect(name.text, 'sugar');
      expect(unit.text, 'gram');
    });

    testWidgets('leaves the unit alone for an entry with no default', (
      tester,
    ) async {
      unit.text = 'cube';
      await pumpPicker(tester);

      await openPicker(tester);
      await pick(tester, 'Ice');

      expect(name.text, 'Ice');
      expect(unit.text, 'cube');
    });

    group('create action', () {
      testWidgets('keeps the typed text and opens the sheet prefilled', (
        tester,
      ) async {
        await pumpPicker(tester);

        await tester.enterText(find.byType(EditableText), 'Bourbon');
        await tester.pumpAndSettle();
        await pick(tester, 'New ingredient');

        expect(name.text, 'Bourbon');
        expect(find.byType(IngredientCreateSheet), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(IngredientCreateSheet),
            matching: find.text('Bourbon'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('leaves the row as typed when the sheet is dismissed', (
        tester,
      ) async {
        await pumpPicker(tester);

        await tester.enterText(find.byType(EditableText), 'bourbon');
        await tester.pumpAndSettle();
        await pick(tester, 'New ingredient');
        await pick(tester, 'Cancel');

        expect(find.byType(IngredientCreateSheet), findsNothing);
        expect(name.text, 'bourbon');
        expect(unit.text, isEmpty);
      });

      testWidgets('fills the row from the entry the sheet returns', (
        tester,
      ) async {
        await pumpPicker(tester);

        // A name the catalog already holds comes straight back as a reuse.
        await tester.enterText(find.byType(EditableText), 'gin');
        await tester.pumpAndSettle();
        await pick(tester, 'New ingredient');
        await pick(tester, 'Save ingredient');

        expect(find.byType(IngredientCreateSheet), findsNothing);
        expect(name.text, 'Gin');
        expect(unit.text, 'ml');
      });
    });

    testWidgets('parses nothing out of the typed text', (tester) async {
      await pumpPicker(tester);

      final field = tester.widget<FAutocomplete<IngredientOption>>(
        find.byType(FAutocomplete<IngredientOption>),
      );

      expect(field.parse('Gin'), isNull);
    });
  });
}
