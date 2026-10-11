import 'package:flutter/widgets.dart';
import 'package:membar/l10n/l10n.dart';

/// The label of a field a recipe has to fill in: the text with a mark after
/// it, read out as "…, required" rather than as a bare glyph.
class RequiredFieldLabel extends StatelessWidget {
  /// Creates a [RequiredFieldLabel] marking [label].
  const RequiredFieldLabel(this.label, {super.key});

  /// What the field is called, without the mark.
  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Text(
      l10n.recipeEditorRequiredFieldMark(label),
      semanticsLabel: l10n.recipeEditorRequiredFieldSemanticLabel(label),
    );
  }
}
