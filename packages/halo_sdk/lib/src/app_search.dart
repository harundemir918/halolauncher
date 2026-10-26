import 'models.dart';

/// Apps whose label matches [query], best first (see [searchByLabel]).
List<HaloAppInfo> searchApps(Iterable<HaloAppInfo> apps, String query) =>
    searchByLabel(apps, (a) => a.label, query);

/// Items whose label matches [query], best first: the label starts with it,
/// then a word in the label does, then it appears anywhere. Case and Latin
/// accents (Turkish included) are ignored. An empty query matches nothing.
/// Within a rank the input order is kept.
List<T> searchByLabel<T>(
  Iterable<T> items,
  String Function(T) labelOf,
  String query,
) {
  final q = foldForSearch(query.trim());
  if (q.isEmpty) return const [];
  final ranked = <(int, T)>[];
  for (final item in items) {
    final label = foldForSearch(labelOf(item));
    final rank = label.startsWith(q)
        ? 0
        : label.split(RegExp(r'[\s\-_.·&]+')).any((w) => w.startsWith(q))
        ? 1
        : label.contains(q)
        ? 2
        : -1;
    if (rank >= 0) ranked.add((rank, item));
  }
  return [
    for (var r = 0; r <= 2; r++)
      for (final (rank, item) in ranked)
        if (rank == r) item,
  ];
}

/// Lowercases and strips Latin accents, so `şa`, `Şa` and `sa` all match.
/// `İ` and `I` both fold to `i`, which Turkish and English speakers expect.
String foldForSearch(String s) {
  final out = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    out.write(_fold[c] ?? c.toLowerCase());
  }
  return out.toString();
}

const _fold = {
  'İ': 'i', 'I': 'i', 'ı': 'i', //
  'Ç': 'c', 'ç': 'c', 'Ğ': 'g', 'ğ': 'g', 'Ö': 'o', 'ö': 'o',
  'Ş': 's', 'ş': 's', 'Ü': 'u', 'ü': 'u',
  'Á': 'a', 'á': 'a', 'À': 'a', 'à': 'a', 'Â': 'a', 'â': 'a', 'Ä': 'a',
  'ä': 'a', 'Ã': 'a', 'ã': 'a', 'Å': 'a', 'å': 'a',
  'É': 'e', 'é': 'e', 'È': 'e', 'è': 'e', 'Ê': 'e', 'ê': 'e', 'Ë': 'e',
  'ë': 'e', 'Í': 'i', 'í': 'i', 'Ì': 'i', 'ì': 'i', 'Î': 'i', 'î': 'i',
  'Ï': 'i', 'ï': 'i', 'Ó': 'o', 'ó': 'o', 'Ò': 'o', 'ò': 'o', 'Ô': 'o',
  'ô': 'o', 'Õ': 'o', 'õ': 'o', 'Ú': 'u', 'ú': 'u', 'Ù': 'u', 'ù': 'u',
  'Û': 'u', 'û': 'u', 'Ñ': 'n', 'ñ': 'n',
};
