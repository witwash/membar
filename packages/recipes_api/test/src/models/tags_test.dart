import 'package:recipes_api/recipes_api.dart';
import 'package:test/test.dart';

void main() {
  group('compareCaseInsensitive', () {
    test('orders regardless of case', () {
      final tags = ['zest', 'Aperol', 'bitter']..sort(compareCaseInsensitive);

      expect(tags, ['Aperol', 'bitter', 'zest']);
    });
  });

  group('foldCaseInsensitive', () {
    test('keeps the first spelling of a repeated value', () {
      expect(foldCaseInsensitive(['Bitter', 'BITTER', 'bitter']), ['Bitter']);
    });

    test('trims each value and drops the blanks', () {
      expect(foldCaseInsensitive(['  Stirred ', '   ', '']), ['Stirred']);
    });

    test('keeps the order the values arrived in', () {
      expect(foldCaseInsensitive(['Zest', 'Aperol']), ['Zest', 'Aperol']);
    });
  });
}
