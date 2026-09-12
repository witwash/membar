import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:membar/app/app.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

class _MockRecipesRepository extends Mock implements RecipesRepository {}

void main() {
  group('App', () {
    late RecipesRepository recipesRepository;

    setUp(() {
      recipesRepository = _MockRecipesRepository();
      when(recipesRepository.watch).thenAnswer(
        (_) => Stream.value(
          RecipesSnapshot(
            libraries: [cocktailsLibrary],
            recipes: const [],
            ingredients: const [],
            activeLibraryId: cocktailsLibrary.id,
            ingredientsImported: false,
          ),
        ),
      );
    });

    testWidgets('renders RecipesPage', (tester) async {
      await tester.pumpWidget(App(recipesRepository: recipesRepository));
      expect(find.byType(RecipesPage), findsOneWidget);
    });

    testWidgets('provides the repository to the tree', (tester) async {
      await tester.pumpWidget(App(recipesRepository: recipesRepository));

      final context = tester.element(find.byType(RecipesPage));
      expect(context.read<RecipesRepository>(), same(recipesRepository));
    });

    testWidgets("boots to the active library's recipe list", (tester) async {
      await tester.pumpWidget(App(recipesRepository: recipesRepository));
      await tester.pump();

      expect(find.text(cocktailsLibrary.name), findsOneWidget);
    });
  });
}
