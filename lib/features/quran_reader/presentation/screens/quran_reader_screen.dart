import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../../app/reader_localization.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/services/system_ui_service.dart';
import '../../data/services/reader_page_report_service.dart';
import '../../domain/models/reader_settings.dart';
import '../../domain/models/quran_page.dart';
import '../controllers/quran_reader_controller.dart';
import '../widgets/bootstrap_splash.dart';
import '../widgets/dual_page_spread.dart';
import '../widgets/jump_to_page_dialog.dart';
import '../widgets/kanzul_iman_study_sheet.dart';
import '../widgets/reader_audio_sheet.dart';
import '../widgets/reader_app_bar.dart';
import '../widgets/reader_bottom_dock.dart';
import '../widgets/reader_compare_sheet.dart';
import '../widgets/reader_dashboard_sheet.dart';
import '../widgets/reader_insights_sheet.dart';
import '../widgets/reader_motion.dart';
import '../widgets/reader_page_strip_sheet.dart';
import '../widgets/reader_zoom_viewport.dart';
import '../widgets/quran_page_image_provider.dart';
import '../widgets/single_page_reader.dart';
import '../widgets/mushaf_page_widget.dart';
import '../widgets/placeholder_quran_page.dart';
import '../widgets/reader_page_pin_overlay.dart';
import 'quran_ai_studio_screen.dart';
import 'quran_asset_packs_screen.dart';
import 'quran_bookmarks_screen.dart';
import 'quran_growth_hub_screen.dart';
import 'quran_search_screen.dart';
import 'quran_settings_screen.dart';

enum QuranReaderInitialAction {
  none,
  openSurahIndex,
  openJuzIndex,
  openPageJump,
  openBookmarks,
  openSettings,
  openDashboard,
  openInsights,
  openAudio,
  openAiStudio,
  openPageStrip,
  openCompare,
  openKanzulStudy,
}

class QuranReaderScreen extends StatefulWidget {
  const QuranReaderScreen({
    super.key,
    required this.controller,
    this.initialAction = QuranReaderInitialAction.none,
  });

