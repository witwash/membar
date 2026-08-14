import 'package:local_storage_recipes_api/local_storage_recipes_api.dart';
import 'package:membar/app/app.dart';
import 'package:membar/bootstrap.dart';
import 'package:recipes_repository/recipes_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  await bootstrap(() async {
    final recipesRepository = RecipesRepository(
      recipesApi: LocalStorageRecipesApi(
        plugin: await SharedPreferences.getInstance(),
      ),
    );

    return App(recipesRepository: recipesRepository);
  });
}
