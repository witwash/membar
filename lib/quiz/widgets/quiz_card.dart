import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/quiz/bloc/quiz_bloc.dart';
import 'package:membar/quiz/widgets/quiz_card_back.dart';
import 'package:membar/ui/ui.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// How far, as a fraction of the card's width, a released drag must have
/// travelled to grade the card.
const swipeDistanceFraction = 0.35;

/// How fast, in logical pixels per second, a released drag must be moving to
/// grade the card however short it was.
const swipeVelocity = 800.0;

/// How long the card takes to turn over.
const flipDuration = Duration(milliseconds: 300);

/// How long a graded card takes to leave the screen.
const flyOffDuration = Duration(milliseconds: 200);

/// How long a released, ungraded card takes to settle back.
const springBackDuration = Duration(milliseconds: 250);

/// How far the card tilts, in radians, when dragged one full width.
const _maxTilt = 0.3;

/// One flash card: [recipe]'s name until tapped, then its back, which a
/// horizontal swipe grades — right as remembered, left as not.
///
/// Key it per card, so a new card never inherits a drag or fly-off in
/// progress.
class QuizCard extends StatefulWidget {
  /// Creates a [QuizCard] for [recipe], showing its back when [flipped].
  const QuizCard({required this.recipe, required this.flipped, super.key});

  /// The recipe the card shows.
  final Recipe recipe;

  /// Whether the card shows its back.
  final bool flipped;

  @override
  State<QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<QuizCard>
    with SingleTickerProviderStateMixin {
  late final _offset = AnimationController.unbounded(vsync: this);
  var _flyingOff = false;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  Duration _duration(Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

  void _onDragUpdate(DragUpdateDetails details) {
    if (_flyingOff) return;
    _offset.value += details.delta.dx;
  }

  void _onDragEnd(DragEndDetails details, double width) {
    if (_flyingOff) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() > swipeVelocity) {
      unawaited(_flyOff(remembered: velocity > 0, width: width));
    } else if (_offset.value.abs() > width * swipeDistanceFraction) {
      unawaited(_flyOff(remembered: _offset.value > 0, width: width));
    } else {
      _springBack();
    }
  }

  void _springBack() {
    if (_flyingOff) return;
    _offset.animateTo(
      0,
      duration: _duration(springBackDuration),
      curve: Curves.easeOut,
    );
  }

  Future<void> _flyOff({
    required bool remembered,
    required double width,
  }) async {
    _flyingOff = true;
    final bloc = context.read<QuizBloc>();
    await _offset.animateTo(
      (remembered ? 1 : -1) * width * 1.5,
      duration: _duration(flyOffDuration),
      curve: Curves.easeIn,
    );
    if (!mounted) return;
    bloc.add(QuizCardGraded(remembered: remembered));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return GestureDetector(
          onHorizontalDragUpdate: widget.flipped ? _onDragUpdate : null,
          onHorizontalDragEnd: widget.flipped
              ? (details) => _onDragEnd(details, width)
              : null,
          onHorizontalDragCancel: widget.flipped ? _springBack : null,
          child: AnimatedBuilder(
            animation: _offset,
            builder: (context, child) => Transform.translate(
              offset: Offset(_offset.value, 0),
              child: Transform.rotate(
                angle: _offset.value / width * _maxTilt,
                child: child,
              ),
            ),
            child: AnimatedSwitcher(
              duration: _duration(flipDuration),
              // Each side turns during its own half, so the outgoing side is
              // edge-on before the incoming one starts to show.
              switchInCurve: const Interval(0.5, 1),
              switchOutCurve: const Interval(0.5, 1),
              transitionBuilder: _turn,
              child: widget.flipped
                  ? QuizCardBack(
                      key: const ValueKey('back'),
                      recipe: widget.recipe,
                    )
                  : _Front(
                      key: const ValueKey('front'),
                      name: widget.recipe.name,
                      onPress: () =>
                          context.read<QuizBloc>().add(const QuizCardFlipped()),
                    ),
            ),
          ),
        );
      },
    );
  }

  static Widget _turn(Widget child, Animation<double> animation) =>
      AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY((1 - animation.value) * pi / 2),
          child: child,
        ),
        child: child,
      );
}

class _Front extends StatelessWidget {
  const _Front({required this.name, required this.onPress, super.key});

  final String name;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;

    return FTappable(
      autofocus: true,
      semanticsLabel: name,
      onPress: onPress,
      child: Semantics(
        onTapHint: l10n.quizRevealAction,
        child: FCard(
          child: SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.spacing200),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: AppSpacing.spacing200,
                children: [
                  // The tappable's label already reads the name.
                  ExcludeSemantics(
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: theme.typography.display.xl3.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: Text(
                      l10n.quizRevealHint,
                      style: theme.typography.body.sm.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
