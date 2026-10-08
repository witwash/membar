import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:membar/ui/app_spacing.dart';

/// An inline message reporting that a save or a delete did not go through.
///
/// It is rendered in place rather than as a toast so the user stays on the
/// screen that failed, with the form they were working on untouched.
class FailureBanner extends StatelessWidget {
  /// Creates a [FailureBanner] reporting [message].
  const FailureBanner(this.message, {super.key});

  /// What went wrong, in the user's language.
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.spacing150),
      child: Text(
        message,
        style: theme.typography.body.sm.copyWith(color: theme.colors.error),
      ),
    );
  }
}
