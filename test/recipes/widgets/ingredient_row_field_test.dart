import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

class _MockRecipesBloc extends MockBloc<RecipesEvent, RecipesState>
    implements RecipesBloc {}

void main() {
  group('IngredientRowControllers', () {
    final state = RecipesState(
      ingredientLibraries: [cocktailsPantry, coffeeShelf],
      ingredients: [ginIngredient, sugarIngredient, cinnamonIngredient],
    );

    test('primes each controller from the ingredient and its entry', () {
      final controllers = IngredientRowControllers(
        0,
        ingredient: Ingredient(
          catalogId: ginIngredient.id,
          quantity: '2',
          unit: 'oz',
        ),
        entry: ginIngredient,
      );
      addTearDown(controllers.dispose);

      expect(controllers.name.text, 'Gin');
      expect(controllers.quantity.text, '2');
      expect(controllers.unit.text, 'oz');
      expect(controllers.state, ['Gin', '2', 'oz']);
    });

    test('shows the current name of the entry the ingredient references', () {
      final controllers = IngredientRowControllers(
        0,
        ingredient: Ingredient(catalogId: ginIngredient.id),
        entry: CatalogIngredient(
          id: ginIngredient.id,
          name: 'London Dry Gin',
          ingredientLibraryId: ginIngredient.ingredientLibraryId,
        ),
      );
      addTearDown(controllers.dispose);

      expect(controllers.name.text, 'London Dry Gin');
    });

    test('opens blank when the entry it references is gone', () {
      final controllers = IngredientRowControllers(
        0,
        ingredient: Ingredient(catalogId: 'ingredient-gone', quantity: '2'),
      );
      addTearDown(controllers.dispose);

      expect(controllers.name.text, isEmpty);
      expect(
        controllers.ingredientIn(
          state,
          ingredientLibraryId: cocktailsPantry.id,
        ),
        isNull,
      );
    });

    test('starts blank when there is no ingredient yet', () {
      final controllers = IngredientRowControllers(0);
      addTearDown(controllers.dispose);

      expect(
        controllers.ingredientIn(
          const RecipesState(),
          ingredientLibraryId: cocktailsPantry.id,
        ),
        isNull,
      );
      expect(controllers.state, ['', '', '']);
    });

    test(
      'reads a row with no name as no ingredient, whatever else it holds',
      () {
        final controllers = IngredientRowControllers(0);
        addTearDown(controllers.dispose);
        controllers.quantity.text = '2';

        expect(
          controllers.ingredientIn(
            state,
            ingredientLibraryId: cocktailsPantry.id,
          ),
          isNull,
        );
        expect(
          controllers.isUnknownIn(
            state,
            ingredientLibraryId: cocktailsPantry.id,
          ),
          isFalse,
        );
      },
    );

    test('links to the entry its name matches, ignoring case', () {
      final controllers = IngredientRowControllers(0);
      addTearDown(controllers.dispose);
      controllers.name.text = ' gIN ';
      controllers.quantity.text = '2';

      expect(
        controllers.ingredientIn(
          state,
          ingredientLibraryId: cocktailsPantry.id,
        ),
        Ingredient(catalogId: ginIngredient.id, quantity: '2'),
      );
      expect(
        controllers.isUnknownIn(
          state,
          ingredientLibraryId: cocktailsPantry.id,
        ),
        isFalse,
      );
    });

    test('is unknown when its name matches no entry', () {
      final controllers = IngredientRowControllers(0);
      addTearDown(controllers.dispose);
      controllers.name.text = 'Gin and tonic';

      expect(
        controllers.ingredientIn(
          state,
          ingredientLibraryId: cocktailsPantry.id,
        ),
        isNull,
      );
      expect(
        controllers.isUnknownIn(
          state,
          ingredientLibraryId: cocktailsPantry.id,
        ),
        isTrue,
      );
    });

    test('is unknown when only another ingredient library holds its name', () {
      final controllers = IngredientRowControllers(0);
      addTearDown(controllers.dispose);
      controllers.name.text = 'Cinnamon';

      expect(
        controllers.ingredientIn(
          state,
          ingredientLibraryId: cocktailsPantry.id,
        ),
        isNull,
      );
      expect(
        controllers.isUnknownIn(
          state,
          ingredientLibraryId: cocktailsPantry.id,
        ),
        isTrue,
      );
    });
  });

  group('IngredientRowField', () {
    late IngredientRowControllers controllers;

    late RecipesBloc recipesBloc;

    setUp(() {
      recipesBloc = _MockRecipesBloc();
      when(() => recipesBloc.state).thenReturn(
        RecipesState(activeLibraryId: cocktailsLibrary.id),
      );
      controllers = IngredientRowControllers(
        0,
        ingredient: Ingredient(
          catalogId: ginIngredient.id,
          quantity: '2',
          unit: 'oz',
        ),
        entry: ginIngredient,
      );
      addTearDown(controllers.dispose);
    });

    Future<void> pumpRow(
      WidgetTester tester, {
      VoidCallback onRemove = _noop,
    }) => tester.pumpApp(
      IngredientRowField(
        controllers: controllers,
        ingredientLibraryId: cocktailsPantry.id,
        onRemove: onRemove,
      ),
      recipesBloc: recipesBloc,
    );

    testWidgets('renders each controller behind its own label', (tester) async {
      await pumpRow(tester);

      expect(
        tester
            .widget<IngredientPicker>(find.byType(IngredientPicker))
            .ingredientLibraryId,
        cocktailsPantry.id,
      );
      expect(
        find.descendant(
          of: find.byKey(controllers.nameKey),
          matching: find.byType(IngredientPicker),
        ),
        findsOneWidget,
      );
      expect(find.text('Ingredient'), findsOneWidget);
      expect(find.text('Quantity'), findsOneWidget);
      expect(find.text('Unit'), findsOneWidget);
      expect(find.text('Gin'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('oz'), findsOneWidget);
    });

    testWidgets('writes typed text back to the controller', (tester) async {
      await pumpRow(tester);

      await tester.enterText(find.byType(EditableText).first, 'Campari');

      expect(controllers.name.text, 'Campari');
    });

    testWidgets('calls onRemove when the remove action is tapped', (
      tester,
    ) async {
      var removed = 0;
      await pumpRow(tester, onRemove: () => removed++);

      await tester.tap(find.bySemanticsLabel('Remove ingredient'));
      await tester.pumpAndSettle();

      expect(removed, 1);
    });
  });
}

void _noop() {}
