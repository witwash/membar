/// Orders two labels the way every list of them is ordered: ignoring case, so
/// `aperol` sorts beside `Aperol` rather than after `Zest`.
int compareCaseInsensitive(String a, String b) =>
    a.toLowerCase().compareTo(b.toLowerCase());

/// Folds [values] to one entry per case-insensitive spelling.
///
/// Each value is trimmed and blanks are dropped, and the first spelling seen
/// is the one kept — so typing `BITTER` beside an existing `Bitter` adds
/// nothing rather than a second chip that means the same thing.
///
/// The result keeps the order the values arrived in. Sort it with
/// [compareCaseInsensitive] to display it.
List<String> foldCaseInsensitive(Iterable<String> values) {
  final seen = <String>{};
  final folded = <String>[];
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) continue;
    if (seen.add(trimmed.toLowerCase())) folded.add(trimmed);
  }
  return folded;
}
