import 'package:flutter/material.dart';

import '../controllers/quran_reader_controller.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpenAudio,
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.94),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.dividerColor.withOpacity(0.55),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            audio.isPlaying
                                ? Icons.graphic_eq_rounded
                                : Icons.headphones_rounded,
                            color: theme.colorScheme.primary,
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
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: audio.isPlaying ? 'Pause' : 'Play',
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
                          ),
                        ),
                        IconButton(
                          tooltip: 'Stop',
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        value: audio.durationMillis > 0 ? audio.progress : 0,
                        backgroundColor: theme.dividerColor.withOpacity(0.22),
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
