import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:membar/ui/ui.dart';
import 'package:recipes_repository/recipes_repository.dart';

enum _StartingPoint { blank, cocktails, coffee }

/// Creates a library, or renames one.
///
/// A new library takes its fields from the chosen template and its name from
/// what was typed. A rename keeps the library's id and fields, so its recipes
/// stay where they are.
class LibraryEditorSheet extends StatefulWidget {
  /// Creates a [LibraryEditorSheet] renaming [library], or creating a library
  /// when it is null.
  const LibraryEditorSheet({this.library, super.key});

  /// Opens the sheet, completing once it closes.
  ///
  /// The sheet's route sits above the provider, so the bloc is re-provided
  /// here.
  static Future<void> show(BuildContext context, {Library? library}) {
    final bloc = context.read<RecipesBloc>();
    return showFSheet<void>(
      context: context,
      side: FLayout.btt,
      // Sized to its content, which scrolls when the keyboard leaves it less.
      mainAxisMaxRatio: null,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: LibraryEditorSheet(library: library),
      ),
    );
  }

  /// The library being renamed, as it was when the sheet opened, or null when
  /// the sheet creates one.
  final Library? library;

  @override
  State<LibraryEditorSheet> createState() => _LibraryEditorSheetState();
}

class _LibraryEditorSheetState extends State<LibraryEditorSheet> {
  static const _templates = LibraryTemplates();

  final _formKey = GlobalKey<FormState>();
  // Empty in create mode whatever template is chosen: a template's own name
  // would collide with the library a fresh install seeded from it.
  late final _nameController = TextEditingController(
    text: widget.library?.name,
  );
  _StartingPoint _startingPoint = _StartingPoint.blank;
  var _submitted = false;
  var _saveFailed = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;
    final creating = widget.library == null;
    final saving = context.select<RecipesBloc, bool>(
      (bloc) =>
          bloc.state.mutation == RecipesMutation.librarySaved &&
          bloc.state.mutationStatus == RecipesMutationStatus.loading,
    );

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
                  creating
                      ? l10n.libraryEditorCreateTitle
                      : l10n.libraryEditorRenameTitle,
                  style: theme.typography.display.xs,
                ),
                if (_saveFailed) FailureBanner(l10n.libraryEditorSaveFailure),
                FTextFormField(
                  label: Text(l10n.libraryEditorNameLabel),
                  control: FTextFieldControl.managed(
                    controller: _nameController,
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validateName,
                ),
                if (creating)
                  FSelect<_StartingPoint>(
                    label: Text(l10n.libraryEditorStartFromLabel),
                    items: {
                      l10n.libraryEditorTemplateBlank: _StartingPoint.blank,
                      l10n.libraryEditorTemplateCocktails:
                          _StartingPoint.cocktails,
                      l10n.libraryEditorTemplateCoffee: _StartingPoint.coffee,
                    },
                    control: FSelectControl.lifted(
                      value: _startingPoint,
                      onChange: (value) => setState(
                        () => _startingPoint = value ?? _StartingPoint.blank,
                      ),
                    ),
                  ),
                FButton(
                  onPress: saving ? null : _save,
                  child: Text(
                    creating
                        ? l10n.libraryEditorCreateLabel
                        : l10n.libraryEditorSaveLabel,
                  ),
                ),
                FButton(
                  variant: FButtonVariant.outline,
                  onPress: () => Navigator.of(context).pop(),
                  child: Text(l10n.libraryEditorCancelLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Refuses a name another library carries before the data layer would, so
  /// the user sees an error rather than a failed save.
  String? _validateName(String? value) {
    final l10n = context.l10n;
    final name = (value ?? '').trim();
    if (name.isEmpty) return l10n.libraryEditorNameRequiredError;

    return switch (context.read<RecipesBloc>().state.libraryNamed(name)) {
      final other? when other.id != widget.library?.id =>
        l10n.libraryEditorNameTakenError(other.name),
      _ => null,
    };
  }

  void _save() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() {
      _saveFailed = false;
      _submitted = true;
    });
    final library = widget.library;
    context.read<RecipesBloc>().add(
      RecipesLibrarySaved(
        Library(
          id: library?.id,
          name: _nameController.text,
          fields: library?.fields ?? _templateFields(),
        ),
      ),
    );
  }

  /// The chosen template's fields under freshly generated ids. Its name is
  /// left behind: the library is called what the user typed.
  List<FieldDefinition> _templateFields() => switch (_startingPoint) {
    _StartingPoint.blank => const [],
    _StartingPoint.cocktails => _templates.cocktails().fields,
    _StartingPoint.coffee => _templates.coffee().fields,
  };
}
