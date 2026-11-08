import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';
import '../../../../core/storage/reader_backup_history.dart';
import '../../../../core/storage/reader_profile_store.dart';
import '../controllers/quran_reader_controller.dart';

class ReaderLocalDataSettings extends StatefulWidget {
  const ReaderLocalDataSettings({super.key, required this.controller});
  final QuranReaderController controller;
  @override
  State<ReaderLocalDataSettings> createState() => _ReaderLocalDataSettingsState();
}

class _ReaderLocalDataSettingsState extends State<ReaderLocalDataSettings> {
  bool _busy = false;
  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try { await task(); }
    catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'Local data could not be saved. Your current profile is unchanged.'))));
    } finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _name({ReaderLocalProfile? profile}) async {
    final name = await showDialog<String>(context: context, builder: (_) => _ProfileNameDialog(profile: profile));
    if (name == null || !mounted) return;
    await _run(() async {
      if (profile == null) { await ReaderProfileStore.instance.create(name); }
      else { await ReaderProfileStore.instance.rename(profile.id, name); }
    });
  }
  Future<void> _switch(String id) => _run(() async {
    await widget.controller.prepareForLocalProfileSwitch();
    await ReaderProfileStore.instance.activate(id);
  });
  Future<void> _history() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _RestoreHistoryScreen(controller: widget.controller)));
    if (mounted) setState(() {});
  }
  @override
  Widget build(BuildContext context) {
    final store = ReaderProfileStore.instance;
    return AnimatedBuilder(animation: store, builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr(context, 'Family profiles'), style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      Text(tr(context, 'Separate reading progress, bookmarks, notes and settings on this browser. Profiles are not password protected.')),
      const SizedBox(height: 12),
      ...store.profiles.map((p) => ListTile(contentPadding: EdgeInsets.zero,
        leading: Icon(p.id == store.activeId ? Icons.account_circle : Icons.account_circle_outlined),
        title: Text(p.name == 'Main reader' ? tr(context, p.name) : p.name),
        subtitle: p.id == store.activeId ? Text(tr(context, 'Current profile')) : null,
        trailing: IconButton(tooltip: tr(context, 'Rename profile'), onPressed: _busy ? null : () => _name(profile: p), icon: const Icon(Icons.edit_outlined)),
        onTap: _busy || p.id == store.activeId ? null : () => _switch(p.id))),
      OutlinedButton.icon(onPressed: _busy || store.profiles.length >= 8 ? null : () => _name(), icon: const Icon(Icons.person_add_alt), label: Text(tr(context, 'New local profile'))),
      const Divider(height: 32),
      Text(tr(context, 'Restore history & Undo'), style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      Text(tr(context, 'Up to 15 local restore points. Changes are saved automatically; deletions and replacements keep a copy first. Browser data removal also removes this history.')),
      const SizedBox(height: 10),
      if (widget.controller.backupHistoryError case final error?) Text(tr(context, error), style: TextStyle(color: Theme.of(context).colorScheme.error)),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.tonalIcon(onPressed: _busy ? null : _history, icon: const Icon(Icons.history), label: Text(tr(context, 'Restore history & Undo'))),
        OutlinedButton.icon(onPressed: _busy ? null : () => _run(() => widget.controller.saveRestorePoint('Manual backup', force: true)), icon: const Icon(Icons.save_outlined), label: Text(tr(context, 'Save restore point'))),
      ]),
      if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
    ]));
  }
}

class _ProfileNameDialog extends StatefulWidget {
  const _ProfileNameDialog({this.profile});
  final ReaderLocalProfile? profile;
  @override
  State<_ProfileNameDialog> createState() => _ProfileNameDialogState();
}
class _ProfileNameDialogState extends State<_ProfileNameDialog> {
  late final _text = TextEditingController(text: widget.profile?.name ?? '');
  @override
  void dispose() { _text.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr(context, widget.profile == null ? 'New local profile' : 'Rename profile')),
    content: TextField(controller: _text, autofocus: true, maxLength: 40, decoration: InputDecoration(labelText: tr(context, 'Profile name'))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr(context, 'Cancel'))),
      FilledButton(onPressed: () { if (_text.text.trim().isNotEmpty) Navigator.pop(context, _text.text.trim()); }, child: Text(tr(context, 'Save')))],
  );
}

class _RestoreHistoryScreen extends StatefulWidget {
  const _RestoreHistoryScreen({required this.controller});
  final QuranReaderController controller;
  @override
  State<_RestoreHistoryScreen> createState() => _RestoreHistoryScreenState();
}
class _RestoreHistoryScreenState extends State<_RestoreHistoryScreen> {
  late Future<List<ReaderRestorePoint>> _points = widget.controller.backupHistory.list();
  bool _busy = false;
  String? _error;
  Future<void> _restore(ReaderRestorePoint point) async {
    final approved = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: Text(tr(dialog, 'Restore this point?')),
      content: Text(tr(dialog, 'This replaces this profile’s reader data. A copy of your current reader data is saved first, so you can undo the restore. Recordings and image pins are kept separately.')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(tr(dialog, 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(tr(dialog, 'Restore')))],
    ));
    if (approved != true || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.controller.restoreHistoryPoint(point);
      if (mounted) {
        setState(() => _points = widget.controller.backupHistory.list());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'Reader data restored. Use Undo last data change to undo the restore.'))));
      }
    } catch (_) { if (mounted) setState(() => _error = 'Restore failed. Your saved restore points are still available.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, 'Restore history & Undo'))),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: FutureBuilder<List<ReaderRestorePoint>>(
      future: _points, builder: (context, snapshot) {
        if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(24), child: Text(tr(context, 'Restore history could not be read. Export your current reader data before clearing browser storage.')));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final points = snapshot.data!;
        final undoPoints = points.where((point) => point.reason.startsWith('Before '));
        return ListView(padding: const EdgeInsets.all(20), children: [
          if (_error != null) Text(tr(context, _error!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (_busy) const LinearProgressIndicator(),
          if (undoPoints.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 16), child: FilledButton.icon(
            onPressed: _busy ? null : () => _restore(undoPoints.first), icon: const Icon(Icons.undo), label: Text(tr(context, 'Undo last data change')))),
          if (points.isEmpty) Text(tr(context, 'No restore points yet. Use Save restore point, or make a reading change.')),
          for (final point in points) Card(child: ListTile(
            leading: const Icon(Icons.restore), title: Text(tr(context, point.reason)),
            subtitle: Text('${point.createdAt.toLocal()}'.split('.').first),
            trailing: OutlinedButton(onPressed: _busy ? null : () => _restore(point), child: Text(tr(context, 'Restore'))),
          )),
        ]);
      },
    ))),
  );
}
