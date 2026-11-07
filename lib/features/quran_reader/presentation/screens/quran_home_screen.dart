import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/reader_admin_config.dart';
import '../../domain/models/quran_page.dart';
import '../../domain/models/quran_ai_models.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import '../widgets/kanzul_iman_study_sheet.dart';
import '../widgets/jump_to_page_dialog.dart';
import '../widgets/reader_audio_sheet.dart';
import '../widgets/quran_page_image_provider.dart';
import '../widgets/reader_compare_sheet.dart';
import '../widgets/reader_dashboard_sheet.dart';
import '../widgets/reader_insights_sheet.dart';
import '../widgets/reader_motion.dart';
import '../widgets/reader_page_strip_sheet.dart';
import '../widgets/bootstrap_splash.dart';
import 'quran_ai_studio_screen.dart';
import 'quran_asset_packs_screen.dart';
import 'quran_bookmarks_screen.dart';
import 'quran_growth_hub_screen.dart';
import 'quran_reader_screen.dart';
import 'quran_search_screen.dart';
import 'quran_settings_screen.dart';

class QuranHomeScreen extends StatelessWidget {
  const QuranHomeScreen({
    super.key,
    required this.controller,
  });

  final QuranReaderController controller;

  Future<void> _openReader(
    BuildContext context, {
    QuranReaderInitialAction action = QuranReaderInitialAction.none,
  }) {
    return Navigator.of(context).push(
      buildReaderPageRoute<void>(
        builder: (context) => QuranReaderScreen(
          controller: controller,
          initialAction: action,
        ),
      ),
    );
  }

  Future<void> _openSearchPage(
    BuildContext context, {
    required String title,
    required int initialTab,
  }) async {
    final page = await Navigator.of(context).push<int>(
      buildReaderPageRoute<int>(
        builder: (context) => QuranSearchScreen(
          title: title,
          initialTab: initialTab,
          nightMode: controller.settings.nightMode,
          showTabs: false,
          surahs: controller.surahEntries,
          juzs: controller.juzEntries,
          surahPageResolver: controller.navigationPageForSurahEntry,
          juzPageResolver: controller.navigationPageForJuzEntry,
          surahSearch: controller.searchSurahs,
          juzSearch: controller.searchJuzs,
        ),
      ),
    );
    if (page == null) {
      return;
    }
    await controller.jumpToPage(page);
    if (context.mounted) {
      await _openReader(context);
    }
  }

  Future<void> _openBookmarksPage(BuildContext context) async {
    final page = await Navigator.of(context).push<int>(
      buildReaderPageRoute<int>(
        builder: (context) => QuranBookmarksScreen(controller: controller),
      ),
    );
    if (page == null) {
      return;
    }
    await controller.jumpToPage(page);
    if (context.mounted) {
      await _openReader(context);
    }
  }

  Future<void> _openSettingsPage(BuildContext context) {
    return Navigator.of(context).push(
      buildReaderPageRoute<void>(
        builder: (context) => QuranSettingsScreen(controller: controller),
      ),
    );
  }

  Future<void> _openDashboardPage(BuildContext context) async {
    final page = await Navigator.of(context).push<int>(
      buildReaderPageRoute<int>(
        builder: (screenContext) => QuranDashboardScreen(
          controller: controller,
          onOpenGrowthHub: () => _openGrowthHubPage(screenContext),
          onOpenSearch: () => _openSearchPage(
            screenContext,
            title: tr(context, 'Search'),
            initialTab: 0,
          ),
          onOpenInsights: () => _openInsightsPage(screenContext),
          onOpenAudio: () => _openAudioPage(screenContext),
          onOpenAiStudio: () => _openAiStudioPage(screenContext),
          onOpenPageStrip: () => _openPageStripPage(screenContext),
          onOpenCompare: () => _openComparePage(screenContext),
          onOpenKanzulStudy: () => _openKanzulStudyPage(screenContext),
          onSelectPage: (pageNumber) async {
            Navigator.of(screenContext).pop(pageNumber);
          },
        ),
      ),
    );
    if (page == null) {
      return;
    }
    await controller.jumpToPage(page);
    if (context.mounted) {
      await _openReader(context);
    }
  }

