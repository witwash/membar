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
  group('LibraryFieldsPage', () {
    late RecipesBloc recipesBloc;

    setUp(() {
      recipesBloc = _MockRecipesBloc();
      whenListen(
        recipesBloc,
        const Stream<RecipesState>.empty(),
        initialState: RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary, coffeeLibrary],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
    });

    testWidgets('renders the view of its library under a pushed route with '
        'the bloc re-provided', (tester) async {
      // No bloc above the button: only the route's own provider can supply it.
      await tester.pumpApp(
        Builder(
          builder: (context) => FButton(
            onPress: () => Navigator.of(context).push(
              LibraryFieldsPage.route(
                bloc: recipesBloc,
                libraryId: coffeeLibrary.id,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final view = tester.widget<LibraryFieldsView>(
        find.byType(LibraryFieldsView),
      );
      expect(view.libraryId, coffeeLibrary.id);
      final context = tester.element(find.byType(LibraryFieldsView));
      expect(context.read<RecipesBloc>(), same(recipesBloc));
    });
  });
}
