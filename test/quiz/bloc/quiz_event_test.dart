import 'package:flutter_test/flutter_test.dart';
import 'package:membar/quiz/quiz.dart';

void main() {
  group('QuizEvent', () {
    test('QuizCardFlipped supports value equality', () {
      // Deliberately not const: two const instances are canonicalized into
      // one, so equality would short-circuit on identity and never reach the
      // props this asserts.
      // ignore: prefer_const_constructors
      expect(QuizCardFlipped(), QuizCardFlipped());
    });

    test('QuizCardGraded carries the grade', () {
      expect(
        const QuizCardGraded(remembered: true),
        const QuizCardGraded(remembered: true),
      );
      expect(
        const QuizCardGraded(remembered: true),
        isNot(const QuizCardGraded(remembered: false)),
      );
    });

    test('QuizMissedRetried supports value equality', () {
      // Not const, for the same reason as QuizCardFlipped above.
      // ignore: prefer_const_constructors
      expect(QuizMissedRetried(), QuizMissedRetried());
    });
  });
}
