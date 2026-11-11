import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:membar/ui/ui.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// The answer side of a quiz card: [recipe]'s name, its ingredients with
/// amounts, and its numbered steps.
///
/// Library fields, tags and notes are left off; the card tests what the
/// recipe is made of and how.
class QuizCardBack extends StatefulWidget {
  /// Creates a [QuizCardBack] for [recipe].
  const QuizCardBack({required this.recipe, super.key});

  /// The recipe the card shows.
  final Recipe recipe;

  @override
  State<QuizCardBack> createState() => _QuizCardBackState();
}

class _QuizCardBackState extends State<QuizCardBack> {
  final _titleFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // The front is gone once flipped; without a focus target here, keyboard
    // and screen-reader focus would go with it. Autofocus is not enough: the
    // outgoing front still holds focus while the flip runs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final l10n = context.l10n;
    final theme = context.theme;
    final state = context.watch<RecipesBloc>().state;
    // Decided from the rows that resolve, so a recipe whose catalog entries
    // were all deleted never shows a heading over nothing.
    final lines = [
      for (final row in recipe.ingredients) ?ingredientLine(state, row),
    ];

    return FCard(
      child: SizedBox.expand(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.spacing200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.spacing300,
            children: [
              Focus(
                focusNode: _titleFocus,
                child: Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(
                    recipe.name,
                    style: theme.typography.display.xl2.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              _Section(
                title: l10n.recipeIngredientsSectionTitle,
                empty: l10n.quizNoIngredients,
                lines: lines,
              ),
              _Section(
                title: l10n.recipeStepsSectionTitle,
                empty: l10n.quizNoSteps,
                lines: [
                  for (final (index, step) in recipe.steps.indexed)
                    '${index + 1}. $step',
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.empty,
    required this.lines,
  });

  final String title;
  final String empty;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.spacing100,
      children: [
        RecipeSectionTitle(title),
        if (lines.isEmpty)
          Text(
            empty,
            style: theme.typography.body.md.copyWith(
              color: theme.colors.mutedForeground,
            ),
          )
        else
          for (final line in lines) Text(line),
      ],
    );
  }
}
