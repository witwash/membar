import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/libraries/libraries.dart';
import 'package:membar/recipes/recipes.dart';

import '../../helpers/helpers.dart';

class _MockRecipesBloc extends MockBloc<RecipesEvent, RecipesState>
    implements RecipesBloc {}

void main() {
  group('LibrariesPage', () {
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
            ).push(LibrariesPage.route(bloc: recipesBloc)),
            child: const Text('Open'),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(LibrariesView), findsOneWidget);
      final context = tester.element(find.byType(LibrariesView));
      expect(context.read<RecipesBloc>(), same(recipesBloc));
    });
  });
}
