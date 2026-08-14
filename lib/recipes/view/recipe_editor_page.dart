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
  final _ingredientRows = <_IngredientRow>[];
  final _stepRows = <_StepRow>[];
  final _fieldControllers = <String, SchemaFieldController>{};
  final _fieldKeys = <String, GlobalKey>{};

  var _tagOptions = <String>[];
  var _nextRowId = 0;
  var _initialized = false;
  var _saving = false;
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
      _ingredientRows.add(_IngredientRow(_nextRowId++, ingredient: ingredient));
    }
    for (final step in recipe?.steps ?? const <String>[]) {
      _stepRows.add(_StepRow(_nextRowId++, step: step));
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
    _tagOptions = _libraryTags();
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

    return BlocListener<RecipesBloc, RecipesState>(
      listenWhen: (previous, current) =>
          previous.saveStatus != current.saveStatus,
      listener: _onSaveStatusChanged,
      child: PopScope(
        // Every leave route — the back action and the system gesture alike —
        // runs through maybePop, so the dirty check lives in one place.
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
                onPress: _saving ? null : _save,
              ),
            ],
          ),
          // Every control is built, not lazily paged in: scrolling to the
          // first invalid field needs its key to have a context even when it
          // sits below the fold, which is exactly where the problem bites.
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_saveFailed) FailureBanner(l10n.recipeEditorSaveFailure),
                  Padding(
                    key: _nameKey,
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FTextFormField(
                      label: Text(l10n.recipeEditorNameLabel),
                      control: FTextFieldControl.managed(
                        controller: _nameController,
                      ),
                      validator: _validateName,
                    ),
                  ),
                  for (final field in widget.library.fields)
                    Padding(
                      key: _fieldKeys[field.id],
                      padding: const EdgeInsets.only(bottom: 16),
                      child: SchemaFieldControl(
                        controller: _fieldControllers[field.id]!,
                      ),
                    ),
                  _SectionTitle(l10n.recipeIngredientsSectionTitle),
                  for (final (index, row) in _ingredientRows.indexed)
                    Padding(
                      key: ValueKey(row.id),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: IngredientRowField(
                        name: row.name,
                        quantity: row.quantity,
                        unit: row.unit,
                        onRemove: () => _removeIngredient(index),
                      ),
                    ),
                  FButton(
                    variant: FButtonVariant.outline,
                    prefix: const Icon(FLucideIcons.plus),
                    onPress: _addIngredient,
                    child: Text(l10n.recipeEditorAddIngredientLabel),
                  ),
                  _SectionTitle(l10n.recipeStepsSectionTitle),
                  for (final (index, row) in _stepRows.indexed)
                    Padding(
                      key: ValueKey(row.id),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: StepRowField(
                        number: index + 1,
                        controller: row.controller,
                        onRemove: () => _removeStep(index),
                      ),
                    ),
                  FButton(
                    variant: FButtonVariant.outline,
                    prefix: const Icon(FLucideIcons.plus),
                    onPress: _addStep,
                    child: Text(l10n.recipeEditorAddStepLabel),
                  ),
                  _SectionTitle(l10n.recipeTagsSectionTitle),
                  FMultiSelect<String>(
                    label: Text(l10n.recipeEditorTagsLabel),
                    hint: Text(l10n.recipeEditorTagsHint),
                    items: {for (final tag in _tagOptions) tag: tag},
                    control: FMultiValueControl.managed(
                      controller: _tagsController,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: 8,
                    children: [
                      Expanded(
                        child: FTextFormField(
                          label: Text(l10n.recipeEditorNewTagLabel),
                          control: FTextFieldControl.managed(
                            controller: _newTagController,
                          ),
                          onSubmit: (_) => _addTag(),
                        ),
                      ),
                      FButton(
                        variant: FButtonVariant.outline,
                        onPress: _addTag,
                        child: Text(l10n.recipeEditorAddTagLabel),
                      ),
                    ],
                  ),
                  _SectionTitle(l10n.recipeNotesSectionTitle),
                  FTextFormField(
                    label: Text(l10n.recipeEditorNotesLabel),
                    control: FTextFieldControl.managed(
                      controller: _notesController,
                    ),
                    minLines: 3,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 24),
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
    setState(() => _ingredientRows.add(_IngredientRow(_nextRowId++)));
  }

  void _removeIngredient(int index) {
    setState(() => _ingredientRows.removeAt(index).dispose());
  }

  void _addStep() {
    setState(() => _stepRows.add(_StepRow(_nextRowId++)));
  }

  void _removeStep(int index) {
    setState(() => _stepRows.removeAt(index).dispose());
  }

  void _addTag() {
    final typed = _newTagController.text.trim();
    if (typed.isEmpty) return;

    setState(() {
      // Reuse the library's own casing when the tag already exists, so the
      // filter chips do not sprout a second spelling of the same tag.
      final tag = _tagOptions.firstWhere(
        (option) => option.toLowerCase() == typed.toLowerCase(),
        orElse: () => typed,
      );
      if (!_tagOptions.contains(tag)) {
        _tagOptions = [..._tagOptions, tag]..sort(_byLowerCase);
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

    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    context.read<RecipesBloc>().add(RecipesRecipeSaved(_buildRecipe()));
  }

  void _onSaveStatusChanged(BuildContext context, RecipesState state) {
    // Only a save this editor started concerns it: the same bloc backs the
    // list and details screens.
    if (!_saving) return;

    switch (state.saveStatus) {
      case RecipesSaveStatus.success:
        _saving = false;
        Navigator.of(context).pop();
      case RecipesSaveStatus.failure:
        setState(() {
          _saving = false;
          _saveFailed = true;
        });
      case RecipesSaveStatus.initial:
      case RecipesSaveStatus.loading:
        break;
    }
  }

  Future<void> _onPopInvoked(bool didPop) async {
    if (didPop) return;
    if (_isDirty && !await _confirmDiscard()) return;
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirmDiscard() async {
    final l10n = context.l10n;
    final discard = await showFDialog<bool>(
      context: context,
      builder: (dialogContext, _, animation) => FDialog(
        animation: animation,
        builder: (context, style) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Text(l10n.recipeEditorDiscardTitle, style: style.titleTextStyle),
            Text(
              widget.recipe == null
                  ? l10n.recipeEditorDiscardAddDescription
                  : l10n.recipeEditorDiscardEditDescription,
              style: style.bodyTextStyle,
            ),
            FButton(
              variant: FButtonVariant.destructive,
              onPress: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.recipeEditorDiscardConfirm),
            ),
            FButton(
              variant: FButtonVariant.outline,
              onPress: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.recipeEditorKeepEditingLabel),
            ),
          ],
        ),
      ),
    );
    return discard ?? false;
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
      ingredients: [
        for (final row in _ingredientRows)
          if (row.name.text.trim().isNotEmpty)
            Ingredient(
              name: row.name.text,
              quantity: row.quantity.text,
              unit: row.unit.text,
            ),
      ],
      steps: [
        for (final row in _stepRows)
          if (row.controller.text.trim().isNotEmpty) row.controller.text.trim(),
      ],
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
    'ingredients': [
      for (final row in _ingredientRows)
        [row.name.text.trim(), row.quantity.text.trim(), row.unit.text.trim()],
    ],
    'steps': [for (final row in _stepRows) row.controller.text.trim()],
    'tags': _tagsController.value.toList()..sort(_byLowerCase),
    'fields': {
      for (final field in widget.library.fields)
        field.id: _fieldControllers[field.id]!.value,
    },
  });

  /// The tags the multi-select offers: those already used in this library,
  /// plus any the recipe itself carries.
  List<String> _libraryTags() {
    final seen = <String>{};
    final tags = <String>[];
    void add(String tag) {
      if (seen.add(tag.toLowerCase())) tags.add(tag);
    }

    _tagsController.value.forEach(add);
    for (final recipe in context.read<RecipesBloc>().state.recipes) {
      if (recipe.libraryId == widget.library.id) recipe.tags.forEach(add);
    }
    return tags..sort(_byLowerCase);
  }

  static int _byLowerCase(String a, String b) =>
      a.toLowerCase().compareTo(b.toLowerCase());
}

/// The controllers behind one ingredient row, kept together so the row can be
/// added and disposed as a unit.
class _IngredientRow {
  _IngredientRow(this.id, {Ingredient? ingredient})
    : name = TextEditingController(text: ingredient?.name ?? ''),
      quantity = TextEditingController(text: ingredient?.quantity ?? ''),
      unit = TextEditingController(text: ingredient?.unit ?? '');

  final int id;
  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController unit;

  void dispose() {
    name.dispose();
    quantity.dispose();
    unit.dispose();
  }
}

class _StepRow {
  _StepRow(this.id, {String step = ''})
    : controller = TextEditingController(text: step);

  final int id;
  final TextEditingController controller;

  void dispose() => controller.dispose();
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        title,
        style: theme.typography.body.lg.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
