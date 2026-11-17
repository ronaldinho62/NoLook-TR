/// matching, mirrored in extension/src/match.ts
library;

/// site rule
///
/// domain covers subdomains. path covers everything under it but not /r/GTA6memes.
/// rules with ? are prefix matches.
class SiteRule {
  const SiteRule._(this.text, this.host, this.path);

  final String text;
  final String host;

  /// lowercase, "" = whole site
  final String path;

  /// normalise input, null if not a site
  static String? normalize(String input) {
    var s = input.trim();
    s = s.replaceFirst(RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://'), '');
    s = s.replaceFirst(RegExp(r'^www\.', caseSensitive: false), '');
    s = s.replaceFirst(RegExp(r'#.*$'), '');
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.isEmpty || s.contains(' ')) return null;
    final slash = s.indexOf(RegExp(r'[/?]'));
    final host = (slash == -1 ? s : s.substring(0, slash)).toLowerCase();
    if (!RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+(:\d+)?$').hasMatch(host)) return null;
    return host + (slash == -1 ? '' : s.substring(slash));
  }

  static SiteRule? parse(String input) {
    final text = normalize(input);
    if (text == null) return null;
    final slash = text.indexOf(RegExp(r'[/?]'));
    final host = slash == -1 ? text : text.substring(0, slash);
    var path = slash == -1 ? '' : text.substring(slash).toLowerCase();
    if (path.startsWith('?')) path = '/$path';
    return SiteRule._(text, host, path);
  }

  bool matchesUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;
    return matchesUri(uri);
  }

  bool matchesUri(Uri uri) {
    final h = uri.host.toLowerCase();
    final hostOnly = host.split(':').first;
    if (h != hostOnly && !h.endsWith('.$hostOnly')) return false;
    if (path.isEmpty) return true;
    var full = (uri.path.isEmpty ? '/' : uri.path).toLowerCase();
    if (uri.hasQuery) full += '?${uri.query.toLowerCase()}';
    if (!full.startsWith(path)) return false;
    if (path.contains('?') || full.length == path.length) return true;
    return '/?#'.contains(full[path.length]);
  }
}

/// keyword matching.
///
/// case insensitive, word start, plural/possessive ok. spaces also match - _ or nothing.
/// Türkçe: "final*" gibi sonu * ile biten kelime ekli halleri de yakalar (finali, finalde),
/// büyük/küçük İ-i ve I-ı birbirini tutar.
class KeywordMatcher {
  KeywordMatcher(Iterable<String> keywords)
      : _entries = [
          for (final k in keywords.map((k) => k.trim()).where((k) => k.isNotEmpty).toSet())
            (k, RegExp(patternFor(k), caseSensitive: false, unicode: true)),
        ];

  final List<(String, RegExp)> _entries;

  bool get isEmpty => _entries.isEmpty;

  /// keep it js compatible
  static String patternFor(String keyword) {
    var k = keyword.trim().replaceAll('’', "'");
    final bare = k.replaceFirst(RegExp(r'\*+$'), '');
    final stem = bare != k && bare.trim().isNotEmpty;
    if (stem) k = bare;
    final parts = k.split(RegExp(r'[\s\-_]+')).where((p) => p.isNotEmpty).map((p) {
      return RegExp.escape(p).replaceAllMapped(RegExp('[iIıİ]'), (m) => _dotted[m[0]]!).replaceAll("'", "['’]");
    });
    return r'(?<![\p{L}\p{N}])' + parts.join(r'[\s\-_.]*') + (stem ? '' : r"(?:['’]s|s|es)?(?![\p{L}\p{N}])");
  }

  static const _dotted = {'i': '[iİ]', 'I': '[Iı]', 'ı': '[ıI]', 'İ': '[İi]'};

  List<String> find(String text) => [
        for (final (k, re) in _entries)
          if (re.hasMatch(text)) k,
      ];

  bool any(String text) => _entries.any((e) => e.$2.hasMatch(text));
}

/// keywords always, spoiler words only with a topic word/keyword
class BlockMatcher {
  BlockMatcher({Iterable<String> keywords = const [], Iterable<String> spoilerWords = const [], Iterable<String> topicWords = const []})
      : keywords = KeywordMatcher(keywords),
        spoilers = KeywordMatcher(spoilerWords),
        topics = KeywordMatcher(topicWords);

  final KeywordMatcher keywords;
  final KeywordMatcher spoilers;
  final KeywordMatcher topics;

  bool get isEmpty => keywords.isEmpty && spoilers.isEmpty;

  List<String> find(String text) {
    final k = keywords.find(text);
    final s = spoilers.find(text);
    if (s.isEmpty) return k;
    if (k.isEmpty && !topics.any(text)) return k;
    return [...k, ...s];
  }
}
