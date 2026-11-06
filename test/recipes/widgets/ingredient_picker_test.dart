import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

class _MockRecipesBloc extends MockBloc<RecipesEvent, RecipesState>
    implements RecipesBloc {}

void main() {
  group('IngredientOption', () {
    test('a catalog option is equal by entry', () {
      expect(CatalogOption(ginIngredient), CatalogOption(ginIngredient));
      expect(
        CatalogOption(ginIngredient),
        isNot(CatalogOption(sugarIngredient)),
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
      ingredientLibraryId: cocktailsPantry.id,
    );

    setUpAll(
      () => registerFallbackValue(const RecipesSubscriptionRequested()),
    );

    setUp(() {
      recipesBloc = _MockRecipesBloc();
      whenListen(
        recipesBloc,
        const Stream<RecipesState>.empty(),
        initialState: RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary, coffeeLibrary],
          ingredientLibraries: [cocktailsPantry, coffeeShelf],
          ingredients: [
            ginIngredient,
            sugarIngredient,
            coffeeSugarIngredient,
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
          IngredientPicker(
            name: name,
            unit: unit,
            ingredientLibraryId: cocktailsPantry.id,
          ),
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
      'lists only its ingredient library, sorted, then the create action',
      (tester) async {
        await pumpPicker(tester);

        await openPicker(tester);

        expect(top(tester, 'Gin'), lessThan(top(tester, 'Ice')));
        expect(top(tester, 'Ice'), lessThan(top(tester, 'sugar')));
        expect(
          top(tester, 'sugar'),
          lessThan(top(tester, 'New ingredient')),
        );
        expect(find.text('sugar'), findsOneWidget);
        expect(find.text('Cinnamon'), findsNothing);
        expect(find.text('ml'), findsOneWidget);
      },
    );

    testWidgets('matches anywhere in a name, ignoring case', (tester) async {
      await pumpPicker(tester);

      await tester.enterText(find.byType(EditableText), 'UGA');
      await tester.pumpAndSettle();

      expect(find.text('sugar'), findsOneWidget);
      expect(find.text('Gin'), findsNothing);
      expect(find.text('Ice'), findsNothing);
    });

    testWidgets('offers the create action when its library is empty', (
      tester,
    ) async {
      when(() => recipesBloc.state).thenReturn(
        RecipesState(
          ingredientLibraries: [cocktailsPantry, coffeeShelf],
          ingredients: [cinnamonIngredient],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
      await pumpPicker(tester);

      await openPicker(tester);

      expect(find.text('New ingredient'), findsOneWidget);
      expect(find.text('No matches found.'), findsNothing);
    });

    testWidgets('picking an entry fills the name and unit', (
      tester,
    ) async {
      await pumpPicker(tester);

      await openPicker(tester);
      await pick(tester, 'Gin');

      expect(name.text, 'Gin');
      expect(unit.text, 'ml');
      verifyNever(() => recipesBloc.add(any()));
    });

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
        expect(
          tester
              .widget<IngredientCreateSheet>(
                find.byType(IngredientCreateSheet),
              )
              .ingredientLibraryId,
          cocktailsPantry.id,
        );
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

        // A name its library already holds comes straight back as a reuse.
        await tester.enterText(find.byType(EditableText), 'gin');
        await tester.pumpAndSettle();
        await pick(tester, 'New ingredient');
        await pick(tester, 'Save ingredient');

        expect(find.byType(IngredientCreateSheet), findsNothing);
        expect(name.text, 'Gin');
        expect(unit.text, 'ml');
      });
    });

    group('validation', () {
      late GlobalKey<FormState> formKey;

      setUp(() => formKey = GlobalKey<FormState>());

      Future<bool> validate(WidgetTester tester, String text) async {
        await tester.pumpApp(
          Form(
            key: formKey,
            child: Column(
              children: [
                IngredientPicker(
                  name: name,
                  unit: unit,
                  ingredientLibraryId: cocktailsPantry.id,
                ),
              ],
            ),
          ),
          recipesBloc: recipesBloc,
        );
        name.text = text;
        final valid = formKey.currentState!.validate();
        await tester.pumpAndSettle();
        return valid;
      }

      testWidgets('accepts a name its library holds, ignoring case', (
        tester,
      ) async {
        expect(await validate(tester, ' GIN '), isTrue);
        expect(find.text('Pick or create an ingredient.'), findsNothing);
      });

      testWidgets('accepts a blank name', (tester) async {
        expect(await validate(tester, '  '), isTrue);
      });

      testWidgets('refuses a name only another library holds', (
        tester,
      ) async {
        expect(await validate(tester, 'Cinnamon'), isFalse);
        expect(find.text('Pick or create an ingredient.'), findsOneWidget);
      });

      testWidgets('refuses a name no library holds', (tester) async {
        expect(await validate(tester, 'Bourbon'), isFalse);
        expect(find.text('Pick or create an ingredient.'), findsOneWidget);
      });
    });

    testWidgets('parses the entry a name matches, or the create action', (
      tester,
    ) async {
      await pumpPicker(tester);

      final field = tester.widget<FAutocomplete<IngredientOption>>(
        find.byType(FAutocomplete<IngredientOption>),
      );

      expect(field.parse('gin'), CatalogOption(ginIngredient));
      expect(field.parse('Cinnamon'), const CreateOption('Cinnamon'));
      expect(field.parse(' '), isNull);
      expect(field.parse(null), isNull);
    });
  });
}
