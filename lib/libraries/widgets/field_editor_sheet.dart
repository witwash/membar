import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/libraries/libraries.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:membar/ui/ui.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// What each [FieldType] is called in the field editor.
extension FieldTypeName on AppLocalizations {
  /// The name of [type]. The switch is exhaustive, so a new type is a compile
  /// error here rather than a blank entry in the type list.
  String fieldTypeName(FieldType type) => switch (type) {
    FieldType.text => fieldTypeText,
    FieldType.longText => fieldTypeLongText,
    FieldType.number => fieldTypeNumber,
    FieldType.select => fieldTypeSelect,
  };
}

/// Adds a field to a library, or edits one.
///
/// Either way the sheet saves the whole library with the field appended or
/// replaced in place; the storage layer works out what that does to the
/// recipes. A field's type is fixed once it exists, so editing locks it.
class FieldEditorSheet extends StatefulWidget {
  /// Creates a [FieldEditorSheet] editing [field] of [library], or adding a
  /// field to [library] when [field] is null.
  const FieldEditorSheet({required this.library, this.field, super.key});

  /// Opens the sheet, completing once it closes.
  ///
  /// The sheet's route sits above the provider, so the bloc is re-provided
  /// here.
  static Future<void> show(
    BuildContext context, {
    required Library library,
    FieldDefinition? field,
  }) {
    final bloc = context.read<RecipesBloc>();
    return showFSheet<void>(
      context: context,
      side: FLayout.btt,
      // Sized to its content, which scrolls when the keyboard leaves it less.
      mainAxisMaxRatio: null,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: FieldEditorSheet(library: library, field: field),
      ),
    );
  }

  /// The library the field belongs to, as it was when the sheet opened.
  final Library library;

  /// The field being edited, as it was when the sheet opened, or null when
  /// the sheet adds one.
  final FieldDefinition? field;

  @override
  State<FieldEditorSheet> createState() => _FieldEditorSheetState();
}

class _FieldEditorSheetState extends State<FieldEditorSheet> {
  // The order the type list offers them in, which is not the enum's.
  static const List<FieldType> _types = [
    FieldType.text,
    FieldType.longText,
    FieldType.number,
    FieldType.select,
  ];

  final _formKey = GlobalKey<FormState>();
  late final _labelController = TextEditingController(
    text: widget.field?.label,
  );
  late final _unitController = TextEditingController(text: widget.field?.unit);
  late final List<OptionRowControllers> _optionRows = [
    for (final option in widget.field?.optionsOrEmpty ?? const <String>[])
      _optionRow(original: option),
  ];
  late FieldType _type = widget.field?.type ?? FieldType.text;
  late bool _required = widget.field?.required ?? false;

  // Row ids are never reused, so removing a row does not hand its key — and
  // with it the State of its text field — to the row below.
  var _nextRowId = 0;
  var _optionsChecked = false;
  var _submitted = false;
  var _saveFailed = false;

