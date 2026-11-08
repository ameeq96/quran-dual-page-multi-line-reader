import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;

import '../../../../app/reader_localization.dart';
import '../../../../app/app_theme.dart';
import '../../../../core/services/quran_study_binary_export.dart';
import '../../../../core/services/quran_study_export.dart';
import '../../data/services/quran_study_data_source.dart';
import '../../domain/models/quran_study_models.dart';
import '../controllers/quran_reader_controller.dart';

class QuranStudyScreen extends StatefulWidget {
  const QuranStudyScreen({super.key, this.initialVerseKey = '1:1', this.controller});
  final String initialVerseKey;
  final QuranReaderController? controller;
  @override
  State<QuranStudyScreen> createState() => _QuranStudyScreenState();
}

class _QuranStudyScreenState extends State<QuranStudyScreen> {
  final _source = QuranStudyDataSource();
  late final TextEditingController _reference;
  final _note = TextEditingController();
  QuranStudyVerse? _verse;
  QuranStudyCollection? _collection;
  bool _duas = true;
  bool _loading = true;
  bool _onlineBusy = false;
  bool _exporting = false;
  bool _urdu = false;
  String? _error;
  int _selection = 0;

  @override
  void initState() {
    super.initState();
    _reference = TextEditingController(text: widget.initialVerseKey);
    _urdu = ReaderLocalization.instance.language == ReaderLanguage.urdu;
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _source.initialize();
      if (!mounted) return;
      _openReference(widget.initialVerseKey, initial: true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Study data could not be opened. Try again.');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  void _openReference(String reference, {bool initial = false}) {
    try {
      final verse = _source.verse(reference.trim());
      setState(() {
        if (_verse?.reference != verse.reference) _note.clear();
        _selection++; _onlineBusy = false; _verse = verse;
        _reference.text = verse.reference; _error = null;
      });
    } on FormatException {
      if (initial && reference != '1:1') { _openReference('1:1'); return; }
      _notice('Enter a valid Surah:Ayah reference.');
    }
  }

  void _notice(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, text))));
  }

  Future<void> _loadMeanings() async {
    final verse = _verse;
    if (verse == null || _onlineBusy) return;
    final selected = _selection;
    setState(() => _onlineBusy = true);
    try {
      final updated = await _source.loadOnlineMeanings(verse.reference, urdu: _urdu);
      if (mounted && selected == _selection) setState(() => _verse = updated);
    } catch (_) {
      if (mounted && selected == _selection) _notice('Word meanings could not be loaded. Offline study is still available.');
    } finally { if (mounted && selected == _selection) setState(() => _onlineBusy = false); }
  }

  Future<void> _export({required bool pdf, bool collection = false}) async {
    if (_verse == null || _exporting) return;
    final references = collection && _collection != null ? _collection!.references : [_verse!.reference];
    final collectionId = _collection?.id;
    final selectedReference = _verse!.reference;
    final note = _note.text.trim();
    final noteLabel = tr(context, 'Personal study note');
    final urdu = _urdu;
    setState(() => _exporting = true);
    try {
      final cards = <QuranStudyCard>[];
      for (final reference in references) {
        cards.add(await QuranStudyExport.render(_source.verse(reference), urdu: urdu,
          notes: reference == selectedReference ? note : '', noteLabel: noteLabel));
      }
      final label = collection ? 'collection_${collectionId!.replaceAll('-', '_')}' : references.first.replaceAll(':', '_');
      await exportQuranStudyBytes(fileName: 'quran_${label}_${urdu ? 'ur' : 'en'}.${pdf ? 'pdf' : 'png'}',
        bytes: pdf ? QuranStudyExport.pdf(cards) : cards.single.png,
        mimeType: pdf ? 'application/pdf' : 'image/png');
      _notice('Study export is ready.');
    } on StateError catch (error) {
      _notice(error.message == 'This Ayah and note are too long for a single card.'
          ? 'This Ayah and note do not fit on one card. Shorten the note or reduce line breaks. Your note is still here.'
          : 'Study export could not be saved. Try again.');
    } catch (_) { _notice('Study export could not be saved. Try again.'); }
    finally { if (mounted) setState(() => _exporting = false); }
  }

  Future<void> _showSources() async {
    final license = await _source.licenses();
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: Text(tr(context, 'Sources and licenses')),
      content: SizedBox(width: 620, child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SelectableText(QuranStudyDataSource.corpusNotice),
          const SizedBox(height: 12),
          const SelectableText('https://corpus.quran.com/download/\nhttps://corpus.quran.com/java/buckwalter.jsp\nhttps://tanzil.info'),
          const SizedBox(height: 12),
          const SelectableText(QuranStudyDataSource.translationNotice),
          const SizedBox(height: 12),
          Text(tr(context, 'Online meanings: Quran Foundation / Quran.com. They are cleared when the app closes.')),
          const SelectableText('https://api-docs.quran.com/legal/developer-terms/'),
          const SizedBox(height: 16), SelectableText(license),
        ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr(context, 'Close')))],
    ));
  }

  @override
  void dispose() { _selection++; _source.dispose(); _reference.dispose(); _note.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller == null) return _buildStudy(context);
    return AnimatedBuilder(animation: Listenable.merge([
      controller.settingsListenable, controller.experienceListenable,
    ]), builder: (context, _) {
      final experience = controller.experienceSettings;
      final theme = controller.settings.nightMode
          ? AppTheme.dark(highContrast: experience.highContrastMode, largerText: experience.largerTextMode)
          : AppTheme.light(highContrast: experience.highContrastMode, largerText: experience.largerTextMode);
      return Theme(data: theme, child: Builder(builder: _buildStudy));
    });
  }

  Widget _buildStudy(BuildContext context) {
    final theme = Theme.of(context);
    final verse = _verse;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Quran study')),
        actions: [IconButton(onPressed: _loading ? null : _showSources,
          tooltip: tr(context, 'Sources and licenses'), icon: const Icon(Icons.info_outline_rounded))]),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : _error != null ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(24), child: Text(tr(context, _error!))),
          FilledButton(onPressed: _initialize, child: Text(tr(context, 'Try again'))),
        ])) : SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(context, 'Explore an Ayah'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(tr(context, 'Study references, word roots and translations without changing your Mushaf pages.')),
              const SizedBox(height: 18),
              Row(children: [Expanded(child: TextField(controller: _reference,
                textDirection: TextDirection.ltr, keyboardType: TextInputType.text,
                decoration: InputDecoration(labelText: tr(context, 'Surah:Ayah'), hintText: '2:201',
                  border: const OutlineInputBorder()), onSubmitted: _openReference)),
                const SizedBox(width: 10), FilledButton(onPressed: () => _openReference(_reference.text), child: Text(tr(context, 'Open')))]),
              const SizedBox(height: 24),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: Text(tr(context, 'Quranic duas')), selected: _duas, onSelected: (_) => setState(() => _duas = true)),
                ChoiceChip(label: Text(tr(context, 'Topics')), selected: !_duas, onSelected: (_) => setState(() => _duas = false)),
              ]),
              const SizedBox(height: 10),
              Text(tr(context, 'Curated references. Read each complete Ayah in its context.'), style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: quranStudyCollections.where((item) => item.isDua == _duas).map((item) => ChoiceChip(
                label: Text(tr(context, item.title)), selected: _collection?.id == item.id,
                onSelected: (_) { setState(() => _collection = item); _openReference(item.references.first); })).toList()),
              if (_collection != null) ...[
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: _collection!.references.map((reference) => ActionChip(
                  label: Text(reference), onPressed: () => _openReference(reference))).toList()),
              ],
              if (verse != null) ...[
                const SizedBox(height: 24),
                Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('${verse.chapterName} · ${verse.reference}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 18),
                  SelectableText(verse.arabic, textDirection: TextDirection.rtl, textAlign: TextAlign.right,
                    style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: (theme.textTheme.headlineSmall?.fontSize ?? 24) * 1.25, height: 1.9)),
                  const Divider(height: 32),
                  Wrap(spacing: 8, children: [
                    ChoiceChip(label: Text(tr(context, 'English')), selected: !_urdu, onSelected: (_) => setState(() => _urdu = false)),
                    ChoiceChip(label: Text(tr(context, 'Urdu')), selected: _urdu, onSelected: (_) => setState(() => _urdu = true)),
                  ]),
                  const SizedBox(height: 12),
                  SelectableText(_urdu ? verse.urdu : verse.english, textDirection: _urdu ? TextDirection.rtl : TextDirection.ltr,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.7)),
                  const SizedBox(height: 18),
                  TextField(controller: _note, minLines: 3, maxLines: 6, maxLength: 2000,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    decoration: InputDecoration(labelText: tr(context, 'Personal study note (export only)'),
                      border: const OutlineInputBorder())),
                  Text(tr(context, 'This note is included in exports only. Download it before changing the Ayah or leaving.'),
                    style: theme.textTheme.bodySmall),
                  const SizedBox(height: 18),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    OutlinedButton.icon(onPressed: _exporting ? null : () => _export(pdf: false),
                      icon: const Icon(Icons.image_outlined), label: Text(tr(context, 'Share PNG card'))),
                    OutlinedButton.icon(onPressed: _exporting ? null : () => _export(pdf: true),
                      icon: const Icon(Icons.picture_as_pdf_outlined), label: Text(tr(context, 'Export PDF'))),
                    if (_collection != null) OutlinedButton.icon(onPressed: _exporting ? null : () => _export(pdf: true, collection: true),
                      icon: const Icon(Icons.collections_bookmark_outlined), label: Text(tr(context, 'Export collection PDF'))),
                  ]),
                  if (_exporting) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
                ]))),
                const SizedBox(height: 24),
                Text(tr(context, 'Word by word'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(tr(context, 'All roots and word forms are available offline. Al-Fatihah also includes offline English meanings and pronunciation.')),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(onPressed: _onlineBusy ? null : _loadMeanings,
                  icon: const Icon(Icons.cloud_download_outlined), label: Text(tr(context, _urdu ? 'Load Urdu meanings online' : 'Load English meanings online'))),
                if (_onlineBusy) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
                const SizedBox(height: 14),
                LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 800 ? 5 : constraints.maxWidth >= 560 ? 4 : constraints.maxWidth >= 400 ? 3 : 2;
                  final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
                  return Directionality(textDirection: TextDirection.rtl, child: Wrap(spacing: 10, runSpacing: 10,
                    children: verse.words.map((word) => SizedBox(width: width, child: _WordCard(word))).toList()));
                }),
                const SizedBox(height: 18),
                Text(tr(context, verse.onlineMeanings ? 'Word meanings and pronunciation: Quran Foundation / Quran.com (online).'
                    : 'Word forms, roots and Al-Fatihah glosses: Quranic Arabic Corpus.')),
                const SizedBox(height: 8),
                Text(tr(context, 'A root is shown only when it is listed in the source. Transliteration is a reading aid, not recitation assessment.'), style: theme.textTheme.bodySmall),
                const SizedBox(height: 20),
              ],
            ])),
        ))),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard(this.word);
  final QuranStudyWord word;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meaningRtl = word.meaning != null && RegExp(r'[\u0600-\u06FF]').hasMatch(word.meaning!);
    return Card(margin: EdgeInsets.zero, child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Text('${word.position}', style: theme.textTheme.labelSmall),
      const SizedBox(height: 6),
      SelectableText(word.arabic, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 27, height: 1.6)),
      if (word.transliteration != null) Padding(padding: const EdgeInsets.only(top: 6),
        child: SelectableText(word.transliteration!, textDirection: TextDirection.ltr, textAlign: TextAlign.center)),
      const SizedBox(height: 8),
      Text(word.meaning ?? tr(context, 'Meaning not loaded'), textDirection: word.meaning == null ? null : meaningRtl ? TextDirection.rtl : TextDirection.ltr,
        textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
      const Divider(height: 18),
      Text(tr(context, 'Root'), style: theme.textTheme.labelSmall),
      SelectableText(word.root ?? tr(context, 'Not listed'), textDirection: TextDirection.rtl,
        textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
      if (word.partOfSpeech.isNotEmpty) Text(word.partOfSpeech, textDirection: TextDirection.ltr,
        textAlign: TextAlign.center, style: theme.textTheme.labelSmall),
    ])));
  }
}
