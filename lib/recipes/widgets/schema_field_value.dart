import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// Formats [value] for display in the ambient locale.
///
/// [NumberFormat] renders a whole number as `92` rather than `92.0`, so no
/// trailing-zero trimming is needed on top of it.
String formatSchemaNumber(BuildContext context, num value) =>
    NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(value);

/// The display text [recipe] holds for [field], or null when the field has no
/// value.
///
/// This is the only place a schema value is turned into text, so "has a value"
/// and "renders as" can never disagree.
String? schemaFieldText(
  BuildContext context,
  FieldDefinition field,
  Recipe recipe,
) {
  if (field.type == FieldType.number) {
    final value = recipe.numberValue(field.id);
    return value == null ? null : formatSchemaNumber(context, value);
  }
  return recipe.textValue(field.id);
}

/// Renders [value] the way [field]'s type calls for: a Select as a badge, a
/// Number alongside its unit, and free text inline with its newlines intact.
class SchemaFieldValue extends StatelessWidget {
  /// Creates a [SchemaFieldValue] rendering [value] as [field] prescribes.
  ///
  /// [value] is the text [schemaFieldText] produced for the same field.
  const SchemaFieldValue({required this.field, required this.value, super.key});

  /// The schema field the value belongs to.
  final FieldDefinition field;

  /// The already-formatted value to render.
  final String value;

  @override
  Widget build(BuildContext context) {
    return switch (field.type) {
      FieldType.select => FBadge(child: Text(value)),
      FieldType.number => Text(
        field.unit == null ? value : '$value ${field.unit}',
      ),
      FieldType.text || FieldType.longText => Text(value),
    };
  }
}
