import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:membar/l10n/l10n.dart';

/// The image slot a recipe reserves, standing in for a photo until image
/// picking ships.
///
/// It always renders the placeholder: `Recipe` carries no image path this
/// slice, so there is nothing else it could render.
class RecipePlaceholderImage extends StatelessWidget {
  /// Creates a [RecipePlaceholderImage] of [size] logical pixels square.
  const RecipePlaceholderImage({this.size = 48, super.key});

  /// The width and height of the slot, in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Semantics(
      label: context.l10n.recipeImagePlaceholderLabel,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colors.muted,
          borderRadius: theme.style.borderRadius.md,
        ),
        child: Icon(
          FLucideIcons.image,
          size: size / 2,
          color: theme.colors.mutedForeground,
        ),
      ),
    );
  }
}
