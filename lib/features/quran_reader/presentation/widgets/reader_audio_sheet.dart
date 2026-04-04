import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import '../models/reader_audio_state.dart';
import 'reader_sheet_frame.dart';

Future<void> showReaderAudioSheet(
  BuildContext context, {
  required QuranReaderController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.74,
        child: ReaderSheetFrame(
          child: ReaderAudioContent(
            controller: controller,
            showHandle: true,
          ),
        ),
      );
    },
  );
}

class QuranAudioScreen extends StatelessWidget {
  const QuranAudioScreen({
    super.key,
    required this.controller,
  });

  final QuranReaderController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReaderSettings>(
      valueListenable: controller.settingsListenable,
      builder: (context, settings, _) {
        return Theme(
          data: settings.nightMode ? AppTheme.dark() : AppTheme.light(),
          child: Scaffold(
            body: SafeArea(
              child: ReaderAudioContent(
                controller: controller,
                showHandle: false,
              ),
            ),
          ),
        );
      },
    );
  }
}

class ReaderAudioContent extends StatelessWidget {
  const ReaderAudioContent({
    super.key,
    required this.controller,
    this.showHandle = true,
  });

  final QuranReaderController controller;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxHeight < 520 || constraints.maxWidth < 380;
          final sectionGap = compact ? 14.0 : 20.0;
          final cardPadding = compact ? 14.0 : 18.0;

