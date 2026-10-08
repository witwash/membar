import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/ui/ui.dart';

/// The controller behind one editable option, with the id that keys its row
/// and the text the option was stored under.
class OptionRowControllers {
  /// Creates the controller for an option row, primed with [original].
  ///
  /// [id] identifies the row for as long as it exists, so removing a row does
  /// not renumber the keys of the rows below it.
  OptionRowControllers(this.id, {this.original})
    : text = TextEditingController(text: original);

  /// Identifies this row among the sheet's rows.
  final int id;

  /// The option's stored text, or null for a row added in this session.
  ///
  /// Remembering it per row is what tells a rename from a removal plus an
  /// addition: the row is the same row, whatever its text became.
  final String? original;

  /// What the option says.
  final TextEditingController text;

  /// Releases the controller. Called when the row is removed, and again for
  /// the surviving rows when the sheet closes.
  void dispose() => text.dispose();
}

/// The option list and the renames a set of edited rows amounts to.
///
/// Each row's text is trimmed and a blank row is dropped *before* anything is
/// derived, so blanking a stored option removes it rather than renaming it to
/// nothing.
({List<String> options, Map<String, String> renames}) optionEdits(
  Iterable<({String? original, String text})> rows,
) {
  final options = <String>[];
  final renames = <String, String>{};
  for (final (:original, :text) in rows) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) continue;

    options.add(trimmed);
    if (original != null && original != trimmed) renames[original] = trimmed;
  }
  return (options: options, renames: renames);
}

/// One editable option of a choice field, labelled with its position and
/// carrying the action that removes it.
///
/// The controller is owned by the sheet, which builds it when the row is
/// added and disposes it when the row is removed.
class OptionRowField extends StatelessWidget {
  /// Creates an [OptionRowField] labelled `Option [number]`.
  const OptionRowField({
    required this.number,
    required this.controllers,
    required this.onRemove,
    super.key,
  });

  /// The option's position in the list, counted from one.
  final int number;

  /// The controller this row edits.
  final OptionRowControllers controllers;

  /// Called when the row's remove action is tapped.
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: AppSpacing.spacing100,
      children: [
        Expanded(
          child: FTextFormField(
            label: Text(l10n.fieldEditorOptionLabel(number)),
            control: FTextFieldControl.managed(controller: controllers.text),
          ),
        ),
        FButton.icon(
          onPress: onRemove,
          semanticsLabel: l10n.fieldEditorRemoveOptionLabel(number),
          child: const Icon(FLucideIcons.x),
        ),
      ],
    );
  }
}
