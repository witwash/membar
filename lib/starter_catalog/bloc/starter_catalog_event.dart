part of 'starter_catalog_bloc.dart';

sealed class StarterCatalogEvent extends Equatable {
  const StarterCatalogEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the bundled set for the catalog's template.
final class StarterCatalogRequested extends StarterCatalogEvent {
  const StarterCatalogRequested();
}

/// Narrows the visible recipes to those whose name contains [term].
final class StarterCatalogSearchChanged extends StarterCatalogEvent {
  const StarterCatalogSearchChanged(this.term);

  final String term;

  @override
  List<Object?> get props => [term];
}

/// Selects the recipe carrying [key], or deselects it when it is selected.
final class StarterCatalogRecipeToggled extends StarterCatalogEvent {
  const StarterCatalogRecipeToggled(this.key);

  final String key;

  @override
  List<Object?> get props => [key];
}

/// Selects every visible recipe, or deselects them all when every one of them
/// is already selected. Hidden selections are left alone.
final class StarterCatalogVisibleToggled extends StarterCatalogEvent {
  const StarterCatalogVisibleToggled();
}

/// Writes the imported rows in [system].
final class StarterCatalogMeasureSystemChanged extends StarterCatalogEvent {
  const StarterCatalogMeasureSystemChanged(this.system);

  final MeasureSystem system;

  @override
  List<Object?> get props => [system];
}
