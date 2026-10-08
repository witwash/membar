import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// The controllers behind one editable ingredient row, kept together so a row
/// can be added and disposed as a unit.
class IngredientRowControllers {
  /// Creates the controllers for a row, primed from [ingredient] when the
  /// recipe already has one.
  ///
  /// [id] identifies the row for as long as it exists, so removing a row does
  /// not renumber the keys of the rows below it.
  ///
  /// [entry] is the catalog entry [ingredient] references, when it still
  /// exists. Its current name is shown in place of the stored one, so a
  /// renamed entry keeps its link when the recipe is saved again.
  IngredientRowControllers(
    this.id, {
    Ingredient? ingredient,
    CatalogIngredient? entry,
  }) : name = FAutocompleteController(
         text: entry?.name ?? ingredient?.name ?? '',
       ),
       quantity = TextEditingController(text: ingredient?.quantity ?? ''),
       unit = TextEditingController(text: ingredient?.unit ?? '');

  /// Identifies this row among the editor's rows.
  final int id;

  /// What the ingredient is. The only part a saved ingredient needs.
  final FAutocompleteController name;

  /// How much of it the recipe calls for. Free text.
  final TextEditingController quantity;

  /// The unit the quantity is expressed in. Free text.
  final TextEditingController unit;

  /// The ingredient this row describes, or null when it is blank.
  ///
  /// A row with no name is not an ingredient, whatever else was typed into it.
  /// It links to the catalog entry in [state] its name matches, and to
  /// nothing otherwise — so picking an entry, typing its name, and editing a
  /// picked name back into free text all resolve without the row tracking a
  /// link.
  Ingredient? ingredientIn(RecipesState state) => name.text.trim().isEmpty
      ? null
      : Ingredient(
          name: name.text,
          quantity: quantity.text,
          unit: unit.text,
          catalogId: state.ingredientNamed(name.text)?.id,
        );

  /// What the row holds, for telling a touched editor from an untouched one.
  List<String> get state => [
    name.text.trim(),
    quantity.text.trim(),
    unit.text.trim(),
  ];

  /// Releases every controller. Called when the row is removed, and again for
  /// the surviving rows when the editor closes.
  void dispose() {
    name.dispose();
    quantity.dispose();
    unit.dispose();
  }
}

/// One editable ingredient row: its name, quantity and unit, plus the action
/// that removes the row.
///
/// The controllers are owned by the editor, which builds them when the row is
/// added and disposes them when it is removed.
class IngredientRowField extends StatelessWidget {
  /// Creates an [IngredientRowField] bound to [controllers].
  const IngredientRowField({
    required this.controllers,
    required this.onRemove,
    super.key,
  });

  /// The controllers this row edits.
  final IngredientRowControllers controllers;

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
              child: IngredientPicker(
                name: controllers.name,
                unit: controllers.unit,
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
                control: FTextFieldControl.managed(
                  controller: controllers.quantity,
                ),
              ),
            ),
            Expanded(
              child: FTextFormField(
                label: Text(l10n.recipeEditorUnitLabel),
                control: FTextFieldControl.managed(
                  controller: controllers.unit,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
