import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:membar/recipes/recipes.dart';

import '../../helpers/helpers.dart';

void main() {
  group('RecipePlaceholderImage', () {
    testWidgets('always renders the placeholder icon', (tester) async {
      await tester.pumpApp(const RecipePlaceholderImage());

      expect(find.byIcon(FLucideIcons.image), findsOneWidget);
    });

    testWidgets('carries an accessible label', (tester) async {
      await tester.pumpApp(const RecipePlaceholderImage());

      expect(
        tester.getSemantics(find.byType(RecipePlaceholderImage)).label,
        'No photo yet',
      );
    });

    testWidgets('sizes itself to the given size', (tester) async {
      await tester.pumpApp(
        const Center(child: RecipePlaceholderImage(size: 120)),
      );

      expect(
        tester.getSize(find.byType(RecipePlaceholderImage)),
        const Size.square(120),
      );
    });
  });
}
