import 'package:json_annotation/json_annotation.dart';
import 'package:recipes_api/recipes_api.dart';

/// {@template library_template}
/// The starting point a [Library] was created from, which decides the bundled
/// starter recipes it is offered.
///
/// It is fixed at creation. A library edited beyond recognition keeps it, and
/// starter values its fields no longer fit are dropped on import.
/// {@endtemplate}
@JsonEnum()
enum LibraryTemplate {
  /// Created from [LibraryTemplates.cocktails].
  cocktails,

  /// Created from [LibraryTemplates.coffee].
  coffee,
}
