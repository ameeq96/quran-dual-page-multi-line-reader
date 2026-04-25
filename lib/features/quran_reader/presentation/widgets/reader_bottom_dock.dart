import 'package:flutter/material.dart';

import '../controllers/quran_reader_controller.dart';

class ReaderBottomDock extends StatelessWidget {
  const ReaderBottomDock({
    super.key,
    required this.controller,
    required this.onOpenAudio,
    required this.onOpenInsights,
    required this.compact,
  });

  final QuranReaderController controller;
  final VoidCallback onOpenAudio;
  final VoidCallback onOpenInsights;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(compact ? 12 : 18, 0, compact ? 12 : 18, 10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(compact ? 20 : 24),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.36),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(compact ? 8 : 10),
                child: AnimatedBuilder(
                  animation: Listenable.merge(<Listenable>[
                    controller.pageListenable,
                    controller.audioListenable,
                  ]),
                  builder: (context, _) {
                    final audio = controller.audioState;
                    final chapter = controller.currentChapterSummary;
                    final isCurrentChapterPlaying = chapter != null &&
                        audio.currentChapterId == chapter.id &&
                        audio.isPlaying;
                    final title = chapter?.nameSimple ?? 'Audio recitation';
                    final subtitle =
                        audio.selectedReciter?.displayName ?? 'Select reciter';

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DockActionTile(
                          icon: Icons.translate_rounded,
                          title: 'Translation',
                          subtitle: 'Open translation and page insights',
                          onTap: onOpenInsights,
                          compact: compact,
                          trailingLabel: 'Page ${controller.currentPageNumber}',
                        ),
                        const SizedBox(height: 8),
                        _DockActionTile(
                          icon: isCurrentChapterPlaying
                              ? Icons.graphic_eq_rounded
                              : Icons.headphones_rounded,
                          title: title,
                          subtitle: subtitle,
                          onTap: onOpenAudio,
                          compact: compact,
                          trailing: IconButton(
                            tooltip: isCurrentChapterPlaying ? 'Pause' : 'Play',
                            visualDensity: const VisualDensity(
                              horizontal: -3,
                              vertical: -3,
                            ),
                            onPressed: chapter == null
                                ? onOpenAudio
                                : () {
                                    if (isCurrentChapterPlaying) {
                                      controller.pauseAudio();
                                    } else {
                                      controller.playCurrentSurah();
                                    }
                                  },
                            icon: Icon(
                              isCurrentChapterPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              size: compact ? 26 : 30,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockActionTile extends StatelessWidget {
  const _DockActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.compact,
    this.trailing,
    this.trailingLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool compact;
  final Widget? trailing;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: compact ? 12 : 13,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest
                .withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(compact ? 16 : 18),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 38 : 42,
                height: compact ? 38 : 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.primary,
                  size: compact ? 20 : 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingLabel != null) ...[
                const SizedBox(width: 8),
                Text(
                  trailingLabel!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 4),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
