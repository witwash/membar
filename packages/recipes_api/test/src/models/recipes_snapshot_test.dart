import 'package:recipes_api/recipes_api.dart';
import 'package:test/test.dart';

void main() {
  group('RecipesSnapshot', () {
    RecipesSnapshot buildSnapshot({String activeLibraryId = 'l1'}) =>
        RecipesSnapshot(
          libraries: [Library(id: 'l1', name: 'Cocktails')],
          recipes: [Recipe(id: 'r1', libraryId: 'l1', name: 'Negroni')],
          activeLibraryId: activeLibraryId,
        );

    test('exposes what it was built with', () {
      final snapshot = buildSnapshot();

      expect(snapshot.libraries.single.name, equals('Cocktails'));
      expect(snapshot.recipes.single.name, equals('Negroni'));
      expect(snapshot.activeLibraryId, equals('l1'));
    });

    test('supports value equality', () {
      expect(buildSnapshot(), equals(buildSnapshot()));
      expect(
        buildSnapshot(),
        isNot(equals(buildSnapshot(activeLibraryId: 'l2'))),
      );
    });
  });
}
