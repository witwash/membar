import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:membar/recipes/recipes.dart';

/// Reports the outcome of one kind of mutation to the screen that started it.
///
/// Three screens share a single bloc, so each of them would otherwise have to
/// keep its own "was that mine?" flag in widget state and run its own switch
/// over the status. [mutation] answers the question from the state itself, and
/// this widget owns the switch.
class RecipesMutationListener extends StatelessWidget {
  /// Creates a [RecipesMutationListener] watching [mutation].
  const RecipesMutationListener({
    required this.mutation,
    required this.onSuccess,
    required this.onFailure,
    required this.child,
    super.key,
  });

  /// The kind of mutation this screen started, and the only kind it reacts to.
  final RecipesMutation mutation;

  /// Called once the mutation has gone through.
  final VoidCallback onSuccess;

  /// Called when the mutation failed and the user is staying put.
  final VoidCallback onFailure;

  /// The screen below the listener.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<RecipesBloc, RecipesState>(
      listenWhen: (previous, current) =>
          previous.mutation != current.mutation ||
          previous.mutationStatus != current.mutationStatus,
      listener: (context, state) {
        if (state.mutation != mutation) return;
        switch (state.mutationStatus) {
          case RecipesMutationStatus.success:
            onSuccess();
          case RecipesMutationStatus.failure:
            onFailure();
          case RecipesMutationStatus.initial:
          case RecipesMutationStatus.loading:
            break;
        }
      },
      child: child,
    );
  }
}
