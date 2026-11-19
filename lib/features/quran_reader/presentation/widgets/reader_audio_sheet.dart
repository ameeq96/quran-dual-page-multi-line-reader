import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/quran_page_verse.dart';
import '../controllers/quran_reader_controller.dart';
import '../models/reader_audio_state.dart';
import 'app_motion.dart';
import 'reader_app_bar.dart';
import 'reader_sheet_frame.dart';
import 'reader_audio_practice_panel.dart';

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
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        controller.settingsListenable,
        controller.experienceListenable,
      ]),
      builder: (context, _) {
        final settings = controller.settings;
        final experience = controller.experienceSettings;
        return Theme(
          data: settings.nightMode
              ? AppTheme.dark(
                  highContrast: experience.highContrastMode,
                  largerText: experience.largerTextMode,
                )
              : AppTheme.light(
                  highContrast: experience.highContrastMode,
                  largerText: experience.largerTextMode,
                ),
          child: Scaffold(
            appBar: AppBar(
              title: Text(tr(context, 'Recitation')),
              centerTitle: false,
            ),
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
    final decor = AppDecor.of(context);

    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxHeight < 520 || constraints.maxWidth < 600;
          final sectionGap = compact ? 12.0 : 16.0;
          final contentInset = constraints.maxWidth > 808
              ? (constraints.maxWidth - 760) / 2
              : 16.0;

          return AnimatedBuilder(
            animation: controller.pageListenable,
            builder: (context, _) {
              return ValueListenableBuilder<ReaderAudioState>(
                valueListenable: controller.audioListenable,
                builder: (context, audio, _) {
                  final chapter =
                      controller.chapterForId(audio.currentChapterId) ??
                          controller.selectedAudioChapter;
                  final hasError = audio.errorMessage != null &&
                      audio.errorMessage!.trim().isNotEmpty;

                  final playButton = FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                      iconSize: 26,
                    ),
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
                      tr(context, audio.isPlaying ? 'Pause' : 'Play'),
                    ),
                  );
                  final stopButton = OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(0, compact ? 48 : 56),
                    ),
                    onPressed: audio.currentChapterId == null
                        ? null
                        : () {
                            controller.stopAudio();
                          },
                    icon: const Icon(Icons.stop_rounded),
                    label: Text(tr(context, 'Stop')),
                  );
                  final downloadButton = FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: chapter == null ||
                            audio.isDownloading ||
                            controller.isSelectedAudioDownloaded
                        ? null
                        : () {
                            controller.downloadSelectedAudio();
                          },
                    icon: const Icon(Icons.download_rounded),
                    label: Text(
                      tr(context, audio.isDownloading
                          ? 'Downloading...'
                          : 'Download offline'),
                    ),
                  );
                  final removeDownloadButton = OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed:
                        chapter == null || !controller.isSelectedAudioDownloaded
                            ? null
                            : () {
                                controller.deleteSelectedAudioDownload();
                              },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                    ),
                    label: Text(tr(context, 'Remove download')),
                  );

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      contentInset,
                      12,
                      contentInset,
                      MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showHandle) ...[
                          ReaderSheetHeader(title: tr(context, 'Recitation')),
                          const SizedBox(height: 8),
                        ],
                        AppStagger(
                          index: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: decor.heroGradient,
                              borderRadius: BorderRadius.circular(AppRadii.xl),
                              border: Border.all(
                                color: decor.gold.withValues(alpha: 0.22),
                              ),
                              boxShadow: decor.floatShadow,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(compact ? 16 : 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _AudioSectionLabel(
                                    label: tr(context, 'Listen & reflect'),
                                    color: decor.gold,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Container(
                                        width: compact ? 52 : 60,
                                        height: compact ? 52 : 60,
                                        decoration: BoxDecoration(
                                          color: decor.gold,
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.md,
                                          ),
                                        ),
                                        child: Icon(
                                          audio.isPlaying
                                              ? Icons.graphic_eq_rounded
                                              : Icons.headphones_rounded,
                                          color: decor.onGold,
                                          size: compact ? 26 : 30,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tr(context, chapter?.nameSimple ??
                                                  'Audio recitation'),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.titleLarge
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: decor.onHero,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              tr(context, chapter == null
                                                  ? 'Recitation is unavailable for this page.'
                                                  : 'Choose a Surah and reciter for your listening.'),
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                color: decor.onHero
                                                    .withValues(alpha: 0.84),
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
                                        label: tr(context, chapter == null
                                            ? 'No Surah selected'
                                            : 'Surah ${chapter.id}'),
                                      ),
                                      _AudioStatusChip(
                                        icon: audio.isPlaying
                                            ? Icons.play_circle_fill_rounded
                                            : Icons.pause_circle_outline_rounded,
                                        label:
                                            tr(context, audio.isPlaying ? 'Playing' : 'Ready'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: sectionGap),
                        AppStagger(
                          index: 1,
                          child: ReaderSheetCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _AudioSectionLabel(label: tr(context, 'Your recitation')),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  initialValue: chapter?.id,
                                  isExpanded: true,
                                  menuMaxHeight: 360,
                                  decoration: InputDecoration(
                                    labelText: tr(context, 'Surah'),
                                    prefixIcon: const Icon(Icons.menu_book_outlined),
                                  ),
                                  selectedItemBuilder: (context) {
                                    return controller.chapters.map((entry) {
                                      return Align(
                                        alignment:
                                            AlignmentDirectional.centerStart,
                                        child: Text(
                                          tr(context, '${entry.id}. ${entry.nameSimple}'),
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
                                        tr(context, '${entry.id}. ${entry.nameSimple}'),
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
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  initialValue: audio.selectedReciter?.id,
                                  isExpanded: true,
                                  menuMaxHeight: 320,
                                  decoration: InputDecoration(
                                    labelText: tr(context, 'Qari'),
                                    prefixIcon: const Icon(Icons.person_outline_rounded),
                                  ),
                                  selectedItemBuilder: (context) {
                                    return controller.reciters.map((reciter) {
                                      return Align(
                                        alignment:
                                            AlignmentDirectional.centerStart,
                                        child: Text(
                                          tr(context, reciter.displayName),
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
                                        tr(context, reciter.displayName),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(growable: false),
                                  onChanged: (value) {
                                    if (value == null) {
                                      return;
                                    }
                                    final reciter =
                                        controller.reciters.firstWhere(
                                      (entry) => entry.id == value,
                                    );
                                    controller.selectReciter(reciter);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: sectionGap),
                        AppStagger(
                          index: 2,
                          child: ReaderSheetCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _AudioSectionLabel(label: tr(context, 'Playback')),
                                const SizedBox(height: 4),
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
                                    Text(
                                      tr(context, _formatMillis(audio.positionMillis)),
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      tr(context, _formatMillis(audio.durationMillis)),
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                if (compact) ...[
                                  playButton,
                                  const SizedBox(height: 10),
                                  stopButton,
                                ] else
                                  Row(
                                    children: [
                                      Expanded(flex: 2, child: playButton),
                                      const SizedBox(width: 12),
                                      Expanded(child: stopButton),
                                    ],
                                  ),
                                if (audio.isLoading || audio.isBuffering) ...[
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: const LinearProgressIndicator(
                                      minHeight: 3,
                                    ),
                                  ),
                                ],
                                if (hasError) ...[
                                  const SizedBox(height: 12),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.errorContainer,
                                      borderRadius:
                                          BorderRadius.circular(AppRadii.md),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.error_outline_rounded,
                                            size: 20,
                                            color: theme
                                                .colorScheme.onErrorContainer,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              tr(context, _audioFailureMessage(audio.errorMessage!)),
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: theme.colorScheme
                                                    .onErrorContainer,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerLow,
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.md),
                                    border: Border.all(
                                      color: theme.dividerColor
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  child: Row(children: [
                                    Icon(Icons.sync_rounded, size: 20, color: theme.colorScheme.primary),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(tr(context, controller.recitationFollowStatus), style: theme.textTheme.bodySmall)),
                                  ]),
                                ),
                                ReaderAudioVersePanel(verse: controller.currentAudioVerse),
                                const SizedBox(height: 4),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  value: audio.repeatEnabled,
                                  onChanged: (value) {
                                    controller.toggleAudioRepeat(value);
                                  },
                                  title: Text(tr(context, 'Repeat selected surah')),
                                  subtitle: Text(
                                    tr(context, controller.hasAudioResumePoint
                                        ? 'Resume point: ${_formatMillis(controller.audioResumePositionMillis)}'
                                        : 'Playback will continue from the beginning.'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: sectionGap),
                        AppStagger(
                          index: 3,
                          child: ReaderSheetCard(
                            child: ReaderAudioPracticePanel(
                              key: ValueKey('${audio.currentChapterId}:${audio.selectedReciter?.id}'),
                              service: controller.audioPracticeService,
                              audio: audio,
                              verseKey: controller.currentRecitationVerseKey,
                            ),
                          ),
                        ),
                        SizedBox(height: sectionGap),
                        AppStagger(
                          index: 4,
                          child: ReaderSheetCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _AudioSectionLabel(
                                        label: tr(context, 'Listen offline'),
                                      ),
                                    ),
                                    if (controller.isSelectedAudioDownloaded)
                                      Chip(
                                        avatar: const Icon(
                                          Icons.offline_pin_rounded,
                                          size: 18,
                                        ),
                                        label: Text(tr(context, 'Available offline')),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (compact) ...[
                                  downloadButton,
                                  const SizedBox(height: 10),
                                  removeDownloadButton,
                                ] else
                                  Row(
                                    children: [
                                      Expanded(child: downloadButton),
                                      const SizedBox(width: 12),
                                      Expanded(child: removeDownloadButton),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class ReaderAudioVersePanel extends StatelessWidget {
  const ReaderAudioVersePanel({super.key, required this.verse});

  final QuranPageVerse? verse;

  @override
  Widget build(BuildContext context) {
    final current = verse;
    if (current == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr(context, 'Audio Ayah'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  current.verseKey,
                  key: const ValueKey('audio-ayah-reference'),
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            if (current.translationEn.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(tr(context, 'English'), style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              SelectableText(
                current.translationEn,
                key: const ValueKey('audio-ayah-en'),
                textDirection: TextDirection.ltr,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ],
            if (current.translationUr.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(tr(context, 'Urdu'), style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              SelectableText(
                current.translationUr,
                key: const ValueKey('audio-ayah-ur'),
                textDirection: TextDirection.rtl,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.8),
              ),
            ],
            if (current.translationEn.trim().isEmpty &&
                current.translationUr.trim().isEmpty) ...[
              const SizedBox(height: 10),
              Text(tr(context, 'Translation unavailable for this Ayah.')),
            ],
          ],
        ),
      ),
    );
  }
}

class _AudioSectionLabel extends StatelessWidget {
  const _AudioSectionLabel({
    required this.label,
    this.color,
  });

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      tr(context, label.toUpperCase()),
      style: theme.textTheme.labelSmall?.copyWith(
        color: color ?? theme.colorScheme.secondary,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );
  }
}

/// Status pill shown on the emerald hero card, so it takes its colours from
/// the hero tokens rather than the surface scheme.
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
    final decor = AppDecor.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: decor.onHero.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: decor.gold.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: decor.gold,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                tr(context, label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: decor.onHero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _audioFailureMessage(String error) {
  final message = error.toLowerCase();
  if (message.contains('quota') || message.contains('storage')) return 'Storage is full or unavailable. Free some space and try again.';
  if (message.contains('timeout') || message.contains('timed out')) return 'Audio took too long to load. Try again.';
  if (message.contains('socket') || message.contains('host lookup') || message.contains('xmlhttprequest') || message.contains('network')) return 'Check your internet connection and try again.';
  if (message.contains('missingplugin') || message.contains('unsupported')) return 'This audio feature is unavailable on this device.';
  return 'Unable to play or download this recitation. Try again or choose another Qari.';
}
