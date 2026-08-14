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
  Future<void> setActiveLibraryId(String id) async {}

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
      await api.setActiveLibraryId('l1');
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

  group('RecipesPersistenceException', () {
    test('carries the reason the write failed', () {
      const exception = RecipesPersistenceException('disk full');

      expect(exception.message, equals('disk full'));
      expect(exception.toString(), contains('disk full'));
    });
  });
}
