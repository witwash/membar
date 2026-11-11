import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/quiz/bloc/quiz_bloc.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:membar/ui/ui.dart';

/// The end of a quiz pass: the score, the recipes it missed, and the way to
/// retry only those or leave.
class QuizSummary extends StatelessWidget {
  /// Creates a [QuizSummary] of the finished pass.
  const QuizSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;
    final state = context.watch<QuizBloc>().state;
    final total = state.deck.length;
    final missed = state.missedRecipes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.spacing100,
      children: [
        Expanded(
          child: ListView(
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.quizSummaryScore(state.rememberedCount, total),
                  style: theme.typography.display.xl2.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.spacing300),
              if (missed.isEmpty)
                Text(l10n.quizSummaryAllRemembered(total))
              else ...[
                RecipeSectionTitle(l10n.quizSummaryMissedTitle),
                const SizedBox(height: AppSpacing.spacing100),
                for (final recipe in missed)
                  Padding(
                    key: ValueKey(recipe.id),
                    padding: const EdgeInsets.only(
                      bottom: AppSpacing.spacing50,
                    ),
                    child: Text(recipe.name),
                  ),
              ],
            ],
          ),
        ),
        if (missed.isNotEmpty)
          FButton(
            onPress: () =>
                context.read<QuizBloc>().add(const QuizMissedRetried()),
            child: Text(l10n.quizRetryMissedLabel),
          ),
        FButton(
          variant: missed.isEmpty ? FButtonVariant.primary : .outline,
          onPress: () => Navigator.of(context).maybePop(),
          child: Text(l10n.quizDoneLabel),
        ),
      ],
    );
  }
}
