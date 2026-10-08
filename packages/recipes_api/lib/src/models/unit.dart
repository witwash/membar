import 'package:equatable/equatable.dart';

/// The measurement units the app knows by name.
enum StandardUnit {
  /// Millilitres.
  ml,

  /// Centilitres.
  cl,

  /// Fluid ounces.
  oz,

  /// A dash, as shaken from a bitters bottle.
  dash,

  /// A single drop.
  drop,

  /// A bar spoon.
  barspoon,

  /// A teaspoon.
  teaspoon,

  /// A tablespoon.
  tablespoon,

  /// Grams.
  gram,

  /// A whole item, such as one egg or one lemon wedge.
  piece,
}

/// {@template unit}
/// A measurement unit: either one of the [StandardUnit]s or a [CustomUnit]
/// label for everything else.
///
/// The two kinds are kept apart in JSON, so a custom label spelled `ml` is
/// never mistaken for the known unit.
/// {@endtemplate}
sealed class Unit extends Equatable {
  /// {@macro unit}
  const Unit();

  /// Converts a JSON [Map] into a [Unit].
  ///
  /// A standard unit this build does not know — one written by a newer
  /// version — decodes as a [CustomUnit] carrying its name rather than
  /// throwing, so a single unfamiliar unit cannot cost the whole catalog.
  factory Unit.fromJson(Map<String, dynamic> json) {
    switch (json['kind']) {
      case 'standard':
        final name = json['unit'] as String;
        final unit = StandardUnit.values.asNameMap()[name];
        return unit == null ? CustomUnit(name) : KnownUnit(unit);
      case 'custom':
        return CustomUnit(json['label'] as String);
      default:
        throw FormatException('Unknown unit kind: ${json['kind']}.');
    }
  }

  /// What is written into an ingredient row's unit field, such as `ml`.
  String get label;

  /// Converts this [Unit] into a JSON [Map].
  Map<String, dynamic> toJson();
}

/// {@template known_unit}
/// One of the [StandardUnit]s.
/// {@endtemplate}
final class KnownUnit extends Unit {
  /// {@macro known_unit}
  const KnownUnit(this.unit);

  /// The standard unit this is.
  final StandardUnit unit;

  @override
  String get label => unit.name;

  @override
  Map<String, dynamic> toJson() => {'kind': 'standard', 'unit': unit.name};

  @override
  List<Object?> get props => [unit];
}

/// {@template custom_unit}
/// A unit outside the [StandardUnit]s, such as `sprig` or `pinch`.
/// {@endtemplate}
final class CustomUnit extends Unit {
  /// {@macro custom_unit}
  ///
  /// [label] is trimmed and must not be blank.
  CustomUnit(String label)
    : assert(label.trim().isNotEmpty, 'A unit label must not be blank.'),
      label = label.trim();

  @override
  final String label;

  @override
  Map<String, dynamic> toJson() => {'kind': 'custom', 'label': label};

  @override
  List<Object?> get props => [label];
}
