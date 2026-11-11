import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/quiz/bloc/quiz_bloc.dart';
import 'package:membar/quiz/widgets/quiz_card.dart';
import 'package:membar/quiz/widgets/quiz_summary.dart';
import 'package:membar/ui/ui.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// The quiz screen: the card on top of the deck and the buttons grading it,
/// or the summary once the pass is finished.
class QuizView extends StatelessWidget {
  /// Creates a [QuizView].
  const QuizView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<QuizBloc>().state;

    return PopScope(
      // Leaving freely while nothing is at stake keeps the iOS edge swipe
      // working; only a pass with grades in it asks first.
      canPop: state.isFinished || !state.hasGradedInPass,
      onPopInvokedWithResult: (didPop, _) =>
          unawaited(_onPopInvoked(context, didPop: didPop)),
      child: FScaffold(
        header: FHeader.nested(
          title: Text(l10n.quizTitle),
          prefixes: [
            FHeaderAction.back(onPress: () => Navigator.of(context).maybePop()),
          ],
        ),
        child: switch (state.currentRecipe) {
          final recipe? => _Pass(state: state, recipe: recipe),
          null => const QuizSummary(),
        },
      ),
    );
  }

  Future<void> _onPopInvoked(
    BuildContext context, {
    required bool didPop,
  }) async {
    if (didPop) return;
    final l10n = context.l10n;
    final leave = await showConfirmDialog(
      context: context,
      title: l10n.quizLeaveTitle,
      description: l10n.quizLeaveDescription,
      confirmLabel: l10n.quizLeaveConfirm,
      cancelLabel: l10n.quizKeepGoingLabel,
    );
    if (leave && context.mounted) Navigator.of(context).pop();
  }
}

class _Pass extends StatelessWidget {
  const _Pass({required this.state, required this.recipe});

  final QuizState state;
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<QuizBloc>();
    final flipped = state.flipped;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.spacing200,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            l10n.quizProgressLabel(state.index + 1, state.deck.length),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: QuizCard(
            // A new key per card, across passes too, so the next card never
            // inherits the last one's drag, fly-off or focus.
            key: ValueKey((state.passStart, state.index)),
            recipe: recipe,
            flipped: flipped,
          ),
        ),
        Row(
          spacing: AppSpacing.spacing100,
          children: [
            Expanded(
              child: FButton(
                variant: FButtonVariant.outline,
                prefix: const Icon(FLucideIcons.x),
                onPress: flipped
                    ? () => bloc.add(const QuizCardGraded(remembered: false))
                    : null,
                child: Text(l10n.quizForgotLabel),
              ),
            ),
            Expanded(
              child: FButton(
                prefix: const Icon(FLucideIcons.check),
                onPress: flipped
                    ? () => bloc.add(const QuizCardGraded(remembered: true))
                    : null,
                child: Text(l10n.quizRememberedLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
