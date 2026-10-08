import 'dart:convert';

import 'package:recipes_api/recipes_api.dart';
import 'package:test/test.dart';

void main() {
  group('Unit', () {
    Unit roundTrip(Unit unit) => Unit.fromJson(
      json.decode(json.encode(unit.toJson())) as Map<String, dynamic>,
    );

    group('KnownUnit', () {
      test('is labelled with the standard unit name', () {
        expect(const KnownUnit(StandardUnit.ml).label, equals('ml'));
        expect(const KnownUnit(StandardUnit.barspoon).label, 'barspoon');
      });

      test('round-trips every standard unit', () {
        for (final standard in StandardUnit.values) {
          final unit = KnownUnit(standard);

          expect(roundTrip(unit), equals(unit));
        }
      });

      test('serializes with the standard discriminator', () {
        expect(
          const KnownUnit(StandardUnit.oz).toJson(),
          equals({'kind': 'standard', 'unit': 'oz'}),
        );
      });
    });

    group('CustomUnit', () {
      test('trims the label', () {
        expect(CustomUnit('  pinch ').label, equals('pinch'));
      });

      test('asserts on a blank label', () {
        expect(() => CustomUnit('   '), throwsA(isA<AssertionError>()));
      });

      test('round-trips', () {
        final unit = CustomUnit('pinch');

        expect(roundTrip(unit), equals(unit));
      });

      test('serializes with the custom discriminator', () {
        expect(
          CustomUnit('pinch').toJson(),
          equals({'kind': 'custom', 'label': 'pinch'}),
        );
      });

      test('keeps a label spelled like a standard unit custom', () {
        expect(roundTrip(CustomUnit('ml')), isA<CustomUnit>());
      });
    });

    test('supports value equality', () {
      expect(
        const KnownUnit(StandardUnit.ml),
        equals(const KnownUnit(StandardUnit.ml)),
      );
      expect(CustomUnit('pinch'), equals(CustomUnit('pinch')));
      expect(
        const KnownUnit(StandardUnit.ml),
        isNot(equals(const KnownUnit(StandardUnit.cl))),
      );
    });

    test('never equates a known unit with a custom one of the same label', () {
      expect(const KnownUnit(StandardUnit.ml), isNot(equals(CustomUnit('ml'))));
    });

    test('decodes an unrecognised standard unit as a custom one', () {
      expect(
        Unit.fromJson(const {'kind': 'standard', 'unit': 'gill'}),
        equals(CustomUnit('gill')),
      );
    });

    test('throws a FormatException for an unknown kind', () {
      expect(
        () => Unit.fromJson(const {'kind': 'metric', 'label': 'ml'}),
        throwsFormatException,
      );
    });
  });
}