  Future<void> _openInsightsPage(BuildContext context) async {
    final page = await Navigator.of(context).push<int>(
      buildReaderPageRoute<int>(
        builder: (context) => QuranInsightsScreen(controller: controller),
      ),
    );
    if (page == null) {
      return;
    }
    await controller.jumpToPage(page);
    if (context.mounted) {
      await _openReader(context);
    }
  }

  Future<void> _openAudioPage(BuildContext context) {
    return Navigator.of(context).push(
      buildReaderPageRoute<void>(
        builder: (context) => QuranAudioScreen(controller: controller),
      ),
    );
  }

  Future<void> _openPageStripPage(BuildContext context) async {
    final page = await Navigator.of(context).push<int>(
      buildReaderPageRoute<int>(
        builder: (context) => QuranPageStripScreen(controller: controller),
      ),
    );
    if (page == null) {
      return;
    }
    await controller.jumpToPage(page);
    if (context.mounted) {
      await _openReader(context);
    }
  }

  Future<void> _openComparePage(BuildContext context) {
    if (!controller.isCompareEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(context, 'Download at least one more Quran edition to compare pages.'),
          ),
        ),
      );
      return _openAssetPacksPage(context);
    }
    return Navigator.of(context).push(
      buildReaderPageRoute<void>(
        builder: (context) => QuranCompareScreen(controller: controller),
      ),
    );
  }

  Future<void> _openKanzulStudyPage(BuildContext context) {
    if (!controller.isKanzulStudyEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(context, 'Download the Kanzul Iman pack first to open Kanzul study mode.'),
          ),
        ),
      );
      return _openAssetPacksPage(context);
    }
    return Navigator.of(context).push(
      buildReaderPageRoute<void>(
        builder: (context) =>
            QuranKanzulImanStudyScreen(controller: controller),
      ),
    );
  }

  Future<void> _openAiStudioPage(BuildContext context, {QuranAiTool initialTool = QuranAiTool.explainer}) async {
    final page = await Navigator.of(context).push<int>(
      buildReaderPageRoute<int>(
        builder: (context) => QuranAiStudioScreen(controller: controller, initialTool: initialTool),
      ),
    );
    if (page == null) {
      return;
    }
    await controller.jumpToPage(page);
    if (context.mounted) {
      await _openReader(context);
    }
  }

  Future<void> _openPageJumpDialog(BuildContext context) async {
    final page = await showJumpToPageDialog(
      context,
      currentPage: controller.currentPageNumber,
      maxPage: controller.totalPages,
    );
    if (page == null) {
      return;
    }
    await controller.jumpToPage(page);
    if (context.mounted) {
      await _openReader(context);
    }
  }

  Future<void> _openGrowthHubPage(BuildContext context) async {
    final page = await Navigator.of(context).push<int>(
      buildReaderPageRoute<int>(
        builder: (context) => QuranGrowthHubScreen(
          controller: controller,
        ),
      ),
    );
    if (page == null) {
      return;
    }
    await controller.jumpToPage(page);
    if (context.mounted) {
      await _openReader(context);
    }
  }

  Future<void> _openAssetPacksPage(BuildContext context) {
    return Navigator.of(context).push(
      buildReaderPageRoute<void>(
        builder: (context) => QuranAssetPacksScreen(controller: controller),
      ),
    );
  }

  Future<void> _downloadFirstAvailablePack(BuildContext context) async {
    final candidates = controller.offlineEditionPacks
        .map((pack) => pack.edition)
        .where(
          (edition) =>
              controller.hasDownloadablePackForEdition(edition) &&
              !controller.isOfflinePackDownloaded(edition) &&
              !controller.isOfflinePackDownloading(edition) &&
              !controller.isBundledPackForEdition(edition),
        )
        .toList(growable: false);
    if (candidates.isEmpty) {
      await _openAssetPacksPage(context);
      return;
    }
    final edition = candidates.first;
    final activeDownload = controller.activeOfflineDownloadEdition;
    if (activeDownload != null && activeDownload != edition) {
      final shouldDownload = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text(tr(context, 'Download another edition?')),
                content: Text(
                  tr(context, '${activeDownload.label} is already downloading. '
                  'Do you want to start downloading ${edition.label} too?'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(tr(context, 'Cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(tr(context, 'Download')),
                  ),
                ],
              );
            },
          ) ??
          false;
      if (!shouldDownload || !context.mounted) {
        return;
      }
    }

    try {
      await controller.downloadOfflineEditionPack(edition);
      if (!context.mounted) {
        return;
      }
      if (!controller.isOfflinePackDownloaded(edition) ||
          controller.isOfflinePackPaused(edition) ||
          controller.isOfflinePackDownloading(edition)) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, '${edition.label} is ready offline.'))),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, _downloadErrorMessage(error)))),
      );
    }
  }

  String _downloadErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('paused')) return 'Download paused. Saved data is kept for resume.';
    if (message.contains('wi-fi-only')) return 'Wi-Fi-only downloads are enabled. Connect to Wi-Fi to continue.';
    if (message.contains('cancelled') ||
        message.contains('canceled') ||
        message.contains('request cancelled') ||
        message.contains('request canceled') ||
        message.contains('manually cancelled') ||
        message.contains('manually canceled') ||
        message.contains('dioexceptiontype.cancel')) {
      return 'Download cancelled.';
    }
    if (message.contains('connection error') ||
        message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('could not resolve host') ||
        message.contains('network is unreachable') ||
        message.contains('connection refused') ||
        message.contains('connection timed out')) {
      return 'Please connect to Wi-Fi and try again.';
    }
    return 'Download failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        controller.pageListenable,
        controller.settingsListenable,
        controller.contentListenable,
        controller.experienceListenable,
        controller.loadingListenable,
      ]),
      builder: (context, _) {
        final settings = controller.settings;
        final experience = controller.experienceSettings;
        final chapterLabel =
            controller.currentChapterSummary?.nameSimple ?? 'The Holy Quran';
        final pageLabel = tr(context, 'Page ${controller.currentPageNumber}');
        final editionLabel = tr(context, settings.mushafEdition.label);
        final themeData = settings.nightMode
            ? AppTheme.dark(
                highContrast: experience.highContrastMode,
                largerText: experience.largerTextMode,
              )
            : AppTheme.light(
                highContrast: experience.highContrastMode,
                largerText: experience.largerTextMode,
              );
        return Theme(
          data: themeData,
          child: Builder(
            builder: (context) {
              if (controller.isLoading) {
                return BootstrapSplash(nightMode: settings.nightMode);
              }
              final theme = Theme.of(context);
              final desktop = MediaQuery.sizeOf(context).width >= 1100;
              void selectDestination(int index) {
                switch (index) {
                  case 1:
                    _openReader(context);
                    break;
                  case 2:
                    _openBookmarksPage(context);
                    break;
                  case 3:
                    _openSettingsPage(context);
                    break;
                }
              }

              final actions = <_HomeMenuTile>[
                _HomeMenuTile(
                  icon: Icons.dashboard_outlined,
                  title: tr(context, 'Dashboard'),
                  subtitle: tr(context, 'Your reading at a glance'),
                  onTap: () => _openDashboardPage(context),
                ),
                _HomeMenuTile(
                  icon: Icons.bookmark_border_rounded,
                  title: tr(context, 'Bookmarks'),
                  subtitle: tr(context, 'Return to a meaningful place'),
                  onTap: () => _openBookmarksPage(context),
                ),
                _HomeMenuTile(
                  icon: Icons.pin_outlined,
                  title: tr(context, 'Go to page'),
                  subtitle: tr(context, 'Pick up exactly where you want'),
                  onTap: () => _openPageJumpDialog(context),
                ),
                if (controller.isAudioEnabled)
                  _HomeMenuTile(
                    icon: Icons.headphones_outlined,
                    title: tr(context, 'Recitation'),
                    subtitle: tr(context, 'Listen with your favourite qari'),
                    onTap: () => _openAudioPage(context),
                  ),
                if (controller.isPlansPacksEnabled) ...[
                  _HomeMenuTile(
                    icon: Icons.event_note_outlined,
                    title: tr(context, 'Plans & Hifz'),
                    subtitle: tr(context, 'Build a steady reading habit'),
                    onTap: () => _openGrowthHubPage(context),
                  ),
                  _HomeMenuTile(
                    icon: Icons.download_outlined,
                    title: tr(context, 'Asset Packs'),
                    subtitle: tr(context, 'Keep your Mushaf within reach'),
                    onTap: () => _openAssetPacksPage(context),
                  ),
                ],
                if (controller.isInsightsEnabled)
                  _HomeMenuTile(
                    icon: Icons.auto_stories_outlined,
                    title: tr(context, 'Insights'),
                    subtitle: tr(context, 'Translation, notes and reflection'),
                    onTap: () => _openInsightsPage(context),
                  ),
                if (controller.isAiStudioEnabled)
                  _HomeMenuTile(
                    icon: Icons.auto_awesome_outlined,
                    title: tr(context, 'AI Studio'),
                    subtitle: tr(context, 'Explore your study questions'),
                    onTap: () => _openAiStudioPage(context),
                  ),
                if (controller.isPageStripEnabled)
                  _HomeMenuTile(
                    icon: Icons.grid_view_outlined,
                    title: tr(context, 'Page Thumbnails'),
                    subtitle: tr(context, 'Find your place visually'),
                    onTap: () => _openPageStripPage(context),
                  ),
                if (controller.isCompareEnabled)
                  _HomeMenuTile(
                    icon: Icons.compare_outlined,
                    title: tr(context, 'Compare Editions'),
                    subtitle: tr(context, 'Study Mushaf pages side by side'),
                    onTap: () => _openComparePage(context),
                  ),
                if (controller.isKanzulStudyEnabled)
                  _HomeMenuTile(
                    icon: Icons.translate_rounded,
                    title: tr(context, 'Kanzul Iman Study'),
                    subtitle: tr(context, 'Read with a deeper understanding'),
                    onTap: () => _openKanzulStudyPage(context),
                  ),
                _HomeMenuTile(
                  icon: Icons.tune_rounded,
                  title: tr(context, 'Settings'),
                  subtitle: tr(context, 'Make your reading space your own'),
                  onTap: () => _openSettingsPage(context),
                ),
              ];

              return Scaffold(
                backgroundColor: theme.scaffoldBackgroundColor,
                bottomNavigationBar: desktop
                    ? null
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: theme.dividerColor),
                          ),
                        ),
                        child: NavigationBar(
                          selectedIndex: 0,
                          onDestinationSelected: selectDestination,
                          destinations: [
                            NavigationDestination(
                              icon: Icon(Icons.home_outlined),
                              selectedIcon: Icon(Icons.home_rounded),
                              label: tr(context, 'Home'),
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.menu_book_outlined),
                              label: tr(context, 'Read'),
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.bookmark_border_rounded),
                              label: tr(context, 'Saved'),
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.tune_rounded),
                              label: tr(context, 'Settings'),
                            ),
                          ],
                        ),
                      ),
                body: SafeArea(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (desktop)
                        _HomeNavigation(onSelected: selectDestination),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            desktop ? 40 : 20,
                            desktop ? 28 : 20,
                            desktop ? 40 : 20,
                            32,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1120),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final wide = constraints.maxWidth >= 820;
                                  final hero = _HomeTopCard(
                                    title: chapterLabel,
                                    subtitle: tr(context, '$editionLabel · $pageLabel'),
                                    page: controller.currentPage,
                                    compact: !wide,
                                    onResume: () => _openReader(context),
                                  );
                                  final rhythm = _DailyFocusCard(
                                    pages: controller.dailyTargetPages,
                                    completedPages:
                                        controller.dailyProgressPages,
                                    streakDays: controller.readingStreakCount,
                                    compact: !wide,
                                    onTap: () => _openDashboardPage(context),
                                  );
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Icon(
                                              Icons.menu_book_rounded,
                                              color:
                                                  theme.colorScheme.onPrimary,
                                              size: 23,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  tr(context, controller.homeHeroTitle),
                                                  maxLines: 2,
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  tr(context, 'READ · REFLECT · RETURN'),
                                                  style: theme
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .secondary,
                                                        letterSpacing: 1.4,
                                                        fontSize: 10,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          IconButton.outlined(
                                            tooltip: tr(context, 'Reading settings'),
                                            onPressed: () =>
                                                _openSettingsPage(context),
                                            icon: const Icon(
                                              Icons.tune_rounded,
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: desktop ? 30 : 24),
                                      Text(
                                        tr(context, 'Assalamu Alaikum'),
                                        style: theme.textTheme.headlineMedium,
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        tr(context, controller.homeHeroSubtitle(
                                          chapterLabel: chapterLabel,
                                          pageLabel: pageLabel,
                                          editionLabel: editionLabel,
                                        )),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                      const SizedBox(height: 22),
                                      if (wide)
                                        IntrinsicHeight(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Expanded(flex: 7, child: hero),
                                              const SizedBox(width: 18),
                                              Expanded(flex: 4, child: rhythm),
                                            ],
                                          ),
                                        )
                                      else
                                        hero,
                                      const SizedBox(height: 18),
                                      _EditionSelectorCard(
                                        editions:
                                            controller.availableImageEditions,
                                        selectedEdition: settings.mushafEdition,
                                        isEditionReady:
                                            controller.isMushafEditionReady,
                                        isEditionDownloading:
                                            controller.isOfflinePackDownloading,
                                        downloadProgressForEdition: controller
                                            .offlinePackProgressForEdition,
                                        onSelectEdition:
                                            controller.selectMushafEdition,
                                        onDownloadEdition: (edition) =>
                                            _openAssetPacksPage(context),
                                        nightMode: settings.nightMode,
                                        onToggleNightMode:
                                            controller.toggleNightMode,
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _QuickAction(
                                              icon: Icons.menu_book_outlined,
                                              label: 'Surah',
                                              onTap: () => _openSearchPage(
                                                context,
                                                title: tr(context, 'Surah Index'),
                                                initialTab: 0,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _QuickAction(
                                              icon: Icons.layers_outlined,
                                              label: 'Juz',
                                              onTap: () => _openSearchPage(
                                                context,
                                                title: tr(context, 'Juz Index'),
                                                initialTab: 1,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _QuickAction(
                                              icon: Icons.search_rounded,
                                              label: 'Search',
                                              onTap: () =>
                                                  controller.isAiStudioEnabled
                                                  ? _openAiStudioPage(
                                                      context,
                                                      initialTool: QuranAiTool
                                                          .smartSearch,
                                                    )
                                                  : _openSearchPage(
                                                      context,
                                                      title: tr(context, 'Search'),
                                                      initialTab: 0,
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (!wide) ...[
                                        const SizedBox(height: 18),
                                        rhythm,
                                      ],
                                      Builder(
                                        builder: (context) {
                                          final announcements = controller
                                              .adminAnnouncements
                                              .where((item) => item.active)
                                              .toList(growable: false);
                                          return announcements.isEmpty
                                              ? const SizedBox.shrink()
                                              : Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 20,
                                                      ),
                                                  child: _AnnouncementsCard(
                                                    announcements:
                                                        announcements,
                                                  ),
                                                );
                                        },
                                      ),
                                      const SizedBox(height: 30),
                                      _SectionTitle(
                                        title: tr(context, 'Your reading companions'),
                                        subtitle:
                                            tr(context, 'Save a place. Listen. Study a little deeper.'),
                                        horizontalInset: 0,
                                      ),
                                      const SizedBox(height: 16),
                                      Builder(
                                        builder: (context) {
                                          final count =
                                              constraints.maxWidth >= 900
                                              ? 3
                                              : constraints.maxWidth >= 340
                                              ? 2
                                              : 1;
                                          final cardWidth =
                                              (constraints.maxWidth -
                                                  12 * (count - 1)) /
                                              count;
                                          final scale = MediaQuery.textScalerOf(
                                            context,
                                          ).scale(1).clamp(1.0, 2.5);
                                          return GridView.count(
                                            crossAxisCount: count,
                                            mainAxisSpacing: 12,
                                            crossAxisSpacing: 12,
                                            mainAxisExtent:
                                                (cardWidth >= 250 ? 116 : 170) *
                                                scale,
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            children: actions,
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 24),
                                      _OfflinePacksCard(
                                        bundledEdition: MushafEdition.lines16,
                                        downloadableCount:
                                            controller.downloadableZipPackCount,
                                        downloadedCount:
                                            controller.downloadedZipPackCount,
                                        activeDownloadEdition: controller
                                            .activeOfflineDownloadEdition,
                                        activeDownloadProgress:
                                            controller
                                                    .activeOfflineDownloadEdition ==
                                                null
                                            ? 0
                                            : controller
                                                  .offlinePackProgressForEdition(
                                                    controller
                                                        .activeOfflineDownloadEdition!,
                                                  ),
                                        onOpenPacks: () =>
                                            _openAssetPacksPage(context),
                                        onDownloadNext: () =>
                                            _downloadFirstAvailablePack(
                                              context,
                                            ),
                                        onCancelActiveDownload: controller
                                            .cancelAllOfflinePackDownloads,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _HomeNavigation extends StatelessWidget {
  const _HomeNavigation({required this.onSelected});
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const ivory = Color(0xFFF3EDDB);
    const gold = Color(0xFFD8BD82);
    return Container(
      width: 216,
      color: const Color(0xFF163F35),
      padding: const EdgeInsets.fromLTRB(18, 30, 18, 24),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 35),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: gold.withValues(alpha: 0.55),
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: gold,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          tr(context, 'Quran Reader'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: ivory,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          tr(context, 'YOUR PERSONAL MUSHAF'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: gold,
                            letterSpacing: 1.1,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 14, bottom: 14),
                    child: Text(
                      tr(context, 'LIBRARY'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.4,
                        color: gold.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  for (final item in const [
                    (Icons.home_outlined, 'Home'),
                    (Icons.menu_book_outlined, 'Read Quran'),
                    (Icons.bookmark_border_rounded, 'Saved places'),
                    (Icons.tune_rounded, 'Settings'),
                  ].indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: item.$1 == 0
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          leading: Icon(
                            item.$2.$1,
                            color: item.$1 == 0
                                ? gold
                                : ivory.withValues(alpha: 0.7),
                            size: 22,
                          ),
                          title: Text(
                            tr(context, item.$2.$2),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: ivory,
                              fontWeight: item.$1 == 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          onTap: () => onSelected(item.$1),
                        ),
                      ),
                    ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 40, 12, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 30, height: 1, color: gold),
                        const SizedBox(height: 18),
                        Text(
                          tr(context, 'A little, every day.'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: ivory,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr(context, 'A quiet moment.\nA lasting connection.'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: ivory.withValues(alpha: 0.7),
                            height: 1.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTopCard extends StatelessWidget {
  const _HomeTopCard({
    required this.title,
    required this.subtitle,
    required this.page,
    required this.compact,
    required this.onResume,
  });
  final String title;
  final String subtitle;
  final QuranPage page;
  final bool compact;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const cream = Color(0xFFF7F0DD);
    const gold = Color(0xFFE5C88D);
    final button = FilledButton.icon(
      onPressed: onResume,
      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
      iconAlignment: IconAlignment.end,
      style: FilledButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: const Color(0xFF173C30),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      label: Text(tr(context, 'Resume Reading')),
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF163F35),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: gold.withValues(alpha: 0.2)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _MushafMotif())),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 20 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.bookmark_outline_rounded,
                                size: 16,
                                color: gold,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  tr(context, 'Continue your reading'),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: gold,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: compact ? 16 : 22),
                          Text(
                            tr(context, title),
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: cream,
                              fontSize:
                                  (theme.textTheme.headlineLarge?.fontSize ??
                                      34) *
                                  (compact ? 0.89 : 1.06),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            tr(context, subtitle),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cream.withValues(alpha: 0.78),
                            ),
                          ),
                          if (!compact) ...[const SizedBox(height: 23), button],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Semantics(
                      label: tr(context, 'Preview of your original Mushaf page'),
                      image: true,
                      child: Container(
                        width: compact ? 88 : 132,
                        height: compact ? 132 : 196,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: cream,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: gold, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: page.assetPath == null
                            ? const Icon(
                                Icons.menu_book_outlined,
                                color: Color(0xFF163F35),
                                size: 36,
                              )
                            : Image(
                                image: buildQuranPageImageProvider(
                                  page,
                                  cacheWidth: 320,
                                ),
                                fit: BoxFit.contain,
                                excludeFromSemantics: true,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.menu_book_outlined,
                                  color: Color(0xFF163F35),
                                  size: 36,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                if (compact) ...[
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: button),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MushafMotif extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE5C88D).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final inset = i * 15.0;
      final path = Path()
        ..moveTo(size.width * 0.55 + inset, size.height + 4)
        ..lineTo(size.width * 0.55 + inset, size.height * 0.5)
        ..quadraticBezierTo(
          size.width * 0.55 + inset,
          35,
          size.width * 0.79,
          10 + inset,
        )
        ..quadraticBezierTo(
          size.width - inset,
          35,
          size.width - inset,
          size.height * 0.5,
        )
        ..lineTo(size.width - inset, size.height + 4);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MushafMotif oldDelegate) => false;
}

class _DailyFocusCard extends StatelessWidget {
  const _DailyFocusCard({
    required this.pages,
    required this.completedPages,
    required this.streakDays,
    required this.compact,
    required this.onTap,
  });
  final int pages;
  final int completedPages;
  final int streakDays;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = pages <= 0
        ? 0.0
        : (completedPages / pages).clamp(0.0, 1.0);
    return _MenuCard(
      child: Padding(
        padding: EdgeInsets.all(compact ? 18 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wb_sunny_outlined,
                  color: theme.colorScheme.secondary,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr(context, "Today's rhythm"),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: tr(context, 'View reading dashboard'),
                  onPressed: onTap,
                  icon: const Icon(Icons.north_east_rounded, size: 17),
                ),
              ],
            ),
            SizedBox(height: compact ? 6 : 12),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: tr(context, '$completedPages'),
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontSize:
                          (theme.textTheme.headlineLarge?.fontSize ?? 34) *
                          (compact ? 0.8 : 1.06),
                    ),
                  ),
                  TextSpan(
                    text: tr(context, ' / $pages pages'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.primaryContainer,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  Icons.local_fire_department_outlined,
                  color: theme.colorScheme.secondary,
                  size: 17,
                ),
                Text(
                  tr(context, '$streakDays ${tr(context, streakDays == 1 ? 'day' : 'days')} of consistency'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: 14),
              Text(
                tr(context, 'Small steps make a beautiful habit.'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    this.horizontalInset = 0,
  });

  final String title;
  final String subtitle;
  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, title),
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(context, subtitle),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditionSelectorCard extends StatelessWidget {
  const _EditionSelectorCard({
    required this.editions,
    required this.selectedEdition,
    required this.isEditionReady,
    required this.isEditionDownloading,
    required this.downloadProgressForEdition,
    required this.onSelectEdition,
    required this.onDownloadEdition,
    required this.nightMode,
    required this.onToggleNightMode,
  });
  final List<MushafEdition> editions;
  final MushafEdition selectedEdition;
  final bool Function(MushafEdition edition) isEditionReady;
  final bool Function(MushafEdition edition) isEditionDownloading;
  final double Function(MushafEdition edition) downloadProgressForEdition;
  final Future<void> Function(MushafEdition edition) onSelectEdition;
  final Future<void> Function(MushafEdition edition) onDownloadEdition;
  final bool nightMode;
  final Future<void> Function(bool enabled) onToggleNightMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _MenuCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  color: theme.colorScheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    tr(context, 'Choose your Mushaf'),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: tr(context, nightMode
                      ? 'Use light app theme'
                      : 'Use dark app theme'),
                  onPressed: () => onToggleNightMode(!nightMode),
                  icon: Icon(
                    nightMode
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: editions
                  .map((edition) {
                    final selected = edition == selectedEdition;
                    final ready = isEditionReady(edition);
                    final downloading = isEditionDownloading(edition);
                    final progress = (downloadProgressForEdition(edition) * 100)
                        .round();
                    return ChoiceChip(
                      showCheckmark: false,
                      selected: selected,
                      avatar: Icon(
                        selected
                            ? Icons.check_circle_outline_rounded
                            : ready
                            ? Icons.menu_book_outlined
                            : Icons.download_outlined,
                        size: 16,
                        color: selected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.primary,
                      ),
                      label: Text(
                        tr(context, downloading
                            ? '${edition.label} $progress%'
                            : edition.label),
                      ),
                      labelStyle: theme.textTheme.labelMedium?.copyWith(
                        color: selected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                      selectedColor: theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme.surface,
                      side: BorderSide(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.dividerColor,
                      ),
                      onSelected: (_) => ready
                          ? onSelectEdition(edition)
                          : onDownloadEdition(edition),
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflinePacksCard extends StatelessWidget {
  const _OfflinePacksCard({
    required this.bundledEdition,
    required this.downloadableCount,
    required this.downloadedCount,
    required this.activeDownloadEdition,
    required this.activeDownloadProgress,
    required this.onOpenPacks,
    required this.onDownloadNext,
    required this.onCancelActiveDownload,
  });

  final MushafEdition bundledEdition;
  final int downloadableCount;
  final int downloadedCount;
  final MushafEdition? activeDownloadEdition;
  final double activeDownloadProgress;
  final VoidCallback onOpenPacks;
  final VoidCallback onDownloadNext;
  final VoidCallback onCancelActiveDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDownloading = activeDownloadEdition != null;
    final progressPercent = (activeDownloadProgress * 100).round();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.96 : 0.9,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.16 : 0.06,
            ),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.download_for_offline_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context, 'Offline Quran packs'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tr(context, '${tr(context, bundledEdition.label)} is ready offline. $downloadableCount more pack(s) can be downloaded.'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isDownloading) ...[
              Text(
                tr(context, 'Downloading ${activeDownloadEdition!.label} ($progressPercent%)'),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value:
                    activeDownloadProgress <= 0 || activeDownloadProgress >= 1
                        ? null
                        : activeDownloadProgress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: 12),
            ] else
              Text(
                tr(context, downloadedCount == 0
                    ? 'Download extra editions once, then read them without internet.'
                    : '$downloadedCount downloaded edition(s) are stored on this device.'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: downloadableCount == 0 ? null : onDownloadNext,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(tr(context, 'Download next')),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenPacks,
                  icon: const Icon(Icons.list_alt_rounded),
                  label: Text(tr(context, 'Manage packs')),
                ),
                if (isDownloading)
                  OutlinedButton.icon(
                    onPressed: onCancelActiveDownload,
                    icon: const Icon(Icons.close_rounded),
                    label: Text(tr(context, 'Cancel all')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: child,
    );
  }
}

class _HomeMenuTile extends StatelessWidget {
  const _HomeMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final badge = Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.65,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 22),
              );
              final copy = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, title),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    tr(context, subtitle),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
              if (constraints.maxWidth >= 218) {
                return Row(
                  children: [
                    badge,
                    const SizedBox(width: 13),
                    Expanded(child: copy),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: theme.colorScheme.secondary,
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  badge,
                  const SizedBox(height: 13),
                  Expanded(child: copy),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AnnouncementsCard extends StatelessWidget {
  const _AnnouncementsCard({
    required this.announcements,
  });

  final List<ReaderAdminAnnouncement> announcements;

  String _formatDate(String isoValue) {
    final parsed = DateTime.tryParse(isoValue);
    if (parsed == null) {
      return '';
    }
    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, 'Announcements'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...announcements.map((announcement) {
            final dateLabel = _formatDate(announcement.publishAtIso);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(context, announcement.title),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (dateLabel.isNotEmpty)
                        Text(
                          tr(context, dateLabel),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  if (announcement.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      tr(context, announcement.body),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = switch (label) {
      'Surah' => '114 chapters',
      'Juz' => '30 sections',
      _ => 'Find an ayah',
    };
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.secondary, size: 24),
              const SizedBox(height: 9),
              Text(tr(context, label), style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(
                tr(context, caption),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
