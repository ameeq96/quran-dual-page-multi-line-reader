abstract final class QuranConstants {
  static const int defaultTotalPages = 604;
  static const int linesPerPage = 16;
  static const int mushafTextLineSlots = 15;
  static const double scannedPageAspectRatio =
      373.2340087890625 / 554.4500122070312;
  static const double textPageAspectRatio = 0.72;
  static const double lines10PageAspectRatio = 0.7450110864745011;
  static const double lines13PageAspectRatio = 0.757185332011893;
  static const double lines14PageAspectRatio = 0.7415730337078652;
  static const double lines15PageAspectRatio = 0.6278101582014988;
  static const double lines16PageAspectRatio = 0.6735798016230838;
  static const double lines17PageAspectRatio = 0.6689791873141725;
  static const double kanzulImanPageAspectRatio = 0.6698564593301436;

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

  static double pageAspectRatio({
    required bool usesImage,
    String? assetPath,
  }) {
    if (!usesImage) {
      return textPageAspectRatio;
    }
    return scannedPageAspectRatioForAssetPath(assetPath);
  }

  static double scannedPageAspectRatioForAssetPath(String? assetPath) {
    if (assetPath == null) {
      return scannedPageAspectRatio;
    }
    if (assetPath.contains('/10_line/') || assetPath.contains('/10_lines/')) {
      return lines10PageAspectRatio;
    }
    if (assetPath.contains('/13_line/') || assetPath.contains('/13_lines/')) {
      return lines13PageAspectRatio;
    }
    if (assetPath.contains('/14_line/') || assetPath.contains('/14_lines/')) {
      return lines14PageAspectRatio;
    }
    if (assetPath.contains('/15_line/') || assetPath.contains('/15_lines/')) {
      return lines15PageAspectRatio;
    }
    if (assetPath.contains('/16_line/') || assetPath.contains('/16_lines/')) {
      return lines16PageAspectRatio;
    }
    if (assetPath.contains('/17_line/') || assetPath.contains('/17_lines/')) {
      return lines17PageAspectRatio;
    }
    if (assetPath.contains('/kanzul_iman/')) {
      return kanzulImanPageAspectRatio;
    }
    return scannedPageAspectRatio;
  }
}
