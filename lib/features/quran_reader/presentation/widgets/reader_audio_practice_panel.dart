import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';
import '../../data/services/quran_audio_service.dart';
import '../models/reader_audio_state.dart';

Duration? parseReaderAudioTime(String text) {
  final parts = text.trim().split(':');
  if (parts.length < 2 || parts.length > 3) return null;
  if (!RegExp(r'^\d{1,3}$').hasMatch(parts.first)) return null;
  final seconds = RegExp(r'^([0-5]\d)(?:\.(\d{1,3}))?$').firstMatch(parts.last);
  if (seconds == null) return null;
  var minutes = int.parse(parts.first);
  if (parts.length == 3) {
    if (!RegExp(r'^[0-5]\d$').hasMatch(parts[1])) return null;
    minutes = minutes * 60 + int.parse(parts[1]);
  }
  return Duration(
      minutes: minutes,
      seconds: int.parse(seconds[1]!),
      milliseconds: int.parse((seconds[2] ?? '').padRight(3, '0')));
}

String formatReaderAudioTime(Duration duration) {
  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  final millis = duration.inMilliseconds.remainder(1000);
  return '$minutes:$seconds${millis == 0 ? '' : '.${millis.toString().padLeft(3, '0')}'}';
}

class ReaderAudioPracticePanel extends StatefulWidget {
  const ReaderAudioPracticePanel(
      {super.key, required this.service, required this.audio, this.verseKey});
  final QuranAudioService service;
  final ReaderAudioState audio;
  final String? verseKey;
  @override
  State<ReaderAudioPracticePanel> createState() =>
      _ReaderAudioPracticePanelState();
}

class _ReaderAudioPracticePanelState extends State<ReaderAudioPracticePanel> {
  final _a = TextEditingController(text: '00:00');
  final _b = TextEditingController(text: '00:10');
  int _repeats = 3;
  int _gapSeconds = 2;
  int _sleepMinutes = 0;
  String? _error;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  Future<void> _begin() async {
    try {
      final start = parseReaderAudioTime(_a.text);
      final end = parseReaderAudioTime(_b.text);
      if (start == null || end == null) {
        throw const FormatException(
            'Enter times as minutes:seconds, with optional milliseconds.');
      }
      setState(() => _error = null);
      await widget.service.practice.begin(
          start: start,
          end: end,
          repetitions: _repeats,
          gap: Duration(seconds: _gapSeconds));
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is FormatException
            ? error.message
            : 'A–B practice stopped. Try loading the recitation again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final practice = widget.service.practice;
    final theme = Theme.of(context);
    final loaded = !widget.audio.isLoading &&
        !widget.audio.isBuffering &&
        widget.audio.errorMessage == null &&
        widget.audio.durationMillis > 0 &&
        widget.audio.currentChapterId == widget.service.loadedChapterId &&
        widget.audio.selectedReciter?.id == widget.service.loadedReciterId;
    return AnimatedBuilder(
        animation: practice,
        builder: (context, _) {
          final range = widget.verseKey == null
              ? null
              : widget.service.practiceRangeForAyah(widget.verseKey!);
          final remaining = practice.sleepUntil?.difference(DateTime.now());
          return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(context, 'Audio practice'),
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(tr(context,
                      'Choose an audio section, repeat it, and leave a pause to recite along.')),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: _a,
                            enabled: !practice.active && !practice.busy,
                            keyboardType: TextInputType.datetime,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                                labelText: tr(context, 'A · start time'),
                                hintText: '00:00'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextField(
                            controller: _b,
                            enabled: !practice.active && !practice.busy,
                            keyboardType: TextInputType.datetime,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                                labelText: tr(context, 'B · end time'),
                                hintText: '00:10'))),
                  ]),
                  Wrap(spacing: 8, children: [
                    TextButton(
                        onPressed: !loaded || practice.active || practice.busy
                            ? null
                            : () => _a.text = formatReaderAudioTime(Duration(
                                milliseconds: widget.audio.positionMillis)),
                        child: Text(tr(context, 'Set A here'))),
                    TextButton(
                        onPressed: !loaded || practice.active || practice.busy
                            ? null
                            : () => _b.text = formatReaderAudioTime(Duration(
                                milliseconds: widget.audio.positionMillis)),
                        child: Text(tr(context, 'Set B here'))),
                    TextButton(
                        onPressed: !loaded ||
                                range == null ||
                                practice.active ||
                                practice.busy
                            ? null
                            : () {
                                _a.text = formatReaderAudioTime(range.start);
                                _b.text = formatReaderAudioTime(range.end);
                              },
                        child: Text(tr(context, 'Use current Ayah'))),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: DropdownButtonFormField<int>(
                            initialValue: _repeats,
                            decoration: InputDecoration(
                                labelText: tr(context, 'Repeats')),
                            items: [
                              for (final value in [3, 5, 10])
                                DropdownMenuItem(
                                    value: value, child: Text('$value'))
                            ],
                            onChanged: practice.active || practice.busy
                                ? null
                                : (value) =>
                                    setState(() => _repeats = value ?? 3))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: DropdownButtonFormField<int>(
                            initialValue: _gapSeconds,
                            decoration: InputDecoration(
                                labelText:
                                    tr(context, 'Pause between repeats')),
                            items: [
                              for (final value in [0, 2, 5, 10, 30])
                                DropdownMenuItem(
                                    value: value,
                                    child: Text(tr(context, '{seconds} seconds',
                                        args: {'seconds': value})))
                            ],
                            onChanged: practice.active || practice.busy
                                ? null
                                : (value) =>
                                    setState(() => _gapSeconds = value ?? 0))),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 10, runSpacing: 8, children: [
                    FilledButton.tonal(
                        onPressed: !loaded || practice.active || practice.busy
                            ? null
                            : _begin,
                        child: Text(tr(context, 'Start A–B practice'))),
                    if (practice.active || practice.busy)
                      OutlinedButton(
                          onPressed: () async {
                            try {
                              await practice.cancel();
                              await widget.service.pause();
                            } catch (_) {
                              if (mounted) {
                                setState(() => _error =
                                    'A–B practice stopped. Try loading the recitation again.');
                              }
                            }
                          },
                          child: Text(tr(context, 'Cancel practice'))),
                  ]),
                  if (practice.active || practice.completed > 0) ...[
                    const SizedBox(height: 8),
                    Text(tr(context, 'Completed {done} of {total}', args: {
                      'done': practice.completed,
                      'total': practice.repetitions,
                    })),
                    if (practice.waiting)
                      Text(tr(context, 'Waiting between repeats')),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                      initialValue: _sleepMinutes,
                      decoration: InputDecoration(
                          labelText: tr(context, 'Sleep timer')),
                      items: [
                        for (final value in [0, 5, 15, 30, 60])
                          DropdownMenuItem(
                              value: value,
                              child: Text(tr(context,
                                  value == 0 ? 'Off' : '{minutes} minutes',
                                  args: {'minutes': value})))
                      ],
                      onChanged: (value) {
                        setState(() => _sleepMinutes = value ?? 0);
                        practice.setSleepTimer(value == null || value == 0
                            ? null
                            : Duration(minutes: value));
                      }),
                  if (remaining != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                            tr(context, 'Playback pauses in {time}', args: {
                          'time': formatReaderAudioTime(
                              remaining.isNegative ? Duration.zero : remaining),
                        }))),
                  if (_error != null || practice.errorMessage != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                            tr(context, _error ?? practice.errorMessage!),
                            style: TextStyle(color: theme.colorScheme.error))),
                ],
              ));
        });
  }
}
