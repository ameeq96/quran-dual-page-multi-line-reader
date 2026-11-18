import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';

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
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Color.alphaBlend(
                    theme.colorScheme.secondary.withValues(alpha: 0.12),
                    theme.dividerColor,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.07),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(compact ? 6 : 8),
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

                    final actions = <Widget>[
                      _DockActionTile(
                        icon: Icons.translate_rounded,
                        title: tr(context, 'Translation'),
                        subtitle: tr(context, 'Translation & reflection'),
                        onTap: onOpenInsights,
                        compact: compact,
                        trailingLabel: 'Page ${controller.currentPageNumber}',
                      ),
                      _DockActionTile(
                        icon: isCurrentChapterPlaying
                            ? Icons.graphic_eq_rounded
                            : Icons.headphones_rounded,
                        title: title,
                        subtitle: subtitle,
                        onTap: onOpenAudio,
                        compact: compact,
                        trailing: IconButton(
                          tooltip: tr(context, isCurrentChapterPlaying ? 'Pause' : 'Play'),
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
                    ];
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 460) {
                          return Row(
                            children: [
                              Expanded(child: actions[0]),
                              const SizedBox(width: 8),
                              Expanded(child: actions[1]),
                            ],
                          );
                        }
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            actions[0],
                            const SizedBox(height: 6),
                            actions[1],
                          ],
                        );
                      },
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
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 9 : 11,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 34 : 38,
                height: compact ? 34 : 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.secondary,
                  size: compact ? 20 : 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr(context, subtitle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingLabel != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: compact ? 80 : 64),
                  child: Text(
                    tr(context, trailingLabel!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
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
