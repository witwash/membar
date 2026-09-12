import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:membar/ingredients/ingredients.dart';
import 'package:membar/recipes/recipes.dart';

/// The screen that curates the ingredients catalog.
///
/// It reads the same [RecipesBloc] as the recipe screens: deciding whether an
/// entry can be deleted needs the recipes and the catalog together.
class IngredientsPage extends StatelessWidget {
  /// Creates an [IngredientsPage].
  const IngredientsPage({super.key});

  /// The route that pushes this page, re-providing [bloc].
  ///
  /// The pushed route sits above the provider `RecipesPage` created, so
  /// without re-providing it here the page would throw
  /// `ProviderNotFoundException`.
  static Route<void> route({required RecipesBloc bloc}) {
    return MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const IngredientsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const IngredientsView();
}
