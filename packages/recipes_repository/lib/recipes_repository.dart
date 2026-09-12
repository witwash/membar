/// A repository that exposes recipes, libraries, and the active library to the
/// app.
library;

// The models travel with the repository: for a local-first app with no wire
// schema to insulate against, a second set of domain models plus a
// transformation layer would be speculative. `RecipesApi` deliberately does
// not travel with them — being the only thing that can reach the data layer is
// the repository's whole job, and re-exporting its contract would hand that
// reach to every widget and bloc above it.
export 'package:recipes_api/recipes_api.dart'
    show
        CatalogIngredient,
        CustomUnit,
        FieldDefinition,
        FieldType,
        Ingredient,
        IngredientInUseException,
        IngredientNameTakenException,
        IngredientNotFoundException,
        KnownUnit,
        Library,
        Recipe,
        RecipeNotFoundException,
        RecipesPersistenceException,
        RecipesSnapshot,
        StandardUnit,
        Unit,
        compareCaseInsensitive,
        foldCaseInsensitive;
export 'src/recipes_repository.dart';
