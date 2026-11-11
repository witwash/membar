import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:membar/ui/ui.dart';
import 'package:recipes_repository/recipes_repository.dart';
import 'package:starter_recipes_repository/starter_recipes_repository.dart';

/// Resolves the picked starter recipes whose names a recipe in the library
/// already carries: each is renamed or skipped before anything is written.
class StarterRenameSheet extends StatefulWidget {
  /// Creates a [StarterRenameSheet] over [clashes].
  const StarterRenameSheet({
    required this.library,
    required this.clashes,
    required this.others,
    super.key,
  });

  /// Opens the sheet over [clashes].
  ///
  /// Resolves to the name each clash is imported under, keyed by recipe key,
  /// with null for a skipped one. Resolves to null when the sheet is
  /// cancelled. The sheet's route sits above the provider, so the bloc is
  /// re-provided here.
  static Future<Map<String, String?>?> show(
    BuildContext context, {
    required Library library,
    required List<StarterRecipe> clashes,
    required List<StarterRecipe> others,
  }) {
    final bloc = context.read<RecipesBloc>();
    return showFSheet<Map<String, String?>>(
      context: context,
      side: FLayout.btt,
      // Sized to its content, which scrolls when the keyboard leaves it less.
      mainAxisMaxRatio: null,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: StarterRenameSheet(
          library: library,
          clashes: clashes,
          others: others,
        ),
      ),
    );
  }

  /// The library the recipes are imported into.
  final Library library;

  /// The picked recipes whose names are taken in [library].
  final List<StarterRecipe> clashes;

  /// The other picked recipes, imported under their own names, which a
  /// rename must not take.
  final List<StarterRecipe> others;

  @override
  State<StarterRenameSheet> createState() => _StarterRenameSheetState();
}

class _StarterRenameSheetState extends State<StarterRenameSheet> {
  late final List<TextEditingController> _controllers = [
    for (final recipe in widget.clashes)
      TextEditingController(text: recipe.name)..addListener(_rebuild),
  ];
  late final List<bool> _skipped = List.filled(widget.clashes.length, false);

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // The Import button and every other row's duplicate check depend on each
  // row's text.
  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;
    final state = context.watch<RecipesBloc>().state;

    return DecoratedBox(
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.starterRenameTitle,
                    style: theme.typography.display.xs,
                  ),
                ),
                FButton(
                  variant: FButtonVariant.ghost,
                  mainAxisSize: MainAxisSize.min,
                  onPress: () => setState(
                    () => _skipped.fillRange(0, _skipped.length, true),
                  ),
                  child: Text(l10n.starterRenameSkipAllLabel),
                ),
              ],
            ),
            Text(l10n.starterRenameDescription(widget.library.name)),
            for (final (index, recipe) in widget.clashes.indexed)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.spacing100,
                children: [
                  Expanded(
                    child: FTextFormField(
                      // A disabled field stops validating and would keep the
                      // error it had when skipped, so a toggle rebuilds it.
                      key: ValueKey((recipe.key, _skipped[index])),
                      label: Text(l10n.starterRenameFieldLabel(recipe.name)),
                      control: FTextFieldControl.managed(
                        controller: _controllers[index],
                      ),
                      enabled: !_skipped[index],
                      autofocus: index == 0,
                      autovalidateMode: AutovalidateMode.always,
                      validator: (_) => _validate(index, state),
                    ),
                  ),
                  FButton(
                    variant: FButtonVariant.outline,
                    mainAxisSize: MainAxisSize.min,
                    onPress: () =>
                        setState(() => _skipped[index] = !_skipped[index]),
                    child: Text(
                      _skipped[index]
                          ? l10n.starterRenameUndoSkipLabel
                          : l10n.starterRenameSkipLabel,
                    ),
                  ),
                ],
              ),
            FButton(
              onPress: _canImport(state) ? _import : null,
              child: Text(l10n.starterRenameImportLabel),
            ),
            FButton(
              variant: FButtonVariant.outline,
              onPress: () => Navigator.of(context).pop(),
              child: Text(l10n.starterRenameCancelLabel),
            ),
          ],
        ),
      ),
    );
  }

  bool _canImport(RecipesState state) {
    var remaining = widget.others.length;
    for (var index = 0; index < widget.clashes.length; index++) {
      if (_skipped[index]) continue;
      if (_validate(index, state) != null) return false;
      remaining++;
    }
    return remaining > 0;
  }

  /// The error for the row at [index], or null when it is skipped or its name
  /// is free in the library and among every other recipe being imported.
  String? _validate(int index, RecipesState state) {
    if (_skipped[index]) return null;

    final l10n = context.l10n;
    final name = _controllers[index].text.trim();
    if (name.isEmpty) return l10n.starterRenameNameRequiredError;

    if (state.recipeNamed(name, libraryId: widget.library.id)
        case final other?) {
      return l10n.starterRenameNameTakenError(other.name);
    }

    final folded = name.toLowerCase();
    final taken = [
      for (final recipe in widget.others) recipe.name,
      for (final (other, controller) in _controllers.indexed)
        if (other != index && !_skipped[other]) controller.text,
    ];
    if (taken.any((other) => other.trim().toLowerCase() == folded)) {
      return l10n.starterRenameDuplicateError;
    }
    return null;
  }

  void _import() {
    Navigator.of(context).pop({
      for (final (index, recipe) in widget.clashes.indexed)
        recipe.key: _skipped[index] ? null : _controllers[index].text.trim(),
    });
  }
}
