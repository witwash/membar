import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:membar/ui/ui.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// Adds an ingredient to the catalog from inside the recipe editor: a name and
/// a default unit, scoped to the library being browsed.
///
/// A sheet rather than a pushed page, so the editor underneath keeps its
/// controllers and its dirty check untouched.
class IngredientCreateSheet extends StatefulWidget {
  /// Creates an [IngredientCreateSheet] whose name field starts as [name].
  const IngredientCreateSheet({required this.name, super.key});

  /// Opens the sheet with its name field prefilled with [name].
  ///
  /// Resolves to the entry the row should use, or null when the sheet was
  /// dismissed. The sheet's route sits above the provider, so the bloc is
  /// re-provided here.
  static Future<CatalogIngredient?> show(
    BuildContext context, {
    required String name,
  }) {
    final bloc = context.read<RecipesBloc>();
    return showFSheet<CatalogIngredient>(
      context: context,
      side: FLayout.btt,
      // Sized to its content, which scrolls when the keyboard leaves it less.
      mainAxisMaxRatio: null,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: IngredientCreateSheet(name: name),
      ),
    );
  }

  /// What the name field starts as: whatever was typed into the row.
  final String name;

  @override
  State<IngredientCreateSheet> createState() => _IngredientCreateSheetState();
}

class _IngredientCreateSheetState extends State<IngredientCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.name);
  final _customUnitController = TextEditingController();

  StandardUnit? _standardUnit;
  var _custom = false;
  var _saveFailed = false;
  CatalogIngredient? _pending;

  @override
  void dispose() {
    _nameController.dispose();
    _customUnitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;
    final saving = context.select<RecipesBloc, bool>(
      (bloc) =>
          bloc.state.mutation == RecipesMutation.ingredientSaved &&
          bloc.state.mutationStatus == RecipesMutationStatus.loading,
    );

    return RecipesMutationListener(
      mutation: RecipesMutation.ingredientSaved,
      onSuccess: () {
        if (_pending case final entry?) Navigator.of(context).pop(entry);
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
                  l10n.ingredientCreateTitle,
                  style: theme.typography.display.xs,
                ),
                if (_saveFailed)
                  FailureBanner(l10n.ingredientCreateSaveFailure),
                FTextFormField(
                  label: Text(l10n.ingredientCreateNameLabel),
                  control: FTextFieldControl.managed(
                    controller: _nameController,
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? l10n.ingredientCreateNameRequiredError
                      : null,
                ),
                ListenableBuilder(
                  listenable: _nameController,
                  builder: (context, _) => _UnitSection(
                    existing: catalogEntryNamed(
                      context.select<RecipesBloc, List<CatalogIngredient>>(
                        (bloc) => bloc.state.ingredients,
                      ),
                      _nameController.text,
                    ),
                    standardUnit: _standardUnit,
                    customUnitController: _customUnitController,
                    custom: _custom,
                    onStandardUnitChanged: (unit) =>
                        setState(() => _standardUnit = unit),
                    onCustomToggled: () => setState(() => _custom = !_custom),
                  ),
                ),
                FButton(
                  onPress: saving ? null : _save,
                  child: Text(l10n.ingredientCreateSaveLabel),
                ),
                FButton(
                  variant: FButtonVariant.outline,
                  onPress: () => Navigator.of(context).pop(),
                  child: Text(l10n.ingredientCreateCancelLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Unit? get _chosenUnit {
    if (!_custom) {
      return switch (_standardUnit) {
        final unit? => KnownUnit(unit),
        null => null,
      };
    }
    final label = _customUnitController.text.trim();
    return label.isEmpty ? null : CustomUnit(label);
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final bloc = context.read<RecipesBloc>();
    final libraryId = bloc.state.activeLibraryId;
    final existing = catalogEntryNamed(
      bloc.state.ingredients,
      _nameController.text,
    );

    // Reusing an existing entry is the same act as picking it from the list,
    // and saving its own id is what keeps it clear of the uniqueness guard.
    if (existing != null) {
      if (!existing.libraryIds.contains(libraryId)) {
        bloc.add(RecipesIngredientScopeWidened(existing.id, libraryId));
      }
      Navigator.of(context).pop(existing);
      return;
    }

    final entry = CatalogIngredient(
      name: _nameController.text,
      defaultUnit: _chosenUnit,
      libraryIds: {libraryId},
    );
    setState(() {
      _saveFailed = false;
      _pending = entry;
    });
    bloc.add(RecipesIngredientSaved(entry));
  }
}

/// The default unit controls: a list of the standard units, or a field for a
/// custom one.
///
/// While the typed name matches an existing entry, they show that entry's
/// unit and cannot be changed, so the user sees what reuse will give them
/// before saving.
class _UnitSection extends StatelessWidget {
  const _UnitSection({
    required this.existing,
    required this.standardUnit,
    required this.customUnitController,
    required this.custom,
    required this.onStandardUnitChanged,
    required this.onCustomToggled,
  });

  final CatalogIngredient? existing;
  final StandardUnit? standardUnit;
  final TextEditingController customUnitController;
  final bool custom;
  final ValueChanged<StandardUnit?> onStandardUnitChanged;
  final VoidCallback onCustomToggled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final existing = this.existing;
    final reusing = existing != null;
    final existingUnit = existing?.defaultUnit;
    final showCustom = reusing ? existingUnit is CustomUnit : custom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.spacing100,
      children: [
        if (existing != null)
          Text(
            l10n.ingredientCreateReuseNote(existing.name),
            style: context.theme.typography.body.sm,
          ),
        // Each control is keyed apart from the others, so none of them inherits
        // another's state — or controller — when they swap places.
        if (existing != null && existingUnit is CustomUnit)
          FTextFormField(
            key: ValueKey(existing.id),
            label: Text(l10n.ingredientCreateCustomUnitLabel),
            enabled: false,
            control: FTextFieldControl.managed(
              initial: TextEditingValue(text: existingUnit.label),
            ),
          )
        else if (showCustom)
          FTextFormField(
            key: const ValueKey('custom-unit'),
            label: Text(l10n.ingredientCreateCustomUnitLabel),
            control: FTextFieldControl.managed(
              controller: customUnitController,
            ),
          )
        else
          FSelect<StandardUnit>(
            key: const ValueKey('standard-unit'),
            label: Text(l10n.ingredientCreateUnitLabel),
            items: {
              for (final unit in StandardUnit.values)
                KnownUnit(unit).label: unit,
            },
            clearable: true,
            enabled: !reusing,
            control: FSelectControl.lifted(
              value: reusing
                  ? (existingUnit as KnownUnit?)?.unit
                  : standardUnit,
              onChange: onStandardUnitChanged,
            ),
          ),
        FButton(
          variant: FButtonVariant.ghost,
          onPress: reusing ? null : onCustomToggled,
          child: Text(
            showCustom
                ? l10n.ingredientCreateUnitStandardLabel
                : l10n.ingredientCreateUnitCustomLabel,
          ),
        ),
      ],
    );
  }
}
