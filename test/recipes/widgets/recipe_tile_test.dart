import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  group('RecipeTile', () {
    // A tile sizes itself to its content, so it needs a parent that hands it
    // loose constraints the way the list does.
    Future<void> pumpTile(WidgetTester tester, Widget tile) =>
        tester.pumpApp(Align(alignment: Alignment.topCenter, child: tile));

    testWidgets('renders the name, tags and image slot', (tester) async {
      await pumpTile(
        tester,
        RecipeTile(
          recipe: Recipe(
            libraryId: cocktailsLibrary.id,
            name: 'Negroni',
            tags: const ['Bitter', 'Stirred'],
          ),
          onPress: () {},
        ),
      );

      expect(find.text('Negroni'), findsOneWidget);
      expect(find.text('Bitter · Stirred'), findsOneWidget);
      expect(find.byType(RecipePlaceholderImage), findsOneWidget);
    });

    testWidgets('renders no subtitle when the recipe has no tags', (
      tester,
    ) async {
      await pumpTile(
        tester,
        RecipeTile(
          recipe: Recipe(libraryId: cocktailsLibrary.id, name: 'Daiquiri'),
          onPress: () {},
        ),
      );

      expect(find.text('Daiquiri'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('calls onPress when tapped', (tester) async {
      var pressed = 0;

      await pumpTile(
        tester,
        RecipeTile(
          recipe: Recipe(libraryId: cocktailsLibrary.id, name: 'Daiquiri'),
          onPress: () => pressed++,
        ),
      );

      await tester.tap(find.text('Daiquiri'));
      await tester.pumpAndSettle();

      expect(pressed, 1);
    });
  });
}