          return AnimatedBuilder(
            animation: controller.pageListenable,
            builder: (context, _) {
              return ValueListenableBuilder<ReaderAudioState>(
                valueListenable: controller.audioListenable,
                builder: (context, audio, _) {
                  final chapter =
                      controller.chapterForId(audio.currentChapterId) ??
                          controller.selectedAudioChapter;

                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      18,
                      20,
                      MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    children: [
                      if (showHandle) ...[
                        Center(
                          child: Container(
                            width: 54,
                            height: 5,
                            decoration: BoxDecoration(
                              color: theme.dividerColor.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        SizedBox(height: sectionGap),
                      ],
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              theme.colorScheme.surface.withOpacity(0.97),
                              theme.colorScheme.surfaceContainer.withOpacity(
                                0.92,
                              ),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: theme.dividerColor.withOpacity(0.46),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.shadow.withOpacity(0.06),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(cardPadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: compact ? 46 : 52,
                                    height: compact ? 46 : 52,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      audio.isPlaying
                                          ? Icons.graphic_eq_rounded
                                          : Icons.headphones_rounded,
                                      color: theme.colorScheme.primary,
                                      size: compact ? 24 : 28,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          chapter?.nameSimple ??
                                              'Audio recitation',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          chapter == null
                                              ? 'Recitation is unavailable for this page.'
                                              : 'Choose any Surah and Qari, then play recitation.',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: theme.colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _AudioStatusChip(
                                    icon: Icons.menu_book_rounded,
                                    label: chapter == null
                                        ? 'No Surah selected'
                                        : 'Surah ${chapter.id}',
                                  ),
                                  _AudioStatusChip(
                                    icon: Icons.person_outline_rounded,
                                    label: audio.selectedReciter?.displayName ??
                                        'Select Qari',
                                  ),
                                  _AudioStatusChip(
                                    icon: audio.isPlaying
                                        ? Icons.play_circle_fill_rounded
                                        : Icons.pause_circle_outline_rounded,
                                    label:
                                        audio.isPlaying ? 'Playing' : 'Ready',
                                  ),
                                ],
                              ),
                              SizedBox(height: sectionGap),
                              const _AudioSectionLabel(label: 'Selection'),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<int>(
                                value: chapter?.id,
                                isExpanded: true,
                                menuMaxHeight: 360,
                                decoration: const InputDecoration(
                                  labelText: 'Surah',
                                ),
                                selectedItemBuilder: (context) {
                                  return controller.chapters.map((entry) {
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${entry.id}. ${entry.nameSimple}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(growable: false);
                                },
                                items: controller.chapters.map((entry) {
                                  return DropdownMenuItem<int>(
                                    value: entry.id,
                                    child: Text(
                                      '${entry.id}. ${entry.nameSimple}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(growable: false),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  final selectedChapter =
                                      controller.chapters.firstWhere(
                                    (entry) => entry.id == value,
                                  );
                                  controller.selectAudioChapter(
                                    selectedChapter,
                                  );
                                },
                              ),
                              SizedBox(height: sectionGap),
                              DropdownButtonFormField<int>(
                                value: audio.selectedReciter?.id,
                                isExpanded: true,
                                menuMaxHeight: 320,
                                decoration: const InputDecoration(
                                  labelText: 'Qari',
                                ),
                                selectedItemBuilder: (context) {
                                  return controller.reciters.map((reciter) {
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        reciter.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(growable: false);
                                },
                                items: controller.reciters.map((reciter) {
                                  return DropdownMenuItem<int>(
                                    value: reciter.id,
                                    child: Text(
                                      reciter.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(growable: false),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  final reciter = controller.reciters.firstWhere(
                                    (entry) => entry.id == value,
                                  );
                                  controller.selectReciter(reciter);
                                },
                              ),
                              SizedBox(height: sectionGap),
                              const _AudioSectionLabel(label: 'Playback'),
                              const SizedBox(height: 10),
                              Slider(
                                value: audio.progress,
                                onChanged: audio.durationMillis <= 0
                                    ? null
                                    : (value) {
                                        controller.seekAudio(value);
                                      },
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatMillis(audio.positionMillis)),
                                  Text(_formatMillis(audio.durationMillis)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: audio.repeatEnabled,
                                onChanged: (value) {
                                  controller.toggleAudioRepeat(value);
                                },
                                title: const Text('Repeat selected surah'),
                                subtitle: Text(
                                  controller.hasAudioResumePoint
                                      ? 'Resume point: ${_formatMillis(controller.audioResumePositionMillis)}'
                                      : 'Playback will continue from the beginning.',
                                ),
                              ),
                              SizedBox(height: compact ? 12 : 14),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: compact ? double.infinity : 240,
                                    child: FilledButton.icon(
                                      onPressed: chapter == null
                                          ? null
                                          : () {
                                              controller.playSelectedSurah();
                                            },
                                      icon: Icon(
                                        audio.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                      ),
                                      label: Text(
                                        audio.isPlaying ? 'Pause' : 'Play',
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: compact ? double.infinity : 240,
                                    child: OutlinedButton.icon(
                                      onPressed: audio.currentChapterId == null
                                          ? null
                                          : () {
                                              controller.stopAudio();
                                            },
                                      icon: const Icon(Icons.stop_rounded),
                                      label: const Text('Stop'),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: sectionGap),
                              const _AudioSectionLabel(label: 'Offline'),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: chapter == null ||
                                            audio.isDownloading ||
                                            controller.isSelectedAudioDownloaded
                                        ? null
                                        : () {
                                            controller.downloadSelectedAudio();
                                          },
                                    icon: const Icon(Icons.download_rounded),
                                    label: Text(
                                      audio.isDownloading
                                          ? 'Downloading...'
                                          : 'Download offline',
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: chapter == null ||
                                            !controller.isSelectedAudioDownloaded
                                        ? null
                                        : () {
                                            controller
                                                .deleteSelectedAudioDownload();
                                          },
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                    label: const Text('Remove download'),
                                  ),
                                  if (controller.isSelectedAudioDownloaded)
                                    const Chip(
                                      avatar: Icon(
                                        Icons.offline_pin_rounded,
                                        size: 18,
                                      ),
                                      label: Text('Available offline'),
                                    ),
                                ],
                              ),
                              if (audio.errorMessage != null &&
                                  audio.errorMessage!.trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.errorContainer
                                        .withOpacity(0.72),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      audio.errorMessage!,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme
                                            .colorScheme.onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (audio.isLoading || audio.isBuffering) ...[
                                const SizedBox(height: 12),
                                const LinearProgressIndicator(minHeight: 3),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatMillis(int millis) {
    final duration = Duration(milliseconds: millis);
    final minutes = duration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class _AudioSectionLabel extends StatelessWidget {
  const _AudioSectionLabel({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _AudioStatusChip extends StatelessWidget {
  const _AudioStatusChip({
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
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.38),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
