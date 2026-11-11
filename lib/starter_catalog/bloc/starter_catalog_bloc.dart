import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:recipes_repository/recipes_repository.dart';
import 'package:starter_recipes_repository/starter_recipes_repository.dart';

part 'starter_catalog_event.dart';
part 'starter_catalog_state.dart';

/// {@template starter_catalog_bloc}
/// Holds the bundled set offered to a library built from [LibraryTemplate],
/// and the search, selection and measure system the user picks it through.
///
/// Importing is not its job: the picks are handed to the `RecipesBloc`, which
/// owns every write.
/// {@endtemplate}
class StarterCatalogBloc
    extends Bloc<StarterCatalogEvent, StarterCatalogState> {
  /// {@macro starter_catalog_bloc}
  StarterCatalogBloc({
    required this._starterRecipesRepository,
    required this._template,
  }) : super(const StarterCatalogState()) {
    on<StarterCatalogRequested>(_onRequested);
    on<StarterCatalogSearchChanged>(_onSearchChanged);
    on<StarterCatalogRecipeToggled>(_onRecipeToggled);
    on<StarterCatalogVisibleToggled>(_onVisibleToggled);
    on<StarterCatalogMeasureSystemChanged>(_onMeasureSystemChanged);
  }

  final StarterRecipesRepository _starterRecipesRepository;

  final LibraryTemplate _template;

  Future<void> _onRequested(
    StarterCatalogRequested event,
    Emitter<StarterCatalogState> emit,
  ) async {
    emit(state.copyWith(status: StarterCatalogStatus.loading));
    try {
      final set = await _starterRecipesRepository.load(_template);
      emit(state.copyWith(status: StarterCatalogStatus.success, set: set));
      // The bundle is schema-tested, so whatever a load throws is a bug. It is
      // caught whole so the screen reports it rather than spinning forever.
    } on Object {
      emit(state.copyWith(status: StarterCatalogStatus.failure));
    }
  }

  void _onSearchChanged(
    StarterCatalogSearchChanged event,
    Emitter<StarterCatalogState> emit,
  ) {
    emit(state.copyWith(searchTerm: event.term));
  }

  void _onRecipeToggled(
    StarterCatalogRecipeToggled event,
    Emitter<StarterCatalogState> emit,
  ) {
    final selected = {...state.selectedKeys};
    if (!selected.remove(event.key)) selected.add(event.key);
    emit(state.copyWith(selectedKeys: selected));
  }

  void _onVisibleToggled(
    StarterCatalogVisibleToggled event,
    Emitter<StarterCatalogState> emit,
  ) {
    final visible = {for (final recipe in state.visibleRecipes) recipe.key};
    emit(
      state.copyWith(
        selectedKeys: state.allVisibleSelected
            ? state.selectedKeys.difference(visible)
            : state.selectedKeys.union(visible),
      ),
    );
  }

  void _onMeasureSystemChanged(
    StarterCatalogMeasureSystemChanged event,
    Emitter<StarterCatalogState> emit,
  ) {
    emit(state.copyWith(system: event.system));
  }
}
