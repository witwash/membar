import 'package:flutter_test/flutter_test.dart';
import 'package:membar/starter_catalog/starter_catalog.dart';
import 'package:starter_recipes_repository/starter_recipes_repository.dart';

void main() {
  group('StarterCatalogState', () {
    const negroni = StarterRecipe(key: 'negroni', name: 'Negroni');
    const daiquiri = StarterRecipe(key: 'daiquiri', name: 'Daiquiri');
    const set = StarterSet(ingredients: [], recipes: [negroni, daiquiri]);

    test('offers nothing before the set has loaded', () {
      const state = StarterCatalogState(selectedKeys: {'negroni'});

      expect(state.visibleRecipes, isEmpty);
      expect(state.selectedRecipes, isEmpty);
      expect(state.allVisibleSelected, isFalse);
    });

    test('lists the selected recipes in catalog order', () {
      const state = StarterCatalogState(
        set: set,
        selectedKeys: {'daiquiri', 'negroni'},
      );

      expect(state.selectedRecipes, [negroni, daiquiri]);
    });

    test('is not all-selected when the search matches nothing', () {
      const state = StarterCatalogState(
        set: set,
        searchTerm: 'martini',
        selectedKeys: {'negroni', 'daiquiri'},
      );

      expect(state.allVisibleSelected, isFalse);
    });

    test('copyWith keeps every field it is not given', () {
      const state = StarterCatalogState(
        status: StarterCatalogStatus.success,
        set: set,
        searchTerm: 'neg',
        selectedKeys: {'negroni'},
        system: MeasureSystem.imperial,
      );

      expect(state.copyWith(), equals(state));
      expect(
        state.copyWith(searchTerm: ''),
        isNot(equals(state)),
      );
    });
  });
}
