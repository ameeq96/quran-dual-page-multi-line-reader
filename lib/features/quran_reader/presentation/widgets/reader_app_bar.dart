import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';

import '../../domain/models/reader_settings.dart';

import '../controllers/quran_reader_controller.dart';

enum ReaderMoreAction {
  dashboard,
  growthHub,
  insights,
  audio,
  aiStudio,
  pageStrip,
  compare,
  kanzulStudy,
  settings,
}

class ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ReaderAppBar({
    super.key,
    required this.controller,
    required this.portraitMode,
    required this.onOpenSearch,
    required this.onOpenDashboard,
    required this.onOpenGrowthHub,
    required this.onOpenInsights,
    required this.onOpenAudio,
    required this.onOpenAiStudio,
    required this.onOpenPageStrip,
    required this.onOpenCompare,
    required this.onOpenKanzulStudy,
    required this.onOpenSettings,
  });

  final QuranReaderController controller;
  final bool portraitMode;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenDashboard;
  final VoidCallback onOpenGrowthHub;
  final VoidCallback onOpenInsights;
  final VoidCallback onOpenAudio;
  final VoidCallback onOpenAiStudio;
  final VoidCallback onOpenPageStrip;
  final VoidCallback onOpenCompare;
  final VoidCallback onOpenKanzulStudy;
  final VoidCallback onOpenSettings;

  @override
  Size get preferredSize => Size.fromHeight(portraitMode ? 88 : 76);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final compact = size.width < 420 || size.height < 720;
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 8 : 12,
          compact ? 6 : 8,
          compact ? 8 : 12,
          0,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Color.alphaBlend(
                theme.colorScheme.secondary
                    .withValues(alpha: isDark ? 0.18 : 0.12),
                theme.dividerColor,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 16,
              compact ? 10 : 12,
              compact ? 10 : 12,
              compact ? 10 : 12,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: tr(context, 'Back'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.surfaceContainerLow,
                    fixedSize: const Size(44, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                ),
                SizedBox(width: compact ? 10 : 16),
                if (size.width >= 600) ...[
                  Container(
                    width: 1,
                    height: 30,
                    color: theme.colorScheme.secondary.withValues(alpha: 0.36),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: controller.pageListenable,
                    builder: (context, _, __) {
                      final secondaryLabel = portraitMode
                          ? controller.pageProgressLabel
                          : controller.spreadProgressLabel;
                      final title = controller.currentChapterSummary?.nameSimple ?? 'Quran Reader';

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(context, title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: (portraitMode
                                    ? theme.textTheme.titleMedium
                                    : theme.textTheme.titleLarge)
                                ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${tr(context, secondaryLabel)} • ${tr(context, controller.settings.preferImageMode ? controller.settings.mushafEdition.label : 'Arabic text')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(width: compact ? 6 : 12),
                _ActionPill(
                  icon: controller.settings.pageNightMode
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  tooltip: tr(context, controller.settings.pageNightMode
                      ? 'Use light Quran page'
                      : 'Use dark Quran page'),
                  onPressed: () => controller.togglePageNightMode(
                    !controller.settings.pageNightMode,
                  ),
                  compact: compact,
                ),
                SizedBox(width: compact ? 4 : 8),
                _ActionPill(
                  icon: Icons.search_rounded,
                  tooltip: tr(context, 'Search'),
                  onPressed: onOpenSearch,
                  compact: compact,
                ),
                SizedBox(width: compact ? 4 : 8),
                PopupMenuButton<ReaderMoreAction>(
                  tooltip: tr(context, 'More'),
                  onSelected: (value) {
                    switch (value) {
                      case ReaderMoreAction.dashboard:
                        onOpenDashboard();
                        break;
                      case ReaderMoreAction.growthHub:
                        onOpenGrowthHub();
                        break;
                      case ReaderMoreAction.insights:
                        onOpenInsights();
                        break;
                      case ReaderMoreAction.audio:
                        onOpenAudio();
                        break;
                      case ReaderMoreAction.aiStudio:
                        onOpenAiStudio();
                        break;
                      case ReaderMoreAction.pageStrip:
                        onOpenPageStrip();
                        break;
                      case ReaderMoreAction.compare:
                        onOpenCompare();
                        break;
                      case ReaderMoreAction.kanzulStudy:
                        onOpenKanzulStudy();
                        break;
                      case ReaderMoreAction.settings:
                        onOpenSettings();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: ReaderMoreAction.dashboard,
                      child: _MenuRow(
                        icon: Icons.dashboard_customize_outlined,
                        label: tr(context, 'Dashboard'),
                      ),
                    ),
                    if (controller.isPlansPacksEnabled)
                      PopupMenuItem(
                        value: ReaderMoreAction.growthHub,
                        child: _MenuRow(
                          icon: Icons.insights_outlined,
                          label: tr(context, 'Plans & Packs'),
                        ),
                      ),
                    if (controller.isInsightsEnabled)
                      PopupMenuItem(
                        value: ReaderMoreAction.insights,
                        child: _MenuRow(
                          icon: Icons.auto_stories_outlined,
                          label: tr(context, 'Insights'),
                        ),
                      ),
                    if (controller.isAudioEnabled)
                      PopupMenuItem(
                        value: ReaderMoreAction.audio,
                        child: _MenuRow(
                          icon: Icons.headphones_rounded,
                          label: tr(context, 'Audio'),
                        ),
                      ),
                    if (controller.isAiStudioEnabled)
                      PopupMenuItem(
                        value: ReaderMoreAction.aiStudio,
                        child: _MenuRow(
                          icon: Icons.auto_awesome_rounded,
                          label: tr(context, 'AI Studio'),
                        ),
                      ),
                    if (controller.isPageStripEnabled)
                      PopupMenuItem(
                        value: ReaderMoreAction.pageStrip,
                        child: _MenuRow(
                          icon: Icons.photo_library_outlined,
                          label: tr(context, 'Pages'),
                        ),
                      ),
                    if (controller.isCompareEnabled)
                      PopupMenuItem(
                        value: ReaderMoreAction.compare,
                        child: _MenuRow(
                          icon: Icons.compare_rounded,
                          label: tr(context, 'Compare'),
                        ),
                      ),
                    if (controller.isKanzulStudyEnabled)
                      PopupMenuItem(
                        value: ReaderMoreAction.kanzulStudy,
                        child: _MenuRow(
                          icon: Icons.translate_rounded,
                          label: tr(context, 'Kanzul study'),
                        ),
                      ),
                    PopupMenuItem(
                      value: ReaderMoreAction.settings,
                      child: _MenuRow(
                        icon: Icons.tune_rounded,
                        label: tr(context, 'Settings'),
                      ),
                    ),
                  ],
                  child: _MorePill(compact: compact),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.compact,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(13),
          child: Ink(
            width: compact ? 44 : 48,
            height: compact ? 44 : 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              size: compact ? 20 : 22,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _MorePill extends StatelessWidget {
  const _MorePill({
    required this.compact,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: compact ? 44 : 48,
      height: compact ? 44 : 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Icon(
        Icons.more_horiz_rounded,
        size: compact ? 20 : 22,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Text(tr(context, label)),
      ],
    );
  }
}
