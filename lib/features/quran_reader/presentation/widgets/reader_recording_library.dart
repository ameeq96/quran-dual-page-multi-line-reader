import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';
import '../../../../core/services/reader_recording_store.dart';
import '../../../../core/services/reader_voice_capture.dart';
import '../../../../core/storage/reader_profile_store.dart';

class ReaderRecordingSaveControls extends StatefulWidget {
  const ReaderRecordingSaveControls(
      {super.key,
      required this.capture,
      this.profileId,
      this.chapterId,
      this.chapterName,
      this.store});
  final ReaderVoiceCapture capture;
  final String? profileId;
  final int? chapterId;
  final String? chapterName;
  final ReaderRecordingStore? store;
  @override
  State<ReaderRecordingSaveControls> createState() =>
      _ReaderRecordingSaveControlsState();
}

class _ReaderRecordingSaveControlsState
    extends State<ReaderRecordingSaveControls> {
  late final String _profileId;
  late final ReaderRecordingStore _store;
  bool _saving = false;
  int? _savedRevision;
  String? _message;
  @override
  void initState() {
    super.initState();
    _profileId = widget.profileId ?? ReaderProfileStore.instance.activeId;
    _store = widget.store ?? ReaderRecordingStore(profileId: _profileId);
    if (_store.profileId != _profileId) {
      throw ArgumentError('Recording profile mismatch.');
    }
  }

  @override
  void dispose() {
    if (widget.store == null) _store.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || widget.capture.isBusy || !widget.capture.hasRecording) {
      return;
    }
    final capture = widget.capture;
    final revision = capture.recordingRevision;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final details = await showDialog<({String label, String reference})>(
          context: context,
          builder: (_) =>
              _RecordingSaveDialog(initialReference: widget.chapterName ?? ''));
      if (details == null || !mounted) return;
      final bytes = await capture.readRecordingBytes();
      if (!mounted ||
          capture.recordingRevision != revision ||
          ReaderProfileStore.instance.activeId != _profileId) {
        throw const ReaderRecordingFailure(
            'The recording changed before it could be saved.');
      }
      await _store.save(
          bytes: bytes,
          mimeType: capture.recordingMimeType,
          duration: capture.elapsed,
          label: details.label,
          reference: details.reference,
          chapterId: details.reference.trim() == widget.chapterName?.trim()
              ? widget.chapterId
              : null);
      if (mounted) {
        setState(() {
          _savedRevision = revision;
          _message = 'Recording saved to this profile.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = error is ReaderRecordingFailure
            ? error.message
            : 'The recording could not be saved. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.capture,
      builder: (context, _) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton.tonalIcon(
                onPressed: !_store.supported ||
                        _saving ||
                        widget.capture.isBusy ||
                        !widget.capture.hasRecording ||
                        _savedRevision == widget.capture.recordingRevision
                    ? null
                    : _save,
                icon: const Icon(Icons.save_outlined),
                label:
                    Text(tr(context, _saving ? 'Saving…' : 'Save recording'))),
            OutlinedButton.icon(
                onPressed: _saving || widget.capture.isBusy
                    ? null
                    : () async {
                        if (widget.capture.isPlaying) {
                          await widget.capture.togglePlayback();
                        }
                        if (!context.mounted) return;
                        Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => ReaderRecordingLibraryScreen(
                                profileId: _profileId)));
                      },
                icon: const Icon(Icons.library_music_outlined),
                label: Text(tr(context, 'My recordings'))),
          ]),
          if (_message != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(tr(context, _message!))),
        ]);
      });
}

class _RecordingSaveDialog extends StatefulWidget {
  const _RecordingSaveDialog({required this.initialReference});
  final String initialReference;
  @override
  State<_RecordingSaveDialog> createState() => _RecordingSaveDialogState();
}

class _RecordingSaveDialogState extends State<_RecordingSaveDialog> {
  final _label = TextEditingController();
  late final TextEditingController _reference;
  @override
  void initState() {
    super.initState();
    _reference = TextEditingController(text: widget.initialReference);
  }

  @override
  void dispose() {
    _label.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(tr(context, 'Save recording')),
        content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(tr(context,
                      'Saved only in this browser and this profile. Clearing browser data removes saved recordings.')),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _label,
                      maxLength: 120,
                      decoration: InputDecoration(
                          labelText: tr(context, 'Recording label'),
                          hintText: tr(context, 'Practice recording'))),
                  TextField(
                      controller: _reference,
                      maxLength: 120,
                      decoration: InputDecoration(
                          labelText:
                              tr(context, 'Surah or reference (optional)'))),
                ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr(context, 'Cancel'))),
          FilledButton(
              onPressed: () => Navigator.of(context).pop((
                    label: _label.text.trim(),
                    reference: _reference.text.trim()
                  )),
              child: Text(tr(context, 'Save'))),
        ],
      );
}

