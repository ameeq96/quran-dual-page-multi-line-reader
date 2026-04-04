abstract final class QuranConstants {
  static const int defaultTotalPages = 604;
  static const int linesPerPage = 16;
  static const int mushafTextLineSlots = 15;
  static const double scannedPageAspectRatio =
      373.2340087890625 / 554.4500122070312;

  static int totalSpreadsFor(int totalPages) {
    return (totalPages + 1) ~/ 2;
  }

  static int clampPage(
    int pageNumber, {
    int totalPages = defaultTotalPages,
  }) {
    return pageNumber.clamp(1, totalPages);
  }

  static int clampSpread(
    int spreadIndex, {
    int totalPages = defaultTotalPages,
  }) {
    final totalSpreads = totalSpreadsFor(totalPages);
    return spreadIndex.clamp(0, totalSpreads - 1);
  }

  static int spreadIndexFromPage(
    int pageNumber, {
    int totalPages = defaultTotalPages,
  }) {
    return (clampPage(pageNumber, totalPages: totalPages) - 1) ~/ 2;
  }

  static int rightPageForSpread(
    int spreadIndex, {
    int totalPages = defaultTotalPages,
  }) {
    return (clampSpread(spreadIndex, totalPages: totalPages) * 2) + 1;
  }

  static int leftPageForSpread(
    int spreadIndex, {
    int totalPages = defaultTotalPages,
  }) {
    final leftPage =
        rightPageForSpread(spreadIndex, totalPages: totalPages) + 1;
    return leftPage > totalPages ? totalPages : leftPage;
  }

  static String paddedAssetName(int pageNumber) {
    return pageNumber.toString().padLeft(3, '0');
  }
}
