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
  final _unitController = DefaultUnitController();
  var _saveFailed = false;
  CatalogIngredient? _pending;

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
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
                  builder: (context, _) {
                    final existing = context
                        .select<RecipesBloc, CatalogIngredient?>(
                          (bloc) =>
                              bloc.state.ingredientNamed(_nameController.text),
                        );
                    // While the typed name matches an entry, the unit shows
                    // that entry's and cannot change, so the user sees what
                    // reuse will give them before saving.
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: AppSpacing.spacing100,
                      children: [
                        if (existing != null)
                          Text(
                            l10n.ingredientCreateReuseNote(existing.name),
                            style: theme.typography.body.sm,
                          ),
                        DefaultUnitField(
                          controller: _unitController,
                          locked: existing != null,
                          lockedUnit: existing?.defaultUnit,
                        ),
                      ],
                    );
                  },
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

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final bloc = context.read<RecipesBloc>();
    final libraryId = bloc.state.activeLibraryId;
    final existing = bloc.state.ingredientNamed(_nameController.text);

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
      defaultUnit: _unitController.unit,
      libraryIds: {libraryId},
    );
    setState(() {
      _saveFailed = false;
      _pending = entry;
    });
    bloc.add(RecipesIngredientSaved(entry));
  }
}
