import 'dart:collection';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/models/quran_page.dart';

const int _maxQuranPageImageProviderCacheEntries = 96;

final LinkedHashMap<String, ImageProvider<Object>>
    _quranPageImageProviderCache =
    LinkedHashMap<String, ImageProvider<Object>>();

ImageProvider<Object> buildQuranPageImageProvider(
  QuranPage page, {
  int? cacheWidth,
  int? cacheHeight,
}) {
  final imageSource = page.assetPath;
  if (imageSource == null || imageSource.trim().isEmpty) {
    throw StateError('Quran page does not have an image source.');
  }

  final cacheKey = '$imageSource|${cacheWidth ?? 0}|${cacheHeight ?? 0}';
  final cached = _quranPageImageProviderCache.remove(cacheKey);
  if (cached != null) {
    _quranPageImageProviderCache[cacheKey] = cached;
    return cached;
  }

  final ImageProvider<Object> baseProvider = page.usesRemoteImage
      ? CachedNetworkImageProvider(imageSource)
      : imageSource.startsWith('assets/')
          ? AssetImage(imageSource)
          : FileImage(File(imageSource));

  final provider = ResizeImage.resizeIfNeeded(
    cacheWidth,
    cacheHeight,
    baseProvider,
  );

  _quranPageImageProviderCache[cacheKey] = provider;
  while (_quranPageImageProviderCache.length >
      _maxQuranPageImageProviderCacheEntries) {
    _quranPageImageProviderCache.remove(
      _quranPageImageProviderCache.keys.first,
    );
  }
  return provider;
}

void clearQuranPageImageProviderCache() {
  _quranPageImageProviderCache.clear();
}