  @override
  void dispose() {
    _labelController.dispose();
    _unitController.dispose();
    for (final row in _optionRows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;
    final editing = widget.field != null;
    final saving = context.select<RecipesBloc, bool>(
      (bloc) =>
          bloc.state.mutation == RecipesMutation.librarySaved &&
          bloc.state.mutationStatus == RecipesMutationStatus.loading,
    );
    final optionsError = _optionsChecked ? _optionsError(l10n) : null;

    return RecipesMutationListener(
      mutation: RecipesMutation.librarySaved,
      onSuccess: (_) {
        if (_submitted) Navigator.of(context).pop();
      },
      onFailure: () => setState(() => _saveFailed = true),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.background,
          border: Border(top: BorderSide(color: theme.colors.border)),
        ),
        child: SingleChildScrollView(
          padding: AppInsets.sheetContent,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.spacing200,
              children: [
                Text(
                  editing
                      ? l10n.fieldEditorEditTitle
                      : l10n.fieldEditorAddTitle,
                  style: theme.typography.display.xs,
                ),
                if (_saveFailed) FailureBanner(l10n.fieldEditorSaveFailure),
                FTextFormField(
                  label: Text(l10n.fieldEditorLabelLabel),
                  control: FTextFieldControl.managed(
                    controller: _labelController,
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validateLabel,
                ),
                FSelect<FieldType>(
                  label: Text(l10n.fieldEditorTypeLabel),
                  description: editing
                      ? Text(l10n.fieldEditorTypeLockedNote)
                      : null,
                  enabled: !editing,
                  items: {
                    for (final type in _types) l10n.fieldTypeName(type): type,
                  },
                  control: FSelectControl.lifted(
                    value: _type,
                    onChange: (type) => setState(() => _type = type ?? _type),
                  ),
                ),
                if (_type == FieldType.number)
                  FTextFormField(
                    label: Text(l10n.fieldEditorUnitLabel),
                    control: FTextFieldControl.managed(
                      controller: _unitController,
                    ),
                  ),
                if (_type == FieldType.select)
                  _OptionList(
                    rows: _optionRows,
                    error: optionsError,
                    onAdd: _addOption,
                    onRemove: _removeOption,
                  ),
                FCheckbox(
                  label: Text(l10n.fieldEditorRequiredLabel),
                  value: _required,
                  onChange: (checked) => setState(() => _required = checked),
                ),
                FButton(
                  onPress: saving ? null : () => unawaited(_save()),
                  child: Text(l10n.fieldEditorSaveLabel),
                ),
                FButton(
                  variant: FButtonVariant.outline,
                  onPress: () => Navigator.of(context).pop(),
                  child: Text(l10n.fieldEditorCancelLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  OptionRowControllers _optionRow({String? original}) =>
      OptionRowControllers(_nextRowId++, original: original)
        ..text.addListener(_onOptionChanged);

  /// Re-judges the options as they are typed, once a save has been refused,
  /// so the error line clears with the correction rather than at the next
  /// save.
  void _onOptionChanged() {
    if (_optionsChecked) setState(() {});
  }

  void _addOption() => setState(() => _optionRows.add(_optionRow()));

  void _removeOption(int index) {
    setState(() => _optionRows.removeAt(index).dispose());
  }

  ({List<String> options, Map<String, String> renames}) get _optionEdits =>
      optionEdits([
        for (final row in _optionRows)
          (original: row.original, text: row.text.text),
      ]);

  /// Refuses a label another field of the library carries. Only the form
  /// checks this: recipe values are keyed by field id, so the data layer has
  /// no stake in it.
  String? _validateLabel(String? value) {
    final l10n = context.l10n;
    final label = (value ?? '').trim();
    if (label.isEmpty) return l10n.fieldEditorLabelRequiredError;

    for (final other in widget.library.fields) {
      if (other.id != widget.field?.id &&
          compareCaseInsensitive(other.label, label) == 0) {
        return l10n.fieldEditorLabelTakenError(other.label);
      }
    }
    return null;
  }

  /// What is wrong with the option list, or null when it can be saved.
  ///
  /// Duplicates are judged between the rows' current texts, never against a
  /// row's own original, so retyping `dry` as `Dry` is a rename rather than a
  /// clash with itself.
  String? _optionsError(AppLocalizations l10n) {
    if (_type != FieldType.select) return null;

    final options = _optionEdits.options;
    if (options.isEmpty) return l10n.fieldEditorOptionsRequiredError;

    final folded = {for (final option in options) option.toLowerCase()};
    return folded.length == options.length
        ? null
        : l10n.fieldEditorOptionsDuplicateError;
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() => _optionsChecked = true);
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _optionsError(l10n) != null) return;

    final bloc = context.read<RecipesBloc>();
    final library = widget.library;
    final stored = widget.field;
    final (:options, :renames) = _optionEdits;
    final unit = _unitController.text.trim();
    final edited = FieldDefinition(
      id: stored?.id,
      label: _labelController.text,
      type: _type,
      required: _required,
      options: _type == FieldType.select ? options : null,
      unit: _type == FieldType.number && unit.isNotEmpty ? unit : null,
    );

    if (stored != null) {
      final recipeCount = bloc.state.recipeCountUsingOptions(
        library.id,
        stored.id,
        stored.optionsRemovedBy(edited, renames: renames),
      );
      if (recipeCount > 0) {
        final confirmed = await showConfirmDialog(
          context: context,
          title: l10n.fieldEditorRemoveOptionsDialogTitle,
          description: l10n.fieldEditorRemoveOptionsDialogDescription(
            recipeCount,
          ),
          confirmLabel: l10n.fieldEditorRemoveOptionsDialogConfirm,
          cancelLabel: l10n.fieldEditorRemoveOptionsDialogCancel,
        );
        if (!confirmed || !mounted) return;
      }
    }

    setState(() {
      _saveFailed = false;
      _submitted = true;
    });
    bloc.add(
      RecipesLibrarySaved(
        Library(
          id: library.id,
          name: library.name,
          fields: stored == null
              ? [...library.fields, edited]
              : [
                  for (final field in library.fields)
                    if (field.id == stored.id) edited else field,
                ],
        ),
        optionRenames: {if (renames.isNotEmpty) edited.id: renames},
      ),
    );
  }
}

/// The options of a choice field: one row each, what is wrong with them as a
/// whole, and the action that adds a row.
class _OptionList extends StatelessWidget {
  const _OptionList({
    required this.rows,
    required this.error,
    required this.onAdd,
    required this.onRemove,
  });

  final List<OptionRowControllers> rows;

  final String? error;

  final VoidCallback onAdd;

  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.spacing100,
      children: [
        Text(
          l10n.fieldEditorOptionsLabel,
          style: theme.typography.body.sm.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
        for (final (index, row) in rows.indexed)
          OptionRowField(
            key: ValueKey(row.id),
            number: index + 1,
            controllers: row,
            onRemove: () => onRemove(index),
          ),
        if (error case final error?)
          Semantics(
            liveRegion: true,
            child: Text(
              error,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.error,
              ),
            ),
          ),
        FButton(
          variant: FButtonVariant.outline,
          prefix: const Icon(FLucideIcons.plus),
          onPress: onAdd,
          child: Text(l10n.fieldEditorAddOptionLabel),
        ),
      ],
    );
  }
}
