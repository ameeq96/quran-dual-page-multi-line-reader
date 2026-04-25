import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/reader_admin_config.dart';
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
            title: 'Search',
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
        const SnackBar(
          content: Text(
            'Download at least one more Quran edition to compare pages.',
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
        const SnackBar(
          content: Text(
            'Download the Kanzul Iman pack first to open Kanzul study mode.',
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

  Future<void> _openAiStudioPage(BuildContext context) async {
    final page = await Navigator.of(context).push<int>(
      buildReaderPageRoute<int>(
        builder: (context) => QuranAiStudioScreen(controller: controller),
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
              controller.hasZipPackForEdition(edition) &&
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
                title: const Text('Download another edition?'),
                content: Text(
                  '${activeDownload.label} is already downloading. '
                  'Do you want to start downloading ${edition.label} too?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Download'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${edition.label} is ready offline.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_downloadErrorMessage(error))),
      );
    }
  }

  String _downloadErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
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
        final chapter = controller.currentChapterSummary;
        final chapterLabel = chapter?.nameSimple ?? 'Continue reading';
        final pageLabel = 'Page ${controller.currentPageNumber}';
        final settings = controller.settings;
        final experience = controller.experienceSettings;
        final editionLabel = settings.mushafEdition.label;
        final heroSubtitle = controller.homeHeroSubtitle(
          chapterLabel: chapterLabel,
          pageLabel: pageLabel,
          editionLabel: editionLabel,
        );
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
              final size = MediaQuery.of(context).size;
              final contentHorizontalPadding = size.width < 420 ? 10.0 : 12.0;
              final contentTopPadding = size.height < 760 ? 6.0 : 8.0;
              final contentBottomPadding = size.height < 760 ? 12.0 : 14.0;
              final contentMaxWidth = size.width > 1200
                  ? 920.0
                  : size.width > 700
                      ? 760.0
                      : double.infinity;

              return Scaffold(
                backgroundColor: theme.scaffoldBackgroundColor,
                body: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.scaffoldBackgroundColor,
                        theme.colorScheme.surfaceContainerLowest
                            .withValues(alpha: settings.nightMode ? 0.94 : 1),
                        theme.colorScheme.surface,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          contentHorizontalPadding,
                          contentTopPadding,
                          contentHorizontalPadding,
                          contentBottomPadding,
                        ),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: contentMaxWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ReaderEntranceMotion(
                                child: _HomeTopCard(
                                  title: controller.homeHeroTitle,
                                  subtitle: heroSubtitle,
                                  /* '$chapterLabel • $pageLabel • $editionLabel', */
                                  streakLabel:
                                      '${controller.readingStreakCount} day streak',
                                  onResume: () => _openReader(context),
                                ),
                              ),
                              Builder(
                                builder: (context) {
                                  final activeAnnouncements = controller
                                      .adminAnnouncements
                                      .where(
                                          (announcement) => announcement.active)
                                      .toList(growable: false);
                                  if (activeAnnouncements.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const SizedBox(height: 16),
                                      ReaderEntranceMotion(
                                        distance: 16,
                                        child: _AnnouncementsCard(
                                          announcements: activeAnnouncements,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              ReaderEntranceMotion(
                                distance: 17,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _InfoPill(
                                      icon: Icons.menu_book_rounded,
                                      label: pageLabel,
                                    ),
                                    _InfoPill(
                                      icon: Icons.auto_graph_rounded,
                                      label:
                                          controller.dailyProgressSummaryLabel,
                                    ),
                                    _InfoPill(
                                      icon:
                                          Icons.local_fire_department_outlined,
                                      label:
                                          '${controller.readingStreakCount} day streak',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              ReaderEntranceMotion(
                                distance: 18,
                                child: _EditionSelectorCard(
                                  editions: MushafEdition.values,
                                  selectedEdition: settings.mushafEdition,
                                  isEditionReady:
                                      controller.isMushafEditionReady,
                                  isEditionDownloading:
                                      controller.isOfflinePackDownloading,
                                  downloadProgressForEdition:
                                      controller.offlinePackProgressForEdition,
                                  onSelectEdition:
                                      controller.selectMushafEdition,
                                  onDownloadEdition: (edition) =>
                                      _openAssetPacksPage(context),
                                  nightMode: settings.nightMode,
                                  onToggleNightMode: controller.toggleNightMode,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ReaderEntranceMotion(
                                distance: 19,
                                child: _OfflinePacksCard(
                                  bundledEdition: MushafEdition.lines16,
                                  downloadableCount:
                                      controller.downloadableZipPackCount,
                                  downloadedCount:
                                      controller.downloadedZipPackCount,
                                  activeDownloadEdition:
                                      controller.activeOfflineDownloadEdition,
                                  activeDownloadProgress:
                                      controller.activeOfflineDownloadEdition ==
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
                                      _downloadFirstAvailablePack(context),
                                  onCancelActiveDownload:
                                      controller.cancelAllOfflinePackDownloads,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ReaderEntranceMotion(
                                distance: 20,
                                child: _SectionTitle(
                                  title: 'Quick Access',
                                  subtitle: controller.quickAccessSubtitle,
                                  horizontalInset: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ReaderEntranceMotion(
                                distance: 22,
                                child: _MenuCard(
                                  child: Column(
                                    children: [
                                      _HomeMenuTile(
                                        icon: Icons.play_circle_outline_rounded,
                                        title: 'Resume',
                                        subtitle:
                                            'Open the last page you were reading',
                                        onTap: () => _openReader(context),
                                      ),
                                      const _TileDivider(),
                                      _HomeMenuTile(
                                        icon:
                                            Icons.dashboard_customize_outlined,
                                        title: 'Dashboard',
                                        subtitle:
                                            'Reading summary and quick tools',
                                        onTap: () =>
                                            _openDashboardPage(context),
                                      ),
                                      const _TileDivider(),
                                      _HomeMenuTile(
                                        icon: Icons.layers_outlined,
                                        title: 'Juz Index',
                                        subtitle:
                                            'Browse sipara wise navigation',
                                        onTap: () => _openSearchPage(
                                          context,
                                          title: 'Juz Index',
                                          initialTab: 1,
                                        ),
                                      ),
                                      const _TileDivider(),
                                      _HomeMenuTile(
                                        icon: Icons.menu_book_rounded,
                                        title: 'Surah Index',
                                        subtitle:
                                            'Browse and jump to any surah',
                                        onTap: () => _openSearchPage(
                                          context,
                                          title: 'Surah Index',
                                          initialTab: 0,
                                        ),
                                      ),
                                      const _TileDivider(),
                                      _HomeMenuTile(
                                        icon: Icons.pin_outlined,
                                        title: 'Go to page',
                                        subtitle:
                                            'Open a page directly by number',
                                        onTap: () =>
                                            _openPageJumpDialog(context),
                                      ),
                                      const _TileDivider(),
                                      _HomeMenuTile(
                                        icon: Icons.bookmark_outline_rounded,
                                        title: 'Bookmarks',
                                        subtitle:
                                            'Saved places and favorite pages',
                                        onTap: () =>
                                            _openBookmarksPage(context),
                                      ),
                                      if (controller.isPlansPacksEnabled) ...[
                                        const _TileDivider(),
                                        _HomeMenuTile(
                                          icon: Icons
                                              .download_for_offline_outlined,
                                          title: 'Asset Packs',
                                          subtitle:
                                              'Download, extract, and manage Quran ZIP editions',
                                          onTap: () =>
                                              _openAssetPacksPage(context),
                                        ),
                                        const _TileDivider(),
                                        _HomeMenuTile(
                                          icon: Icons.insights_outlined,
                                          title: 'Plans & Packs',
                                          subtitle:
                                              'Reading plans, hifz tracking, and accessibility',
                                          onTap: () =>
                                              _openGrowthHubPage(context),
                                        ),
                                      ],
                                      if (controller.isInsightsEnabled) ...[
                                        const _TileDivider(),
                                        _HomeMenuTile(
                                          icon: Icons.auto_stories_outlined,
                                          title: 'Insights',
                                          subtitle:
                                              'Translation, notes, and page details',
                                          onTap: () =>
                                              _openInsightsPage(context),
                                        ),
                                      ],
                                      if (controller.isAudioEnabled) ...[
                                        const _TileDivider(),
                                        _HomeMenuTile(
                                          icon: Icons.headphones_rounded,
                                          title: 'Audio',
                                          subtitle:
                                              'Recitation, qari, and playback controls',
                                          onTap: () => _openAudioPage(context),
                                        ),
                                      ],
                                      if (controller.isAiStudioEnabled) ...[
                                        const _TileDivider(),
                                        _HomeMenuTile(
                                          icon: Icons.auto_awesome_rounded,
                                          title: 'AI Studio',
                                          subtitle:
                                              'Explainer, smart search, hifz, tajweed, and study help',
                                          onTap: () =>
                                              _openAiStudioPage(context),
                                        ),
                                      ],
                                      if (controller.isPageStripEnabled) ...[
                                        const _TileDivider(),
                                        _HomeMenuTile(
                                          icon: Icons.photo_library_outlined,
                                          title: 'Page Thumbnails',
                                          subtitle:
                                              'Jump quickly by previewing pages',
                                          onTap: () =>
                                              _openPageStripPage(context),
                                        ),
                                      ],
                                      if (controller.isCompareEnabled) ...[
                                        const _TileDivider(),
                                        _HomeMenuTile(
                                          icon: Icons.compare_rounded,
                                          title: 'Compare Editions',
                                          subtitle:
                                              'Compare the same page across multiple Quran editions',
                                          onTap: () =>
                                              _openComparePage(context),
                                        ),
                                      ],
                                      if (controller.isKanzulStudyEnabled) ...[
                                        const _TileDivider(),
                                        _HomeMenuTile(
                                          icon: Icons.translate_rounded,
                                          title: 'Kanzul Iman Study',
                                          subtitle:
                                              'Open Quran with Kanzul Iman study mode',
                                          onTap: () =>
                                              _openKanzulStudyPage(context),
                                        ),
                                      ],
                                      const _TileDivider(),
                                      _HomeMenuTile(
                                        icon: Icons.tune_rounded,
                                        title: 'Settings',
                                        subtitle:
                                            'Reading surface, edition, and reader controls',
                                        onTap: () => _openSettingsPage(context),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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

class _HomeTopCard extends StatelessWidget {
  const _HomeTopCard({
    required this.title,
    required this.subtitle,
    required this.streakLabel,
    required this.onResume,
  });

  final String title;
  final String subtitle;
  final String streakLabel;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const heroTextColor = Color(0xFFF5F0E3);
    const heroSubtextColor = Color(0xFFD5E4D8);
    final heroShellColor = Colors.white.withValues(alpha: isDark ? 0.10 : 0.12);
    final heroPillColor = Colors.white.withValues(alpha: isDark ? 0.08 : 0.10);
    final heroPillBorderColor =
        Colors.white.withValues(alpha: isDark ? 0.12 : 0.16);
    const heroButtonColor = Color(0xFFD9F2E8);
    const heroButtonTextColor = Color(0xFF0E3B26);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF143126),
                  Color(0xFF0D2119),
                ]
              : const [
                  Color(0xFF134B2F),
                  Color(0xFF0E3D26),
                ],
        ),
        border: Border.all(
          color:
              theme.colorScheme.primary.withValues(alpha: isDark ? 0.28 : 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow
                .withValues(alpha: isDark ? 0.22 : 0.14),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: heroShellColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const IconTheme(
                  data: IconThemeData(
                    color: heroTextColor,
                    size: 28,
                  ),
                  child: Icon(Icons.auto_stories_rounded),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: heroTextColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: heroSubtextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: heroPillColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: heroPillBorderColor,
              ),
            ),
            child: Text(
              streakLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: heroTextColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow_rounded),
            style: FilledButton.styleFrom(
              backgroundColor: heroButtonColor,
              foregroundColor: heroButtonTextColor,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
            ),
            label: const Text('Resume Reading'),
          ),
        ],
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
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
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
            Text(
              'Reading setup',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select which line Mushaf you want to read and switch dark mode from here.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: editions.map((edition) {
                final ready = isEditionReady(edition);
                final downloading = isEditionDownloading(edition);
                final progress =
                    (downloadProgressForEdition(edition) * 100).round();
                final selected = edition == selectedEdition;
                final foregroundColor = selected
                    ? theme.colorScheme.onPrimary
                    : ready
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant;
                final backgroundColor = selected
                    ? theme.colorScheme.primary
                    : ready
                        ? theme.colorScheme.primary.withValues(alpha: 0.10)
                        : theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.74);

                return Tooltip(
                  message: ready
                      ? 'Switch to ${edition.label}'
                      : downloading
                          ? 'Downloading ${edition.label} ($progress%)'
                          : 'Download ${edition.label}',
                  child: ActionChip(
                    avatar: Icon(
                      ready
                          ? Icons.check_circle_rounded
                          : downloading
                              ? Icons.downloading_rounded
                              : Icons.download_rounded,
                      size: 18,
                      color: foregroundColor,
                    ),
                    label: Text(
                      downloading
                          ? '${edition.label} $progress%'
                          : edition.label,
                    ),
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w800,
                    ),
                    backgroundColor: backgroundColor,
                    side: BorderSide(
                      color: selected
                          ? theme.colorScheme.primary
                          : ready
                              ? theme.colorScheme.primary
                                  .withValues(alpha: 0.28)
                              : theme.colorScheme.outlineVariant,
                    ),
                    onPressed: downloading
                        ? null
                        : ready
                            ? () {
                                onSelectEdition(edition);
                              }
                            : () {
                                onDownloadEdition(edition);
                              },
                  ),
                );
              }).toList(growable: false),
            ),
            if (editions.any((edition) => !isEditionReady(edition))) ...[
              const SizedBox(height: 10),
              Text(
                'Editions with the download icon open the pack downloader first.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Divider(color: theme.dividerColor.withValues(alpha: 0.65)),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: nightMode,
              onChanged: onToggleNightMode,
              title: const Text('Dark mode'),
              subtitle: Text(
                nightMode
                    ? 'Night theme is active across the app.'
                    : 'Paper day mode is active across the app.',
              ),
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
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.14 : 0.05,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                        'Offline Quran packs',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${bundledEdition.label} is ready offline. $downloadableCount more pack(s) can be downloaded.',
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
                'Downloading ${activeDownloadEdition!.label} ($progressPercent%)',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
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
                downloadedCount == 0
                    ? 'Download extra editions once, then read them without internet.'
                    : '$downloadedCount downloaded edition(s) are stored on this device.',
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
                  label: const Text('Download next'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenPacks,
                  icon: const Icon(Icons.list_alt_rounded),
                  label: const Text('Manage packs'),
                ),
                if (isDownloading)
                  OutlinedButton.icon(
                    onPressed: onCancelActiveDownload,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cancel all'),
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
  const _MenuCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.2 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.primary.withValues(alpha: 0.8),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.94 : 0.82,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
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
            'Announcements',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
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
                          announcement.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (dateLabel.isNotEmpty)
                        Text(
                          dateLabel,
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
                      announcement.body,
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
