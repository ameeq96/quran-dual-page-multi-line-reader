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

  Future<void> _showRootResults(BuildContext studyContext, String root) async {
    final references = _source.referencesForRoot(root);
    final selected = await showModalBottomSheet<String>(context: studyContext,
      isScrollControlled: true, useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 760),
      builder: (context) => SizedBox(height: MediaQuery.sizeOf(context).height * 0.8,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(_rootLabel(context, english: 'Root search', urdu: 'مادّے کی تلاش', arabic: 'البحث بالجذر'),
                  style: Theme.of(context).textTheme.titleLarge)),
                IconButton(onPressed: () => Navigator.pop(context),
                  tooltip: tr(context, 'Close'), icon: const Icon(Icons.close_rounded)),
              ]),
              Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                SelectableText(root, textDirection: TextDirection.rtl,
                  style: Theme.of(context).textTheme.headlineSmall),
                Text(_rootLabel(context, english: '${references.length} Ayahs',
                  urdu: '${references.length} آیات', arabic: '${references.length} آية')),
              ]),
              const SizedBox(height: 10),
              Text(_rootLabel(context,
                english: 'Matches use only roots listed in the Quranic Arabic Corpus. Tap a result to study its complete Ayah.',
                urdu: 'نتائج صرف Quranic Arabic Corpus میں درج مادّوں پر مبنی ہیں۔ مکمل آیت پڑھنے کے لیے نتیجہ کھولیں۔',
                arabic: 'تعتمد النتائج فقط على الجذور الواردة في Quranic Arabic Corpus. اضغط على النتيجة لدراسة الآية كاملة.'),
                style: Theme.of(context).textTheme.bodySmall),
            ]))),
          if (references.isEmpty) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(20),
            child: Text(_rootLabel(context, english: 'No Ayahs found for this source root.',
              urdu: 'اس درج شدہ مادّے کے لیے کوئی آیت نہیں ملی۔', arabic: 'لم يتم العثور على آيات لهذا الجذر الوارد في المصدر.')))),
          SliverList(delegate: SliverChildBuilderDelegate((context, index) {
            final verse = _source.verse(references[index]);
            return Column(children: [
              ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                title: Text('${verse.chapterName} · ${verse.reference}', textDirection: TextDirection.ltr),
                subtitle: Padding(padding: const EdgeInsets.only(top: 8),
                  child: Text(verse.arabic, textDirection: TextDirection.rtl, textAlign: TextAlign.right,
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.7))),
                onTap: () => Navigator.pop(context, verse.reference)),
              const Divider(height: 1),
            ]);
          }, childCount: references.length)),
        ])));
    if (!mounted || selected == null) return;
    _openReference(selected);
  }

  Future<void> _showAyahComparison(BuildContext studyContext) => showDialog<void>(
    context: studyContext,
    builder: (_) => _AyahComparisonDialog(
      source: _source,
      initialReference: _verse?.reference ?? widget.initialVerseKey,
    ),
  );

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
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _showAyahComparison(context),
                icon: const Icon(Icons.compare_arrows_rounded),
                label: Text(_rootLabel(context, english: 'Compare Ayahs',
                  urdu: 'آیات کا موازنہ', arabic: 'مقارنة الآيات')),
              ),
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
                    children: verse.words.map((word) => SizedBox(width: width, child: _WordCard(word,
                      onRootSelected: (root) => _showRootResults(context, root)))).toList()));
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

class _AyahComparisonDialog extends StatefulWidget {
  const _AyahComparisonDialog({required this.source, required this.initialReference});
  final QuranStudyDataSource source;
  final String initialReference;

  @override
  State<_AyahComparisonDialog> createState() => _AyahComparisonDialogState();
}

class _AyahComparisonDialogState extends State<_AyahComparisonDialog> {
  late final TextEditingController _first;
  final _second = TextEditingController();
  String? _firstError;
  String? _secondError;
  List<QuranStudyVerse>? _verses;

  String _t(String english, String urdu, String arabic) =>
      _rootLabel(context, english: english, urdu: urdu, arabic: arabic);

  @override
  void initState() {
    super.initState();
    _first = TextEditingController(text: widget.initialReference);
  }

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _inputChanged(String _) {
    if (_verses == null && _firstError == null && _secondError == null) return;
    setState(() { _verses = null; _firstError = null; _secondError = null; });
  }

  void _compare() {
    QuranStudyVerse? readReference(String reference) {
      try { return widget.source.verse(reference.trim()); }
      on FormatException { return null; }
    }
    final first = readReference(_first.text);
    final second = readReference(_second.text);
    final invalid = _t('Enter a valid Surah:Ayah reference.',
      'سورت اور آیت کا درست حوالہ درج کریں۔', 'أدخل مرجعًا صحيحًا بصيغة سورة:آية.');
    setState(() {
      _firstError = first == null ? invalid : null;
      _secondError = second == null ? invalid : null;
      _verses = first == null || second == null ? null : [first, second];
    });
    if (first != null && second != null) FocusScope.of(context).unfocus();
  }

