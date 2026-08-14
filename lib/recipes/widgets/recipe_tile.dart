import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// One row of the recipe list: the reserved image slot, the recipe's name, and
/// its tags.
class RecipeTile extends StatelessWidget {
  /// Creates a [RecipeTile] for [recipe], calling [onPress] when it is tapped.
  const RecipeTile({required this.recipe, required this.onPress, super.key});

  /// The recipe this tile stands for.
  final Recipe recipe;

  /// Called when the tile is tapped.
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    return FTile(
      prefix: const RecipePlaceholderImage(),
      title: Text(recipe.name),
      subtitle: recipe.tags.isEmpty ? null : Text(recipe.tags.join(' · ')),
      onPress: onPress,
    );
  }
}
