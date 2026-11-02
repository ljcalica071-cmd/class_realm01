class SearchUtils {
  /// Sorts a list of objects based on a search query using relevance tiers.
  /// Tier 1: String starts exactly with the query.
  /// Tier 2: Any word inside the string starts with the query.
  /// Tier 3: The query is found anywhere inside the string.
  /// Fallback: Alphabetical order.
  static void sortByRelevance<T>(
    String query,
    List<T> list,
    String Function(T) nameExtractor, {
    String Function(T)? secondaryExtractor,
  }) {
    if (query.trim().isEmpty) return;

    final q = query.trim().toLowerCase();

    int getTier(T item) {
      final name = nameExtractor(item).toLowerCase();
      final secondary = secondaryExtractor != null ? secondaryExtractor(item).toLowerCase() : '';

      // Tier 1: Starts exactly with query
      if (name.startsWith(q) || secondary.startsWith(q)) return 1;

      // Tier 2: Any word starts with query
      final words = name.split(RegExp(r'\s+'));
      if (words.any((w) => w.startsWith(q))) return 2;

      if (secondary.isNotEmpty) {
        final secWords = secondary.split(RegExp(r'\s+'));
        if (secWords.any((w) => w.startsWith(q))) return 2;
      }

      // Tier 3: Contains query anywhere
      if (name.contains(q) || secondary.contains(q)) return 3;

      // Tier 4: No match (should ideally be filtered out before sorting)
      return 4;
    }

    list.sort((a, b) {
      final tierA = getTier(a);
      final tierB = getTier(b);

      if (tierA != tierB) {
        return tierA.compareTo(tierB);
      }

      // Fallback: Alphabetical
      return nameExtractor(a).toLowerCase().compareTo(nameExtractor(b).toLowerCase());
    });
  }
}