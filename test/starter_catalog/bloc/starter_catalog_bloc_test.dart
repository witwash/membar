import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:membar/starter_catalog/starter_catalog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';
import 'package:starter_recipes_repository/starter_recipes_repository.dart';

class _MockStarterRecipesRepository extends Mock
    implements StarterRecipesRepository {}

void main() {
  group('StarterCatalogBloc', () {
    late StarterRecipesRepository repository;

    const negroni = StarterRecipe(key: 'negroni', name: 'Negroni');
    const whiskeySour = StarterRecipe(
      key: 'whiskey-sour',
      name: 'Whiskey Sour',
    );
    const amarettoSour = StarterRecipe(
      key: 'amaretto-sour',
      name: 'Amaretto Sour',
    );
    const set = StarterSet(
      ingredients: [],
      recipes: [negroni, whiskeySour, amarettoSour],
    );
    const loaded = StarterCatalogState(
      status: StarterCatalogStatus.success,
      set: set,
    );

    setUp(() {
      repository = _MockStarterRecipesRepository();
    });

    StarterCatalogBloc buildBloc() => StarterCatalogBloc(
      starterRecipesRepository: repository,
      template: LibraryTemplate.cocktails,
    );

    test('starts in the initial state', () {
      expect(buildBloc().state, const StarterCatalogState());
    });

    group('StarterCatalogRequested', () {
      blocTest<StarterCatalogBloc, StarterCatalogState>(
        "emits loading then success with the template's set",
        setUp: () => when(
          () => repository.load(LibraryTemplate.cocktails),
        ).thenAnswer((_) async => set),
        build: buildBloc,
        act: (bloc) => bloc.add(const StarterCatalogRequested()),
        expect: () => const [
          StarterCatalogState(status: StarterCatalogStatus.loading),
          loaded,
        ],
      );

      blocTest<StarterCatalogBloc, StarterCatalogState>(
        'emits loading then failure when the load throws',
        setUp: () => when(
          () => repository.load(LibraryTemplate.cocktails),
        ).thenThrow(const FormatException('bad bundle')),
        build: buildBloc,
        act: (bloc) => bloc.add(const StarterCatalogRequested()),
        expect: () => const [
          StarterCatalogState(status: StarterCatalogStatus.loading),
          StarterCatalogState(status: StarterCatalogStatus.failure),
        ],
      );
    });

    blocTest<StarterCatalogBloc, StarterCatalogState>(
      'StarterCatalogSearchChanged narrows the visible recipes, ignoring case',
      build: buildBloc,
      seed: () => loaded,
      act: (bloc) => bloc.add(const StarterCatalogSearchChanged(' SOUR ')),
      verify: (bloc) => expect(bloc.state.visibleRecipes, [
        whiskeySour,
        amarettoSour,
      ]),
    );

    blocTest<StarterCatalogBloc, StarterCatalogState>(
      'StarterCatalogRecipeToggled selects a recipe, then deselects it',
      build: buildBloc,
      seed: () => loaded,
      act: (bloc) => bloc
        ..add(const StarterCatalogRecipeToggled('negroni'))
        ..add(const StarterCatalogRecipeToggled('negroni')),
      expect: () => [
        loaded.copyWith(selectedKeys: {'negroni'}),
        loaded.copyWith(selectedKeys: {}),
      ],
    );

    group('StarterCatalogVisibleToggled', () {
      final searched = loaded.copyWith(
        searchTerm: 'sour',
        selectedKeys: {'negroni'},
      );

      blocTest<StarterCatalogBloc, StarterCatalogState>(
        'selects the visible recipes, then deselects them, leaving hidden '
        'selections alone',
        build: buildBloc,
        seed: () => searched,
        act: (bloc) => bloc
          ..add(const StarterCatalogVisibleToggled())
          ..add(const StarterCatalogVisibleToggled()),
        expect: () => [
          searched.copyWith(
            selectedKeys: {'negroni', 'whiskey-sour', 'amaretto-sour'},
          ),
          searched,
        ],
      );

      blocTest<StarterCatalogBloc, StarterCatalogState>(
        'selects every visible recipe when only some are selected',
        build: buildBloc,
        seed: () => loaded.copyWith(selectedKeys: {'negroni'}),
        act: (bloc) => bloc.add(const StarterCatalogVisibleToggled()),
        expect: () => [
          loaded.copyWith(
            selectedKeys: {'negroni', 'whiskey-sour', 'amaretto-sour'},
          ),
        ],
      );
    });

    blocTest<StarterCatalogBloc, StarterCatalogState>(
      'StarterCatalogMeasureSystemChanged keeps the selection',
      build: buildBloc,
      seed: () => loaded.copyWith(selectedKeys: {'negroni'}),
      act: (bloc) => bloc.add(
        const StarterCatalogMeasureSystemChanged(MeasureSystem.imperial),
      ),
      expect: () => [
        loaded.copyWith(
          selectedKeys: {'negroni'},
          system: MeasureSystem.imperial,
        ),
      ],
    );
  });

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
  });
}
