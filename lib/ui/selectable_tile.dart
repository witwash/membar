import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// A tile carrying a checkbox, read out as one node: its title, subtitle and
/// badge, and whether it is selected.
///
/// The whole row is the one tap target and the one keyboard stop; the
/// checkbox only shows the state.
class SelectableTile extends StatelessWidget {
  /// Creates a [SelectableTile] that calls [onPress] when tapped anywhere.
  const SelectableTile({
    required this.title,
    required this.selected,
    required this.onPress,
    this.subtitle,
    this.badge,
    super.key,
  });

  /// The row's main text.
  final String title;

  /// A secondary line under [title]; hidden when null or empty.
  final String? subtitle;

  /// A short outlined tag at the row's end; hidden when null.
  final String? badge;

  /// Whether the checkbox is ticked.
  final bool selected;

  /// Called when the row is tapped or activated from the keyboard.
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final badge = this.badge;
    final hasSubtitle = subtitle != null && subtitle.isNotEmpty;

    return FTile(
      semanticsLabel: [title, if (hasSubtitle) subtitle, ?badge].join(', '),
      selected: selected,
      prefix: FTappableGroup.isolate(
        // FTileGroup routes a press to the deepest FTappable under it by
        // geometry, not by hit-testing, so IgnorePointer alone would leave
        // this checkbox swallowing taps; isolate keeps it out of the group and
        // ExcludeFocus out of the tab order, leaving the tile as the one
        // target.
        child: ExcludeFocus(
          child: IgnorePointer(
            child: ExcludeSemantics(child: FCheckbox(value: selected)),
          ),
        ),
      ),
      // The label above already reads these; left in, the tile would merge
      // them in a second time.
      title: ExcludeSemantics(child: Text(title)),
      subtitle: hasSubtitle ? ExcludeSemantics(child: Text(subtitle)) : null,
      suffix: badge == null
          ? null
          : ExcludeSemantics(
              child: FBadge(variant: FBadgeVariant.outline, child: Text(badge)),
            ),
      onPress: onPress,
    );
  }
}
