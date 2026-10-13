import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// Answers a tap the app will not act on. A refusal is a toast because it has
/// no form to keep in view; a failed save or delete is a `FailureBanner`.
///
/// Shown at the bottom: the touch theme's default is top centre, over the
/// header actions a refusal may be telling the user to press.
FToasterEntry showRefusalToast(
  BuildContext context, {
  required String title,
  required String description,
}) => showFToast(
  context: context,
  alignment: .bottomCenter,
  title: Text(title),
  description: Text(description),
);
