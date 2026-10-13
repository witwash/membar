import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:membar/ui/ui.dart';

import '../helpers/helpers.dart';

void main() {
  group('showRefusalToast', () {
    late FToasterEntry entry;

    Future<void> raise(WidgetTester tester) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => FButton(
            onPress: () => entry = showRefusalToast(
              context,
              title: 'Nope',
              description: 'Here is why.',
            ),
            child: const Text('Raise'),
          ),
        ),
      );
      await tester.tap(find.text('Raise'));
      await tester.pumpAndSettle();
    }

    testWidgets('renders the title and description in a toast', (
      tester,
    ) async {
      await raise(tester);

      expect(inToast('Nope'), findsOneWidget);
      expect(inToast('Here is why.'), findsOneWidget);
    });

    testWidgets('shows the toast in the bottom half of the screen', (
      tester,
    ) async {
      await raise(tester);

      final screen = tester.getRect(find.byType(FToaster));
      expect(
        tester.getRect(find.byType(FToast)).top,
        greaterThan(screen.center.dy),
      );
    });

    testWidgets('hands back an entry that dismisses the toast', (tester) async {
      await raise(tester);

      entry.dismiss();
      await tester.pumpAndSettle();

      expect(find.byType(FToast), findsNothing);
    });
  });
}
