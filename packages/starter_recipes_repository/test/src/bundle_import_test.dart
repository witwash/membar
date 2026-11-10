import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes_api/recipes_api.dart';
import 'package:starter_recipes_repository/starter_recipes_repository.dart';

/// Serves `starter_recipes`' asset keys from its files on disk, found through
/// the package config, so the real loader reads the real bundle.
class _DiskBundle extends CachingAssetBundle {
  _DiskBundle(this._root);

  final Uri _root;

  @override
  Future<ByteData> load(String key) async {
    final path = key.replaceFirst('packages/starter_recipes/', '');
    final file = File.fromUri(_root.resolve(path));
    return ByteData.sublistView(await file.readAsBytes());
  }
}

Uri _starterRecipesRoot() {
  final config = File('.dart_tool/package_config.json');
  final packages =
      (jsonDecode(config.readAsStringSync())
              as Map<String, dynamic>)['packages']
          as List<dynamic>;
  final entry = packages.cast<Map<String, dynamic>>().singleWhere(
    (package) => package['name'] == 'starter_recipes',
  );
  final root = config.absolute.uri.resolve(entry['rootUri'] as String);
  return root.path.endsWith('/') ? root : Uri.parse('$root/');
}

Library _library(LibraryTemplate template) {
  const templates = LibraryTemplates();
  return switch (template) {
    LibraryTemplate.cocktails => templates.cocktails(ingredientLibraryId: 'x'),
    LibraryTemplate.coffee => templates.coffee(ingredientLibraryId: 'x'),
  };
}

void main() {
  final repository = StarterRecipesRepository(
    loader: StarterRecipesLoader(_DiskBundle(_starterRecipesRoot())),
  );

  for (final template in LibraryTemplate.values) {
    for (final system in MeasureSystem.values) {
      test(
        'imports every ${template.name} recipe in ${system.name} without '
        'dropping a value',
        () async {
          final set = await repository.load(template);

          final import = repository.buildImport(
            set: set,
            names: {for (final recipe in set.recipes) recipe.key: recipe.name},
            library: _library(template),
            entries: const [],
            system: system,
          );

          expect(import.recipes, hasLength(set.recipes.length));
          for (final (index, recipe) in import.recipes.indexed) {
            final starter = set.recipes[index];
            expect(
              recipe.fieldValues,
              hasLength(starter.fields.length),
              reason: starter.key,
            );
            expect(
              recipe.ingredients,
              hasLength(starter.rows.length),
              reason: starter.key,
            );
          }
        },
      );
    }
  }
}
