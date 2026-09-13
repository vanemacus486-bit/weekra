/// Suggests only from an explicit pattern already present in local events.
/// This deliberately avoids assigning meanings to the legacy color palette.
String? suggestCategoryForTitle(
  String title,
  Iterable<({String title, String categoryId})> history, {
  String uncategorizedId = 'uncategorized',
}) {
  final normalized = _normalizedTitle(title);
  if (normalized.isEmpty) {
    return null;
  }

  String? suggestion;
  for (final item in history) {
    if (_normalizedTitle(item.title) != normalized ||
        item.categoryId == uncategorizedId) {
      continue;
    }
    if (suggestion != null && suggestion != item.categoryId) {
      return null;
    }
    suggestion = item.categoryId;
  }
  return suggestion;
}

String _normalizedTitle(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
