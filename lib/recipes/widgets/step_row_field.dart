import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:membar/l10n/l10n.dart';

/// One editable step of a recipe's method, labelled with its position and
/// carrying the action that removes it.
///
/// The controller is owned by the editor, which builds it when the row is
/// added and disposes it when the row is removed.
class StepRowField extends StatelessWidget {
  /// Creates a [StepRowField] labelled `Step [number]`.
  const StepRowField({
    required this.number,
    required this.controller,
    required this.onRemove,
    super.key,
  });

  /// The step's position in the method, counted from one.
  final int number;

  /// The text of the step.
  final TextEditingController controller;

  /// Called when the row's remove action is tapped.
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 8,
      children: [
        Expanded(
          child: FTextFormField(
            label: Text(l10n.recipeEditorStepLabel(number)),
            control: FTextFieldControl.managed(controller: controller),
            minLines: 2,
            maxLines: 3,
          ),
        ),
        FButton.icon(
          onPress: onRemove,
          semanticsLabel: l10n.recipeEditorRemoveStepLabel,
          child: const Icon(FLucideIcons.x),
        ),
      ],
    );
  }
}
