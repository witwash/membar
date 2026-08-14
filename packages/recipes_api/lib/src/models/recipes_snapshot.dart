import 'package:equatable/equatable.dart';
import 'package:recipes_api/recipes_api.dart';

/// {@template recipes_snapshot}
/// Everything the app needs to render, as one mutually consistent value.
///
/// The three collections travel together because a recipe list is meaningless
/// without the library that describes it: emitting them separately would let a
/// listener observe recipes against a schema that no longer matches.
///
/// This value is never persisted — [libraries], [recipes] and
/// [activeLibraryId] are stored under separate keys — so it carries no JSON
/// serialization.
/// {@endtemplate}
class RecipesSnapshot extends Equatable {
  /// {@macro recipes_snapshot}
  const RecipesSnapshot({
    required this.libraries,
    required this.recipes,
    required this.activeLibraryId,
  });

  /// Every library that exists, in creation order.
  final List<Library> libraries;

  /// Every recipe that exists, across all libraries.
  final List<Recipe> recipes;

  /// The id of the library currently being browsed.
  ///
  /// Never blank: there is always at least one library, so there is always an
  /// active one.
  final String activeLibraryId;

  @override
  List<Object?> get props => [libraries, recipes, activeLibraryId];
}
