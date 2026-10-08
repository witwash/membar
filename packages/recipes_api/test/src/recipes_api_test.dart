import 'package:recipes_api/recipes_api.dart';
import 'package:test/test.dart';

class _FakeRecipesApi extends RecipesApi {
  const _FakeRecipesApi();

  @override
  Stream<RecipesSnapshot> watch() => const Stream.empty();

  @override
  Future<void> saveRecipe(Recipe recipe) async {}

  @override
  Future<void> deleteRecipe(String id) async {}

  @override
  Future<void> saveIngredient(CatalogIngredient ingredient) async {}

  @override
  Future<void> importIngredients(List<CatalogIngredient> ingredients) async {}

  @override
  Future<void> deleteIngredient(String id) async {}

  @override
  Future<void> setActiveLibraryId(String id) async {}

  @override
  Future<void> saveLibrary(
    Library library, {
    Map<String, Map<String, String>> optionRenames = const {},
  }) async {}

  @override
  Future<void> deleteLibrary(String id, {required String successorId}) async {}

  @override
  Future<void> close() async {}
}

void main() {
  group('RecipesApi', () {
    test('can be implemented', () async {
      const api = _FakeRecipesApi();

      expect(api.watch(), emitsDone);
      await api.saveRecipe(Recipe(libraryId: 'l1', name: 'Negroni'));
      await api.deleteRecipe('r1');
      await api.saveIngredient(
        CatalogIngredient(name: 'Gin', libraryIds: const {'l1'}),
      );
      await api.importIngredients(const []);
      await api.deleteIngredient('i1');
      await api.setActiveLibraryId('l1');
      await api.saveLibrary(Library(name: 'Tea'));
      await api.deleteLibrary('l1', successorId: 'l2');
      await api.close();
    });
  });

  group('RecipeNotFoundException', () {
    test('names the id it was thrown for', () {
      const exception = RecipeNotFoundException('r1');

      expect(exception.id, equals('r1'));
      expect(exception.toString(), contains('r1'));
    });
  });

  group('IngredientNotFoundException', () {
    test('names the id it was thrown for', () {
      const exception = IngredientNotFoundException('i1');

      expect(exception.id, equals('i1'));
      expect(exception.toString(), contains('i1'));
    });
  });

  group('IngredientNameTakenException', () {
    test('names the name that is taken', () {
      const exception = IngredientNameTakenException('Gin');

      expect(exception.name, equals('Gin'));
      expect(exception.toString(), contains('Gin'));
    });
  });

  group('IngredientInUseException', () {
    test('names the id and how many recipes use it', () {
      const exception = IngredientInUseException('i1', 4);

      expect(exception.id, equals('i1'));
      expect(exception.recipeCount, equals(4));
      expect(exception.toString(), allOf(contains('i1'), contains('4')));
    });
  });

  group('LibraryNameTakenException', () {
    test('names the name that is taken', () {
      const exception = LibraryNameTakenException('Tea');

      expect(exception.name, equals('Tea'));
      expect(exception.toString(), contains('Tea'));
    });
  });

  group('LibraryNotFoundException', () {
    test('names the id it was thrown for', () {
      const exception = LibraryNotFoundException('l1');

      expect(exception.id, equals('l1'));
      expect(exception.toString(), contains('l1'));
    });
  });

  group('RecipesPersistenceException', () {
    test('carries the reason the write failed', () {
      const exception = RecipesPersistenceException('disk full');

      expect(exception.message, equals('disk full'));
      expect(exception.toString(), contains('disk full'));
    });
  });
}
