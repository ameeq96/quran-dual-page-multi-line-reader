import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';
import '../../../../app/prayer_translations.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/services/reader_web_surah_navigation.dart';
import '../../domain/models/reader_admin_config.dart';
import '../../domain/models/quran_ai_models.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import '../widgets/kanzul_iman_study_sheet.dart';
import '../widgets/jump_to_page_dialog.dart';
import '../widgets/reader_audio_sheet.dart';
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
import 'quran_study_screen.dart';
import 'prayer_settings_screen.dart';
import 'worship_hub_screen.dart';
import '../widgets/app_motion.dart';
import '../widgets/home/home_hero_card.dart';
import '../widgets/home/home_sections.dart';

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
        settings: readerWebSurahRouteSettings,
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

  Future<void> _openPrayerSettings(BuildContext context) {
    return Navigator.of(context).push(
      buildReaderPageRoute<void>(
        builder: (context) => PrayerSettingsScreen(baseUrl: controller.adminSyncBaseUrl),
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

              final actions = <HomeMenuTile>[
                HomeMenuTile(
                  icon: Icons.dashboard_outlined,
                  title: tr(context, 'Dashboard'),
                  subtitle: tr(context, 'Your reading at a glance'),
                  onTap: () => _openDashboardPage(context),
                ),
                HomeMenuTile(
                  icon: Icons.bookmark_border_rounded,
                  title: tr(context, 'Bookmarks'),
                  subtitle: tr(context, 'Return to a meaningful place'),
                  onTap: () => _openBookmarksPage(context),
                ),
                HomeMenuTile(
                  icon: Icons.pin_outlined,
                  title: tr(context, 'Go to page'),
                  subtitle: tr(context, 'Pick up exactly where you want'),
                  onTap: () => _openPageJumpDialog(context),
                ),
                if (controller.isAudioEnabled)
                  HomeMenuTile(
                    icon: Icons.headphones_outlined,
                    title: tr(context, 'Recitation'),
                    subtitle: tr(context, 'Listen with your favourite qari'),
                    onTap: () => _openAudioPage(context),
                  ),
                HomeMenuTile(
                  icon: Icons.mosque_outlined,
                  title: prayerText(context, 'Namaz & Azan'),
                  subtitle: prayerText(context, 'Prayer times and Azan reminders'),
                  onTap: () => _openPrayerSettings(context),
                ),
                HomeMenuTile(
                  icon: Icons.explore_outlined,
                  title: switch (ReaderLocalization.instance.language) {
                    ReaderLanguage.urdu => 'عبادت کے ساتھی',
                    ReaderLanguage.arabic => 'رفقاء العبادة',
                    _ => 'Worship companions',
                  },
                  subtitle: switch (ReaderLocalization.instance.language) {
                    ReaderLanguage.urdu => 'قضا، رمضان اور سیکھنے کے اسباق',
                    ReaderLanguage.arabic => 'القضاء ورمضان والدروس',
                    _ => 'Qaza, Ramadan and learning',
                  },
                  onTap: () => Navigator.of(context).push<void>(buildReaderPageRoute<void>(
                    builder: (_) => WorshipHubScreen(controller: controller),
                  )),
                ),
                if (controller.isPlansPacksEnabled) ...[
                  HomeMenuTile(
                    icon: Icons.event_note_outlined,
                    title: tr(context, 'Plans & Hifz'),
                    subtitle: tr(context, 'Build a steady reading habit'),
                    onTap: () => _openGrowthHubPage(context),
                  ),
                  HomeMenuTile(
                    icon: Icons.download_outlined,
                    title: tr(context, 'Asset Packs'),
                    subtitle: tr(context, 'Keep your Mushaf within reach'),
                    onTap: () => _openAssetPacksPage(context),
                  ),
                ],
                if (controller.isInsightsEnabled)
                  HomeMenuTile(
                    icon: Icons.auto_stories_outlined,
                    title: tr(context, 'Insights'),
                    subtitle: tr(context, 'Translation, notes and reflection'),
                    onTap: () => _openInsightsPage(context),
                  ),
                if (controller.isAiStudioEnabled)
                  HomeMenuTile(
                    icon: Icons.auto_awesome_outlined,
                    title: tr(context, 'AI Studio'),
                    subtitle: tr(context, 'Explore your study questions'),
                    onTap: () => _openAiStudioPage(context),
                  ),
                if (controller.isPageStripEnabled)
                  HomeMenuTile(
                    icon: Icons.grid_view_outlined,
                    title: tr(context, 'Page Thumbnails'),
                    subtitle: tr(context, 'Find your place visually'),
                    onTap: () => _openPageStripPage(context),
                  ),
                if (controller.isCompareEnabled)
                  HomeMenuTile(
                    icon: Icons.compare_outlined,
                    title: tr(context, 'Compare Editions'),
                    subtitle: tr(context, 'Study Mushaf pages side by side'),
                    onTap: () => _openComparePage(context),
                  ),
                if (controller.isKanzulStudyEnabled)
                  HomeMenuTile(
                    icon: Icons.translate_rounded,
                    title: tr(context, 'Kanzul Iman Study'),
                    subtitle: tr(context, 'Read with a deeper understanding'),
                    onTap: () => _openKanzulStudyPage(context),
                  ),
                HomeMenuTile(
                  icon: Icons.menu_book_outlined,
                  title: tr(context, 'Word study & collections'),
                  subtitle: tr(context, 'Translation, notes and reflection'),
                  onTap: () => Navigator.of(context).push(buildReaderPageRoute<void>(builder: (_) => QuranStudyScreen(controller: controller))),
                ),
                HomeMenuTile(
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
                    : SafeArea(
                        top: false,
                        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppRadii.xl),
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.8),
                          ),
                          boxShadow: AppDecor.of(context).floatShadow,
                        ),
                        child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                        child: NavigationBar(
                          backgroundColor: Colors.transparent,
                          height: 68,
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
                        ),
                      ),
                extendBody: true,
                body: Stack(
                  children: [
                    const Positioned.fill(
                      child: IgnorePointer(child: _HomeAura()),
                    ),
                    SafeArea(
                  bottom: false,
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
                            desktop ? 32 : 124,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1120),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final wide = constraints.maxWidth >= 820;
                                  final totalPages = controller.totalPages;
                                  final hero = AppStagger(
                                    index: 0,
                                    child: HomeHeroCard(
                                      progress: totalPages <= 0
                                          ? 0
                                          : (controller.currentPageNumber /
                                                    totalPages)
                                                .clamp(0.0, 1.0),
                                      title: chapterLabel,
                                      subtitle: tr(context, '$editionLabel · $pageLabel'),
                                      page: controller.currentPage,
                                      compact: !wide,
                                      currentPage: controller.currentPageNumber,
                                      totalPages: totalPages,
                                      onResume: () => _openReader(context),
                                    ),
                                  );
                                  final rhythm = AppStagger(
                                    index: 2,
                                    child: HomeDailyFocusCard(
                                      pages: controller.dailyTargetPages,
                                      completedPages:
                                          controller.dailyProgressPages,
                                      streakDays: controller.readingStreakCount,
                                      compact: !wide,
                                      onTap: () => _openDashboardPage(context),
                                    ),
                                  );
                                  final quickActions = AppStagger(
                                    index: 1,
                                    child: IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: HomeQuickAction(
                                              icon: Icons.menu_book_outlined,
                                              label: 'Surah',
                                              onTap: () => _openSearchPage(
                                                context,
                                                title: tr(context, 'Surah Index'),
                                                initialTab: 0,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: HomeQuickAction(
                                              icon: Icons.layers_outlined,
                                              label: 'Juz',
                                              onTap: () => _openSearchPage(
                                                context,
                                                title: tr(context, 'Juz Index'),
                                                initialTab: 1,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: HomeQuickAction(
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
                                    ),
                                  );
                                  final editionSelector = AppStagger(
                                    index: 3,
                                    child: HomeEditionSelector(
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
                                  );
                                  final announcements = controller
                                      .adminAnnouncements
                                      .where((item) => item.active)
                                      .toList(growable: false);

                                  // Feature tiles: the first four lead as
                                  // illustrated cards, the rest follow as a
                                  // calmer grid. Order is unchanged.
                                  final textScale = MediaQuery.textScalerOf(
                                    context,
                                  ).scale(1);
                                  final roomy = constraints.maxWidth >= 900;
                                  final single =
                                      constraints.maxWidth < 320 ||
                                      (textScale > 1.3 &&
                                          constraints.maxWidth < 420);
                                  final columns = roomy
                                      ? 3
                                      : single
                                      ? 1
                                      : 2;
                                  final featuredColumns = roomy
                                      ? 4
                                      : single
                                      ? 1
                                      : 2;
                                  final tileWidth =
                                      (constraints.maxWidth -
                                          12 * (columns - 1)) /
                                      columns;
                                  final featuredCount = actions.length < 4
                                      ? actions.length
                                      : 4;
                                  // A tile left alone on the last row takes
                                  // the full width, so it lays out sideways.
                                  final loneLast =
                                      (actions.length - featuredCount) %
                                          columns ==
                                      1;
                                  Widget tile(int index, {required bool featured}) {
                                    final action = actions[index];
                                    return AppStagger(
                                      index: 4 + index,
                                      child: HomeMenuTile(
                                        icon: action.icon,
                                        title: action.title,
                                        subtitle: action.subtitle,
                                        onTap: action.onTap,
                                        accentIndex: index,
                                        featured: featured,
                                        horizontal: featured
                                            ? roomy
                                            : tileWidth >= 250 ||
                                                  (loneLast &&
                                                      index ==
                                                          actions.length - 1),
                                      ),
                                    );
                                  }

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          const HomeLogoBadge(),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  tr(context, controller.homeHeroTitle),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        height: 1.2,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  tr(context, 'READ · REFLECT · RETURN'),
                                                  style: theme
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .secondary,
                                                        letterSpacing: 1.6,
                                                        fontSize: 10,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.surface,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: theme.dividerColor
                                                    .withValues(alpha: 0.8),
                                              ),
                                              boxShadow: AppDecor.of(
                                                context,
                                              ).cardShadow,
                                            ),
                                            child: IconButton(
                                              tooltip: tr(context, 'Reading settings'),
                                              onPressed: () =>
                                                  _openSettingsPage(context),
                                              style: IconButton.styleFrom(
                                                shape: const CircleBorder(),
                                              ),
                                              icon: const Icon(
                                                Icons.tune_rounded,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: desktop ? 32 : 24),
                                      Text(
                                        tr(context, 'Assalamu Alaikum'),
                                        textScaler: MediaQuery.textScalerOf(
                                          context,
                                        ).clamp(maxScaleFactor: 1.3),
                                        style: theme.textTheme.headlineMedium
                                            ?.copyWith(
                                              color:
                                                  theme.colorScheme.onSurface,
                                              fontSize:
                                                  (theme
                                                          .textTheme
                                                          .headlineMedium
                                                          ?.fontSize ??
                                                      28) *
                                                  (wide ? 1.2 : 1.08),
                                            ),
                                      ),
                                      const SizedBox(height: 4),
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
                                      const SizedBox(height: 16),
                                      const HomeOrnamentDivider(),
                                      const SizedBox(height: 20),
                                      if (wide)
                                        IntrinsicHeight(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Expanded(flex: 7, child: hero),
                                              const SizedBox(width: 16),
                                              Expanded(flex: 4, child: rhythm),
                                            ],
                                          ),
                                        )
                                      else
                                        hero,
                                      const SizedBox(height: 20),
                                      quickActions,
                                      if (!wide) ...[
                                        const SizedBox(height: 16),
                                        rhythm,
                                      ],
                                      const SizedBox(height: 16),
                                      editionSelector,
                                      if (announcements.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        _AnnouncementsCard(
                                          announcements: announcements,
                                        ),
                                      ],
                                      const SizedBox(height: 32),
                                      HomeSectionTitle(
                                        title: tr(context, 'Your reading companions'),
                                        subtitle:
                                            tr(context, 'Save a place. Listen. Study a little deeper.'),
                                      ),
                                      const SizedBox(height: 16),
                                      HomeTileGrid(
                                        columns: featuredColumns,
                                        children: [
                                          for (
                                            var index = 0;
                                            index < featuredCount;
                                            index++
                                          )
                                            tile(index, featured: true),
                                        ],
                                      ),
                                      if (actions.length > featuredCount) ...[
                                        const SizedBox(height: 12),
                                        HomeTileGrid(
                                          columns: columns,
                                          children: [
                                            for (
                                              var index = featuredCount;
                                              index < actions.length;
                                              index++
                                            )
                                              tile(index, featured: false),
                                          ],
                                        ),
                                      ],
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
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Soft emerald and gold light behind the top of the home screen.
class _HomeAura extends StatelessWidget {
  const _HomeAura();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final decor = AppDecor.of(context);
    Widget glow(Color color, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
    return Stack(
      children: [
        PositionedDirectional(
          top: -170,
          start: -130,
          child: glow(
            theme.colorScheme.primary.withValues(alpha: dark ? 0.22 : 0.13),
            460,
          ),
        ),
        PositionedDirectional(
          top: -120,
          end: -150,
          child: glow(decor.gold.withValues(alpha: dark ? 0.12 : 0.26), 400),
        ),
      ],
    );
  }
}

class _HomeNavigation extends StatelessWidget {
  const _HomeNavigation({required this.onSelected});
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = AppDecor.of(context);
    final ivory = decor.onHero;
    final gold = decor.gold;
    return Container(
      width: 232,
      decoration: BoxDecoration(gradient: decor.heroGradient),
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
                          child: Icon(
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
                    padding: const EdgeInsetsDirectional.only(
                      start: 14,
                      bottom: 14,
                    ),
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
                            ? ivory.withValues(alpha: 0.14)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadii.md),
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
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.7),
        ),
        boxShadow: AppDecor.of(context).cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
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
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
        boxShadow: AppDecor.of(context).cardShadow,
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
