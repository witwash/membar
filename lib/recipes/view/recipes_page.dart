import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// The app's home route: the recipe list of the active library.
///
/// It creates the one [RecipesBloc] that backs every recipe screen. The pushed
/// routes sit above this provider, so each of them re-provides this instance
/// with `BlocProvider.value`.
class RecipesPage extends StatelessWidget {
  /// Creates a [RecipesPage].
  const RecipesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          RecipesBloc(recipesRepository: context.read<RecipesRepository>())
            ..add(const RecipesSubscriptionRequested()),
      child: const RecipesView(),
    );
  }
}
