import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// Holds the live value of one schema field while the editor is open, and
/// knows what makes that value invalid.
///
/// There is one subclass per [FieldType], picked by the exhaustive switch in
/// the factory below, so adding a field type in a later slice is a compile
/// error here rather than a silently blank control.
sealed class SchemaFieldController {
  /// Creates the controller [field]'s type calls for, primed with whatever
  /// [recipe] already holds for it.
  ///
  /// [numberFormat] parses and formats a [FieldType.number] field in the app's
  /// locale, so a grouped entry such as `1,234` reads as 1234.
  factory SchemaFieldController({
    required FieldDefinition field,
    required NumberFormat numberFormat,
    Recipe? recipe,
  }) {
    return switch (field.type) {
      FieldType.text || FieldType.longText => _TextSchemaFieldController(
        field,
        recipe?.textValue(field.id) ?? '',
      ),
      FieldType.number => _NumberSchemaFieldController(
        field,
        numberFormat,
        recipe?.numberValue(field.id),
      ),
      FieldType.select => _SelectSchemaFieldController(
        field,
        _selectedOption(field, recipe),
      ),
    };
  }

  SchemaFieldController._(this.field) {
    _initialValue = value;
  }

  /// The schema field this controller stands for.
  final FieldDefinition field;

  late final Object? _initialValue;

  /// Whether the user changed this field since the editor opened.
  ///
  /// Only a changed field is written on save. An untouched one is left exactly
  /// as it is stored — which is what keeps a Select value the schema no longer
  /// offers, and which the control therefore shows as no selection, from being
  /// wiped by a round trip that never touched it.
  bool get isDirty => value != _initialValue;

  /// The value to store for [field], or null when it holds nothing.
  ///
  /// The editor omits a null value from `fieldValues` rather than storing a
  /// blank, so "absent" keeps its single representation.
  Object? get value;

  /// The error to show under the control, or null when the field is valid.
  String? validate(AppLocalizations l10n);

  /// Releases the underlying controller. Called from the editor's `dispose`.
  void dispose();

  /// The stored option, or null when the recipe holds no value or one the
  /// schema no longer offers.
  ///
  /// A stale value shows as no selection. Nothing more is needed: the editor
  /// saves its edits *over* the stored map, so an untouched stale value
  /// survives the round trip.
  static String? _selectedOption(FieldDefinition field, Recipe? recipe) {
    final stored = recipe?.textValue(field.id);
    return field.options!.contains(stored) ? stored : null;
  }
}

final class _TextSchemaFieldController extends SchemaFieldController {
  _TextSchemaFieldController(super.field, String initial)
    : controller = TextEditingController(text: initial),
      super._();

  final TextEditingController controller;

  @override
  Object? get value {
    final trimmed = controller.text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  String? validate(AppLocalizations l10n) => field.required && value == null
      ? l10n.recipeEditorRequiredFieldError
      : null;

  @override
  void dispose() => controller.dispose();
}

final class _NumberSchemaFieldController extends SchemaFieldController {
  _NumberSchemaFieldController(super.field, NumberFormat format, num? initial)
    : _format = format,
      controller = TextEditingController(
        text: initial == null ? '' : format.format(initial),
      ),
      super._();

  final NumberFormat _format;

  final TextEditingController controller;

  @override
  Object? get value => _parse(controller.text);

  @override
  String? validate(AppLocalizations l10n) {
    // Required means *present*, not truthy, so 0 satisfies it. Only a blank
    // field and an unparseable one fail, and they fail differently.
    if (controller.text.trim().isEmpty) {
      return field.required ? l10n.recipeEditorRequiredFieldError : null;
    }
    return _parse(controller.text) == null
        ? l10n.recipeEditorNumberFieldError
        : null;
  }

  @override
  void dispose() => controller.dispose();

  /// Parses through [NumberFormat] first so grouped input reads correctly.
  ///
  /// Replacing `,` with `.` instead would turn `1,234` into 1.234 in English,
  /// the only locale this app ships — a live bug, not a hypothetical one.
  num? _parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    num? parsed;
    try {
      parsed = _format.parse(trimmed);
    } on FormatException {
      parsed = num.tryParse(trimmed);
    }
    return parsed != null && parsed.isFinite ? parsed : null;
  }
}

final class _SelectSchemaFieldController extends SchemaFieldController {
  _SelectSchemaFieldController(super.field, String? initial)
    : controller = FSelectController<String>(
        value: initial,
        // Clearing a required Select could only produce a value the form
        // refuses to save, so only an optional one is toggleable.
        toggleable: !field.required,
      ),
      super._();

  final FSelectController<String> controller;

  @override
  Object? get value => controller.value;

  @override
  String? validate(AppLocalizations l10n) =>
      field.required && controller.value == null
      ? l10n.recipeEditorRequiredFieldError
      : null;

  @override
  void dispose() => controller.dispose();
}

/// The editor's control for a single schema field: the widget the field's
/// [FieldType] calls for, bound to [controller].
class SchemaFieldControl extends StatelessWidget {
  /// Creates the control [controller]'s field calls for.
  const SchemaFieldControl({required this.controller, super.key});

  /// The controller holding the field's live value.
  final SchemaFieldController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final field = controller.field;
    String? validate() => controller.validate(l10n);

    return switch (controller) {
      _TextSchemaFieldController(controller: final text) => FTextFormField(
        label: Text(field.label),
        control: FTextFieldControl.managed(controller: text),
        minLines: field.type == FieldType.longText ? 3 : null,
        maxLines: field.type == FieldType.longText ? 5 : 1,
        validator: (_) => validate(),
      ),
      _NumberSchemaFieldController(controller: final text) => FTextFormField(
        label: Text(
          field.unit == null ? field.label : '${field.label} (${field.unit})',
        ),
        control: FTextFieldControl.managed(controller: text),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (_) => validate(),
      ),
      _SelectSchemaFieldController(controller: final select) => FSelect<String>(
        label: Text(field.label),
        items: {for (final option in field.options!) option: option},
        control: FSelectControl.managed(controller: select),
        autovalidateMode: AutovalidateMode.disabled,
        validator: (_) => validate(),
      ),
    };
  }
}
