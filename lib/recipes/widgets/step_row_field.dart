import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:membar/l10n/l10n.dart';

/// The controller behind one editable step, with the id that keys its row.
class StepRowControllers {
  /// Creates the controller for a step row, primed with [step].
  ///
  /// [id] identifies the row for as long as it exists, so removing a row does
  /// not renumber the keys of the rows below it.
  StepRowControllers(this.id, {String step = ''})
    : text = TextEditingController(text: step);

  /// Identifies this row among the editor's rows.
  final int id;

  /// What the step says.
  final TextEditingController text;

  /// The step this row describes, or null when it is blank.
  String? get step => text.text.trim().isEmpty ? null : text.text.trim();

  /// Releases the controller. Called when the row is removed, and again for
  /// the surviving rows when the editor closes.
  void dispose() => text.dispose();
}

/// One editable step of a recipe's method, labelled with its position and
/// carrying the action that removes it.
///
/// The controller is owned by the editor, which builds it when the row is
/// added and disposes it when the row is removed.
class StepRowField extends StatelessWidget {
  /// Creates a [StepRowField] labelled `Step [number]`.
  const StepRowField({
    required this.number,
    required this.controllers,
    required this.onRemove,
    super.key,
  });

  /// The step's position in the method, counted from one.
  final int number;

  /// The controller this row edits.
  final StepRowControllers controllers;

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
            control: FTextFieldControl.managed(controller: controllers.text),
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
