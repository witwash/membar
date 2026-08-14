import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:membar/app/app.dart';
import 'package:membar/counter/counter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';

class _MockRecipesRepository extends Mock implements RecipesRepository {}

void main() {
  group('App', () {
    late RecipesRepository recipesRepository;

    setUp(() {
      recipesRepository = _MockRecipesRepository();
    });

    testWidgets('renders CounterPage', (tester) async {
      await tester.pumpWidget(App(recipesRepository: recipesRepository));
      expect(find.byType(CounterPage), findsOneWidget);
    });

    testWidgets('provides the repository to the tree', (tester) async {
      await tester.pumpWidget(App(recipesRepository: recipesRepository));

      final context = tester.element(find.byType(CounterPage));
      expect(context.read<RecipesRepository>(), same(recipesRepository));
    });
  });
}
