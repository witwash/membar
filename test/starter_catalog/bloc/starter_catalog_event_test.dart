import 'package:flutter_test/flutter_test.dart';
import 'package:membar/starter_catalog/starter_catalog.dart';
import 'package:starter_recipes_repository/starter_recipes_repository.dart';

void main() {
  group('StarterCatalogEvent', () {
    test('StarterCatalogRequested supports value equality', () {
      // Deliberately not const: two const instances are canonicalized into
      // one, so equality would short-circuit on identity and never reach the
      // props this asserts.
      // ignore: prefer_const_constructors
      expect(StarterCatalogRequested(), StarterCatalogRequested());
    });

    test('StarterCatalogSearchChanged carries the term', () {
      expect(
        const StarterCatalogSearchChanged('sour'),
        const StarterCatalogSearchChanged('sour'),
      );
      expect(
        const StarterCatalogSearchChanged('sour'),
        isNot(const StarterCatalogSearchChanged('fizz')),
      );
    });

    test('StarterCatalogRecipeToggled carries the key', () {
      expect(
        const StarterCatalogRecipeToggled('negroni'),
        const StarterCatalogRecipeToggled('negroni'),
      );
      expect(
        const StarterCatalogRecipeToggled('negroni'),
        isNot(const StarterCatalogRecipeToggled('daiquiri')),
      );
    });

    test('StarterCatalogVisibleToggled supports value equality', () {
      // Not const, for the same reason as StarterCatalogRequested above.
      // ignore: prefer_const_constructors
      expect(StarterCatalogVisibleToggled(), StarterCatalogVisibleToggled());
    });

    test('StarterCatalogMeasureSystemChanged carries the system', () {
      expect(
        const StarterCatalogMeasureSystemChanged(MeasureSystem.imperial),
        const StarterCatalogMeasureSystemChanged(MeasureSystem.imperial),
      );
      expect(
        const StarterCatalogMeasureSystemChanged(MeasureSystem.imperial),
        isNot(const StarterCatalogMeasureSystemChanged(MeasureSystem.metric)),
      );
    });
  });
}
