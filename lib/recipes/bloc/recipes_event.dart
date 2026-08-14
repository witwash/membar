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
