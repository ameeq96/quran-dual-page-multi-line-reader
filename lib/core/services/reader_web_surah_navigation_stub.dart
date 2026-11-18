import 'package:flutter/material.dart';

import '../../features/quran_reader/presentation/controllers/quran_reader_controller.dart';

const RouteSettings? readerWebSurahRouteSettings = null;

ReaderWebSurahNavigation? createReaderWebSurahNavigation(String profileId) =>
    null;

class ReaderWebSurahNavigation extends NavigatorObserver {
  void bind({
    required Object owner,
    required QuranReaderController controller,
    required Future<void> readyFuture,
    required VoidCallback openReader,
  }) {}

  void unbind(Object owner) {}
}
