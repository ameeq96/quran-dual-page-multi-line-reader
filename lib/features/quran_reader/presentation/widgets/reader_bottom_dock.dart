import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/reader_localization.dart';

import '../controllers/quran_reader_controller.dart';
import 'app_motion.dart';
import 'reader_app_bar.dart';

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
                borderRadius: BorderRadius.circular(AppRadii.xl - 4),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.7),
                ),
                boxShadow: AppDecor.of(context).floatShadow,
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
                        accentIndex: 1,
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
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 48,
                            height: 48,
                          ),
                          color: theme.colorScheme.primary,
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
                            size: compact ? 36 : 40,
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
    this.accentIndex = 0,
    this.trailing,
    this.trailingLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool compact;
  final int accentIndex;
  final Widget? trailing;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A trailing button brings its own 48dp height, so the tile needs less
    // padding to stay the same height as its neighbour.
    final verticalPadding = trailing != null
        ? (compact ? 4.0 : 6.0)
        : (compact ? 9.0 : 11.0);

    return AppPressable(
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              compact ? 10 : 12,
              verticalPadding,
              trailing != null ? 4 : (compact ? 10 : 12),
              verticalPadding,
            ),
            child: Row(
              children: [
                ReaderAccentBadge(
                  icon: icon,
                  accentIndex: accentIndex,
                  size: compact ? 36 : 40,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context, title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr(context, subtitle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailingLabel != null) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: compact ? 88 : 72),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
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
      ),
    );
  }
}
