import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// The heading above one section of a recipe.
///
/// The editor and the details screen are meant to mirror each other section
/// for section, which they cannot do if each styles its own headings.
class RecipeSectionTitle extends StatelessWidget {
  /// Creates a [RecipeSectionTitle] reading [title].
  const RecipeSectionTitle(this.title, {super.key});

  /// What the section is called.
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Text(
      title,
      style: theme.typography.body.lg.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
