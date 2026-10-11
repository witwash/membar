import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

/// Finds [text] rendered inside a toast.
Finder inToast(String text) =>
    find.descendant(of: find.byType(FToast), matching: find.text(text));
