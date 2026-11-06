import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:membar/ui/ui.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// Confirms deleting a library, stating what goes with it and what stays.
class LibraryDeleteSheet extends StatefulWidget {
  /// Creates a [LibraryDeleteSheet] deleting [library], which must not be the
  /// only library: the deletion needs another one to become the active
  /// library.
  const LibraryDeleteSheet({required this.library, super.key});

  /// Opens the sheet on [library], completing once it closes.
  ///
  /// The sheet's route sits above the provider, so the bloc is re-provided
  /// here.
  static Future<void> show(BuildContext context, {required Library library}) {
    final bloc = context.read<RecipesBloc>();
    return showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: null,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: LibraryDeleteSheet(library: library),
      ),
    );
  }

  /// The library to delete.
  final Library library;

  @override
  State<LibraryDeleteSheet> createState() => _LibraryDeleteSheetState();
}

class _LibraryDeleteSheetState extends State<LibraryDeleteSheet> {
  late final int _recipeCount;
  late final String? _ingredientLibraryName;
  late final String _successorId;
  var _submitted = false;
  var _deleteFailed = false;

  /// What the sheet states is read once, when it opens. The success it waits
  /// for removes the library, so a live read would restate the sheet as
  /// deleting nothing while it slides away.
  @override
  void initState() {
    super.initState();
    final state = context.read<RecipesBloc>().state;
    final id = widget.library.id;
    _recipeCount = state.recipeCountIn(id);
    _ingredientLibraryName = state
        .ingredientLibraryById(widget.library.ingredientLibraryId)
        ?.name;
    _successorId = state.libraries.firstWhere((library) => library.id != id).id;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;
    final deleting = context.select<RecipesBloc, bool>(
      (bloc) =>
          bloc.state.mutation == RecipesMutation.libraryDeleted &&
          bloc.state.mutationStatus == RecipesMutationStatus.loading,
    );

    return RecipesMutationListener(
      mutation: RecipesMutation.libraryDeleted,
      onSuccess: (_) {
        if (_submitted) Navigator.of(context).pop();
      },
      onFailure: () => setState(() => _deleteFailed = true),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.background,
          border: Border(top: BorderSide(color: theme.colors.border)),
        ),
        child: SingleChildScrollView(
          padding: AppInsets.sheetContent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.spacing200,
            children: [
              Text(
                l10n.libraryDeleteTitle(widget.library.name),
                style: theme.typography.display.xs,
              ),
              if (_deleteFailed) FailureBanner(l10n.libraryDeleteFailure),
              Text(l10n.libraryDeleteRecipeCount(_recipeCount)),
              if (_ingredientLibraryName case final name?)
                Text(l10n.libraryDeleteIngredientLibraryKept(name)),
              FButton(
                variant: FButtonVariant.destructive,
                onPress: deleting ? null : _delete,
                child: Text(l10n.libraryDeleteConfirmLabel),
              ),
              FButton(
                variant: FButtonVariant.outline,
                onPress: () => Navigator.of(context).pop(),
                child: Text(l10n.libraryDeleteCancelLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _delete() {
    setState(() {
      _deleteFailed = false;
      _submitted = true;
    });
    context.read<RecipesBloc>().add(
      RecipesLibraryDeleted(widget.library.id, successorId: _successorId),
    );
  }
}
