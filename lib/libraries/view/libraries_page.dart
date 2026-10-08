import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/libraries/libraries.dart';
import 'package:membar/recipes/recipes.dart';

/// The screen that creates, renames and deletes libraries.
///
/// It reads the same [RecipesBloc] as the recipe screens: deleting a library
/// needs the libraries, the recipes and the catalog together.
class LibrariesPage extends StatelessWidget {
  /// Creates a [LibrariesPage].
  const LibrariesPage({super.key});

  /// The route that pushes this page, re-providing [bloc].
  ///
  /// The pushed route sits above the provider `RecipesPage` created, so
  /// without re-providing it here the page would throw
  /// `ProviderNotFoundException`.
  static Route<void> route({required RecipesBloc bloc}) {
    return MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const LibrariesPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const LibrariesView();
}
