import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// The entry in [catalog] whose name matches [name] without regard to case, or
/// null when none does.
///
/// Catalog names are unique on that same folding, so at most one entry can
/// match. This is the rule that links a saved ingredient row to an entry, and
/// the rule that makes the create sheet reuse an entry rather than add a
/// second one spelled differently.
CatalogIngredient? catalogEntryNamed(
  Iterable<CatalogIngredient> catalog,
  String name,
) {
  final folded = name.trim().toLowerCase();
  if (folded.isEmpty) return null;
  for (final entry in catalog) {
    if (entry.name.toLowerCase() == folded) return entry;
  }
  return null;
}

/// Something the ingredient picker offers.
sealed class IngredientOption extends Equatable {
  const IngredientOption();
}

/// A catalog entry the picker offers.
final class CatalogOption extends IngredientOption {
  /// Creates a [CatalogOption] for [entry].
  const CatalogOption(this.entry, {required this.inScope});

  /// The entry picking this option fills the row from.
  final CatalogIngredient entry;

  /// Whether [entry] is already visible in the library being edited.
  final bool inScope;

  @override
  List<Object?> get props => [entry, inScope];
}

/// The action that creates a catalog entry from what the user typed.
final class CreateOption extends IngredientOption {
  /// Creates a [CreateOption] carrying the typed [query].
  const CreateOption(this.query);

  /// What was in the field when the option was offered.
  final String query;

  @override
  List<Object?> get props => [query];
}

/// An ingredient row's name field: free text, with the catalog offered as
/// suggestions over it.
///
/// Picking a suggestion fills in the name and, where it can, the unit. It
/// never stores which entry was picked: the editor links a row to an entry by
/// its name when the recipe is saved, so a hand-edited name cannot keep a
/// stale link.
class IngredientPicker extends StatefulWidget {
  /// Creates an [IngredientPicker] editing [name], prefilling [unit].
  const IngredientPicker({required this.name, required this.unit, super.key});

  /// The row's name, which this field edits.
  final FAutocompleteController name;

  /// The row's unit, which picking an entry prefills.
  final TextEditingController unit;

  @override
  State<IngredientPicker> createState() => _IngredientPickerState();
}

class _IngredientPickerState extends State<IngredientPicker> {
  /// The unit the last pick wrote into the row, so the next pick knows it may
  /// replace it. A unit the user typed is never replaced.
  String? _prefilledUnit;

  @override
  Widget build(BuildContext context) {
    return FAutocomplete<IngredientOption>.builder(
      label: Text(context.l10n.recipeEditorIngredientLabel),
      control: FAutocompleteControl.managed(controller: widget.name),
      filter: _filter,
      format: _format,
      // Only a validator or onSaved would consult this, and the field has
      // neither: whatever is typed stays plain text.
      parse: (_) => null,
      contentBuilder: _content,
      onItemPress: (option) => unawaited(_onItemPress(option)),
    );
  }

  /// Reads the catalog as it is now, on every keystroke, so an entry created
  /// for one row is offered to the next without the list reshuffling under a
  /// finger mid-tap.
  Iterable<IngredientOption> _filter(String query) {
    final state = context.read<RecipesBloc>().state;
    final term = query.trim().toLowerCase();
    bool matches(CatalogIngredient entry) =>
        entry.name.toLowerCase().contains(term);

    return [
      for (final entry in state.libraryIngredients)
        if (matches(entry)) CatalogOption(entry, inScope: true),
      for (final entry in state.otherLibraryIngredients)
        if (matches(entry)) CatalogOption(entry, inScope: false),
    ];
  }

  /// Maps the create action back to what was typed, so pressing it leaves the
  /// field as it was rather than stamping the action's label into it.
  static String _format(IngredientOption option) => switch (option) {
    CatalogOption(:final entry) => entry.name,
    CreateOption(:final query) => query,
  };

  /// Appends the create action here rather than in [_filter]: the popover
  /// shows its empty message when this builder returns nothing, which would
  /// hide the action on the empty catalog a fresh install starts with.
  List<FAutocompleteItemMixin<IngredientOption>> _content(
    BuildContext context,
    String query,
    Iterable<IngredientOption> values,
  ) {
    final l10n = context.l10n;
    final options = values.whereType<CatalogOption>();
    FAutocompleteItem<IngredientOption> item(CatalogOption option) =>
        FAutocompleteItem(
          value: option,
          title: Text(option.entry.name),
          suffix: switch (option.entry.defaultUnit) {
            final unit? => Text(unit.label),
            null => null,
          },
        );
    final others = [
      for (final option in options)
        if (!option.inScope) item(option),
    ];

    return [
      for (final option in options)
        if (option.inScope) item(option),
      if (others.isNotEmpty)
        FAutocompleteSection.rich(
          label: Text(l10n.ingredientPickerOtherLibrariesLabel),
          children: others,
        ),
      FAutocompleteItem.raw(
        value: CreateOption(query),
        prefix: const Icon(FLucideIcons.plus),
        child: Text(l10n.ingredientPickerCreateLabel),
      ),
    ];
  }

  Future<void> _onItemPress(IngredientOption option) async {
    switch (option) {
      case CatalogOption(:final entry, :final inScope):
        if (!inScope) {
          final bloc = context.read<RecipesBloc>();
          bloc.add(
            RecipesIngredientScopeWidened(entry.id, bloc.state.activeLibraryId),
          );
        }
        _prefillUnit(entry);
      case CreateOption(:final query):
        final entry = await IngredientCreateSheet.show(context, name: query);
        if (entry == null || !mounted) return;
        widget.name.text = entry.name;
        _prefillUnit(entry);
    }
  }

  void _prefillUnit(CatalogIngredient entry) {
    final label = entry.defaultUnit?.label;
    if (label == null) return;

    final current = widget.unit.text.trim();
    if (current.isNotEmpty && current != _prefilledUnit) return;
    widget.unit.text = label;
    _prefilledUnit = label;
  }
}
