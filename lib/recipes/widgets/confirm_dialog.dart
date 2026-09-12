import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:membar/ui/ui.dart';

/// Asks the user to confirm something destructive, resolving to true when they
/// confirm and false when they cancel or dismiss the dialog.
///
/// Both places that ask — leaving a dirty editor and deleting a recipe — get
/// the same layout and the same button order from here, so the two cannot
/// drift into looking like different kinds of question.
Future<bool> showRecipeConfirmDialog({
  required BuildContext context,
  required String title,
  required String description,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final confirmed = await showFDialog<bool>(
    context: context,
    builder: (dialogContext, _, animation) => FDialog(
      animation: animation,
      builder: (context, style) => Padding(
        padding: AppInsets.dialogContent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.spacing200,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.spacing100,
              children: [
                Text(title, style: style.titleTextStyle),
                Text(description, style: style.bodyTextStyle),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.spacing100,
              children: [
                FButton(
                  variant: FButtonVariant.destructive,
                  onPress: () => Navigator.of(dialogContext).pop(true),
                  child: Text(confirmLabel),
                ),
                FButton(
                  variant: FButtonVariant.outline,
                  onPress: () => Navigator.of(dialogContext).pop(false),
                  child: Text(cancelLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}
