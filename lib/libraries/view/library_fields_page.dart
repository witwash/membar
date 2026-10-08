import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/libraries/libraries.dart';
import 'package:membar/recipes/recipes.dart';

/// The screen that adds, edits and deletes the fields one library declares.
class LibraryFieldsPage extends StatelessWidget {
  /// Creates a [LibraryFieldsPage] for the library carrying [libraryId].
  const LibraryFieldsPage({required this.libraryId, super.key});

  /// The route that pushes this page, re-providing [bloc].
  ///
  /// The pushed route sits above the provider `RecipesPage` created, so
  /// without re-providing it here the page would throw
  /// `ProviderNotFoundException`.
  static Route<void> route({
    required RecipesBloc bloc,
    required String libraryId,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: LibraryFieldsPage(libraryId: libraryId),
      ),
    );
  }

  /// The id of the library whose fields are edited. An id rather than the
  /// library itself, because this screen is what changes it.
  final String libraryId;

  @override
  Widget build(BuildContext context) => LibraryFieldsView(libraryId: libraryId);
}
