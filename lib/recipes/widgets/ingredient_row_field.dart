import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:membar/l10n/l10n.dart';

/// One editable ingredient row: its name, quantity and unit, plus the action
/// that removes the row.
///
/// The controllers are owned by the editor, which builds them when the row is
/// added and disposes them when it is removed.
class IngredientRowField extends StatelessWidget {
  /// Creates an [IngredientRowField] bound to the given controllers.
  const IngredientRowField({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.onRemove,
    super.key,
  });

  /// What the ingredient is. The only part a saved ingredient needs.
  final TextEditingController name;

  /// How much of it the recipe calls for. Free text.
  final TextEditingController quantity;

  /// The unit the quantity is expressed in. Free text.
  final TextEditingController unit;

  /// Called when the row's remove action is tapped.
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: 8,
          children: [
            Expanded(
              child: FTextFormField(
                label: Text(l10n.recipeEditorIngredientLabel),
                control: FTextFieldControl.managed(controller: name),
              ),
            ),
            FButton.icon(
              onPress: onRemove,
              semanticsLabel: l10n.recipeEditorRemoveIngredientLabel,
              child: const Icon(FLucideIcons.x),
            ),
          ],
        ),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: FTextFormField(
                label: Text(l10n.recipeEditorQuantityLabel),
                control: FTextFieldControl.managed(controller: quantity),
              ),
            ),
            Expanded(
              child: FTextFormField(
                label: Text(l10n.recipeEditorUnitLabel),
                control: FTextFieldControl.managed(controller: unit),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
