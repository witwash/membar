import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:membar/app/app.dart';
import 'package:membar/logging/logging.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';
import 'package:talker/talker.dart';

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
            activeLibraryId: cocktailsLibrary.id,
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

    testWidgets('logs navigation when given a talker', (tester) async {
      final talker = createTalker(level: LogLevel.verbose);
      await tester.pumpWidget(
        App(recipesRepository: recipesRepository, talker: talker),
      );

      expect(
        talker.history.whereType<RouteLog>(),
        isNotEmpty,
        reason: 'the home route push should have been logged',
      );
    });

    testWidgets('observes nothing when given no talker', (tester) async {
      await tester.pumpWidget(App(recipesRepository: recipesRepository));

      final navigator = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(navigator.navigatorObservers, isEmpty);
    });
  });
}
