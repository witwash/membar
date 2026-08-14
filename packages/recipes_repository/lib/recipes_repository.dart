/// A repository that exposes recipes, libraries, and the active library to the
/// app.
library;

// The models travel with the repository: for a local-first app with no wire
// schema to insulate against, a second set of domain models plus a
// transformation layer would be speculative. `RecipesApi` comes along because
// it is the type of the repository's constructor argument.
export 'package:recipes_api/recipes_api.dart'
    show
        FieldDefinition,
        FieldType,
        Ingredient,
        Library,
        Recipe,
        RecipeNotFoundException,
        RecipesApi,
        RecipesPersistenceException,
        RecipesSnapshot;
export 'src/recipes_repository.dart';
