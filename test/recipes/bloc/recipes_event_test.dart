import 'package:flutter_test/flutter_test.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';

void main() {
  group('RecipesEvent', () {
    test('RecipesSubscriptionRequested supports value equality', () {
      // Deliberately not const: two const instances are canonicalized into
      // one, so equality would short-circuit on identity and never reach the
      // props this asserts.
      // ignore: prefer_const_constructors
      expect(RecipesSubscriptionRequested(), RecipesSubscriptionRequested());
    });

    test('RecipesRecipeSaved carries the recipe', () {
      final recipe = Recipe(id: 'r1', libraryId: 'l1', name: 'Negroni');
      final other = Recipe(id: 'r2', libraryId: 'l1', name: 'Daiquiri');

      expect(RecipesRecipeSaved(recipe), RecipesRecipeSaved(recipe));
      expect(RecipesRecipeSaved(recipe), isNot(RecipesRecipeSaved(other)));
    });

    test('RecipesRecipeDeleted carries the id', () {
      expect(
        const RecipesRecipeDeleted('r1'),
        const RecipesRecipeDeleted('r1'),
      );
      expect(
        const RecipesRecipeDeleted('r1'),
        isNot(const RecipesRecipeDeleted('r2')),
      );
    });

    test('RecipesLibrarySelected carries the library id', () {
      expect(
        const RecipesLibrarySelected('l1'),
        const RecipesLibrarySelected('l1'),
      );
      expect(
        const RecipesLibrarySelected('l1'),
        isNot(const RecipesLibrarySelected('l2')),
      );
    });

    test('RecipesSearchTermChanged carries the term', () {
      expect(
        const RecipesSearchTermChanged('neg'),
        const RecipesSearchTermChanged('neg'),
      );
      expect(
        const RecipesSearchTermChanged('neg'),
        isNot(const RecipesSearchTermChanged('dai')),
      );
    });

    test('RecipesTagFilterToggled carries the tag', () {
      expect(
        const RecipesTagFilterToggled('Classic'),
        const RecipesTagFilterToggled('Classic'),
      );
      expect(
        const RecipesTagFilterToggled('Classic'),
        isNot(const RecipesTagFilterToggled('Bitter')),
      );
    });
  });
}
