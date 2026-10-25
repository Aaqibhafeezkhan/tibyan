import 'dart:ui' show Size;

/// Whether a pager of [size] shows two facing pages: a box wider than it
/// is tall and wide enough for two readable pages, on a tablet or a
/// desktop. A phone held sideways is wide but short: two pages there would
/// be too small to read, so it keeps one.
bool showsSpread(Size size, {required bool largeDevice}) =>
    largeDevice && size.width > size.height && size.width >= 800;

/// A phone held sideways shows one page as wide as the screen, read by
/// scrolling down: the page's height for a pager of [size], or null where
/// the page fits the pager as it is (upright, a tablet, a desktop).
/// [aspect] is the page's height over its width, near a printed page's.
double? fitWidthHeight(
  Size size, {
  required bool largeDevice,
  double aspect = 1.45,
}) {
  if (largeDevice || size.width <= size.height) return null;
  return size.width * aspect;
}

/// How the pager's pages map to the mushaf's: one page per index, or, on
/// a wide screen held sideways, two facing pages per index (a spread).
///
/// Pages before [base] stand alone (the covers); from [base] on, pages go
/// in pairs: [base] and [base] + 1 face each other (the right page first).
class PageSpreads {
  const PageSpreads({
    required this.first,
    required this.base,
    required this.pageCount,
    required this.spread,
  });

  /// The first page the pager shows (0 for a cover page 0).
  final int first;

  /// The first page that opens a spread.
  final int base;
  final int pageCount;
  final bool spread;

  int indexOf(int page) {
    if (!spread || page < base) return page - first;
    return (base - first) + (page - base) ~/ 2;
  }

  /// The pages at [index], right to left.
  List<int> pagesAt(int index) {
    final singles = base - first;
    if (!spread || index < singles) return [index + first];
    final p = base + (index - singles) * 2;
    return [p, if (p + 1 <= pageCount) p + 1];
  }

  /// How many indexes the pager has.
  int get count => indexOf(pageCount) + 1;

  /// Whether [page] stands on the right of an open mushaf: in a spread
  /// the first page of each pair; a cover or a lone page counts from
  /// [base] the same way, so a fasil keeps its side when spreads come and go.
  bool isRightPage(int page) => (page - base).isEven;
}
