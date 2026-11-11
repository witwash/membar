// Deliberately not const: two const instances are canonicalized into one, so
// equality would short-circuit on identity and never reach the props asserted.
// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:membar/starter_catalog/starter_catalog.dart';
import 'package:starter_recipes_repository/starter_recipes_repository.dart';

void main() {
  group('StarterCatalogEvent', () {
    test('StarterCatalogRequested supports value equality', () {
      expect(StarterCatalogRequested(), StarterCatalogRequested());
    });

    test('StarterCatalogSearchChanged carries the term', () {
      expect(
        StarterCatalogSearchChanged('sour'),
        StarterCatalogSearchChanged('sour'),
      );
      expect(
        StarterCatalogSearchChanged('sour'),
        isNot(StarterCatalogSearchChanged('fizz')),
      );
    });

    test('StarterCatalogRecipeToggled carries the key', () {
      expect(
        StarterCatalogRecipeToggled('negroni'),
        StarterCatalogRecipeToggled('negroni'),
      );
      expect(
        StarterCatalogRecipeToggled('negroni'),
        isNot(StarterCatalogRecipeToggled('daiquiri')),
      );
    });

    test('StarterCatalogVisibleToggled supports value equality', () {
      expect(StarterCatalogVisibleToggled(), StarterCatalogVisibleToggled());
    });

    test('StarterCatalogMeasureSystemChanged carries the system', () {
      expect(
        StarterCatalogMeasureSystemChanged(MeasureSystem.imperial),
        StarterCatalogMeasureSystemChanged(MeasureSystem.imperial),
      );
      expect(
        StarterCatalogMeasureSystemChanged(MeasureSystem.imperial),
        isNot(StarterCatalogMeasureSystemChanged(MeasureSystem.metric)),
      );
    });
  });
}
