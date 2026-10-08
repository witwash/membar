import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/libraries/libraries.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:membar/ui/ui.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// Every library in stored order, with how many fields it declares and how
/// many recipes it holds, plus the actions that create, rename and delete one.
///
/// It dispatches nothing itself: each sheet it opens reports its own outcome.
class LibrariesView extends StatefulWidget {
  /// Creates a [LibrariesView].
  const LibrariesView({super.key});

  @override
  State<LibrariesView> createState() => _LibrariesViewState();
}

class _LibrariesViewState extends State<LibrariesView> {
  String? _refusal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<RecipesBloc>().state;
    final libraries = state.libraries;

    return FScaffold(
      header: FHeader.nested(
        title: Text(l10n.librariesTitle),
        prefixes: [
          FHeaderAction.back(onPress: () => Navigator.of(context).pop()),
        ],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.plus),
            semanticsLabel: l10n.librariesAddLabel,
            onPress: _edit,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_refusal case final refusal?) FailureBanner(refusal),
          Expanded(
            child: FTileGroup.builder(
              count: libraries.length,
              tileBuilder: (context, index) {
                final library = libraries[index];
                return FTile(
                  title: Text(library.name),
                  subtitle: Text(
                    [
                      l10n.librariesFieldCount(library.fields.length),
                      l10n.librariesRecipeCount(
                        state.recipeCountIn(library.id),
                      ),
                    ].join(' · '),
                  ),
                  suffix: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FButton.icon(
                        variant: FButtonVariant.ghost,
                        semanticsLabel: l10n.librariesRenameLabel(library.name),
                        onPress: () => _edit(library),
                        child: const Icon(FLucideIcons.pencil),
                      ),
                      FButton.icon(
                        variant: FButtonVariant.ghost,
                        semanticsLabel: l10n.librariesDeleteLabel(library.name),
                        onPress: () => _delete(library),
                        child: const Icon(FLucideIcons.trash2),
                      ),
                    ],
                  ),
                  onPress: () => _openFields(library),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openFields(Library library) {
    setState(() => _refusal = null);
    Navigator.of(context).push(
      LibraryFieldsPage.route(
        bloc: context.read<RecipesBloc>(),
        libraryId: library.id,
      ),
    );
  }

  void _edit([Library? library]) {
    setState(() => _refusal = null);
    unawaited(LibraryEditorSheet.show(context, library: library));
  }

  /// Refuses the only library here rather than in the sheet: a deletion needs
  /// a successor to take the ingredients, and with one library there is none
  /// to offer.
  void _delete(Library library) {
    if (context.read<RecipesBloc>().state.libraries.length == 1) {
      setState(
        () => _refusal = context.l10n.librariesLastLibraryRefusal(library.name),
      );
      return;
    }

    setState(() => _refusal = null);
    unawaited(LibraryDeleteSheet.show(context, library: library));
  }
}