class ReaderRecordingLibraryScreen extends StatefulWidget {
  const ReaderRecordingLibraryScreen({super.key, this.profileId});
  final String? profileId;
  @override
  State<ReaderRecordingLibraryScreen> createState() =>
      _ReaderRecordingLibraryScreenState();
}

class _ReaderRecordingLibraryScreenState
    extends State<ReaderRecordingLibraryScreen> with WidgetsBindingObserver {
  late final ReaderRecordingStore _store;
  final _selected = <String>{};
  String? _error;
  @override
  void initState() {
    super.initState();
    _store = ReaderRecordingStore(
        profileId: widget.profileId ?? ReaderProfileStore.instance.activeId);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_store.refresh().catchError((_) {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _store.stopPlayback();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      setState(() => _error = null);
      await action();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ReaderRecordingFailure
            ? error.message
            : 'The recording library could not complete this action.');
      }
    }
  }

  Future<void> _delete(ReaderLocalRecording recording) async {
    final accepted = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  title: Text(tr(context, 'Delete this recording?')),
                  content: Text(recording.label.isEmpty
                      ? tr(context, 'Practice recording')
                      : recording.label),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(tr(context, 'Cancel'))),
                    FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(tr(context, 'Delete'))),
                  ],
                )) ??
        false;
    if (accepted && mounted) {
      await _run(() async {
        await _store.delete(recording.id);
        if (mounted) setState(() => _selected.remove(recording.id));
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr(context, 'My recordings'))),
        body: AnimatedBuilder(
            animation: _store,
            builder: (context, _) {
              final entries = _store.recordings;
              final bytes =
                  entries.fold<int>(0, (total, entry) => total + entry.bytes);
              return ListView(padding: const EdgeInsets.all(20), children: [
                Text(tr(context,
                    'Your recordings stay in this browser profile and are never uploaded by the recording library.')),
                const SizedBox(height: 8),
                Text(tr(context, '{count} recordings · {size} MB', args: {
                  'count': entries.length,
                  'size': (bytes / (1024 * 1024)).toStringAsFixed(1),
                })),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 8, children: [
                  OutlinedButton.icon(
                      onPressed:
                          _store.busy ? null : () => _run(_store.refresh),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(tr(context, 'Refresh'))),
                  FilledButton.tonalIcon(
                      onPressed: _store.busy || _selected.length != 2
                          ? null
                          : () => _run(() {
                                final ids = _selected.toList();
                                return _store.compare(ids[0], ids[1]);
                              }),
                      icon: const Icon(Icons.compare_arrows_rounded),
                      label: Text(tr(context, 'Compare selected recordings'))),
                  if (_store.playingId != null)
                    OutlinedButton.icon(
                        onPressed: _store.stopPlayback,
                        icon: const Icon(Icons.stop_rounded),
                        label: Text(tr(context, 'Stop playback'))),
                ]),
                const SizedBox(height: 8),
                Text(tr(context,
                    'Select two recordings to hear them one after the other.')),
                if (_store.comparisonIndex > 0)
                  Text(tr(context, 'Playing recording {index} of 2',
                      args: {'index': _store.comparisonIndex})),
                if (_error != null || _store.errorMessage != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(tr(context, _error ?? _store.errorMessage!),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                if (_store.busy)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator()),
                if (entries.isEmpty && !_store.busy)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(tr(context,
                          'Save a recording from Voice input to build your practice library.'))),
                for (final recording in entries)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(recording.label.isEmpty
                                      ? tr(context, 'Practice recording')
                                      : recording.label),
                                  subtitle: Text(recording.reference.isEmpty
                                      ? tr(context, 'Surah not specified')
                                      : recording.reference),
                                  value: _selected.contains(recording.id),
                                  onChanged: _store.busy ||
                                          !_selected.contains(recording.id) &&
                                              _selected.length >= 2
                                      ? null
                                      : (value) {
                                          setState(() {
                                            if (value == true) {
                                              _selected.add(recording.id);
                                            } else {
                                              _selected.remove(recording.id);
                                            }
                                          });
                                        }),
                              Text(
                                  '${MaterialLocalizations.of(context).formatShortDate(recording.createdAt.toLocal())} · '
                                  '${TimeOfDay.fromDateTime(recording.createdAt.toLocal()).format(context)} · '
                                  '${(recording.durationMillis / 1000).toStringAsFixed(1)} s'),
                              Wrap(spacing: 10, children: [
                                TextButton.icon(
                                    onPressed: _store.busy
                                        ? null
                                        : () => _run(
                                            () => _store.play(recording.id)),
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: Text(tr(context, 'Play recording'))),
                                TextButton.icon(
                                    onPressed: _store.busy
                                        ? null
                                        : () => _delete(recording),
                                    icon: const Icon(
                                        Icons.delete_outline_rounded),
                                    label: Text(tr(context, 'Delete'))),
                              ]),
                            ],
                          ))),
              ]);
            }),
      );
}