  final QuranReaderController controller;
  final QuranReaderInitialAction initialAction;

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  late final PageController _spreadController;
  late final PageController _pageController;
  late int _lastKnownSpreadIndex;
  late int _lastKnownPageViewIndex;
  Timer? _prefetchTimer;
  Timer? _deferredPrefetchTimer;
  int? _lastPrefetchedPageNumber;
  bool? _lastPrefetchedLowMemoryMode;
  bool? _lastPrefetchedPreferImageMode;
  String? _lastWebPrefetchKey;
  final GlobalKey _readerViewportKey = GlobalKey();
  bool _initialActionHandled = false;
  final ValueNotifier<bool> _portraitZoomNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _landscapeZoomNotifier = ValueNotifier<bool>(false);
  Timer? _landscapeControlsTimer;
  bool _landscapeControlsRevealed = false;
  bool? _lastPortraitOrientation;
  bool _changingFullscreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _lastKnownSpreadIndex = widget.controller.currentSpreadIndex;
    _lastKnownPageViewIndex = widget.controller.currentPageViewIndex;
    _spreadController = PageController(
      initialPage: widget.controller.currentSpreadIndex,
      keepPage: false,
    );
    _pageController = PageController(
      initialPage: widget.controller.currentPageViewIndex,
      keepPage: false,
    );
    widget.controller.pageListenable.addListener(_syncViewControllers);
    widget.controller.settingsListenable.addListener(_syncViewControllers);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (!kIsWeb) {
          unawaited(SystemUiService.setFullscreen(
            widget.controller.settings.fullscreenReading,
          ));
        }
        _schedulePrefetchNearbyPages(force: true);
        _runInitialActionIfNeeded();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    if (_lastPortraitOrientation != portrait) {
      _lastPortraitOrientation = portrait;
      _landscapeControlsTimer?.cancel();
      _landscapeControlsRevealed = false;
    }
    if (kIsWeb) {
      _schedulePrefetchNearbyPages();
    }
  }

  late final _ReaderLifecycleObserver _lifecycleObserver =
      _ReaderLifecycleObserver(
    onSavePosition: () {
      widget.controller.persistReadingPosition();
    },
  );

  @override
  void didUpdateWidget(covariant QuranReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    _lastKnownSpreadIndex = widget.controller.currentSpreadIndex;
    _lastKnownPageViewIndex = widget.controller.currentPageViewIndex;
    oldWidget.controller.pageListenable.removeListener(_syncViewControllers);
    oldWidget.controller.settingsListenable
        .removeListener(_syncViewControllers);
    widget.controller.pageListenable.addListener(_syncViewControllers);
    widget.controller.settingsListenable.addListener(_syncViewControllers);
  }

  void _syncViewControllers() {
    if (widget.controller.isLoading) {
      return;
    }

    final targetSpread = widget.controller.currentSpreadIndex;
    if (_spreadController.hasClients &&
        _spreadController.positions.length == 1) {
      final currentSpread = _lastKnownSpreadIndex;
      if (currentSpread != targetSpread) {
        _lastKnownSpreadIndex = targetSpread;
        if ((currentSpread - targetSpread).abs() > 1) {
          _spreadController.jumpToPage(targetSpread);
        } else {
          _spreadController.animateToPage(
            targetSpread,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          );
        }
      }
    }

    final targetPageIndex = widget.controller.currentPageViewIndex;
    if (_pageController.hasClients && _pageController.positions.length == 1) {
      final currentPageIndex = _lastKnownPageViewIndex;
      if (currentPageIndex != targetPageIndex) {
        _lastKnownPageViewIndex = targetPageIndex;
        if ((currentPageIndex - targetPageIndex).abs() > 1) {
          _pageController.jumpToPage(targetPageIndex);
        } else {
          _pageController.animateToPage(
            targetPageIndex,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          );
        }
      }
    }

    if (mounted) {
      _schedulePrefetchNearbyPages();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    widget.controller.persistReadingPosition();
    widget.controller.pageListenable.removeListener(_syncViewControllers);
    widget.controller.settingsListenable.removeListener(_syncViewControllers);
    _prefetchTimer?.cancel();
    _deferredPrefetchTimer?.cancel();
    _landscapeControlsTimer?.cancel();
    unawaited(SystemUiService.setFullscreen(false).catchError((Object _) {}));
    _portraitZoomNotifier.dispose();
    _landscapeZoomNotifier.dispose();
    _spreadController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _setPortraitZoomActive(bool active) {
    if (_portraitZoomNotifier.value == active) {
      return;
    }
    _portraitZoomNotifier.value = active;
  }

  void _setLandscapeZoomActive(bool active) {
    if (_landscapeZoomNotifier.value == active) {
      return;
    }
    _landscapeZoomNotifier.value = active;
  }

  void _toggleReaderControls(bool portraitMode, {bool forceReveal = false}) {
    if (portraitMode) {
      widget.controller.toggleControlsVisibility();
      return;
    }
    final reveal = forceReveal || !_landscapeControlsRevealed ||
        !widget.controller.controlsVisible;
    setState(() => _landscapeControlsRevealed = reveal);
    if (reveal && !widget.controller.controlsVisible) {
      widget.controller.toggleControlsVisibility();
    }
    _landscapeControlsTimer?.cancel();
    if (reveal) {
      _landscapeControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _landscapeControlsRevealed = false);
        }
      });
    }
  }

  Future<void> _toggleReaderFullscreen() async {
    if (_changingFullscreen) return;
    _changingFullscreen = true;
    final enabled = !widget.controller.settings.fullscreenReading;
    try {
      await SystemUiService.setFullscreen(enabled);
      if (!mounted) {
        await SystemUiService.setFullscreen(false);
        return;
      }
      await widget.controller.toggleFullscreen(enabled);
      if (!mounted) {
        await SystemUiService.setFullscreen(false);
        return;
      }
      if (enabled && widget.controller.controlsVisible) {
        widget.controller.toggleControlsVisibility();
      } else if (!enabled && _lastPortraitOrientation == false) {
        _toggleReaderControls(false, forceReveal: true);
      }
    } finally {
      _changingFullscreen = false;
    }
  }

  Future<void> _openDownloads() {
    return Navigator.of(context).push(
      buildReaderPageRoute<void>(
        builder: (context) => QuranAssetPacksScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _readBundledEdition() async {
    try {
      await widget.controller.selectMushafEdition(MushafEdition.lines16);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'Unable to load this page'))),
        );
      }
    }
  }

  Future<void> _runInitialActionIfNeeded() async {
    if (_initialActionHandled ||
        widget.initialAction == QuranReaderInitialAction.none) {
      return;
    }
    _initialActionHandled = true;

    switch (widget.initialAction) {
      case QuranReaderInitialAction.none:
        return;
      case QuranReaderInitialAction.openSurahIndex:
        await _openSearchSheet(initialTab: 0);
        return;
      case QuranReaderInitialAction.openJuzIndex:
        await _openSearchSheet(initialTab: 1);
        return;
      case QuranReaderInitialAction.openPageJump:
        await _openPageJumpDialog();
        return;
      case QuranReaderInitialAction.openBookmarks:
        await _openBookmarksSheet();
        return;
      case QuranReaderInitialAction.openSettings:
        await _openSettingsSheet();
        return;
      case QuranReaderInitialAction.openDashboard:
        await _openDashboardSheet();
        return;
      case QuranReaderInitialAction.openInsights:
        await _openInsightsSheet();
        return;
      case QuranReaderInitialAction.openAudio:
        await _openAudioSheet();
        return;
      case QuranReaderInitialAction.openAiStudio:
        await _openAiStudio();
        return;
      case QuranReaderInitialAction.openPageStrip:
        await _openPageStripSheet();
        return;
      case QuranReaderInitialAction.openCompare:
        await _openCompareSheet();
        return;
      case QuranReaderInitialAction.openKanzulStudy:
        await _openKanzulStudySheet();
        return;
    }
  }

  Future<void> _openSettingsSheet() {
    return Navigator.of(context).push(
      buildReaderPageRoute<void>(
        builder: (context) => QuranSettingsScreen(
          controller: widget.controller,
        ),
      ),
    );
  }

  Future<void> _openSearchSheet({int initialTab = 0}) async {
    final normalizedInitialTab =
        initialTab < 0 ? 0 : (initialTab > 1 ? 1 : initialTab);
    final titles = <int, String>{
      0: 'Surah Index',
      1: 'Juz Index',
    };
    final page = await Navigator.of(context).push<int>(
      buildReaderPageRoute<int>(
        builder: (context) => QuranSearchScreen(
          title: titles[normalizedInitialTab] ?? 'Search',
          initialTab: normalizedInitialTab,
          nightMode: widget.controller.settings.nightMode,
          surahs: widget.controller.surahEntries,
          juzs: widget.controller.juzEntries,
          surahPageResolver: widget.controller.navigationPageForSurahEntry,
          juzPageResolver: widget.controller.navigationPageForJuzEntry,
          surahSearch: widget.controller.searchSurahs,
          juzSearch: widget.controller.searchJuzs,
        ),
      ),
    );
    if (!mounted || page == null) {
      return;
    }
    await widget.controller.jumpToPage(page);
  }

  Future<void> _openPageJumpDialog() async {
    final page = await showJumpToPageDialog(
      context,
      currentPage: widget.controller.currentPageNumber,
      maxPage: widget.controller.totalPages,
    );
    if (!mounted || page == null) {
      return;
    }
    await widget.controller.jumpToPage(page);
  }

  Future<void> _openInsightsSheet() {
    return Navigator.of(context)
        .push<int>(
      buildReaderPageRoute<int>(
        builder: (context) => QuranInsightsScreen(
          controller: widget.controller,
        ),
      ),
    )
        .then((page) async {
      if (!mounted || page == null) {
        return;
      }
      await widget.controller.jumpToPage(page);
    });
  }

  Future<void> _openBookmarksSheet() {
    return Navigator.of(context)
        .push<int>(
      buildReaderPageRoute<int>(
        builder: (context) => QuranBookmarksScreen(
          controller: widget.controller,
        ),
      ),
    )
        .then((page) async {
      if (!mounted || page == null) {
        return;
      }
      await widget.controller.jumpToPage(page);
    });
  }

  Future<void> _openDashboardSheet() {
    return Navigator.of(context)
        .push<int>(
      buildReaderPageRoute<int>(
        builder: (screenContext) => QuranDashboardScreen(
          controller: widget.controller,
          onOpenGrowthHub: () => _openGrowthHub(),
          onOpenSearch: () => _openSearchSheet(),
          onOpenInsights: () => _openInsightsSheet(),
          onOpenAudio: () => _openAudioSheet(),
          onOpenAiStudio: () => _openAiStudio(),
          onOpenPageStrip: () => _openPageStripSheet(),
          onOpenCompare: () => _openCompareSheet(),
          onOpenKanzulStudy: () => _openKanzulStudySheet(),
          onSelectPage: (pageNumber) async {
            Navigator.of(screenContext).pop(pageNumber);
          },
        ),
      ),
    )
        .then((page) async {
      if (!mounted || page == null) {
        return;
      }
      await widget.controller.jumpToPage(page);
    });
  }

  Future<void> _openGrowthHub() {
    return Navigator.of(context)
        .push<int>(
      buildReaderPageRoute<int>(
        builder: (context) => QuranGrowthHubScreen(
          controller: widget.controller,
        ),
      ),
    )
        .then((page) async {
      if (!mounted || page == null) {
        return;
      }
      await widget.controller.jumpToPage(page);
    });
  }

  Future<void> _openAudioSheet() {
    return Navigator.of(context).push(
      buildReaderPageRoute<void>(
        builder: (context) => QuranAudioScreen(
          controller: widget.controller,
        ),
      ),
    );
  }

  Future<void> _openAiStudio() {
    return Navigator.of(context)
        .push<int>(
      buildReaderPageRoute<int>(
        builder: (context) => QuranAiStudioScreen(
          controller: widget.controller,
        ),
      ),
    )
        .then((page) async {
      if (!mounted || page == null) {
        return;
      }
      await widget.controller.jumpToPage(page);
    });
  }

  Future<void> _openPageStripSheet() {
    return Navigator.of(context)
        .push<int>(
      buildReaderPageRoute<int>(
        builder: (context) => QuranPageStripScreen(
          controller: widget.controller,
        ),
      ),
    )
        .then((page) async {
      if (!mounted || page == null) {
        return;
      }
      await widget.controller.jumpToPage(page);
    });
  }

  Future<void> _openPageReport(BuildContext readerContext, {required bool isPortrait}) async {
    final controller = widget.controller;
    final profileId = controller.backupHistory.profileId;
    final baseUrl = controller.adminSyncBaseUrl;
    final edition = controller.settings.mushafEdition;
    final candidates = isPortrait ? [controller.currentPage]
        : [controller.currentSpread.rightPage, controller.currentSpread.leftPage];
    final pages = candidates.where((page) => page.number > 0 && page.contentType == QuranPageContentType.image)
        .map((page) => page.number).toSet().toList();
    if (pages.isEmpty) return;
    await showDialog<void>(context: readerContext, builder: (_) => _ReaderPageReportDialog(
      profileId: profileId, baseUrl: baseUrl, editionKey: edition.key,
      editionLabel: edition.label, pages: List<int>.unmodifiable(pages)));
  }

  Future<void> _openManualPins() async {
    final controller = widget.controller;
    final candidates = MediaQuery.orientationOf(context) == Orientation.landscape
        ? [controller.currentSpread.rightPage, controller.currentSpread.leftPage]
        : [controller.currentPage];
    final pages = <int, QuranPage>{for (final page in candidates)
      if (page.number > 0 && page.contentType == QuranPageContentType.image) page.number: page}.values.toList();
    if (pages.isEmpty) return;
    final settings = controller.settings.copyWith(hifzFocusMode: false);
    final experience = controller.experienceSettings;
    final theme = settings.nightMode
        ? AppTheme.dark(highContrast: experience.highContrastMode, largerText: experience.largerTextMode)
        : AppTheme.light(highContrast: experience.highContrastMode, largerText: experience.largerTextMode);
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => Theme(data: theme,
        child: _ReaderManualPinEditor(pages: pages, settings: settings))));
  }

  Future<void> _openCompareSheet() {
    if (!widget.controller.isCompareEnabled) {
      _showUnavailablePackMessage(
        'Download at least one more Quran edition to compare pages.',
      );
      return Future<void>.value();
    }
    return Navigator.of(context).push(
      buildReaderPageRoute<void>(
        builder: (context) => QuranCompareScreen(
          controller: widget.controller,
        ),
      ),
    );
  }

  Future<void> _openKanzulStudySheet() {
    if (!widget.controller.isKanzulStudyEnabled) {
      _showUnavailablePackMessage(
        'Download the Kanzul Iman pack first to open Kanzul study mode.',
      );
      return Future<void>.value();
    }
    return Navigator.of(context).push(
      buildReaderPageRoute<void>(
        builder: (context) => QuranKanzulImanStudyScreen(
          controller: widget.controller,
        ),
      ),
    );
  }

  void _showUnavailablePackMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr(context, message))),
    );
  }

  void _schedulePrefetchNearbyPages({bool force = false}) {
    _prefetchTimer?.cancel();
    _prefetchTimer = Timer(
      force ? Duration.zero : const Duration(milliseconds: 110),
      () {
        if (!mounted) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _prefetchNearbyPages(force: force);
        });
        if (kIsWeb) {
          WidgetsBinding.instance.ensureVisualUpdate();
        }
      },
    );
  }

  void _prefetchNearbyPages({bool force = false}) {
    final currentPageNumber = widget.controller.currentPageNumber;
    final lowMemoryMode = widget.controller.settings.lowMemoryMode;
    final preferImageMode = widget.controller.settings.preferImageMode;
    if (!preferImageMode || !widget.controller.hasImageAssets) {
      _lastPrefetchedPageNumber = null;
      _lastPrefetchedLowMemoryMode = null;
      _lastPrefetchedPreferImageMode = preferImageMode;
      _lastWebPrefetchKey = null;
      return;
    }
    final mediaQuery = MediaQuery.maybeOf(context);
    final viewportWidth = mediaQuery?.size.width ?? 1080;
    final devicePixelRatio = mediaQuery?.devicePixelRatio ?? 1.0;
    var pageWidth = viewportWidth;
    if (kIsWeb) {
      double? renderedPageWidth;
      void findPageImage(RenderObject object) {
        if (renderedPageWidth != null) return;
        if (object is RenderImage && object.hasSize &&
            object.size.width.isFinite && object.size.width > 0) {
          renderedPageWidth = object.size.width;
          return;
        }
        object.visitChildren(findPageImage);
      }
      final viewport = _readerViewportKey.currentContext?.findRenderObject();
      if (viewport != null) findPageImage(viewport);
      pageWidth = renderedPageWidth ?? viewportWidth;
    }
    final cacheWidth = (pageWidth * devicePixelRatio)
        .round()
        .clamp(lowMemoryMode ? 360 : 480, lowMemoryMode ? 640 : 900)
        .toInt();
    final isPortrait = _pageController.hasClients;
    final webPrefetchKey = kIsWeb
        ? '${widget.controller.settings.mushafEdition.storageValue}|'
            '${widget.controller.currentPage.assetPath}|$cacheWidth|$isPortrait'
        : null;
    if (!force &&
        _lastPrefetchedPageNumber == currentPageNumber &&
        _lastPrefetchedLowMemoryMode == lowMemoryMode &&
        _lastPrefetchedPreferImageMode == preferImageMode &&
        (!kIsWeb || _lastWebPrefetchKey == webPrefetchKey)) {
      return;
    }

    _lastPrefetchedPageNumber = currentPageNumber;
    _lastPrefetchedLowMemoryMode = lowMemoryMode;
    _lastPrefetchedPreferImageMode = preferImageMode;
    _lastWebPrefetchKey = webPrefetchKey;

    final List<int> pagesToWarm;
    if (lowMemoryMode) {
      pagesToWarm = <int>[currentPageNumber];
    } else if (kIsWeb && !isPortrait) {
      final spread = widget.controller.currentSpread;
      final nextSpreadIndex = widget.controller.currentSpreadIndex + 1;
      final nextSpread = nextSpreadIndex < widget.controller.totalSpreads
          ? widget.controller.spreadAt(nextSpreadIndex) : null;
      pagesToWarm = <int>[
        spread.rightPage.number,
        spread.leftPage.number,
        if (nextSpread != null) nextSpread.rightPage.number,
        if (nextSpread != null) nextSpread.leftPage.number,
      ];
    } else {
      pagesToWarm = <int>[
        currentPageNumber,
        currentPageNumber + 1,
        currentPageNumber - 1,
      ];
    }
    _precachePagesSequentially(
      pagesToWarm
          .where((page) => page >= 1 && page <= widget.controller.totalPages)
          .toList(growable: false),
      cacheWidth: cacheWidth,
    );
  }

  void _precachePagesSequentially(
    List<int> pageNumbers, {
    required int cacheWidth,
  }) {
    _deferredPrefetchTimer?.cancel();
    if (pageNumbers.isEmpty || !mounted) {
      return;
    }

    final pageNumber = pageNumbers.first;
    final remaining = pageNumbers.skip(1).toList(growable: false);
    try {
      final page = widget.controller.pageForNumber(pageNumber);
      final assetPath = page.assetPath;
      if (assetPath != null) {
        unawaited(precacheImage(
          buildQuranPageImageProvider(
            page,
            cacheWidth: cacheWidth,
          ),
          context,
        ).catchError((_) {}));
      }
    } catch (_) {
      // Prefetching is opportunistic; the reader should never pause for it.
    }

    if (remaining.isEmpty) {
      return;
    }
    _deferredPrefetchTimer = Timer(const Duration(milliseconds: 90), () {
      _precachePagesSequentially(remaining, cacheWidth: cacheWidth);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.loadingListenable,
      builder: (context, isLoading, _) {
        if (isLoading) {
          return ValueListenableBuilder<ReaderSettings>(
            valueListenable: widget.controller.settingsListenable,
            builder: (context, settings, _) {
              return BootstrapSplash(nightMode: settings.nightMode);
            },
          );
        }

        return AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[
            widget.controller.settingsListenable,
            widget.controller.experienceListenable,
            widget.controller.contentListenable,
          ]),
          builder: (context, _) {
            final settings = widget.controller.settings;
            final experience = widget.controller.experienceSettings;
            return ReaderOfflineActions(
              onOpenDownloads: _openDownloads,
              onReadBundledEdition: widget.controller.isBundledPackForEdition(MushafEdition.lines16)
                  ? _readBundledEdition : null,
              child: LayoutBuilder(
              builder: (context, constraints) {
                final isPortrait = constraints.maxHeight > constraints.maxWidth;
                final compactPortrait = isPortrait &&
                    (constraints.maxHeight < 760 || constraints.maxWidth < 430);
                final effectiveTheme = settings.nightMode
                    ? AppTheme.dark(
                        highContrast: experience.highContrastMode,
                        largerText: experience.largerTextMode,
                      )
                    : AppTheme.light(
                        highContrast: experience.highContrastMode,
                        largerText: experience.largerTextMode,
                      );

                return Theme(
                  data: effectiveTheme,
                  child: Builder(
                    builder: (context) {
                      final theme = Theme.of(context);
                      final zoomNotifier = isPortrait
                          ? _portraitZoomNotifier
                          : _landscapeZoomNotifier;
                      final readerViewport = AnimatedBuilder(
                        animation: widget.controller.viewportListenable,
                        builder: (context, _) {
                          return isPortrait
                              ? _PortraitPageReader(
                                  controller: _pageController,
                                  readerController: widget.controller,
                                  onZoomChanged: _setPortraitZoomActive,
                                  onPageChanged: (index) {
                                    _lastKnownPageViewIndex = index;
                                    widget.controller.setCurrentPageNumber(
                                      index + 1,
                                    );
                                  },
                                )
                              : _LandscapeSpreadReader(
                                  controller: _spreadController,
                                  readerController: widget.controller,
                                  onZoomChanged: _setLandscapeZoomActive,
                                  onPageChanged: (index) {
                                    _lastKnownSpreadIndex = index;
                                    widget.controller.setCurrentSpreadIndex(
                                      index,
                                    );
                                  },
                                );
                        },
                      );

                      return ValueListenableBuilder<bool>(
                        valueListenable: zoomNotifier,
                        child: readerViewport,
                        builder: (context, zoomActive, readerViewport) {
                          return AnimatedBuilder(
                            animation: widget.controller.controlsListenable,
                            child: readerViewport,
                            builder: (context, readerViewport) {
                              final showControls =
                                  widget.controller.controlsVisible &&
                                  (isPortrait || _landscapeControlsRevealed);
                              final fullscreenReading =
                                  widget.controller.settings.fullscreenReading;
                              final expandedReading =
                                  !isPortrait || fullscreenReading;
                              final showAppBar = showControls ||
                                  (isPortrait && !fullscreenReading);
                              final showBottomDock = isPortrait &&
                                  !showControls &&
                                  !fullscreenReading &&
                                  !zoomActive;
                              final bodyTopPadding = !expandedReading && showAppBar
                                  ? (isPortrait
                                      ? (compactPortrait ? 2.0 : 4.0)
                                      : 2.0)
                                  : 0.0;
                              final bodyBottomPadding = showBottomDock
                                  ? (compactPortrait ? 74.0 : 84.0)
                                  : (expandedReading ? 0.0 : 6.0);

                              return Scaffold(
                                extendBodyBehindAppBar: expandedReading,
                                appBar: showAppBar
                                    ? ReaderAppBar(
                                        controller: widget.controller,
                                        portraitMode: isPortrait,
                                        onToggleFullscreen: _toggleReaderFullscreen,
                                        onOpenSearch: _openSearchSheet,
                                        onOpenDashboard: _openDashboardSheet,
                                        onOpenGrowthHub: _openGrowthHub,
                                        onOpenInsights: _openInsightsSheet,
                                        onOpenAudio: _openAudioSheet,
                                        onOpenAiStudio: _openAiStudio,
                                        onOpenPageStrip: _openPageStripSheet,
                                        onOpenCompare: _openCompareSheet,
                                        onOpenKanzulStudy:
                                            _openKanzulStudySheet,
                                        onOpenSettings: _openSettingsSheet,
                                        onOpenManualPins: _openManualPins,
                                        onOpenPageReport: settings.preferImageMode
                                            ? () => _openPageReport(context, isPortrait: isPortrait) : null,
                                        bottom: !fullscreenReading || !widget.controller.isMushafEditionStoredOffline(settings.mushafEdition)
                                            ? PreferredSize(
                                                preferredSize: Size.fromHeight(
                                                  (MediaQuery.textScalerOf(context).scale(theme.textTheme.bodyMedium?.fontSize ?? 14) *
                                                      (theme.textTheme.bodyMedium?.height ?? 1.4) * 2)
                                                      .clamp(48.0, double.infinity).toDouble(),
                                                ),
                                                child: _ReaderAvailabilityNotice(
                                                  controller: widget.controller,
                                                  onOpenDownloads: _openDownloads,
                                                  embedded: true,
                                                ),
                                              )
                                            : null,
                                      )
                                    : null,
                                body: LayoutBuilder(builder: (context, bodyConstraints) => Column(children: [
                                  if (!showAppBar && !expandedReading && (!fullscreenReading || !widget.controller.isMushafEditionStoredOffline(settings.mushafEdition)))
                                    ConstrainedBox(
                                      constraints: BoxConstraints(maxHeight: bodyConstraints.maxHeight * 0.4),
                                      child: SingleChildScrollView(child: _ReaderAvailabilityNotice(
                                      controller: widget.controller,
                                      onOpenDownloads: _openDownloads,
                                    ))),
                                  Expanded(child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        theme.scaffoldBackgroundColor,
                                        theme.colorScheme.surface
                                            .withValues(alpha: 0.98),
                                        theme.colorScheme.surface,
                                      ],
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: _ReaderBackdrop(
                                          lowMemoryMode: settings.lowMemoryMode,
                                        ),
                                      ),
                                      SafeArea(
                                        top: !showAppBar,
                                        bottom: true,
                                        child: Stack(
                                          children: [
                                            AnimatedPadding(
                                              duration: const Duration(
                                                  milliseconds: 220),
                                              curve: Curves.easeOutCubic,
                                              padding: EdgeInsets.fromLTRB(
                                                0,
                                                bodyTopPadding,
                                                0,
                                                bodyBottomPadding,
                                              ),
                                              child: GestureDetector(
                                                behavior: HitTestBehavior.translucent,
                                                excludeFromSemantics: true,
                                                onTap: settings.hifzFocusMode || zoomActive
                                                    ? null
                                                    : () => _toggleReaderControls(isPortrait),
                                                child: _DesktopPageNavigation(
                                                  controller: widget.controller,
                                                  portraitMode: isPortrait,
                                                  child: KeyedSubtree(
                                                    key: _readerViewportKey,
                                                    child: readerViewport!,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              left: 0,
                                              right: 0,
                                              bottom: 0,
                                              child: IgnorePointer(
                                                ignoring: !showBottomDock,
                                                child: AnimatedSlide(
                                                  duration: const Duration(
                                                      milliseconds: 220),
                                                  curve: Curves.easeOutCubic,
                                                  offset: showBottomDock
                                                      ? Offset.zero
                                                      : const Offset(0, 0.2),
                                                  child: AnimatedOpacity(
                                                    duration: const Duration(
                                                        milliseconds: 180),
                                                    opacity:
                                                        showBottomDock ? 1 : 0,
                                                    child: ReaderBottomDock(
                                                      controller:
                                                          widget.controller,
                                                      onOpenAudio:
                                                          _openAudioSheet,
                                                      onOpenInsights:
                                                          _openInsightsSheet,
                                                      compact: compactPortrait,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (!showAppBar && expandedReading)
                                              PositionedDirectional(
                                                top: 8,
                                                end: 8,
                                                child: ReaderFullscreenButton(
                                                  fullscreenReading: fullscreenReading,
                                                  onPressed: _toggleReaderFullscreen,
                                                  showLabel: !isPortrait &&
                                                      MediaQuery.sizeOf(context).width >= 600,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                                ])),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ));
          },
        );
      },
    );
  }
}

class _ReaderAvailabilityNotice extends StatefulWidget {
  const _ReaderAvailabilityNotice({
    required this.controller,
    required this.onOpenDownloads,
    this.embedded = false,
  });

  final QuranReaderController controller;
  final VoidCallback onOpenDownloads;
  final bool embedded;

  @override
  State<_ReaderAvailabilityNotice> createState() => _ReaderAvailabilityNoticeState();
}

class _ReaderAvailabilityNoticeState extends State<_ReaderAvailabilityNotice>
    with WidgetsBindingObserver {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool? _connectionAvailable;
  int _connectionGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = _connectivity.onConnectivityChanged.listen(
      _updateConnection,
      onError: (Object _) {},
    );
    _checkConnection();
  }

  void _checkConnection() {
    final generation = ++_connectionGeneration;
    _connectivity.checkConnectivity().then((connections) {
      if (mounted && generation == _connectionGeneration) {
        _updateConnection(connections);
      }
    }).catchError((Object _) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkConnection();
    }
  }

  void _updateConnection(List<ConnectivityResult> connections) {
    _connectionGeneration += 1;
    if (!mounted) return;
    final connected = connections.any((result) => result != ConnectivityResult.none);
    if (_connectionAvailable != connected) {
      setState(() => _connectionAvailable = connected);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final edition = controller.settings.mushafEdition;
        final stored = controller.isMushafEditionStoredOffline(edition);
        final disconnected = _connectionAvailable == false;
        final theme = Theme.of(context);
        final label = stored
            ? 'Available offline'
            : disconnected ? 'No internet connection' : 'Reading online';
        final content = Padding(
              padding: widget.embedded ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: disconnected && !stored
                        ? theme.colorScheme.errorContainer
                        : theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(stored ? Icons.offline_pin_rounded : disconnected
                      ? Icons.cloud_off_rounded : Icons.cloud_outlined,
                    size: 16,
                    color: disconnected && !stored
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(tr(context, label),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ))),
                if (!stored)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    child: FilledButton.tonalIcon(
                    onPressed: widget.onOpenDownloads,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(tr(context, 'Download')),
                    ),
                  ),
                ]),
              ),
            );
        if (widget.embedded) {
          return content;
        }
        final size = MediaQuery.sizeOf(context);
        final compact = size.width < 420 || size.height < 720;
        return SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(compact ? 8 : 12, 4, compact ? 8 : 12, 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                boxShadow: AppDecor.of(context).cardShadow,
              ),
              child: Material(
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  side: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.7),
                  ),
                ),
                child: content,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DesktopPageNavigation extends StatelessWidget {
  const _DesktopPageNavigation({required this.controller,
    required this.portraitMode, required this.child});

  final QuranReaderController controller;
  final bool portraitMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final desktop = switch (Theme.of(context).platform) {
      TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows => true,
      _ => false,
    };
    if (!desktop) return child;
    return AnimatedBuilder(animation: controller.pageListenable, builder: (context, _) {
      void next() => unawaited(portraitMode ? controller.nextPage() : controller.nextSpread());
      void previous() => unawaited(portraitMode ? controller.previousPage() : controller.previousSpread());
      final canNext = portraitMode ? controller.canGoNextPage : controller.canGoNextSpread;
      final canPrevious = portraitMode ? controller.canGoPreviousPage : controller.canGoPreviousSpread;
      return CallbackShortcuts(bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft, includeRepeats: false): next,
        const SingleActivator(LogicalKeyboardKey.arrowRight, includeRepeats: false): previous,
      }, child: Focus(autofocus: true, child: Stack(fit: StackFit.expand, children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 56), child: child),
        Align(alignment: Alignment.centerLeft, child: IconButton.filledTonal(
          tooltip: tr(context, 'Next'), onPressed: canNext ? next : null,
          icon: const Icon(Icons.chevron_left, textDirection: TextDirection.ltr))),
        Align(alignment: Alignment.centerRight, child: IconButton.filledTonal(
          tooltip: tr(context, 'Previous'), onPressed: canPrevious ? previous : null,
          icon: const Icon(Icons.chevron_right, textDirection: TextDirection.ltr))),
      ])));
    });
  }
}

class _LandscapeSpreadReader extends StatelessWidget {
  const _LandscapeSpreadReader({
    required this.controller,
    required this.readerController,
    required this.onZoomChanged,
    required this.onPageChanged,
  });

  final PageController controller;
  final QuranReaderController readerController;
  final ValueChanged<bool> onZoomChanged;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: PageView.builder(
        controller: controller,
        reverse: true,
        padEnds: false,
        allowImplicitScrolling: false,
        itemCount: readerController.totalSpreads,
        onPageChanged: onPageChanged,
        itemBuilder: (context, index) {
          final spread = readerController.spreadAt(index);
          return ReaderZoomViewport(
            key: ValueKey('spread-$index'),
            onZoomChanged: onZoomChanged,
            child: DualPageSpread(
              spread: spread,
              settings: readerController.settings,
              leftSmartHifzHiddenLines:
                  readerController.smartHifzHiddenLinesForPage(
                spread.leftPage.number,
              ),
              rightSmartHifzHiddenLines:
                  readerController.smartHifzHiddenLinesForPage(
                spread.rightPage.number,
              ),
              leftSmartHifzManualMaskAnchors:
                  readerController.smartHifzManualMaskAnchorsForPage(
                spread.leftPage.number,
              ),
              rightSmartHifzManualMaskAnchors:
                  readerController.smartHifzManualMaskAnchorsForPage(
                spread.rightPage.number,
              ),
              onLeftSmartHifzManualMaskAnchorChanged: readerController
                      .smartHifzAppliesToPage(spread.leftPage.number)
                  ? readerController.updateSmartHifzManualMaskAnchor
                  : null,
              onRightSmartHifzManualMaskAnchorChanged: readerController
                      .smartHifzAppliesToPage(spread.rightPage.number)
                  ? readerController.updateSmartHifzManualMaskAnchor
                  : null,
              leftSmartHifzRevealed: readerController.smartHifzRevealedForPage(
                spread.leftPage.number,
              ),
              rightSmartHifzRevealed: readerController.smartHifzRevealedForPage(
                spread.rightPage.number,
              ),
              leftSmartHifzEdition: readerController.smartHifzEditionForPage(
                spread.leftPage.number,
              ),
              rightSmartHifzEdition: readerController.smartHifzEditionForPage(
                spread.rightPage.number,
              ),
              leftSmartHifzLineCount:
                  readerController.smartHifzLineCountForPage(
                spread.leftPage.number,
              ),
              rightSmartHifzLineCount:
                  readerController.smartHifzLineCountForPage(
                spread.rightPage.number,
              ),
            ),
          );
        },
      ),
      ),
    );
  }
}

class _PortraitPageReader extends StatelessWidget {
  const _PortraitPageReader({
    required this.controller,
    required this.readerController,
    required this.onZoomChanged,
    required this.onPageChanged,
  });

  final PageController controller;
  final QuranReaderController readerController;
  final ValueChanged<bool> onZoomChanged;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: PageView.builder(
        controller: controller,
        reverse: true,
        padEnds: false,
        allowImplicitScrolling: false,
        itemCount: readerController.totalPages,
        onPageChanged: onPageChanged,
        itemBuilder: (context, index) {
          final page = readerController.pageForNumber(
            index + 1,
            isLeftPage: false,
          );
          return ReaderZoomViewport(
            key: ValueKey('page-$index'),
            onZoomChanged: onZoomChanged,
            child: SinglePageReader(
              page: page,
              settings: readerController.settings,
              smartHifzHiddenLines:
                  readerController.smartHifzHiddenLinesForPage(page.number),
              smartHifzManualMaskAnchors: readerController
                  .smartHifzManualMaskAnchorsForPage(page.number),
              onSmartHifzManualMaskAnchorChanged:
                  readerController.smartHifzAppliesToPage(page.number)
                      ? readerController.updateSmartHifzManualMaskAnchor
                      : null,
              smartHifzRevealed:
                  readerController.smartHifzRevealedForPage(page.number),
              smartHifzEdition:
                  readerController.smartHifzEditionForPage(page.number),
              smartHifzLineCount:
                  readerController.smartHifzLineCountForPage(page.number),
            ),
          );
        },
      ),
      ),
    );
  }
}

class _ReaderManualPinEditor extends StatefulWidget {
  const _ReaderManualPinEditor({required this.pages, required this.settings});
  final List<QuranPage> pages;
  final ReaderSettings settings;
  @override
  State<_ReaderManualPinEditor> createState() => _ReaderManualPinEditorState();
}

class _ReaderManualPinEditorState extends State<_ReaderManualPinEditor> {
  int _selected = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, 'Manual notes and mistake pins'))),
    body: SafeArea(child: Column(children: [
      if (widget.pages.length > 1) Padding(padding: const EdgeInsets.all(10), child: Wrap(
        spacing: 10, runSpacing: 10, children: [for (var index = 0; index < widget.pages.length; index++)
          ChoiceChip(label: Text(tr(context, 'Page {page}', args: {'page': widget.pages[index].number})),
            selected: _selected == index, onSelected: (_) => setState(() => _selected = index)),
        ])),
      Expanded(child: ReaderZoomViewport(key: ValueKey(widget.pages[_selected].number),
        onZoomChanged: (_) {}, child: ReaderPinEditingScope(child: MushafPageWidget(
          page: widget.pages[_selected], settings: widget.settings, showPageNumbers: false)))),
    ])),
  );
}

