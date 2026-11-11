part of 'starter_catalog_bloc.dart';

/// How loading the bundled set is faring.
enum StarterCatalogStatus { initial, loading, success, failure }

final class StarterCatalogState extends Equatable {
  const StarterCatalogState({
    this.status = StarterCatalogStatus.initial,
    this.set,
    this.searchTerm = '',
    this.selectedKeys = const {},
    this.system = MeasureSystem.metric,
  });

  final StarterCatalogStatus status;

  /// The bundled set, or null until it has loaded.
  final StarterSet? set;

  /// What the user has typed into the search field.
  final String searchTerm;

  /// The keys of the picked recipes, including ones the search hides.
  final Set<String> selectedKeys;

  /// The system the picked recipes' rows are imported in.
  final MeasureSystem system;

  /// The recipes of [set] whose name contains [searchTerm], ignoring case, in
  /// catalog order.
  List<StarterRecipe> get visibleRecipes {
    final term = searchTerm.trim().toLowerCase();
    return [
      for (final recipe in set?.recipes ?? const <StarterRecipe>[])
        if (recipe.name.toLowerCase().contains(term)) recipe,
    ];
  }

  /// Whether there is a visible recipe and every one of them is selected.
  bool get allVisibleSelected {
    final visible = visibleRecipes;
    return visible.isNotEmpty &&
        visible.every((recipe) => selectedKeys.contains(recipe.key));
  }

  /// The picked recipes, in catalog order.
  List<StarterRecipe> get selectedRecipes => [
    for (final recipe in set?.recipes ?? const <StarterRecipe>[])
      if (selectedKeys.contains(recipe.key)) recipe,
  ];

  StarterCatalogState copyWith({
    StarterCatalogStatus? status,
    StarterSet? set,
    String? searchTerm,
    Set<String>? selectedKeys,
    MeasureSystem? system,
  }) {
    return StarterCatalogState(
      status: status ?? this.status,
      set: set ?? this.set,
      searchTerm: searchTerm ?? this.searchTerm,
      selectedKeys: selectedKeys ?? this.selectedKeys,
      system: system ?? this.system,
    );
  }

  @override
  List<Object?> get props => [status, set, searchTerm, selectedKeys, system];
}
