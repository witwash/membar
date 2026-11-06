import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:membar/ui/ui.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// Changes a catalog entry: its name and its default unit.
///
/// A rename reaches every recipe referencing the entry, because rows link by
/// id and render the entry's current name.
class IngredientEditorSheet extends StatefulWidget {
  /// Creates an [IngredientEditorSheet] editing [entry].
  const IngredientEditorSheet({required this.entry, super.key});

  /// Opens the sheet on [entry], completing once it closes.
  ///
  /// The sheet's route sits above the provider, so the bloc is re-provided
  /// here.
  static Future<void> show(
    BuildContext context, {
    required CatalogIngredient entry,
  }) {
    final bloc = context.read<RecipesBloc>();
    return showFSheet<void>(
      context: context,
      side: FLayout.btt,
      // Sized to its content, which scrolls when the keyboard leaves it less.
      mainAxisMaxRatio: null,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: IngredientEditorSheet(entry: entry),
      ),
    );
  }

  /// The entry as it was when the sheet opened.
  final CatalogIngredient entry;

  @override
  State<IngredientEditorSheet> createState() => _IngredientEditorSheetState();
}

class _IngredientEditorSheetState extends State<IngredientEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.entry.name);
  late final _unitController = DefaultUnitController(
    widget.entry.defaultUnit,
  );
  var _submitted = false;
  var _saveFailed = false;

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
                  l10n.ingredientEditTitle,
                  style: theme.typography.display.xs,
                ),
                if (_saveFailed) FailureBanner(l10n.ingredientEditSaveFailure),
                FTextFormField(
                  label: Text(l10n.ingredientEditNameLabel),
                  control: FTextFieldControl.managed(
                    controller: _nameController,
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validateName,
                ),
                DefaultUnitField(controller: _unitController),
                FButton(
                  onPress: saving ? null : _save,
                  child: Text(l10n.ingredientEditSaveLabel),
                ),
                FButton(
                  variant: FButtonVariant.outline,
                  onPress: () => Navigator.of(context).pop(),
                  child: Text(l10n.ingredientEditCancelLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Refuses a rename onto another entry's name before the data layer would,
  /// so the user sees an error rather than a failed save.
  String? _validateName(String? value) {
    final l10n = context.l10n;
    final name = (value ?? '').trim();
    if (name.isEmpty) return l10n.ingredientEditNameRequiredError;

    final other = context.read<RecipesBloc>().state.ingredientNamed(
      name,
      ingredientLibraryId: widget.entry.ingredientLibraryId,
    );
    return switch (other) {
      final other? when other.id != widget.entry.id =>
        l10n.ingredientEditNameTakenError(other.name),
      _ => null,
    };
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saveFailed = false;
      _submitted = true;
    });
    context.read<RecipesBloc>().add(
      RecipesIngredientSaved(
        CatalogIngredient(
          id: widget.entry.id,
          name: _nameController.text,
          defaultUnit: _unitController.unit,
          ingredientLibraryId: widget.entry.ingredientLibraryId,
        ),
      ),
    );
  }
}
