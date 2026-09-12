import 'package:flutter/widgets.dart';

/// The spacing scale every screen measures its gaps and insets against.
///
/// Steps are named for their percentage of [base], so the name carries the
/// number: `spacing150` is 1.5 × 8 = 12. A value that has no step is a value
/// off the grid, and inserting one later (`spacing250` between 16 and 24)
/// renames nothing.
///
/// This deliberately replaces VGV's t-shirt scale (`xs`, `sm`, `lg`). The
/// deviation is scoped to spacing and sizing tokens; every other VGV
/// convention still applies here.
abstract final class AppSpacing {
  /// The unit every step is a percentage of.
  static const base = 8.0;

  /// 2dp.
  static const double spacing25 = 0.25 * base;

  /// 4dp.
  static const double spacing50 = 0.5 * base;

  /// 6dp.
  static const double spacing75 = 0.75 * base;

  /// 8dp. The default gap between related controls in a row or column.
  static const double spacing100 = base;

  /// 12dp.
  static const double spacing150 = 1.5 * base;

  /// 16dp. The gap between groups that read as separate blocks.
  static const double spacing200 = 2 * base;

  /// 24dp. Surface padding, such as the inside of a dialog.
  static const double spacing300 = 3 * base;

  /// 32dp.
  static const double spacing400 = 4 * base;
}

/// Insets named for the surface they pad, built from [AppSpacing].
///
/// A surface gets its padding from here rather than from a literal at the call
/// site, so two dialogs cannot end up padded differently.
abstract final class AppInsets {
  /// The padding between a dialog's border and its content.
  static const dialogContent = EdgeInsets.all(AppSpacing.spacing300);
}
