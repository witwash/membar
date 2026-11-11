import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/app/app.dart';
import 'package:membar/logging/logging.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';
import 'package:starter_recipes_repository/starter_recipes_repository.dart';
import 'package:talker/talker.dart';

import '../../helpers/helpers.dart';

class _MockRecipesRepository extends Mock implements RecipesRepository {}

class _MockStarterRecipesRepository extends Mock
    implements StarterRecipesRepository {}

void main() {
  group('App', () {
    late RecipesRepository recipesRepository;
    late StarterRecipesRepository starterRecipesRepository;

    setUp(() {
      recipesRepository = _MockRecipesRepository();
      starterRecipesRepository = _MockStarterRecipesRepository();
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

    App buildApp({Talker? talker}) => App(
      recipesRepository: recipesRepository,
      starterRecipesRepository: starterRecipesRepository,
      talker: talker,
    );

    testWidgets('renders RecipesPage', (tester) async {
      await tester.pumpWidget(buildApp());
      expect(find.byType(RecipesPage), findsOneWidget);
    });

    testWidgets('provides both repositories to the tree', (tester) async {
      await tester.pumpWidget(buildApp());

      final context = tester.element(find.byType(RecipesPage));
      expect(context.read<RecipesRepository>(), same(recipesRepository));
      expect(
        context.read<StarterRecipesRepository>(),
        same(starterRecipesRepository),
      );
    });

    testWidgets("boots to the active library's recipe list", (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      expect(find.text(cocktailsLibrary.name), findsOneWidget);
    });

    testWidgets('logs navigation when given a talker', (tester) async {
      final talker = createTalker(level: LogLevel.verbose);
      await tester.pumpWidget(buildApp(talker: talker));

      expect(
        talker.history.whereType<RouteLog>(),
        isNotEmpty,
        reason: 'the home route push should have been logged',
      );
    });

    testWidgets('observes nothing when given no talker', (tester) async {
      await tester.pumpWidget(buildApp());

      final navigator = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(navigator.navigatorObservers, isEmpty);
    });
  });
}
