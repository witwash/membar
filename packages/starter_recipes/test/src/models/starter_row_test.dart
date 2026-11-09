import 'package:flutter_test/flutter_test.dart';
import 'package:recipes_api/recipes_api.dart';
import 'package:starter_recipes/starter_recipes.dart';

void main() {
  group(StarterRow, () {
    group('fromJson', () {
      test('parses a volume row', () {
        expect(
          StarterRow.fromJson(const {
            'ingredient': 'lime_juice',
            'ml': '22.5',
            'oz': '0.75',
          }),
          equals(
            const StarterRow(ingredient: 'lime_juice', ml: '22.5', oz: '0.75'),
          ),
        );
      });

      test('parses a counted row', () {
        expect(
          StarterRow.fromJson(const {
            'ingredient': 'angostura_bitters',
            'quantity': '2',
            'unit': 'dash',
          }),
          equals(
            const StarterRow(
              ingredient: 'angostura_bitters',
              quantity: '2',
              unit: StandardUnit.dash,
            ),
          ),
        );
      });

      test('rejects a row with neither form', () {
        expect(
          () => StarterRow.fromJson(const {'ingredient': 'gin'}),
          throwsA(isA<AssertionError>()),
        );
      });

      test('rejects a row with both forms', () {
        expect(
          () => StarterRow.fromJson(const {
            'ingredient': 'gin',
            'ml': '30',
            'oz': '1',
            'quantity': '1',
            'unit': 'piece',
          }),
          throwsA(isA<AssertionError>()),
        );
      });

      test('rejects a volume row missing its oz', () {
        expect(
          () => StarterRow.fromJson(const {'ingredient': 'gin', 'ml': '30'}),
          throwsA(isA<AssertionError>()),
        );
      });

      test('throws on an unknown unit', () {
        expect(
          () => StarterRow.fromJson(const {
            'ingredient': 'gin',
            'quantity': '1',
            'unit': 'gill',
          }),
          throwsArgumentError,
        );
      });
    });

    group('measured', () {
      const volume = StarterRow(ingredient: 'gin', ml: '45', oz: '1.5');
      const counted = StarterRow(
        ingredient: 'salt',
        quantity: '1',
        unit: StandardUnit.pinch,
      );

      test('gives a volume in ml for metric', () {
        expect(
          volume.measured(MeasureSystem.metric),
          equals(('45', StandardUnit.ml)),
        );
      });

      test('gives a volume in oz for imperial', () {
        expect(
          volume.measured(MeasureSystem.imperial),
          equals(('1.5', StandardUnit.oz)),
        );
      });

      test('gives a counted row unchanged in either system', () {
        for (final system in MeasureSystem.values) {
          expect(
            counted.measured(system),
            equals(('1', StandardUnit.pinch)),
          );
        }
      });
    });
  });
}
