import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import '../widgets/kanzul_iman_study_sheet.dart';
import '../widgets/reader_audio_sheet.dart';
import '../widgets/reader_compare_sheet.dart';
import '../widgets/reader_dashboard_sheet.dart';
import '../widgets/reader_insights_sheet.dart';
import '../widgets/reader_motion.dart';
import '../widgets/reader_page_strip_sheet.dart';
import '../widgets/reader_skeleton.dart';
import 'quran_ai_studio_screen.dart';
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
          rukuMarkers: controller.rukuMarkers,
          hizbMarkers: controller.hizbMarkers,
          manzilMarkers: controller.manzilMarkers,
          rubMarkers: controller.rubMarkers,
          currentPage: controller.currentPageNumber,
          maxPage: controller.totalPages,
          surahPageResolver: controller.navigationPageForSurahEntry,
          juzPageResolver: controller.navigationPageForJuzEntry,
          surahSearch: controller.searchSurahs,
          juzSearch: controller.searchJuzs,
          markerSearch: controller.searchMarkers,
          ayahSearch: controller.searchAyahs,
          textSearch: controller.searchPages,
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
    return Navigator.of(context).push(
      buildReaderPageRoute<void>(
        builder: (context) => QuranCompareScreen(controller: controller),
      ),
    );
  }

  Future<void> _openKanzulStudyPage(BuildContext context) {
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
                return const _HomeSkeletonScreen();
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
                            .withOpacity(settings.nightMode ? 0.94 : 1),
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
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ReaderEntranceMotion(
                          child: _HomeTopCard(
                          title: controller.homeHeroTitle,
                          subtitle: heroSubtitle, /*
                              '$chapterLabel • $pageLabel • $editionLabel',
                          */ streakLabel:
                              '${controller.readingStreakCount} day streak',
                          onResume: () => _openReader(context),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ReaderEntranceMotion(
                          distance: 18,
                          child: _EditionSelectorCard(
                          editions: controller.availableImageEditions,
                          selectedEdition: settings.mushafEdition,
                          onSelectEdition: controller.selectMushafEdition,
                          nightMode: settings.nightMode,
                          onToggleNightMode: controller.toggleNightMode,
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
                                subtitle: 'Open the last page you were reading',
                                onTap: () => _openReader(context),
                              ),
                              const _TileDivider(),
                              _HomeMenuTile(
                                icon: Icons.dashboard_customize_outlined,
                                title: 'Dashboard',
                                subtitle: 'Reading summary and quick tools',
                                onTap: () => _openDashboardPage(context),
                              ),
                              const _TileDivider(),
                              _HomeMenuTile(
                                icon: Icons.layers_outlined,
                                title: 'Juz Index',
                                subtitle: 'Browse sipara wise navigation',
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
                                subtitle: 'Browse and jump to any surah',
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
                                subtitle: 'Open a page directly by number',
                                onTap: () => _openSearchPage(
                                  context,
                                  title: 'Go to page',
                                  initialTab: 4,
                                ),
                              ),
                              const _TileDivider(),
                              _HomeMenuTile(
                                icon: Icons.bookmark_outline_rounded,
                                title: 'Bookmarks',
                                subtitle: 'Saved places and favorite pages',
                                onTap: () => _openBookmarksPage(context),
                              ),
                              if (controller.isPlansPacksEnabled) ...[
                                const _TileDivider(),
                                _HomeMenuTile(
                                  icon: Icons.insights_outlined,
                                  title: 'Plans & Packs',
                                  subtitle:
                                      'Reading plans, hifz tracking, packs, and accessibility',
                                  onTap: () => _openGrowthHubPage(context),
                                ),
                              ],
                              if (controller.isInsightsEnabled) ...[
                                const _TileDivider(),
                                _HomeMenuTile(
                                  icon: Icons.auto_stories_outlined,
                                  title: 'Insights',
                                  subtitle:
                                      'Translation, notes, and page details',
                                  onTap: () => _openInsightsPage(context),
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
                                  onTap: () => _openAiStudioPage(context),
                                ),
                              ],
                              if (controller.isPageStripEnabled) ...[
                                const _TileDivider(),
                                _HomeMenuTile(
                                  icon: Icons.photo_library_outlined,
                                  title: 'Page Thumbnails',
                                  subtitle: 'Jump quickly by previewing pages',
                                  onTap: () => _openPageStripPage(context),
                                ),
                              ],
                              if (controller.isCompareEnabled) ...[
                                const _TileDivider(),
                                _HomeMenuTile(
                                  icon: Icons.compare_rounded,
                                  title: 'Compare Editions',
                                  subtitle:
                                      'Compare the same page across multiple Quran editions',
                                  onTap: () => _openComparePage(context),
                                ),
                              ],
                              if (controller.isKanzulStudyEnabled) ...[
                                const _TileDivider(),
                                _HomeMenuTile(
                                  icon: Icons.translate_rounded,
                                  title: 'Kanzul Iman Study',
                                  subtitle:
                                      'Open Quran with Kanzul Iman study mode',
                                  onTap: () => _openKanzulStudyPage(context),
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
                        const SizedBox(height: 14),
                        ReaderEntranceMotion(
                          distance: 24,
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
                                label: controller.dailyProgressSummaryLabel,
                              ),
                              _InfoPill(
                                icon: Icons.local_fire_department_outlined,
                                label:
                                    '${controller.readingStreakCount} day streak',
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
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _HomeSkeletonScreen extends StatelessWidget {
  const _HomeSkeletonScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ReaderSkeletonBlock(
                          width: 52,
                          height: 52,
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ReaderSkeletonBlock(
                                height: 18,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(999)),
                              ),
                              SizedBox(height: 10),
                              ReaderSkeletonBlock(
                                height: 12,
                                width: 220,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(999)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 18),
                    ReaderSkeletonBlock(
                      width: 130,
                      height: 34,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                    SizedBox(height: 14),
                    ReaderSkeletonBlock(
                      height: 52,
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReaderSkeletonBlock(
                      width: 160,
                      height: 16,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                    SizedBox(height: 14),
                    ReaderSkeletonBlock(
                      height: 52,
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const ReaderSkeletonBlock(
                width: 180,
                height: 16,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  children: [
                    ReaderSkeletonBlock(
                      height: 56,
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                    SizedBox(height: 10),
                    ReaderSkeletonBlock(
                      height: 56,
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                    SizedBox(height: 10),
                    ReaderSkeletonBlock(
                      height: 56,
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                    SizedBox(height: 10),
                    ReaderSkeletonBlock(
                      height: 56,
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                  ],
                ),
              ),
            ],
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
    final heroShellColor = Colors.white.withOpacity(isDark ? 0.10 : 0.12);
    final heroPillColor = Colors.white.withOpacity(isDark ? 0.08 : 0.10);
    final heroPillBorderColor = Colors.white.withOpacity(isDark ? 0.12 : 0.16);
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
          color: theme.colorScheme.primary.withOpacity(isDark ? 0.28 : 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(isDark ? 0.22 : 0.14),
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
    required this.onSelectEdition,
    required this.nightMode,
    required this.onToggleNightMode,
  });

  final List<MushafEdition> editions;
  final MushafEdition selectedEdition;
  final Future<void> Function(MushafEdition edition) onSelectEdition;
  final bool nightMode;
  final Future<void> Function(bool enabled) onToggleNightMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(
          theme.brightness == Brightness.dark ? 0.96 : 0.9,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(
              theme.brightness == Brightness.dark ? 0.16 : 0.06,
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
                return ChoiceChip(
                  label: Text(edition.label),
                  selected: edition == selectedEdition,
                  onSelected: (_) {
                    onSelectEdition(edition);
                  },
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 14),
            Divider(color: theme.dividerColor.withOpacity(0.65)),
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
        color: theme.colorScheme.surface.withOpacity(
          theme.brightness == Brightness.dark ? 0.96 : 0.9,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(
              theme.brightness == Brightness.dark ? 0.16 : 0.06,
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
                  color: theme.colorScheme.primary.withOpacity(
                    theme.brightness == Brightness.dark ? 0.2 : 0.12,
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
                color: theme.colorScheme.primary.withOpacity(0.8),
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
        color: theme.colorScheme.surface.withOpacity(
          theme.brightness == Brightness.dark ? 0.94 : 0.82,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.7),
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
