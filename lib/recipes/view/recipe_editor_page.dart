import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// The recipe form: the core fields every recipe has, plus one control per
/// field the library declares, rendered in schema order.
///
/// The library is passed at push time and never read from the bloc, so the
/// schema cannot change while the form is open — which is what lets the
/// controllers be built once, in [State.didChangeDependencies].
class RecipeEditorPage extends StatefulWidget {
  /// Creates a [RecipeEditorPage] over [library]'s schema.
  ///
  /// [recipe] is null when adding, and the recipe being changed when editing.
  const RecipeEditorPage({required this.library, this.recipe, super.key});

  /// The route that pushes this page, re-providing [bloc].
  ///
  /// The pushed route sits above the provider `RecipesPage` created, so without
  /// re-providing it here the page would throw `ProviderNotFoundException`.
  static Route<void> route({
    required RecipesBloc bloc,
    required Library library,
    Recipe? recipe,
  }) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'recipe-editor'),
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: RecipeEditorPage(library: library, recipe: recipe),
      ),
    );
  }

  /// Pushes the editor on [library], on a new recipe unless [recipe] is given.
  ///
  /// Every entry point — the list's `+`, its empty state, and details' edit
  /// action — goes through here, so they all push the same route.
  static void open(BuildContext context, Library library, {Recipe? recipe}) {
    unawaited(
      Navigator.of(context).push(
        route(
          bloc: context.read<RecipesBloc>(),
          library: library,
          recipe: recipe,
        ),
      ),
    );
  }

  /// The library the recipe belongs to, and whose schema the form renders.
  final Library library;

  /// The recipe being edited, or null when adding a new one.
  final Recipe? recipe;

  @override
  State<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _RecipeEditorPageState extends State<RecipeEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final GlobalKey _nameKey = GlobalKey();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _newTagController = TextEditingController();
  final _tagsController = FMultiValueNotifier<String>();
  final _ingredientRows = <IngredientRowControllers>[];
  final _stepRows = <StepRowControllers>[];
  final _fieldControllers = <String, SchemaFieldController>{};
  final _fieldKeys = <String, GlobalKey>{};

  var _tagOptions = <String>[];
  var _nextRowId = 0;
  var _initialized = false;
  var _saveFailed = false;
  late String _initialSnapshot;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The controllers are built once. They depend on the locale (a Number
    // field formats its initial value through it), which is why this is not
    // initState, and the guard is why a locale change does not rebuild them.
    if (_initialized) return;
    _initialized = true;

    final recipe = widget.recipe;
    final numberFormat = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );

    _nameController.text = recipe?.name ?? '';
    _notesController.text = recipe?.notes ?? '';
    for (final ingredient in recipe?.ingredients ?? const <Ingredient>[]) {
      _ingredientRows.add(
        IngredientRowControllers(_nextRowId++, ingredient: ingredient),
      );
    }
    for (final step in recipe?.steps ?? const <String>[]) {
      _stepRows.add(StepRowControllers(_nextRowId++, step: step));
    }
    for (final field in widget.library.fields) {
      _fieldControllers[field.id] = SchemaFieldController(
        field: field,
        numberFormat: numberFormat,
        recipe: recipe,
      );
      _fieldKeys[field.id] = GlobalKey();
    }
    _tagsController.value = {...?recipe?.tags};
    // Read once, at open time: the tags the library already uses, plus
    // whatever this recipe carries.
    _tagOptions = foldCaseInsensitive([
      ..._tagsController.value,
      ...context.read<RecipesBloc>().state.libraryTags,
    ])..sort(compareCaseInsensitive);
    _initialSnapshot = _snapshot();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    _newTagController.dispose();
    _tagsController.dispose();
    for (final row in _ingredientRows) {
      row.dispose();
    }
    for (final row in _stepRows) {
      row.dispose();
    }
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final adding = widget.recipe == null;
    final saving = context.select<RecipesBloc, bool>(
      (bloc) =>
          bloc.state.mutation == RecipesMutation.recipeSaved &&
          bloc.state.mutationStatus == RecipesMutationStatus.loading,
    );

    return RecipesMutationListener(
      mutation: RecipesMutation.recipeSaved,
      onSuccess: () => Navigator.of(context).pop(),
      onFailure: () => setState(() => _saveFailed = true),
      child: PopScope(
        // Every way out — the back action and the system gesture alike — runs
        // through maybePop, so the dirty check lives in one place.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) => unawaited(_onPopInvoked(didPop)),
        child: FScaffold(
          header: FHeader.nested(
            title: Text(
              adding ? l10n.recipeEditorNewTitle : l10n.recipeEditorEditTitle,
            ),
            prefixes: [
              FHeaderAction.back(
                onPress: () => unawaited(Navigator.of(context).maybePop()),
              ),
            ],
            suffixes: [
              FHeaderAction(
                icon: const Icon(FLucideIcons.check),
                semanticsLabel: l10n.recipeEditorSaveLabel,
                onPress: saving ? null : _save,
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            // Every control is built, not lazily paged in: scrolling to the
            // first invalid field needs its key to have a context even when it
            // sits below the fold, which is exactly where the problem bites.
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  if (_saveFailed) FailureBanner(l10n.recipeEditorSaveFailure),
                  KeyedSubtree(
                    key: _nameKey,
                    child: FTextFormField(
                      label: Text(l10n.recipeEditorNameLabel),
                      control: FTextFieldControl.managed(
                        controller: _nameController,
                      ),
                      // Corrections clear the error as they are typed, rather
                      // than leaving it on screen until the next Save.
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: _validateName,
                    ),
                  ),
                  for (final field in widget.library.fields)
                    KeyedSubtree(
                      key: _fieldKeys[field.id],
                      child: SchemaFieldControl(
                        controller: _fieldControllers[field.id]!,
                      ),
                    ),
                  _IngredientsSection(
                    rows: _ingredientRows,
                    onAdd: _addIngredient,
                    onRemove: _removeIngredient,
                  ),
                  _StepsSection(
                    rows: _stepRows,
                    onAdd: _addStep,
                    onRemove: _removeStep,
                  ),
                  _TagsSection(
                    options: _tagOptions,
                    selection: _tagsController,
                    newTagController: _newTagController,
                    onAdd: _addTag,
                  ),
                  RecipeSectionTitle(l10n.recipeNotesSectionTitle),
                  FTextFormField(
                    label: Text(l10n.recipeEditorNotesLabel),
                    control: FTextFieldControl.managed(
                      controller: _notesController,
                    ),
                    minLines: 3,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateName(String? value) => (value ?? '').trim().isEmpty
      ? context.l10n.recipeEditorNameRequiredError
      : null;

  void _addIngredient() {
    setState(() => _ingredientRows.add(IngredientRowControllers(_nextRowId++)));
  }

  void _removeIngredient(int index) {
    setState(() => _ingredientRows.removeAt(index).dispose());
  }

  void _addStep() {
    setState(() => _stepRows.add(StepRowControllers(_nextRowId++)));
  }

  void _removeStep(int index) {
    setState(() => _stepRows.removeAt(index).dispose());
  }

  void _addTag() {
    final typed = _newTagController.text.trim();
    if (typed.isEmpty) return;

    setState(() {
      // Folding against the options is what reuses the library's own spelling,
      // so re-typing a tag does not sprout a second chip meaning the same.
      final folded = foldCaseInsensitive([..._tagOptions, typed]);
      final tag = folded.length == _tagOptions.length
          ? folded.firstWhere(
              (option) => option.toLowerCase() == typed.toLowerCase(),
            )
          : typed;
      if (!_tagOptions.contains(tag)) {
        _tagOptions = [..._tagOptions, tag]..sort(compareCaseInsensitive);
      }
      _tagsController.update(tag, add: true);
      _newTagController.clear();
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _scrollToFirstInvalid();
      return;
    }

    setState(() => _saveFailed = false);
    context.read<RecipesBloc>().add(RecipesRecipeSaved(_buildRecipe()));
  }

  Future<void> _onPopInvoked(bool didPop) async {
    if (didPop) return;
    if (_isDirty && !await _confirmDiscard()) return;
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirmDiscard() {
    final l10n = context.l10n;
    return showRecipeConfirmDialog(
      context: context,
      title: l10n.recipeEditorDiscardTitle,
      description: widget.recipe == null
          ? l10n.recipeEditorDiscardAddDescription
          : l10n.recipeEditorDiscardEditDescription,
      confirmLabel: l10n.recipeEditorDiscardConfirm,
      cancelLabel: l10n.recipeEditorKeepEditingLabel,
    );
  }

  /// Puts the first field that failed validation on screen.
  ///
  /// `Form.validate` returns only a bool, so the editor runs the validators
  /// itself to find which field failed. On a generated form the offending
  /// control is often below the fold, where "Save does nothing" is what the
  /// user experiences.
  void _scrollToFirstInvalid() {
    final l10n = context.l10n;
    final fields = <(GlobalKey, String?)>[
      (_nameKey, _validateName(_nameController.text)),
      for (final field in widget.library.fields)
        (_fieldKeys[field.id]!, _fieldControllers[field.id]!.validate(l10n)),
    ];

    for (final (key, error) in fields) {
      if (error == null) continue;
      if (key.currentContext case final target?) {
        unawaited(
          Scrollable.ensureVisible(
            target,
            alignment: 0.1,
            duration: const Duration(milliseconds: 200),
          ),
        );
      }
      return;
    }
  }

  Recipe _buildRecipe() {
    final existing = widget.recipe;
    // Edits are laid *over* what is stored, never composed fresh from the
    // rendered controls: a value whose field the schema no longer declares
    // must survive a round trip rather than be silently dropped.
    final fieldValues = {...?existing?.fieldValues};
    for (final field in widget.library.fields) {
      final controller = _fieldControllers[field.id]!;
      if (!controller.isDirty) continue;

      final value = controller.value;
      if (value == null) {
        fieldValues.remove(field.id);
      } else {
        fieldValues[field.id] = value;
      }
    }

    return Recipe(
      id: existing?.id,
      libraryId: widget.library.id,
      name: _nameController.text,
      ingredients: [for (final row in _ingredientRows) ?row.ingredient],
      steps: [for (final row in _stepRows) ?row.step],
      tags: _tagsController.value.toList(),
      notes: _notesController.text.trim(),
      fieldValues: fieldValues,
    );
  }

  bool get _isDirty => _snapshot() != _initialSnapshot;

  /// A canonical rendering of everything the form holds.
  ///
  /// Comparing one of these against the snapshot taken when the form opened is
  /// what tells a dirty editor from a clean one, without needing a listener on
  /// every controller.
  String _snapshot() => jsonEncode({
    'name': _nameController.text.trim(),
    'notes': _notesController.text.trim(),
    'ingredients': [for (final row in _ingredientRows) row.state],
    'steps': [for (final row in _stepRows) row.text.text.trim()],
    'tags': _tagsController.value.toList()..sort(compareCaseInsensitive),
    'fields': [
      for (final field in widget.library.fields)
        if (_fieldControllers[field.id]!.isDirty) field.id,
    ],
  });
}

class _IngredientsSection extends StatelessWidget {
  const _IngredientsSection({
    required this.rows,
    required this.onAdd,
    required this.onRemove,
  });

  final List<IngredientRowControllers> rows;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        RecipeSectionTitle(l10n.recipeIngredientsSectionTitle),
        for (final (index, row) in rows.indexed)
          IngredientRowField(
            key: ValueKey(row.id),
            controllers: row,
            onRemove: () => onRemove(index),
          ),
        FButton(
          variant: FButtonVariant.outline,
          prefix: const Icon(FLucideIcons.plus),
          onPress: onAdd,
          child: Text(l10n.recipeEditorAddIngredientLabel),
        ),
      ],
    );
  }
}

class _StepsSection extends StatelessWidget {
  const _StepsSection({
    required this.rows,
    required this.onAdd,
    required this.onRemove,
  });

  final List<StepRowControllers> rows;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        RecipeSectionTitle(l10n.recipeStepsSectionTitle),
        for (final (index, row) in rows.indexed)
          StepRowField(
            key: ValueKey(row.id),
            number: index + 1,
            controllers: row,
            onRemove: () => onRemove(index),
          ),
        FButton(
          variant: FButtonVariant.outline,
          prefix: const Icon(FLucideIcons.plus),
          onPress: onAdd,
          child: Text(l10n.recipeEditorAddStepLabel),
        ),
      ],
    );
  }
}

class _TagsSection extends StatelessWidget {
  const _TagsSection({
    required this.options,
    required this.selection,
    required this.newTagController,
    required this.onAdd,
  });

  final List<String> options;
  final FMultiValueNotifier<String> selection;
  final TextEditingController newTagController;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        RecipeSectionTitle(l10n.recipeTagsSectionTitle),
        FMultiSelect<String>(
          label: Text(l10n.recipeEditorTagsLabel),
          hint: Text(l10n.recipeEditorTagsHint),
          items: {for (final tag in options) tag: tag},
          control: FMultiValueControl.managed(controller: selection),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: 8,
          children: [
            Expanded(
              child: FTextFormField(
                label: Text(l10n.recipeEditorNewTagLabel),
                control: FTextFieldControl.managed(
                  controller: newTagController,
                ),
                onSubmit: (_) => onAdd(),
              ),
            ),
            FButton(
              variant: FButtonVariant.outline,
              onPress: onAdd,
              child: Text(l10n.recipeEditorAddTagLabel),
            ),
          ],
        ),
      ],
    );
  }
}
