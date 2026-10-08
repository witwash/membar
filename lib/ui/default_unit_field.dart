import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/ui/app_spacing.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// Holds what a [DefaultUnitField] has chosen: a standard unit, or a custom
/// label typed in its place.
class DefaultUnitController extends ChangeNotifier {
  /// Creates a [DefaultUnitController] starting from [initial].
  DefaultUnitController([Unit? initial])
    : _standardUnit = switch (initial) {
        KnownUnit(:final unit) => unit,
        _ => null,
      },
      _custom = initial is CustomUnit,
      customLabel = TextEditingController(
        text: switch (initial) {
          CustomUnit(:final label) => label,
          _ => '',
        },
      );

  /// The text of the custom unit field. Kept while the list is shown, so
  /// swapping back and forth loses nothing typed.
  final TextEditingController customLabel;

  StandardUnit? _standardUnit;
  bool _custom;

  /// The unit picked from the list, or null when none is.
  StandardUnit? get standardUnit => _standardUnit;

  set standardUnit(StandardUnit? unit) {
    _standardUnit = unit;
    notifyListeners();
  }

  /// Whether the custom field is shown in place of the list.
  bool get custom => _custom;

  /// Swaps the list for the custom field, or back.
  void toggleCustom() {
    _custom = !_custom;
    notifyListeners();
  }

  /// The unit chosen from whichever control is shown, or null for none.
  Unit? get unit {
    if (!_custom) {
      return switch (_standardUnit) {
        final unit? => KnownUnit(unit),
        null => null,
      };
    }
    final label = customLabel.text.trim();
    return label.isEmpty ? null : CustomUnit(label);
  }

  @override
  void dispose() {
    customLabel.dispose();
    super.dispose();
  }
}

/// Chooses an ingredient's default unit: one of the standard units from a
/// list, or any other unit typed into a field that swaps in for it.
///
/// Both ingredient sheets use this, so creating and editing an entry offer
/// the same units the same way.
class DefaultUnitField extends StatelessWidget {
  /// Creates a [DefaultUnitField] backed by [controller].
  ///
  /// While [locked], it shows [lockedUnit] instead of the controller's choice
  /// and cannot be changed.
  const DefaultUnitField({
    required this.controller,
    this.locked = false,
    this.lockedUnit,
    super.key,
  });

  /// What the field has chosen.
  final DefaultUnitController controller;

  /// Whether the field shows [lockedUnit] read-only.
  final bool locked;

  /// The unit shown while [locked].
  final Unit? lockedUnit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final lockedUnit = locked ? this.lockedUnit : null;
        final showCustom = locked
            ? lockedUnit is CustomUnit
            : controller.custom;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.spacing100,
          children: [
            // Each control is keyed apart from the others, so none of them
            // inherits another's state — or controller — when they swap.
            if (lockedUnit case final CustomUnit unit)
              FTextFormField(
                key: ValueKey(('locked-unit', unit.label)),
                label: Text(l10n.defaultUnitCustomFieldLabel),
                enabled: false,
                control: FTextFieldControl.managed(
                  initial: TextEditingValue(text: unit.label),
                ),
              )
            else if (showCustom)
              FTextFormField(
                key: const ValueKey('custom-unit'),
                label: Text(l10n.defaultUnitCustomFieldLabel),
                control: FTextFieldControl.managed(
                  controller: controller.customLabel,
                ),
              )
            else
              FSelect<StandardUnit>(
                key: const ValueKey('standard-unit'),
                label: Text(l10n.defaultUnitLabel),
                items: {
                  for (final unit in StandardUnit.values)
                    KnownUnit(unit).label: unit,
                },
                clearable: true,
                enabled: !locked,
                control: FSelectControl.lifted(
                  value: locked
                      ? switch (lockedUnit) {
                          KnownUnit(:final unit) => unit,
                          _ => null,
                        }
                      : controller.standardUnit,
                  onChange: (unit) => controller.standardUnit = unit,
                ),
              ),
            FButton(
              variant: FButtonVariant.ghost,
              onPress: locked ? null : controller.toggleCustom,
              child: Text(
                showCustom
                    ? l10n.defaultUnitStandardLabel
                    : l10n.defaultUnitCustomLabel,
              ),
            ),
          ],
        );
      },
    );
  }
}
