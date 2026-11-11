import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/quiz/quiz.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// A flash-card quiz over a snapshot of recipes.
class QuizPage extends StatelessWidget {
  /// Creates a [QuizPage].
  const QuizPage({super.key});

  /// The route that pushes a quiz over [recipes], re-providing [bloc] so the
  /// cards can name their ingredients.
  static Route<void> route({
    required RecipesBloc bloc,
    required List<Recipe> recipes,
  }) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'quiz'),
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: bloc),
          BlocProvider(create: (_) => QuizBloc(recipes: recipes)),
        ],
        child: const QuizPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const QuizView();
}
