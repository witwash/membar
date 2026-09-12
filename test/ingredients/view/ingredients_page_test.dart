import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:membar/ingredients/ingredients.dart';
import 'package:membar/recipes/recipes.dart';

import '../../helpers/helpers.dart';

class _MockRecipesBloc extends MockBloc<RecipesEvent, RecipesState>
    implements RecipesBloc {}

void main() {
  group('IngredientsPage', () {
    late RecipesBloc recipesBloc;

    setUp(() {
      recipesBloc = _MockRecipesBloc();
      whenListen(
        recipesBloc,
        const Stream<RecipesState>.empty(),
        initialState: RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
    });

    testWidgets('renders the view under a pushed route with the bloc '
        're-provided', (tester) async {
      // No bloc above the button: only the route's own provider can supply it.
      await tester.pumpApp(
        Builder(
          builder: (context) => FButton(
            onPress: () => Navigator.of(
              context,
            ).push(IngredientsPage.route(bloc: recipesBloc)),
            child: const Text('Open'),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(IngredientsView), findsOneWidget);
      final context = tester.element(find.byType(IngredientsView));
      expect(context.read<RecipesBloc>(), same(recipesBloc));
    });
  });
}
