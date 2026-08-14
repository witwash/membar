import 'package:recipes_api/recipes_api.dart';
import 'package:test/test.dart';

/// Builds `id_0`, `id_1`, … so a seeded template's ids can be named in a test.
String Function() _counterIds() {
  var next = 0;
  return () => 'id_${next++}';
}

void main() {
  group('LibraryTemplates', () {
    test('generates uuids by default', () {
      const templates = LibraryTemplates();

      expect(templates.cocktails().id, isNotEmpty);
      expect(
        templates.cocktails().id,
        isNot(equals(templates.cocktails().id)),
      );
    });

    test('generates deterministic ids from an injected builder', () {
      final templates = LibraryTemplates(idBuilder: _counterIds());

      final cocktails = templates.cocktails();

      expect(cocktails.id, equals('id_0'));
      expect(
        cocktails.fields.map((field) => field.id),
        equals(['id_1', 'id_2']),
      );
    });

    group('cocktails', () {
      test('declares Glassware as a select and Garnish as text', () {
        final cocktails = LibraryTemplates(
          idBuilder: _counterIds(),
        ).cocktails();

        expect(cocktails.name, equals('Cocktails'));
        expect(
          cocktails.fields.map((field) => field.label),
          equals(['Glassware', 'Garnish']),
        );
        expect(cocktails.fields.first.type, equals(FieldType.select));
        expect(cocktails.fields.first.options, isNotEmpty);
        expect(cocktails.fields.last.type, equals(FieldType.text));
      });

      test('leaves every field optional', () {
        final cocktails = LibraryTemplates(
          idBuilder: _counterIds(),
        ).cocktails();

        expect(cocktails.fields.every((field) => !field.required), isTrue);
      });
    });

    group('coffee', () {
      test('declares one field per brewing variable', () {
        final coffee = LibraryTemplates(idBuilder: _counterIds()).coffee();

        expect(coffee.name, equals('Coffee'));
        expect(
          coffee.fields.map((field) => field.label),
          equals([
            'Brew method',
            'Dose',
            'Water temp',
            'Grind',
            'Tasting notes',
          ]),
        );
        expect(
          coffee.fields.map((field) => field.type),
          equals([
            FieldType.select,
            FieldType.number,
            FieldType.number,
            FieldType.text,
            FieldType.longText,
          ]),
        );
      });

      test('carries units on its number fields', () {
        final coffee = LibraryTemplates(idBuilder: _counterIds()).coffee();

        expect(coffee.fields[1].unit, equals('g'));
        expect(coffee.fields[2].unit, equals('°C'));
      });
    });

    group('all', () {
      test('seeds cocktails first, so a fresh install opens on it', () {
        final all = LibraryTemplates(idBuilder: _counterIds()).all();

        expect(
          all.map((library) => library.name),
          equals([
            'Cocktails',
            'Coffee',
          ]),
        );
      });

      test('gives every library and field a distinct id', () {
        final all = LibraryTemplates(idBuilder: _counterIds()).all();

        final ids = [
          for (final library in all) ...[
            library.id,
            ...library.fields.map((field) => field.id),
          ],
        ];

        expect(ids.toSet(), hasLength(ids.length));
      });
    });
  });
}
