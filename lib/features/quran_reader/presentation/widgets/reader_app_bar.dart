import 'package:flutter/material.dart';

import '../controllers/quran_reader_controller.dart';

enum ReaderMoreAction {
  dashboard,
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
  final VoidCallback onOpenInsights;
  final VoidCallback onOpenAudio;
  final VoidCallback onOpenAiStudio;
  final VoidCallback onOpenPageStrip;
  final VoidCallback onOpenCompare;
  final VoidCallback onOpenKanzulStudy;
  final VoidCallback onOpenSettings;

  @override
  Size get preferredSize => const Size.fromHeight(104);

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
          compact ? 10 : 14,
          compact ? 8 : 10,
          compact ? 10 : 14,
          0,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (isDark
                    ? theme.colorScheme.surfaceContainerLow
                    : theme.colorScheme.surface)
                .withOpacity(0.94),
            borderRadius: BorderRadius.circular(compact ? 24 : 28),
            border: Border.all(
              color: theme.dividerColor.withOpacity(isDark ? 0.5 : 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withOpacity(isDark ? 0.18 : 0.06),
                blurRadius: isDark ? 24 : 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 14 : 18,
              compact ? 12 : 14,
              compact ? 12 : 14,
              compact ? 12 : 14,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: controller.pageListenable,
                    builder: (context, _, __) {
                      final primaryLabel = portraitMode
                          ? controller.pageLabel
                          : controller.spreadLabel;
                      final secondaryLabel = portraitMode
                          ? controller.pageProgressLabel
                          : controller.spreadProgressLabel;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quran Dual Page',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: -0.35,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$primaryLabel | $secondaryLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                _ActionPill(
                  icon: Icons.search_rounded,
                  tooltip: 'Search',
                  onPressed: onOpenSearch,
                  compact: compact,
                ),
                const SizedBox(width: 8),
                PopupMenuButton<ReaderMoreAction>(
                  tooltip: 'More',
                  onSelected: (value) {
                    switch (value) {
                      case ReaderMoreAction.dashboard:
                        onOpenDashboard();
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
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: ReaderMoreAction.dashboard,
                      child: _MenuRow(
                        icon: Icons.dashboard_customize_outlined,
                        label: 'Dashboard',
                      ),
                    ),
                    PopupMenuItem(
                      value: ReaderMoreAction.insights,
                      child: _MenuRow(
                        icon: Icons.auto_stories_outlined,
                        label: 'Insights',
                      ),
                    ),
                    PopupMenuItem(
                      value: ReaderMoreAction.audio,
                      child: _MenuRow(
                        icon: Icons.headphones_rounded,
                        label: 'Audio',
                      ),
                    ),
                    PopupMenuItem(
                      value: ReaderMoreAction.aiStudio,
                      child: _MenuRow(
                        icon: Icons.auto_awesome_rounded,
                        label: 'AI Studio',
                      ),
                    ),
                    PopupMenuItem(
                      value: ReaderMoreAction.pageStrip,
                      child: _MenuRow(
                        icon: Icons.photo_library_outlined,
                        label: 'Pages',
                      ),
                    ),
                    PopupMenuItem(
                      value: ReaderMoreAction.compare,
                      child: _MenuRow(
                        icon: Icons.compare_rounded,
                        label: 'Compare',
                      ),
                    ),
                    PopupMenuItem(
                      value: ReaderMoreAction.kanzulStudy,
                      child: _MenuRow(
                        icon: Icons.translate_rounded,
                        label: 'Kanzul study',
                      ),
                    ),
                    PopupMenuItem(
                      value: ReaderMoreAction.settings,
                      child: _MenuRow(
                        icon: Icons.tune_rounded,
                        label: 'Settings',
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
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            width: compact ? 44 : 48,
            height: compact ? 44 : 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest.withOpacity(0.9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.dividerColor.withOpacity(0.36),
              ),
            ),
            child: Icon(
              icon,
              size: compact ? 20 : 22,
              color: theme.colorScheme.onSurface,
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
        color: theme.colorScheme.surfaceContainerLowest.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.36),
        ),
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
        Text(label),
      ],
    );
  }
}
