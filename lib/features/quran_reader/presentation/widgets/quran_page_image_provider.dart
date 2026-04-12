import 'package:flutter/material.dart';

import '../../domain/models/quran_page.dart';

final Map<String, ImageProvider<Object>> _quranPageImageProviderCache =
    <String, ImageProvider<Object>>{};

ImageProvider<Object> buildQuranPageImageProvider(
  QuranPage page, {
  int? cacheWidth,
  int? cacheHeight,
}) {
  final imageSource = page.assetPath;
  if (imageSource == null || imageSource.trim().isEmpty) {
    throw StateError('Quran page does not have an image source.');
  }

  final ImageProvider<Object> baseProvider = page.usesRemoteImage
      ? NetworkImage(imageSource)
      : AssetImage(imageSource);

  final provider = ResizeImage.resizeIfNeeded(
    cacheWidth,
    cacheHeight,
    baseProvider,
  );
  final cacheKey = '${page.assetPath}|${cacheWidth ?? 0}|${cacheHeight ?? 0}';
  return _quranPageImageProviderCache.putIfAbsent(cacheKey, () => provider);
}
