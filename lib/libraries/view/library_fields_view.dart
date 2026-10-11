import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/libraries/libraries.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:membar/ui/ui.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// The fields a library declares, in schema order, with the actions that add,
/// edit, delete and reorder them.
///
/// The library is read from the bloc on every build rather than passed in:
/// this screen and the sheet above it are what change it, so a field saved
/// from the sheet appears here without reopening anything.
class LibraryFieldsView extends StatefulWidget {
  /// Creates a [LibraryFieldsView] for the library carrying [libraryId].
  const LibraryFieldsView({required this.libraryId, super.key});

  /// The id of the library whose fields are listed.
  final String libraryId;

  @override
  State<LibraryFieldsView> createState() => _LibraryFieldsViewState();
}

class _LibraryFieldsViewState extends State<LibraryFieldsView> {
  String? _failure;
  var _reordering = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Nothing can delete a library while its fields are open, so a miss is a
    // null-safety branch rather than a state anyone reaches.
    final library = context.select<RecipesBloc, Library?>(
      (bloc) => bloc.state.libraryById(widget.libraryId),
    );
    final fields = library?.fields ?? const <FieldDefinition>[];

    return RecipesMutationListener(
      mutation: RecipesMutation.fieldDeleted,
      onSuccess: (_) {},
      onFailure: () =>
          setState(() => _failure = l10n.libraryFieldsDeleteFailure),
      child: RecipesMutationListener(
        mutation: RecipesMutation.fieldMoved,
        onSuccess: _announceMove,
        onFailure: () =>
            setState(() => _failure = l10n.libraryFieldsMoveFailure),
        child: FScaffold(
          header: FHeader.nested(
            title: Text(library?.name ?? ''),
            prefixes: [
              FHeaderAction.back(onPress: () => Navigator.of(context).pop()),
            ],
            suffixes: [
              if (library != null)
                if (_reordering)
                  FHeaderAction(
                    icon: const Icon(FLucideIcons.check),
                    semanticsLabel: l10n.libraryFieldsReorderDoneLabel,
                    onPress: () => setState(() => _reordering = false),
                  )
                else ...[
                  if (fields.length > 1)
                    FHeaderAction(
                      icon: const Icon(FLucideIcons.arrowUpDown),
                      semanticsLabel: l10n.libraryFieldsReorderLabel,
                      onPress: () => setState(() => _reordering = true),
                    ),
                  FHeaderAction(
                    icon: const Icon(FLucideIcons.plus),
                    semanticsLabel: l10n.libraryFieldsAddLabel,
                    onPress: () => _edit(library),
                  ),
                ],
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_failure case final failure?) FailureBanner(failure),
              if (library != null)
                Expanded(
                  child: fields.isEmpty
                      ? _EmptyState(onAdd: () => _edit(library))
                      : FTileGroup.builder(
                          count: fields.length,
                          tileBuilder: (context, index) {
                            final field = fields[index];
                            return FTile(
                              title: Text(field.label),
                              subtitle: Text(_describe(field)),
                              suffix: _reordering
                                  ? _MoveButtons(
                                      field: field,
                                      onMoveUp: index == 0
                                          ? null
                                          : () => _move(library, field, -1),
                                      onMoveDown: index == fields.length - 1
                                          ? null
                                          : () => _move(library, field, 1),
                                    )
                                  : FButton.icon(
                                      variant: FButtonVariant.ghost,
                                      semanticsLabel: l10n
                                          .libraryFieldsDeleteLabel(
                                            field.label,
                                          ),
                                      onPress: () =>
                                          unawaited(_delete(library, field)),
                                      child: const Icon(FLucideIcons.trash2),
                                    ),
                              onPress: _reordering
                                  ? null
                                  : () => _edit(library, field),
                            );
                          },
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The field's type, then what narrows it — a number's unit or a choice's
  /// option count — then whether a recipe has to fill it in.
  String _describe(FieldDefinition field) {
    final l10n = context.l10n;
    return [
      l10n.fieldTypeName(field.type),
      ?field.unit,
      if (field.type == FieldType.select)
        l10n.libraryFieldsOptionCount(field.optionsOrEmpty.length),
      if (field.required) l10n.libraryFieldsRequired,
    ].join(' · ');
  }

  void _edit(Library library, [FieldDefinition? field]) {
    unawaited(FieldEditorSheet.show(context, library: library, field: field));
  }

  /// States how many recipes carry a value before dispatching, because the
  /// delete purges them and nothing brings them back.
  Future<void> _delete(Library library, FieldDefinition field) async {
    final l10n = context.l10n;
    final bloc = context.read<RecipesBloc>();
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.libraryFieldsDeleteDialogTitle(field.label),
      description: l10n.libraryFieldsDeleteDialogDescription(
        bloc.state.fieldValueCount(library.id, field.id),
      ),
      confirmLabel: l10n.libraryFieldsDeleteDialogConfirm,
      cancelLabel: l10n.libraryFieldsDeleteDialogCancel,
    );
    if (!confirmed || !mounted) return;

    setState(() => _failure = null);
    bloc.add(RecipesFieldDeleted(libraryId: library.id, fieldId: field.id));
  }

  void _move(Library library, FieldDefinition field, int delta) {
    setState(() => _failure = null);
    context.read<RecipesBloc>().add(
      RecipesFieldMoved(
        libraryId: library.id,
        fieldId: field.id,
        delta: delta,
      ),
    );
  }

  /// Says where the field [state] reports as moved now sits. Tiles are not
  /// keyed, so screen-reader focus stays on the slot rather than following
  /// the field, and this is the only thing that tells where it went.
  void _announceMove(RecipesState state) {
    final fields =
        state.libraryById(widget.libraryId)?.fields ??
        const <FieldDefinition>[];
    final index = fields.indexWhere((field) => field.id == state.movedFieldId);
    if (index == -1) return;

    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        context.l10n.libraryFieldsMovedAnnouncement(
          fields[index].label,
          index + 1,
          fields.length,
        ),
        Directionality.of(context),
      ),
    );
  }
}

/// The two actions a tile carries in reorder mode. Both always render, the
/// inapplicable one disabled, so that a button never shifts under a second
/// tap and lands it on the opposite action.
class _MoveButtons extends StatelessWidget {
  const _MoveButtons({
    required this.field,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final FieldDefinition field;

  final VoidCallback? onMoveUp;

  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FButton.icon(
          variant: FButtonVariant.ghost,
          semanticsLabel: l10n.libraryFieldsMoveUpLabel(field.label),
          onPress: onMoveUp,
          child: const Icon(FLucideIcons.arrowUp),
        ),
        FButton.icon(
          variant: FButtonVariant.ghost,
          semanticsLabel: l10n.libraryFieldsMoveDownLabel(field.label),
          onPress: onMoveDown,
          child: const Icon(FLucideIcons.arrowDown),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.spacing100,
        children: [
          Text(l10n.libraryFieldsEmptyTitle, style: theme.typography.body.lg),
          Text(
            l10n.libraryFieldsEmptyDescription,
            textAlign: TextAlign.center,
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.spacing100),
          FButton(
            mainAxisSize: MainAxisSize.min,
            onPress: onAdd,
            child: Text(l10n.libraryFieldsAddLabel),
          ),
        ],
      ),
    );
  }
}
