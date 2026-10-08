part of 'recipes_bloc.dart';

sealed class RecipesEvent extends Equatable {
  const RecipesEvent();

  @override
  List<Object?> get props => [];
}

/// Subscribes to the repository, replacing any existing subscription.
final class RecipesSubscriptionRequested extends RecipesEvent {
  const RecipesSubscriptionRequested();
}

/// Stores [recipe], replacing any recipe that already carries its id.
final class RecipesRecipeSaved extends RecipesEvent {
  const RecipesRecipeSaved(this.recipe);

  final Recipe recipe;

  @override
  List<Object?> get props => [recipe];
}

/// Removes the recipe carrying [id].
final class RecipesRecipeDeleted extends RecipesEvent {
  const RecipesRecipeDeleted(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Switches the library being browsed to the one carrying [libraryId].
final class RecipesLibrarySelected extends RecipesEvent {
  const RecipesLibrarySelected(this.libraryId);

  final String libraryId;

  @override
  List<Object?> get props => [libraryId];
}

/// Stores [library], replacing any library that already carries its id and
/// rewriting its recipes to match.
final class RecipesLibrarySaved extends RecipesEvent {
  const RecipesLibrarySaved(this.library, {this.optionRenames = const {}});

  final Library library;

  /// The Select options retyped by this save, keyed by field id and then by
  /// the option's stored text.
  final Map<String, Map<String, String>> optionRenames;

  @override
  List<Object?> get props => [library, optionRenames];
}

/// Removes the library carrying [id] and its recipes, handing what cannot go
/// with it to the library carrying [successorId].
final class RecipesLibraryDeleted extends RecipesEvent {
  const RecipesLibraryDeleted(this.id, {required this.successorId});

  final String id;

  final String successorId;

  @override
  List<Object?> get props => [id, successorId];
}

/// Removes the field carrying [fieldId] from the library carrying
/// [libraryId], along with every value recipes hold for it.
final class RecipesFieldDeleted extends RecipesEvent {
  const RecipesFieldDeleted({required this.libraryId, required this.fieldId});

  final String libraryId;

  final String fieldId;

  @override
  List<Object?> get props => [libraryId, fieldId];
}

/// Stores [ingredient] in the catalog, replacing any entry that already
/// carries its id.
final class RecipesIngredientSaved extends RecipesEvent {
  const RecipesIngredientSaved(this.ingredient);

  final CatalogIngredient ingredient;

  @override
  List<Object?> get props => [ingredient];
}

/// Removes the catalog entry carrying [id].
final class RecipesIngredientDeleted extends RecipesEvent {
  const RecipesIngredientDeleted(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Adds every entry in [RecipesState.importableIngredients] to the catalog,
/// links the recipe rows using them, and records the import as done.
final class RecipesIngredientsImported extends RecipesEvent {
  const RecipesIngredientsImported();
}

/// Makes the catalog entry carrying [ingredientId] visible in the library
/// carrying [libraryId], because it was picked from there.
final class RecipesIngredientScopeWidened extends RecipesEvent {
  const RecipesIngredientScopeWidened(this.ingredientId, this.libraryId);

  final String ingredientId;

  final String libraryId;

  @override
  List<Object?> get props => [ingredientId, libraryId];
}

/// Narrows the visible recipes to those whose name contains [term].
final class RecipesSearchTermChanged extends RecipesEvent {
  const RecipesSearchTermChanged(this.term);

  final String term;

  @override
  List<Object?> get props => [term];
}

/// Adds [tag] to the tag filter, or removes it when it is already selected.
final class RecipesTagFilterToggled extends RecipesEvent {
  const RecipesTagFilterToggled(this.tag);

  final String tag;

  @override
  List<Object?> get props => [tag];
}
