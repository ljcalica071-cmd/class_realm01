/// Unified, relevance-ranked search used by EVERY search box in ClassRealm
/// (Teacher, Student, Parent, Admin).
///
/// Why this exists: plain `field.contains(query)` matches the query anywhere in
/// any field (emails, RFID, LRN...), so typing a single letter such as "c"
/// matched nearly every row. Real search should behave like this:
///
/// 1. Case, accents and punctuation are ignored ("Peña" == "pena",
///    "Cruz, Carlos" == "cruz carlos").
/// 2. The query is split into tokens; EVERY token must match (AND logic), in
///    any order ("carlos cruz" finds "Cruz, Carlos D.").
/// 3. [names]  : a token must match the START of a word (prefix) - "ca" finds
///    "Carlos" but not "Escarlata".
/// 4. [ids]    : LRN / RFID / student numbers - prefix match, or substring
///    match once the token has 3+ characters (typing the last digits).
/// 5. [loose]  : emails, usernames, sections, descriptions - word-prefix match
///    but ignored for 1-character tokens so one letter never matches every
///    email address.
/// 6. Results are ranked: exact/starts-with name first, then word prefixes,
///    then ids, then loose fields; ties fall back to alphabetical order.
class SearchUtils {
  SearchUtils._();

  static const Map<String, String> _accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ñ': 'n', 'ç': 'c', 'ý': 'y', 'ÿ': 'y',
  };

  static final RegExp _nonAlnum = RegExp(r'[^a-z0-9]+');

  /// Lower-cases, strips accents and turns every punctuation run into a
  /// single space.
  static String normalize(String? input) {
    if (input == null || input.isEmpty) return '';
    final lower = input.toLowerCase();
    final buf = StringBuffer();
    for (final ch in lower.split('')) {
      buf.write(_accents[ch] ?? ch);
    }
    return buf.toString().replaceAll(_nonAlnum, ' ').trim();
  }

  /// Splits a query into normalized tokens.
  static List<String> tokenize(String? query) {
    final n = normalize(query);
    if (n.isEmpty) return const [];
    return n.split(' ').where((t) => t.isNotEmpty).toList();
  }

  /// True when [query] has no usable characters (show everything).
  static bool isEmpty(String? query) => tokenize(query).isEmpty;

  /// Returns a relevance rank (lower = better) when EVERY token of [query]
  /// matches at least one of the provided fields, otherwise `null`.
  static int? rank(
    String? query, {
    List<String?> names = const [],
    List<String?> ids = const [],
    List<String?> loose = const [],
  }) {
    final tokens = tokenize(query);
    if (tokens.isEmpty) return 0;

    final nameNorm = names.map(normalize).where((s) => s.isNotEmpty).toList();
    final nameWords = [for (final n in nameNorm) ...n.split(' ')];
    final idNorm = ids
        .map((s) => (s ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), ''))
        .where((s) => s.isNotEmpty)
        .toList();
    final looseWords = [
      for (final l in loose)
        ...normalize(l).split(' ').where((w) => w.isNotEmpty),
    ];

    var total = 0;
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      int? best;

      // Names: start of the full name beats start of any other word.
      if (nameNorm.any((n) => n.startsWith(t))) {
        best = i == 0 ? 0 : 1;
      } else if (nameWords.any((w) => w.startsWith(t))) {
        best = 1;
      }

      // IDs: prefix, or substring for 3+ characters.
      if (best == null) {
        if (idNorm.any((v) => v.startsWith(t))) {
          best = 1;
        } else if (t.length >= 3 && idNorm.any((v) => v.contains(t))) {
          best = 2;
        }
      }

      // Loose fields: word prefix, never for a single character.
      if (best == null && t.length >= 2) {
        if (looseWords.any((w) => w.startsWith(t))) best = 3;
      }

      if (best == null) return null;
      total += best;
    }
    return total;
  }

  /// Convenience boolean form of [rank].
  static bool matches(
    String? query, {
    List<String?> names = const [],
    List<String?> ids = const [],
    List<String?> loose = const [],
  }) {
    return rank(query, names: names, ids: ids, loose: loose) != null;
  }

  /// Filters [items] by [query] and returns them best-match-first
  /// (alphabetical by the first name field when ranks tie). When the query is
  /// empty the original list is returned unchanged (same order).
  static List<T> filter<T>(
    String? query,
    Iterable<T> items, {
    required List<String?> Function(T item) names,
    List<String?> Function(T item)? ids,
    List<String?> Function(T item)? loose,
  }) {
    if (isEmpty(query)) return items.toList();
    final ranked = <MapEntry<int, T>>[];
    for (final item in items) {
      final r = rank(
        query,
        names: names(item),
        ids: ids?.call(item) ?? const [],
        loose: loose?.call(item) ?? const [],
      );
      if (r != null) ranked.add(MapEntry(r, item));
    }
    ranked.sort((a, b) {
      if (a.key != b.key) return a.key.compareTo(b.key);
      final an = normalize(names(a.value).isEmpty ? '' : names(a.value).first);
      final bn = normalize(names(b.value).isEmpty ? '' : names(b.value).first);
      return an.compareTo(bn);
    });
    return ranked.map((e) => e.value).toList();
  }

  /// Legacy helper kept for existing callers: sorts an ALREADY filtered list
  /// by relevance. Prefer [filter].
  static void sortByRelevance<T>(
    String query,
    List<T> list,
    String Function(T) nameExtractor, {
    String Function(T)? secondaryExtractor,
  }) {
    if (isEmpty(query)) return;
    int rankOf(T item) =>
        rank(
          query,
          names: [nameExtractor(item)],
          loose: [if (secondaryExtractor != null) secondaryExtractor(item)],
        ) ??
        99;
    list.sort((a, b) {
      final ra = rankOf(a);
      final rb = rankOf(b);
      if (ra != rb) return ra.compareTo(rb);
      return normalize(nameExtractor(a)).compareTo(normalize(nameExtractor(b)));
    });
  }
}
