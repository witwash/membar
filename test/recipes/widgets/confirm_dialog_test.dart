import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:membar/recipes/recipes.dart';

import '../../helpers/helpers.dart';

void main() {
  group('showRecipeConfirmDialog', () {
    late Future<bool> result;

    Future<void> open(WidgetTester tester) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showRecipeConfirmDialog(
              context: context,
              title: 'Delete Negroni?',
              description: 'This cannot be undone.',
              confirmLabel: 'Delete',
              cancelLabel: 'Cancel',
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('asks the question it was given', (tester) async {
      await open(tester);

      expect(find.text('Delete Negroni?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);
    });

    testWidgets('pads its content away from the dialog border', (tester) async {
      await open(tester);

      // Measured against what is on screen rather than against the widget
      // tree: the bug was content rendering flush to the frame, and a Padding
      // in the tree is only evidence of a gap, not the gap itself. The 24 is
      // written out so that zeroing the token fails this test.
      final frame = tester.getRect(
        find
            .descendant(
              of: find.byType(FDialog),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final title = tester.getRect(find.text('Delete Negroni?'));

      expect(title.left - frame.left, 24);
      expect(title.top - frame.top, 24);
      expect(frame.right - title.right, 24);
    });

    testWidgets('resolves to true when the user confirms', (tester) async {
      await open(tester);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(await result, isTrue);
    });

    testWidgets('resolves to false when the user cancels', (tester) async {
      await open(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await result, isFalse);
    });

    testWidgets('resolves to false when the user dismisses it', (tester) async {
      await open(tester);

      // The barrier fills everything outside the dialog, so a tap in the top
      // corner lands on it rather than on any of the dialog's own controls.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(await result, isFalse);
    });
  });
}