class _ReaderBackdrop extends StatelessWidget {
  const _ReaderBackdrop({
    required this.lowMemoryMode,
  });

  final bool lowMemoryMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (lowMemoryMode) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface.withValues(alpha: 0.06),
              Colors.transparent,
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned(
          top: -120,
          left: -60,
          child: _BackdropOrb(
            size: 340,
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
          ),
        ),
        Positioned(
          right: -80,
          bottom: -120,
          child: _BackdropOrb(
            size: 380,
            color: theme.colorScheme.secondary.withValues(alpha: 0.07),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.22,
                colors: [
                  theme.colorScheme.surface.withValues(alpha: 0.14),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.025),
                    Colors.transparent,
                    theme.colorScheme.secondary.withValues(alpha: 0.025),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0.02),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

String _pageReportText(BuildContext context, String english, String urdu, String arabic) =>
    switch (ReaderLocalizationScope.of(context).language) {
      ReaderLanguage.urdu => urdu,
      ReaderLanguage.arabic => arabic,
      _ => english,
    };

class _ReaderPageReportDialog extends StatefulWidget {
  const _ReaderPageReportDialog({required this.profileId, required this.baseUrl,
    required this.editionKey, required this.editionLabel, required this.pages});
  final String profileId;
  final String baseUrl;
  final String editionKey;
  final String editionLabel;
  final List<int> pages;
  @override
  State<_ReaderPageReportDialog> createState() => _ReaderPageReportDialogState();
}

class _ReaderPageReportDialogState extends State<_ReaderPageReportDialog> {
  final _description = TextEditingController();
  ReaderPageReportService? _service;
  late int _page;
  String _issue = 'missing';
  bool _busy = true;
  bool _queueReady = false;
  bool _saved = false;
  bool _sent = false;
  String? _clientReportId;
  String? _error;
  List<ReaderPageReport> _pending = const [];

  String _t(String english, String urdu, String arabic) => _pageReportText(context, english, urdu, arabic);
  String _issueLabel(String issue) => switch (issue) {
    'missing' => _t('Missing page', 'صفحہ غائب ہے', 'صفحة مفقودة'),
    'blurred' => _t('Blurred or unreadable', 'دھندلا یا پڑھنے کے قابل نہیں', 'ضبابية أو غير مقروءة'),
    'wrong_page' => _t('Wrong page', 'غلط صفحہ', 'صفحة غير صحيحة'),
    _ => _t('Other problem', 'دوسرا مسئلہ', 'مشكلة أخرى'),
  };

  String _errorLabel(String error) {
    if (error.startsWith('http_')) {
      return _t('Server response ${error.substring(5)}. Still pending.',
        'سرور کا جواب ${error.substring(5)}۔ اطلاع ابھی باقی ہے۔', 'استجابة الخادم ${error.substring(5)}. لا يزال البلاغ معلقًا.');
    }
    return switch (error) {
      'invalid_report' => _t('Check the page and problem selection. Details must be within 1,000 characters and contain no hidden control characters.',
        'صفحہ اور مسئلہ دوبارہ دیکھیں۔ تفصیل ۱۰۰۰ حروف تک ہونی چاہیے اور اس میں پوشیدہ کنٹرول حروف نہیں ہونے چاہییں۔',
        'تحقق من الصفحة ونوع المشكلة. يجب ألا تتجاوز التفاصيل 1000 حرف وألا تحتوي على محارف تحكم مخفية.'),
      'queue_full' => _t('The saved queue is full (20 reports). Retry the pending reports first.',
        'محفوظ فہرست میں ۲۰ اطلاعات ہیں۔ پہلے باقی اطلاعات دوبارہ بھیجیں۔', 'قائمة الحفظ ممتلئة (20 بلاغًا). أعد إرسال البلاغات المعلقة أولًا.'),
      'invalid_queue' => _t('Saved reports could not be read. They have not been deleted.',
        'محفوظ اطلاعات نہیں پڑھی جاسکیں۔ انہیں حذف نہیں کیا گیا۔', 'تعذّرت قراءة البلاغات المحفوظة. لم يتم حذفها.'),
      'timeout' => _t('Connection timed out. Still pending.', 'رابطے کا وقت ختم ہوگیا۔ اطلاع ابھی باقی ہے۔', 'انتهت مهلة الاتصال. لا يزال البلاغ معلقًا.'),
      'invalid_receipt' => _t('The server did not confirm this report. Still pending.',
        'سرور نے اس اطلاع کی تصدیق نہیں کی۔ اطلاع ابھی باقی ہے۔', 'لم يؤكد الخادم هذا البلاغ. لا يزال معلقًا.'),
      'network' || 'cancelled' => _t('Could not connect. Still pending.', 'رابطہ نہیں ہوسکا۔ اطلاع ابھی باقی ہے۔', 'تعذّر الاتصال. لا يزال البلاغ معلقًا.'),
      'insecure_server' || 'server_unavailable' => _t('Reporting needs a valid HTTPS server. Your reading is unchanged.',
        'اطلاع بھیجنے کے لیے درست HTTPS سرور درکار ہے۔ آپ کی تلاوت میں تبدیلی نہیں ہوئی۔', 'يتطلب الإبلاغ خادم HTTPS صالحًا. لم تتغير قراءتك.'),
      _ => _t('Could not save the report status. Keep this form open and try again.',
        'اطلاع کی حالت محفوظ نہیں ہوسکی۔ یہ فارم کھلا رکھیں اور دوبارہ کوشش کریں۔', 'تعذّر حفظ حالة البلاغ. أبقِ النموذج مفتوحًا وحاول مجددًا.'),
    };
  }

  String _failure(Object error) => error is StateError ? error.message
      : error is ArgumentError ? 'invalid_report' : error is FormatException ? 'invalid_queue' : 'save_failed';

  @override
  void initState() {
    super.initState();
    _page = widget.pages.first;
    _initializeReports();
  }

  Future<void> _initializeReports() async {
    try {
      _service = ReaderPageReportService(profileId: widget.profileId, baseUrl: widget.baseUrl);
      await _retryPending();
    } catch (_) {
      if (mounted) setState(() { _busy = false; _error = 'server_unavailable'; });
    }
  }

  Future<void> _retryPending() async {
    final service = _service;
    if (service == null || (_busy && _queueReady)) return;
    setState(() { _busy = true; _error = null; });
    try {
      final pending = await service.pending();
      if (!mounted) return;
      setState(() { _pending = pending; _queueReady = true; });
      for (final report in pending) {
        if (!mounted) return;
        final receipt = await service.send(report.clientReportId);
        if (!mounted) return;
        final remaining = await service.pending();
        if (!mounted) return;
        setState(() {
          _pending = remaining;
          if (receipt != null && report.clientReportId == _clientReportId) _sent = true;
        });
        if (receipt == null && remaining.any((entry) => entry.clientReportId == report.clientReportId &&
            (const {'network', 'timeout', 'cancelled', 'invalid_receipt', 'insecure_server'}.contains(entry.lastError) ||
                (entry.lastError?.startsWith('http_5') ?? false)))) {
          break;
        }
      }
    } catch (error) {
      if (mounted) setState(() { _error = _failure(error); });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  Future<void> _submit() async {
    final service = _service;
    if (_busy || _saved || !_queueReady || service == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final report = await service.enqueue(editionKey: widget.editionKey, pageNumber: _page,
        issueType: _issue, description: _description.text);
      if (!mounted) return;
      setState(() { _saved = true; _clientReportId = report.clientReportId; });
      final receipt = await service.send(report.clientReportId);
      if (!mounted) return;
      setState(() { _sent = receipt != null; });
      final pending = await service.pending();
      if (mounted) setState(() { _pending = pending; });
    } catch (error) {
      if (mounted) setState(() { _error = _failure(error); });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  void dispose() {
    _service?.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editable = !_busy && !_saved && _queueReady;
    return Directionality(textDirection: ReaderLocalizationScope.of(context).textDirection,
      child: AlertDialog(
        title: Text(_t('Report a page problem', 'صفحے کے مسئلے کی اطلاع', 'الإبلاغ عن مشكلة في الصفحة')),
        content: SizedBox(width: 540, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${widget.editionLabel} · ${widget.editionKey}', textDirection: TextDirection.ltr),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(initialValue: _page, isExpanded: true,
              decoration: InputDecoration(labelText: _t('Visible page', 'نظر آنے والا صفحہ', 'الصفحة المعروضة'), border: const OutlineInputBorder()),
              items: widget.pages.map((page) => DropdownMenuItem(value: page,
                child: Text(_t('Page $page', 'صفحہ $page', 'الصفحة $page')))).toList(),
              onChanged: editable ? (value) { if (value != null) setState(() { _page = value; }); } : null),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(initialValue: _issue, isExpanded: true,
              decoration: InputDecoration(labelText: _t('Problem', 'مسئلہ', 'المشكلة'), border: const OutlineInputBorder()),
              items: ReaderPageReportService.issueTypes.map((issue) => DropdownMenuItem(value: issue,
                child: Text(_issueLabel(issue), maxLines: 2, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: editable ? (value) { if (value != null) setState(() { _issue = value; }); } : null),
            const SizedBox(height: 14),
            TextField(controller: _description, enabled: editable, minLines: 3, maxLines: 5,
              maxLength: 1000, maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: InputDecoration(labelText: _t('Details (optional)', 'تفصیل (اختیاری)', 'التفاصيل (اختياري)'), border: const OutlineInputBorder())),
            Text(_t('Include page details only. Reports do not change the Quran automatically.',
              'صرف صفحے کی تفصیل دیں۔ اطلاع بھیجنے سے قرآن میں خودکار تبدیلی نہیں ہوتی۔',
              'أضف تفاصيل الصفحة فقط. لا تؤدي البلاغات إلى تغيير القرآن تلقائيًا.'), style: Theme.of(context).textTheme.bodySmall),
            if (_saved) ...[
              const SizedBox(height: 12),
              Text(_sent ? _t('Sent. The server confirmed your report.', 'بھیج دی گئی۔ سرور نے اطلاع کی تصدیق کردی۔', 'تم الإرسال. أكد الخادم بلاغك.')
                : _t('Saved on this device. Reopen this form or tap Retry to send pending reports.',
                    'اس ڈیوائس پر محفوظ ہے۔ باقی اطلاعات بھیجنے کے لیے یہ فارم دوبارہ کھولیں یا دوبارہ کوشش دبائیں۔',
                    'محفوظ على هذا الجهاز. أعد فتح النموذج أو اضغط إعادة المحاولة لإرسال البلاغات المعلقة.')),
              TextButton(onPressed: _busy ? null : () => setState(() {
                _saved = false; _sent = false; _clientReportId = null; _error = null; _description.clear();
              }), child: Text(_t('New report', 'نئی اطلاع', 'بلاغ جديد'))),
            ],
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
              child: Text(_errorLabel(_error!), style: TextStyle(color: Theme.of(context).colorScheme.error))),
            if (_pending.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(_t('Pending reports: ${_pending.length}', 'باقی اطلاعات: ${_pending.length}', 'البلاغات المعلقة: ${_pending.length}'),
                style: Theme.of(context).textTheme.titleSmall),
              for (final report in _pending) Padding(padding: const EdgeInsets.only(top: 10), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${report.editionKey} · ${report.pageNumber} · ${_issueLabel(report.issueType)}'),
                  if (report.lastError != null) Text(_errorLabel(report.lastError!), style: Theme.of(context).textTheme.bodySmall),
                ])),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _busy ? null : _retryPending, icon: const Icon(Icons.refresh),
                label: Text(_t('Retry pending reports', 'باقی اطلاعات دوبارہ بھیجیں', 'إعادة إرسال البلاغات المعلقة'))),
            ],
            if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_t('Close', 'بند کریں', 'إغلاق'))),
          FilledButton(onPressed: editable ? _submit : null, child: Text(_t('Send report', 'اطلاع بھیجیں', 'إرسال البلاغ'))),
        ],
      ));
  }
}

class _ReaderLifecycleObserver extends WidgetsBindingObserver {
  _ReaderLifecycleObserver({
    required this.onSavePosition,
  });

  final VoidCallback onSavePosition;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      onSavePosition();
    }
  }
}
