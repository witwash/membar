import 'package:flutter_test/flutter_test.dart';
import 'package:membar/quiz/quiz.dart';

void main() {
  group('CardOutcome', () {
    final answeredAt = DateTime(2026, 11, 11, 9);

    CardOutcome outcome({
      String recipeId = 'a',
      bool remembered = true,
      DateTime? at,
    }) => CardOutcome(
      recipeId: recipeId,
      remembered: remembered,
      answeredAt: at ?? answeredAt,
    );

    test('supports value equality', () {
      expect(outcome(), outcome());
    });

    test('differs by recipe', () {
      expect(outcome(), isNot(outcome(recipeId: 'b')));
    });

    test('differs by grade', () {
      expect(outcome(), isNot(outcome(remembered: false)));
    });

    test('differs by answer time', () {
      expect(
        outcome(),
        isNot(outcome(at: answeredAt.add(const Duration(seconds: 1)))),
      );
    });
  });
}
