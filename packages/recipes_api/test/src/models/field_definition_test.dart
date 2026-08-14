import 'package:recipes_api/recipes_api.dart';
import 'package:test/test.dart';

void main() {
  group('FieldDefinition', () {
    test('generates an id when none is given', () {
      final first = FieldDefinition(label: 'Garnish', type: FieldType.text);
      final second = FieldDefinition(label: 'Garnish', type: FieldType.text);

      expect(first.id, isNotEmpty);
      expect(first.id, isNot(equals(second.id)));
    });

    test('keeps the id it is given', () {
      final field = FieldDefinition(
        id: 'f1',
        label: 'Garnish',
        type: FieldType.text,
      );

      expect(field.id, equals('f1'));
    });

    test('trims the label', () {
      final field = FieldDefinition(
        label: '  Garnish  ',
        type: FieldType.text,
      );

      expect(field.label, equals('Garnish'));
    });

    test('is not required by default', () {
      expect(
        FieldDefinition(label: 'Garnish', type: FieldType.text).required,
        isFalse,
      );
    });

    test('exposes select options as an unmodifiable list', () {
      final field = FieldDefinition(
        label: 'Glassware',
        type: FieldType.select,
        options: const ['Coupe'],
      );

      expect(() => field.options!.add('Rocks'), throwsUnsupportedError);
    });

    group('asserts', () {
      test('on a blank label', () {
        expect(
          () => FieldDefinition(label: '  ', type: FieldType.text),
          throwsA(isA<AssertionError>()),
        );
      });

      test('on a select field with no options', () {
        expect(
          () => FieldDefinition(label: 'Glassware', type: FieldType.select),
          throwsA(isA<AssertionError>()),
        );
      });

      test('on a select field with an empty option list', () {
        expect(
          () => FieldDefinition(
            label: 'Glassware',
            type: FieldType.select,
            options: const [],
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('on a select field with duplicate options', () {
        expect(
          () => FieldDefinition(
            label: 'Glassware',
            type: FieldType.select,
            options: const ['Coupe', 'Coupe'],
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('on a non-select field carrying options', () {
        expect(
          () => FieldDefinition(
            label: 'Garnish',
            type: FieldType.text,
            options: const ['Lime'],
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('on a non-number field carrying a unit', () {
        expect(
          () => FieldDefinition(
            label: 'Garnish',
            type: FieldType.text,
            unit: 'g',
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    test('supports value equality', () {
      expect(
        FieldDefinition(id: 'f1', label: 'Garnish', type: FieldType.text),
        equals(
          FieldDefinition(id: 'f1', label: 'Garnish', type: FieldType.text),
        ),
      );
      expect(
        FieldDefinition(id: 'f1', label: 'Garnish', type: FieldType.text),
        isNot(
          equals(
            FieldDefinition(id: 'f2', label: 'Garnish', type: FieldType.text),
          ),
        ),
      );
    });

    group('json', () {
      test('round-trips a select field', () {
        final field = FieldDefinition(
          id: 'f1',
          label: 'Glassware',
          type: FieldType.select,
          required: true,
          options: const ['Coupe', 'Rocks'],
        );

        expect(FieldDefinition.fromJson(field.toJson()), equals(field));
      });

      test('round-trips a number field carrying a unit', () {
        final field = FieldDefinition(
          id: 'f2',
          label: 'Dose',
          type: FieldType.number,
          unit: 'g',
        );

        expect(FieldDefinition.fromJson(field.toJson()), equals(field));
      });

      test('round-trips a long text field', () {
        final field = FieldDefinition(
          id: 'f3',
          label: 'Tasting notes',
          type: FieldType.longText,
        );

        expect(FieldDefinition.fromJson(field.toJson()), equals(field));
      });

      test('decodes an unknown type as text', () {
        final field = FieldDefinition.fromJson(const {
          'id': 'f1',
          'label': 'Mystery',
          'type': 'colorPicker',
          'required': false,
        });

        expect(field.type, equals(FieldType.text));
      });
    });
  });

  group('optionsOrEmpty', () {
    test('is the option list of a select field', () {
      final field = FieldDefinition(
        label: 'Glassware',
        type: FieldType.select,
        options: const ['Coupe'],
      );

      expect(field.optionsOrEmpty, ['Coupe']);
    });

    test('is empty for a field that offers no choices', () {
      final field = FieldDefinition(label: 'Garnish', type: FieldType.text);

      expect(field.optionsOrEmpty, isEmpty);
    });
  });

  group('fromJson repairs a field that breaks its own contract', () {
    // The constructor's asserts are stripped in release, so a hand-edited blob
    // has to be brought back inside the contract on the way in rather than
    // crashing a screen later.
    test('decodes a select with no options as plain text', () {
      final field = FieldDefinition.fromJson(const {
        'id': 'field-glassware',
        'label': 'Glassware',
        'type': 'select',
        'required': false,
        'options': null,
        'unit': null,
      });

      expect(field.type, FieldType.text);
      expect(field.options, isNull);
    });

    test('decodes a select with an empty option list as plain text', () {
      final field = FieldDefinition.fromJson(const {
        'id': 'field-glassware',
        'label': 'Glassware',
        'type': 'select',
        'required': false,
        'options': <String>[],
        'unit': null,
      });

      expect(field.type, FieldType.text);
    });

    test('folds duplicate options rather than rejecting the field', () {
      final field = FieldDefinition.fromJson(const {
        'id': 'field-glassware',
        'label': 'Glassware',
        'type': 'select',
        'required': false,
        'options': ['Coupe', 'Coupe', 'Rocks'],
        'unit': null,
      });

      expect(field.options, ['Coupe', 'Rocks']);
    });

    test('drops options from a type that cannot carry them', () {
      final field = FieldDefinition.fromJson(const {
        'id': 'field-garnish',
        'label': 'Garnish',
        'type': 'text',
        'required': false,
        'options': ['Coupe'],
        'unit': null,
      });

      expect(field.options, isNull);
    });

    test('drops a unit from a type that cannot carry one', () {
      final field = FieldDefinition.fromJson(const {
        'id': 'field-garnish',
        'label': 'Garnish',
        'type': 'text',
        'required': false,
        'options': null,
        'unit': 'g',
      });

      expect(field.unit, isNull);
    });

    test('keeps a well-formed select untouched', () {
      final field = FieldDefinition.fromJson(const {
        'id': 'field-glassware',
        'label': 'Glassware',
        'type': 'select',
        'required': true,
        'options': ['Coupe', 'Rocks'],
        'unit': null,
      });

      expect(field.type, FieldType.select);
      expect(field.options, ['Coupe', 'Rocks']);
      expect(field.required, isTrue);
    });
  });
}
