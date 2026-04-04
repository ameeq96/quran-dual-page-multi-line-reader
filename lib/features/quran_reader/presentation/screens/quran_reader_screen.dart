import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import '../widgets/bootstrap_splash.dart';
import '../widgets/dual_page_spread.dart';
import '../widgets/kanzul_iman_study_sheet.dart';
import '../widgets/reader_audio_sheet.dart';
import '../widgets/reader_app_bar.dart';
import '../widgets/reader_bottom_dock.dart';
import '../widgets/reader_compare_sheet.dart';
import '../widgets/reader_dashboard_sheet.dart';
import '../widgets/reader_insights_sheet.dart';
import '../widgets/reader_motion.dart';
import '../widgets/reader_page_strip_sheet.dart';
import '../widgets/single_page_reader.dart';
import 'quran_ai_studio_screen.dart';
import 'quran_bookmarks_screen.dart';
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
  int? _lastPrefetchedPageNumber;
  bool? _lastPrefetchedLowMemoryMode;
  bool? _lastPrefetchedPreferImageMode;
  bool _initialActionHandled = false;

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
        _prefetchNearbyPages(force: true);
        _runInitialActionIfNeeded();
      }
    });
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
    oldWidget.controller.settingsListenable.removeListener(_syncViewControllers);
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
      _prefetchNearbyPages();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    widget.controller.persistReadingPosition();
    widget.controller.pageListenable.removeListener(_syncViewControllers);
    widget.controller.settingsListenable.removeListener(_syncViewControllers);
    _spreadController.dispose();
    _pageController.dispose();
    super.dispose();
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
        await _openSearchSheet(initialTab: 4);
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
    final titles = <int, String>{
      0: 'Surah Index',
      1: 'Juz Index',
      2: 'Index',
      3: 'Ayah Search',
      4: 'Go to page',
      5: 'Text Search',
    };
    final page = await Navigator.of(context).push<int>(
      buildReaderPageRoute<int>(
        builder: (context) => QuranSearchScreen(
          title: titles[initialTab] ?? 'Search',
          initialTab: initialTab,
          nightMode: widget.controller.settings.nightMode,
          surahs: widget.controller.surahEntries,
          juzs: widget.controller.juzEntries,
          rukuMarkers: widget.controller.rukuMarkers,
          hizbMarkers: widget.controller.hizbMarkers,
          manzilMarkers: widget.controller.manzilMarkers,
          rubMarkers: widget.controller.rubMarkers,
          currentPage: widget.controller.currentPageNumber,
          maxPage: widget.controller.totalPages,
          surahPageResolver: widget.controller.navigationPageForSurahEntry,
          juzPageResolver: widget.controller.navigationPageForJuzEntry,
          ayahSearch: widget.controller.searchAyahs,
          textSearch: widget.controller.searchPages,
        ),
      ),
    );
    if (!mounted || page == null) {
      return;
    }
    await widget.controller.jumpToPage(page);
  }

  Future<void> _openInsightsSheet() {
    return Navigator.of(context).push<int>(
      buildReaderPageRoute<int>(
        builder: (context) => QuranInsightsScreen(
          controller: widget.controller,
        ),
      ),
    ).then((page) async {
      if (!mounted || page == null) {
        return;
      }
      await widget.controller.jumpToPage(page);
    });
  }

  Future<void> _openBookmarksSheet() {
    return Navigator.of(context).push<int>(
      buildReaderPageRoute<int>(
        builder: (context) => QuranBookmarksScreen(
          controller: widget.controller,
        ),
      ),
    ).then((page) async {
      if (!mounted || page == null) {
        return;
      }
      await widget.controller.jumpToPage(page);
    });
  }

  Future<void> _openDashboardSheet() {
    return Navigator.of(context).push<int>(
      buildReaderPageRoute<int>(
        builder: (screenContext) => QuranDashboardScreen(
          controller: widget.controller,
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
    ).then((page) async {
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
    return Navigator.of(context).push<int>(
      buildReaderPageRoute<int>(
        builder: (context) => QuranAiStudioScreen(
          controller: widget.controller,
        ),
      ),
    ).then((page) async {
      if (!mounted || page == null) {
        return;
      }
      await widget.controller.jumpToPage(page);
    });
  }

  Future<void> _openPageStripSheet() {
    return Navigator.of(context).push<int>(
      buildReaderPageRoute<int>(
        builder: (context) => QuranPageStripScreen(
          controller: widget.controller,
        ),
      ),
    ).then((page) async {
      if (!mounted || page == null) {
        return;
      }
      await widget.controller.jumpToPage(page);
    });
  }

  Future<void> _openCompareSheet() {
    return Navigator.of(context).push(
      buildReaderPageRoute<void>(
        builder: (context) => QuranCompareScreen(
          controller: widget.controller,
        ),
      ),
    );
  }

  Future<void> _openKanzulStudySheet() {
    return Navigator.of(context).push(
      buildReaderPageRoute<void>(
        builder: (context) => QuranKanzulImanStudyScreen(
          controller: widget.controller,
        ),
      ),
    );
  }

  void _prefetchNearbyPages({bool force = false}) {
    final currentPageNumber = widget.controller.currentPageNumber;
    final lowMemoryMode = widget.controller.settings.lowMemoryMode;
    final preferImageMode = widget.controller.settings.preferImageMode;
    final mediaQuery = MediaQuery.maybeOf(context);
    final viewportWidth = mediaQuery?.size.width ?? 1080;
    final devicePixelRatio = mediaQuery?.devicePixelRatio ?? 1.0;
    final cacheWidth = (viewportWidth * devicePixelRatio)
        .round()
        .clamp(lowMemoryMode ? 520 : 700, lowMemoryMode ? 980 : 1680)
        .toInt();
    if (!force &&
        _lastPrefetchedPageNumber == currentPageNumber &&
        _lastPrefetchedLowMemoryMode == lowMemoryMode &&
        _lastPrefetchedPreferImageMode == preferImageMode) {
      return;
    }

    _lastPrefetchedPageNumber = currentPageNumber;
    _lastPrefetchedLowMemoryMode = lowMemoryMode;
    _lastPrefetchedPreferImageMode = preferImageMode;

    final pagesToWarm = widget.controller.settings.lowMemoryMode
        ? <int>{currentPageNumber}
        : <int>{
            currentPageNumber - 1,
            currentPageNumber,
            currentPageNumber + 1,
            currentPageNumber + 2,
          };

    for (final pageNumber in pagesToWarm
        .where((page) => page >= 1 && page <= widget.controller.totalPages)) {
      final page = widget.controller.pageForNumber(pageNumber);
      final assetPath = page.assetPath;
      if (assetPath != null) {
        precacheImage(
          ResizeImage.resizeIfNeeded(
            cacheWidth,
            null,
            AssetImage(assetPath),
          ),
          context,
        );
      }
    }
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

        return ValueListenableBuilder<ReaderSettings>(
          valueListenable: widget.controller.settingsListenable,
          builder: (context, settings, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final isPortrait = constraints.maxHeight > constraints.maxWidth;
                final compactPortrait = isPortrait &&
                    (constraints.maxHeight < 760 || constraints.maxWidth < 430);
                final effectiveTheme =
                    settings.nightMode ? AppTheme.dark() : AppTheme.light();

                return Theme(
                  data: effectiveTheme,
                  child: Builder(
                    builder: (context) {
                      final theme = Theme.of(context);

                      return AnimatedBuilder(
                        animation: widget.controller.controlsListenable,
                        builder: (context, _) {
                          final showControls = widget.controller.controlsVisible;
                          final showAppBar = isPortrait || showControls;
                          final showBottomDock = isPortrait && !showControls;
                          final bodyTopPadding = showAppBar
                              ? (isPortrait
                                  ? (compactPortrait ? 6.0 : 8.0)
                                  : 4.0)
                              : 4.0;
                          final bodyBottomPadding = showBottomDock
                              ? (compactPortrait ? 84.0 : 96.0)
                              : 10.0;

                          return Scaffold(
                            extendBodyBehindAppBar: false,
                            appBar: showAppBar
                                ? ReaderAppBar(
                                    controller: widget.controller,
                                    portraitMode: isPortrait,
                                    onOpenSearch: _openSearchSheet,
                                    onOpenDashboard: _openDashboardSheet,
                                    onOpenInsights: _openInsightsSheet,
                                    onOpenAudio: _openAudioSheet,
                                    onOpenAiStudio: _openAiStudio,
                                    onOpenPageStrip: _openPageStripSheet,
                                    onOpenCompare: _openCompareSheet,
                                    onOpenKanzulStudy: _openKanzulStudySheet,
                                    onOpenSettings: _openSettingsSheet,
                                  )
                                : null,
                            body: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    theme.scaffoldBackgroundColor,
                                    theme.colorScheme.surface.withOpacity(0.98),
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
                                    bottom: false,
                                    child: Stack(
                                      children: [
                                        AnimatedPadding(
                                          duration:
                                              const Duration(milliseconds: 220),
                                          curve: Curves.easeOutCubic,
                                          padding: EdgeInsets.fromLTRB(
                                            0,
                                            bodyTopPadding,
                                            0,
                                            bodyBottomPadding,
                                          ),
                                          child: AnimatedBuilder(
                                            animation: Listenable.merge(
                                              <Listenable>[
                                                widget.controller.pageListenable,
                                                widget.controller.viewportListenable,
                                              ],
                                            ),
                                            builder: (context, _) {
                                              return isPortrait
                                                  ? _PortraitPageReader(
                                                      controller: _pageController,
                                                      readerController:
                                                          widget.controller,
                                                      lastKnownPageViewIndex:
                                                          _lastKnownPageViewIndex,
                                                      onPageChanged: (index) {
                                                        _lastKnownPageViewIndex =
                                                            index;
                                                        widget.controller
                                                            .setCurrentPageNumber(
                                                          index + 1,
                                                        );
                                                      },
                                                    )
                                                  : _LandscapeSpreadReader(
                                                      controller:
                                                          _spreadController,
                                                      readerController:
                                                          widget.controller,
                                                      lastKnownSpreadIndex:
                                                          _lastKnownSpreadIndex,
                                                      onPageChanged: (index) {
                                                        _lastKnownSpreadIndex =
                                                            index;
                                                        widget.controller
                                                            .setCurrentSpreadIndex(
                                                          index,
                                                        );
                                                      },
                                                    );
                                            },
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            ignoring:
                                                widget.controller.settings
                                                    .hifzFocusMode,
                                            child: GestureDetector(
                                              behavior:
                                                  HitTestBehavior.translucent,
                                              onTap: widget.controller
                                                  .toggleControlsVisibility,
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
                                                opacity: showBottomDock ? 1 : 0,
                                                child: ReaderBottomDock(
                                                  controller: widget.controller,
                                                  onOpenAudio: _openAudioSheet,
                                                  onOpenInsights:
                                                      _openInsightsSheet,
                                                  compact: compactPortrait,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _LandscapeSpreadReader extends StatelessWidget {
  const _LandscapeSpreadReader({
    required this.controller,
    required this.readerController,
    required this.lastKnownSpreadIndex,
    required this.onPageChanged,
  });

  final PageController controller;
  final QuranReaderController readerController;
  final int lastKnownSpreadIndex;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: PageView.builder(
        controller: controller,
        reverse: true,
        padEnds: false,
        itemCount: readerController.totalSpreads,
        onPageChanged: onPageChanged,
        itemBuilder: (context, index) {
          final spread = readerController.spreadAt(index);
          return DualPageSpread(
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
            onLeftSmartHifzManualMaskAnchorChanged:
                readerController.smartHifzAppliesToPage(spread.leftPage.number)
                    ? readerController.updateSmartHifzManualMaskAnchor
                    : null,
            onRightSmartHifzManualMaskAnchorChanged:
                readerController.smartHifzAppliesToPage(spread.rightPage.number)
                    ? readerController.updateSmartHifzManualMaskAnchor
                    : null,
            leftSmartHifzRevealed:
                readerController.smartHifzRevealedForPage(
              spread.leftPage.number,
            ),
            rightSmartHifzRevealed:
                readerController.smartHifzRevealedForPage(
              spread.rightPage.number,
            ),
            leftSmartHifzEdition:
                readerController.smartHifzEditionForPage(
              spread.leftPage.number,
            ),
            rightSmartHifzEdition:
                readerController.smartHifzEditionForPage(
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
            spreadOffset: index - lastKnownSpreadIndex.toDouble(),
          );
        },
      ),
    );
  }
}

class _PortraitPageReader extends StatelessWidget {
  const _PortraitPageReader({
    required this.controller,
    required this.readerController,
    required this.lastKnownPageViewIndex,
    required this.onPageChanged,
  });

  final PageController controller;
  final QuranReaderController readerController;
  final int lastKnownPageViewIndex;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: PageView.builder(
        controller: controller,
        reverse: true,
        padEnds: false,
        itemCount: readerController.totalPages,
        onPageChanged: onPageChanged,
        itemBuilder: (context, index) {
          final page = readerController.pageForNumber(
            index + 1,
            isLeftPage: false,
          );
          return SinglePageReader(
            page: page,
            settings: readerController.settings,
            smartHifzHiddenLines:
                readerController.smartHifzHiddenLinesForPage(page.number),
            smartHifzManualMaskAnchors:
                readerController.smartHifzManualMaskAnchorsForPage(page.number),
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
            pageOffset: index - lastKnownPageViewIndex.toDouble(),
          );
        },
      ),
    );
  }
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
              theme.colorScheme.surface.withOpacity(0.06),
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
            color: theme.colorScheme.primary.withOpacity(0.08),
          ),
        ),
        Positioned(
          right: -80,
          bottom: -120,
          child: _BackdropOrb(
            size: 380,
            color: theme.colorScheme.secondary.withOpacity(0.07),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.22,
                colors: [
                  theme.colorScheme.surface.withOpacity(0.14),
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
                    theme.colorScheme.primary.withOpacity(0.025),
                    Colors.transparent,
                    theme.colorScheme.secondary.withOpacity(0.025),
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
              color.withOpacity(0.02),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
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
