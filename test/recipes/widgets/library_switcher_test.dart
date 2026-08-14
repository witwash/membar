import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

class _MockRecipesBloc extends MockBloc<RecipesEvent, RecipesState>
    implements RecipesBloc {}

void main() {
  group('LibrarySwitcher', () {
    late RecipesBloc recipesBloc;

    setUp(() {
      recipesBloc = _MockRecipesBloc();
      whenListen(
        recipesBloc,
        const Stream<RecipesState>.empty(),
        initialState: const RecipesState(),
      );
    });

    Future<void> pumpSwitcher(WidgetTester tester) => tester.pumpApp(
      LibrarySwitcher(
        libraries: [cocktailsLibrary, coffeeLibrary],
        activeLibrary: cocktailsLibrary,
      ),
      recipesBloc: recipesBloc,
    );

    testWidgets('renders the active library name', (tester) async {
      await pumpSwitcher(tester);

      expect(find.text('Cocktails'), findsOneWidget);
      expect(find.text('Coffee'), findsNothing);
    });

    testWidgets('lists every library and marks the active one', (tester) async {
      await pumpSwitcher(tester);

      await tester.tap(find.text('Cocktails'));
      await tester.pumpAndSettle();

      expect(find.text('Coffee'), findsOneWidget);

      final activeItem = find.ancestor(
        of: find.byIcon(FLucideIcons.check),
        matching: find.byType(FItem),
      );
      expect(activeItem, findsOneWidget);
      expect(
        find.descendant(of: activeItem, matching: find.text('Cocktails')),
        findsOneWidget,
      );
    });

    testWidgets('dispatches RecipesLibrarySelected for another library', (
      tester,
    ) async {
      await pumpSwitcher(tester);

      await tester.tap(find.text('Cocktails'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Coffee'));
      await tester.pumpAndSettle();

      verify(
        () => recipesBloc.add(RecipesLibrarySelected(coffeeLibrary.id)),
      ).called(1);
    });
  });
}
