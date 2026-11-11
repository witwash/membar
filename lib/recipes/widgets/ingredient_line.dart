import 'package:membar/recipes/bloc/recipes_bloc.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// The text [row] renders as: its quantity, unit and catalog entry's name.
///
/// A row reads as its entry's current name, which is what makes a rename
/// show. A row whose entry is gone has no name to show, so it yields null
/// and is skipped.
String? ingredientLine(RecipesState state, Ingredient row) =>
    switch (state.ingredientById(row.catalogId)) {
      final entry? => [
        row.quantity,
        row.unit,
        entry.name,
      ].where((part) => part.isNotEmpty).join(' '),
      null => null,
    };
