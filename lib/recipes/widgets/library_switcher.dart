import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// The recipe list's header title: the active library's name, tappable to
/// switch to another library.
///
/// It renders only on the list screen. The details and editor screens use a
/// nested header with a back action, so a schema can never change out from
/// under an open screen.
class LibrarySwitcher extends StatelessWidget {
  /// Creates a [LibrarySwitcher] offering [libraries], with [activeLibrary]
  /// marked as the one currently being browsed.
  const LibrarySwitcher({
    required this.libraries,
    required this.activeLibrary,
    super.key,
  });

  /// Every library that can be switched to, in creation order.
  final List<Library> libraries;

  /// The library currently being browsed.
  final Library activeLibrary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;

    return FPopoverMenu(
      semanticsLabel: l10n.recipesLibrarySwitcherLabel,
      menuBuilder: (context, controller, _) => [
        FItemGroup(
          children: [
            for (final library in libraries)
              FItem(
                title: Text(library.name),
                suffix: library.id == activeLibrary.id
                    ? Semantics(
                        label: l10n.recipesActiveLibraryLabel,
                        child: const Icon(FLucideIcons.check),
                      )
                    : null,
                onPress: () {
                  unawaited(controller.hide());
                  context.read<RecipesBloc>().add(
                    RecipesLibrarySelected(library.id),
                  );
                },
              ),
          ],
        ),
      ],
      builder: (context, controller, _) => FTappable(
        semanticsLabel: l10n.recipesLibrarySwitcherLabel,
        onPress: () => unawaited(controller.toggle()),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(activeLibrary.name, style: theme.typography.body.lg),
            const SizedBox(width: 4),
            Icon(
              FLucideIcons.chevronsUpDown,
              size: 16,
              color: theme.colors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}
