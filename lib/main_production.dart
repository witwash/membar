import 'package:local_storage_recipes_api/local_storage_recipes_api.dart';
import 'package:membar/app/app.dart';
import 'package:membar/bootstrap.dart';
import 'package:membar/logging/logging.dart';
import 'package:recipes_repository/recipes_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

Future<void> main() async {
  await bootstrap(logLevel: LogLevel.warning, (talker) async {
    final recipesRepository = RecipesRepository(
      recipesApi: LocalStorageRecipesApi(
        plugin: await SharedPreferences.getInstance(),
        onRecoveryError: talker.storage,
      ),
    );

    return App(recipesRepository: recipesRepository, talker: talker);
  });
}
