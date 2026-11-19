import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/reader_localization.dart';

import '../controllers/quran_reader_controller.dart';
import 'app_motion.dart';
import 'reader_app_bar.dart';

class ReaderNowPlayingBar extends StatelessWidget {
  const ReaderNowPlayingBar({
    super.key,
    required this.controller,
    required this.onOpenAudio,
  });

  final QuranReaderController controller;
  final VoidCallback onOpenAudio;

  @override
  Widget build(BuildContext context) {
    final audio = controller.audioState;
    final chapter = controller.selectedAudioChapter;
    final theme = Theme.of(context);
    final reciterName = audio.selectedReciter?.displayName ?? 'Select reciter';
    final title = chapter?.nameSimple ?? 'Audio recitation';
    final subtitle = controller.hasAudioResumePoint
        ? '$reciterName | Resume ${_formatMillis(controller.audioResumePositionMillis)}'
        : reciterName;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AppPressable(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.xl - 4),
              boxShadow: AppDecor.of(context).floatShadow,
            ),
            child: Material(
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.xl - 4),
                side: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.7),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onOpenAudio,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          ReaderAccentBadge(
                            icon: audio.isPlaying
                                ? Icons.graphic_eq_rounded
                                : Icons.headphones_rounded,
                            size: 42,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
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
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: tr(context, audio.isPlaying ? 'Pause' : 'Play'),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 48,
                              height: 48,
                            ),
                            color: theme.colorScheme.primary,
                            onPressed: chapter == null
                                ? null
                                : () {
                                    if (audio.isPlaying) {
                                      controller.pauseAudio();
                                    } else {
                                      controller.playSelectedSurah();
                                    }
                                  },
                            icon: Icon(
                              audio.isPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              size: 40,
                            ),
                          ),
                          IconButton(
                            tooltip: tr(context, 'Stop'),
                            constraints: const BoxConstraints.tightFor(
                              width: 48,
                              height: 48,
                            ),
                            color: theme.colorScheme.onSurfaceVariant,
                            onPressed: audio.currentChapterId == null
                                ? null
                                : () {
                                    controller.stopAudio();
                                  },
                            icon: const Icon(Icons.stop_circle_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            value:
                                audio.durationMillis > 0 ? audio.progress : 0,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
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
      ),
    );
  }

  String _formatMillis(int millis) {
    final duration = Duration(milliseconds: millis);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
