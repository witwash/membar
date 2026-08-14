import 'dart:convert';

import 'package:recipes_api/recipes_api.dart';
import 'package:test/test.dart';

void main() {
  group('Library', () {
    test('generates an id when none is given', () {
      final first = Library(name: 'Cocktails');
      final second = Library(name: 'Cocktails');

      expect(first.id, isNotEmpty);
      expect(first.id, isNot(equals(second.id)));
    });

    test('keeps the id it is given', () {
      expect(Library(id: 'l1', name: 'Cocktails').id, equals('l1'));
    });

    test('trims the name', () {
      expect(Library(name: '  Cocktails  ').name, equals('Cocktails'));
    });

    test('asserts on a blank name', () {
      expect(() => Library(name: '  '), throwsA(isA<AssertionError>()));
    });

    test('defaults to an empty schema, exposed as unmodifiable', () {
      final library = Library(name: 'Cocktails');

      expect(library.fields, isEmpty);
      expect(
        () => library.fields.add(
          FieldDefinition(label: 'Garnish', type: FieldType.text),
        ),
        throwsUnsupportedError,
      );
    });

    test('keeps its fields in the order they are declared', () {
      final library = Library(
        name: 'Coffee',
        fields: [
          FieldDefinition(id: 'f1', label: 'Dose', type: FieldType.number),
          FieldDefinition(id: 'f2', label: 'Grind', type: FieldType.text),
        ],
      );

      expect(library.fields.map((field) => field.id), equals(['f1', 'f2']));
    });

    test('supports value equality', () {
      expect(
        Library(id: 'l1', name: 'Cocktails'),
        equals(Library(id: 'l1', name: 'Cocktails')),
      );
      expect(
        Library(id: 'l1', name: 'Cocktails'),
        isNot(equals(Library(id: 'l1', name: 'Coffee'))),
      );
    });

    test('round-trips through a JSON string', () {
      final library = Library(
        id: 'l1',
        name: 'Cocktails',
        fields: [
          FieldDefinition(
            id: 'f1',
            label: 'Glassware',
            type: FieldType.select,
            options: const ['Coupe', 'Rocks'],
          ),
          FieldDefinition(id: 'f2', label: 'Garnish', type: FieldType.text),
        ],
      );

      final decoded = Library.fromJson(
        json.decode(json.encode(library.toJson())) as Map<String, dynamic>,
      );

      expect(decoded, equals(library));
    });

    test('decodes a payload with no fields', () {
      final decoded = Library.fromJson(const {'id': 'l1', 'name': 'Cocktails'});

      expect(decoded.fields, isEmpty);
    });
  });
}
