import 'package:flutter_test/flutter_test.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';
import 'package:starter_recipes_repository/starter_recipes_repository.dart';

import '../../helpers/helpers.dart';

class _MockRecipesRepository extends Mock implements RecipesRepository {}

class _MockStarterRecipesRepository extends Mock
    implements StarterRecipesRepository {}

void main() {
  group('RecipesPage', () {
    late RecipesRepository recipesRepository;

    setUp(() {
      recipesRepository = _MockRecipesRepository();
      when(recipesRepository.watch).thenAnswer(
        (_) => Stream.value(
          RecipesSnapshot(
            libraries: [cocktailsLibrary],
            recipes: const [],
            ingredientLibraries: [cocktailsPantry],
            ingredients: const [],
            activeLibraryId: cocktailsLibrary.id,
          ),
        ),
      );
    });

    testWidgets('renders RecipesView', (tester) async {
      await tester.pumpApp(
        const RecipesPage(),
        recipesRepository: recipesRepository,
        starterRecipesRepository: _MockStarterRecipesRepository(),
      );

      expect(find.byType(RecipesView), findsOneWidget);
    });

    testWidgets('subscribes to the repository', (tester) async {
      await tester.pumpApp(
        const RecipesPage(),
        recipesRepository: recipesRepository,
        starterRecipesRepository: _MockStarterRecipesRepository(),
      );
      await tester.pump();

      verify(recipesRepository.watch).called(1);
      expect(find.text(cocktailsLibrary.name), findsOneWidget);
    });
  });
}
