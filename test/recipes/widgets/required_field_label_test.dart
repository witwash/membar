import 'package:flutter_test/flutter_test.dart';
import 'package:membar/recipes/recipes.dart';

import '../../helpers/helpers.dart';

void main() {
  group('RequiredFieldLabel', () {
    testWidgets('renders the label with a mark after it', (tester) async {
      await tester.pumpApp(const RequiredFieldLabel('Garnish'));

      expect(find.text('Garnish *'), findsOneWidget);
    });

    testWidgets('reads the requirement out in words, not as the mark', (
      tester,
    ) async {
      await tester.pumpApp(const RequiredFieldLabel('Garnish'));

      expect(
        tester.getSemantics(find.byType(RequiredFieldLabel)).label,
        'Garnish, required',
      );
    });
  });
}