  Widget _input(TextEditingController controller, {required bool first}) =>
      TextField(
        controller: controller,
        textDirection: TextDirection.ltr,
        keyboardType: TextInputType.text,
        decoration: InputDecoration(
          labelText: first
              ? _t('First Ayah · Surah:Ayah', 'پہلی آیت · سورت:آیت', 'الآية الأولى · سورة:آية')
              : _t('Second Ayah · Surah:Ayah', 'دوسری آیت · سورت:آیت', 'الآية الثانية · سورة:آية'),
          hintText: first ? '2:201' : '3:8',
          border: const OutlineInputBorder(),
          errorText: first ? _firstError : _secondError,
          errorMaxLines: 3,
        ),
        onChanged: _inputChanged,
        onSubmitted: (_) => _compare(),
      );

  Widget _card(QuranStudyVerse verse) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${verse.chapterName} · ${verse.reference}',
              textDirection: TextDirection.ltr, style: theme.textTheme.titleLarge),
            const SizedBox(height: 14),
            SelectableText(verse.arabic, textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: theme.textTheme.headlineSmall?.copyWith(height: 1.9)),
            const Divider(height: 28),
            Text(_t('English · Quran.com resource 84',
              'انگریزی · Quran.com ماخذ 84', 'الإنجليزية · مصدر Quran.com 84'),
              style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SelectableText(verse.english, textDirection: TextDirection.ltr,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.7)),
            const SizedBox(height: 18),
            Text(_t('Urdu · Quran.com resource 97',
              'اردو · Quran.com ماخذ 97', 'الأردية · مصدر Quran.com 97'),
              style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SelectableText(verse.urdu, textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.7)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final verses = _verses;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: SizedBox(
        width: 1080,
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: Directionality(
          textDirection: ReaderLocalizationScope.of(context).textDirection,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 8, 0),
                child: Row(children: [
                  Expanded(child: Text(_t('Compare Ayahs', 'آیات کا موازنہ', 'مقارنة الآيات'),
                    style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                    tooltip: _t('Close', 'بند کریں', 'إغلاق'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ]),
              ),
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_t(
                      'Compare two references you choose. This view does not identify scholarly Mutashabihat groups.',
                      'اپنی منتخب کردہ دو آیات کا موازنہ کریں۔ یہ سہولت علمی طور پر متعین متشابہات کے گروہ تلاش نہیں کرتی۔',
                      'قارن مرجعين تختارهما. لا تُحدّد هذه الأداة مجموعات المتشابهات المعتمدة علميًا.',
                    )),
                    const SizedBox(height: 16),
                    LayoutBuilder(builder: (context, constraints) =>
                      constraints.maxWidth >= 760
                          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(child: _input(_first, first: true)),
                              const SizedBox(width: 16),
                              Expanded(child: _input(_second, first: false)),
                            ])
                          : Column(children: [
                              _input(_first, first: true),
                              const SizedBox(height: 12),
                              _input(_second, first: false),
                            ])),
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FilledButton.icon(
                        onPressed: _compare,
                        icon: const Icon(Icons.compare_arrows_rounded),
                        label: Text(_t('Compare', 'موازنہ کریں', 'مقارنة')),
                      ),
                    ),
                    if (verses != null) ...[
                      const SizedBox(height: 20),
                      LayoutBuilder(builder: (context, constraints) =>
                        constraints.maxWidth >= 760
                            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(child: _card(verses[0])),
                                const SizedBox(width: 16),
                                Expanded(child: _card(verses[1])),
                              ])
                            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                _card(verses[0]),
                                const SizedBox(height: 16),
                                _card(verses[1]),
                              ])),
                      const SizedBox(height: 12),
                      Text(_t('Arabic source: Quranic Arabic Corpus / Tanzil, morphology v0.4.',
                        'عربی متن کا ماخذ: Quranic Arabic Corpus / Tanzil، morphology v0.4۔',
                        'مصدر النص العربي: Quranic Arabic Corpus / Tanzil، morphology v0.4.'),
                        style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard(this.word, {required this.onRootSelected});
  final QuranStudyWord word;
  final ValueChanged<String> onRootSelected;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meaningRtl = word.meaning != null && RegExp(r'[\u0600-\u06FF]').hasMatch(word.meaning!);
    final roots = (word.root ?? '').split(' / ').map((root) => root.trim()).where((root) => root.isNotEmpty).toList();
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
      if (roots.isEmpty) SelectableText(tr(context, 'Not listed'), textDirection: TextDirection.rtl,
        textAlign: TextAlign.center, style: const TextStyle(fontSize: 18))
      else Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center,
        children: roots.map((root) => ActionChip(
          label: Text(root, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 18)),
          onPressed: () => onRootSelected(root))).toList()),
      if (word.partOfSpeech.isNotEmpty) Text(word.partOfSpeech, textDirection: TextDirection.ltr,
        textAlign: TextAlign.center, style: theme.textTheme.labelSmall),
    ])));
  }
}

String _rootLabel(BuildContext context, {required String english, required String urdu, required String arabic}) =>
    switch (ReaderLocalizationScope.of(context).language) {
      ReaderLanguage.urdu => urdu,
      ReaderLanguage.arabic => arabic,
      _ => english,
    };
