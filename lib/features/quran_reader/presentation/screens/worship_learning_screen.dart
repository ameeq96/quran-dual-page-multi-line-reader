import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/reader_localization.dart';
import '../../../../core/worship/worship_content.dart';
import '../../../../core/worship/worship_store.dart';
import '../../../../core/worship/worship_speech.dart';
import '../widgets/app_page_header.dart';

final _worshipLearningObservers =
    <String, RouteObserver<ModalRoute<dynamic>>>{};
RouteObserver<ModalRoute<dynamic>> worshipLearningObserverFor(
  String profileId,
) => _worshipLearningObservers.putIfAbsent(
  profileId,
  () => RouteObserver<ModalRoute<dynamic>>(),
);

class WorshipLearningScreen extends StatefulWidget {
  const WorshipLearningScreen({
    super.key,
    required this.store,
    this.initialTab = 0,
    this.onPlaySurah,
    this.onStopAudio,
    this.onReadSurah,
  });
  final WorshipStore store;
  final int initialTab;
  final Future<void> Function(int surahId)? onPlaySurah;
  final Future<void> Function()? onStopAudio;
  final Future<void> Function(int surahId)? onReadSurah;
  @override
  State<WorshipLearningScreen> createState() => _WorshipLearningScreenState();
}

class _WorshipLearningScreenState extends State<WorshipLearningScreen>
    with WidgetsBindingObserver, RouteAware {
  late Future<void> _loading = widget.store.load();
  String _group = 'morning';
  bool _busy = false;
  bool _wudu = true;
  String? _quizLetter;
  int _quizIndex = 0;
  final _speech = WorshipSpeech();
  int _speechGeneration = 0;
  ModalRoute<dynamic>? _route;
  RouteObserver<ModalRoute<dynamic>> get _routeObserver =>
      worshipLearningObserverFor(widget.store.profileId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!identical(route, _route)) {
      _routeObserver.unsubscribe(this);
      _route = route;
      if (route != null) _routeObserver.subscribe(this, route);
    }
  }

  void _stopDeviceSpeech() {
    _speechGeneration++;
    unawaited(_speech.stop().catchError((Object _) {}));
  }

  @override
  void didPushNext() => _stopDeviceSpeech();

  @override
  void didPop() => _stopDeviceSpeech();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _stopDeviceSpeech();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeObserver.unsubscribe(this);
    _speechGeneration++;
    _speech.dispose();
    super.dispose();
  }

  String get _language => ReaderLocalization.instance.locale.languageCode;
  String _copy(WorshipText value) => value.inLanguage(_language);
  String _t(String en, String ur, String ar) => _copy(WorshipText(en, ur, ar));

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'The action could not finish. Please try again.',
                'عمل مکمل نہیں ہو سکا۔ دوبارہ کوشش کریں۔',
                'تعذّر إكمال الإجراء. حاول مجددًا.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopAudio() async {
    _speechGeneration++;
    try {
      await _speech.stop();
      await widget.onStopAudio?.call();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Audio could not be stopped. Try the recitation controls.',
                'آواز بند نہیں ہو سکی۔ تلاوت کے کنٹرول استعمال کریں۔',
                'تعذّر إيقاف الصوت. جرّب أدوات التلاوة.',
              ),
            ),
          ),
        );
    }
  }

  Future<void> _speakDevice(String text) async {
    if (_busy) return;
    final generation = ++_speechGeneration;
    setState(() => _busy = true);
    if (widget.onStopAudio != null) {
      unawaited(widget.onStopAudio!().catchError((Object _) {}));
    }
    try {
      await _speech.speakArabic(text);
    } catch (_) {
      if (mounted && generation == _speechGeneration)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Device Arabic speech could not play. Check your Arabic voice settings or practise with a teacher.',
                'آلے کی عربی آواز نہیں چل سکی۔ عربی آواز کی ترتیبات دیکھیں یا استاد کے ساتھ مشق کریں۔',
                'تعذّر تشغيل صوت الجهاز العربي. تحقّق من إعدادات الصوت العربي أو تدرّب مع معلّم.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _deviceVoiceControls(String text) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _speakDevice(text),
            icon: const Icon(Icons.record_voice_over_outlined),
            label: Text(
              _t(
                'Listen · device Arabic voice',
                'سنیں · آلے کی عربی آواز',
                'استمع · صوت الجهاز العربي',
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _stopAudio,
            icon: const Icon(Icons.stop_rounded),
            label: Text(_t('Stop audio', 'آواز روکیں', 'إيقاف الصوت')),
          ),
        ],
      ),
      _note(
        _t(
          'Synthetic device/browser Arabic voice for pronunciation practice, not a qari recording. An Arabic voice may need installation or internet. Quran uses the selected qari.',
          'تلفظ کی مشق کے لیے آلے یا براؤزر کی مصنوعی عربی آواز ہے، قاری کی ریکارڈنگ نہیں۔ عربی آواز انسٹال کرنا یا انٹرنیٹ درکار ہو سکتا ہے۔ قرآن کے لیے منتخب قاری کی تلاوت استعمال ہوتی ہے۔',
          'صوت عربي اصطناعي للجهاز أو المتصفح للتدرّب على النطق، وليس تسجيل قارئ. قد يحتاج الصوت العربي إلى تثبيت أو إنترنت. يستخدم القرآن القارئ المختار.',
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.store, ReaderLocalization.instance]),
    builder: (context, _) => Directionality(
      textDirection: ReaderLocalization.instance.textDirection,
      child: DefaultTabController(
        length: 3,
        initialIndex: widget.initialTab.clamp(0, 2),
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              _t('Learn & remember', 'سیکھیں اور یاد کریں', 'تعلّم واذكر'),
            ),
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              tabs: [
                Tab(text: _t('Azkar', 'اذکار', 'الأذكار')),
                Tab(text: _t('Kids learning', 'بچوں کے اسباق', 'تعلّم الصغار')),
                Tab(text: _t('Namaz & Wuzu', 'نماز اور وضو', 'الصلاة والوضوء')),
              ],
            ),
          ),
          body: FutureBuilder<void>(
            future: _loading,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _t(
                            'Learning progress could not be loaded.',
                            'سبق کی پیش رفت لوڈ نہیں ہو سکی۔',
                            'تعذّر تحميل تقدّم التعلّم.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () =>
                              setState(() => _loading = widget.store.load()),
                          child: Text(
                            _t('Retry', 'دوبارہ کوشش', 'إعادة المحاولة'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              if (snapshot.connectionState != ConnectionState.done)
                return const Center(child: CircularProgressIndicator());
              return TabBarView(children: [_azkar(), _kids(), _guide()]);
            },
          ),
        ),
      ),
    ),
  );

  Widget _page(String key, List<Widget> children) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 840),
      child: ListView(
        key: PageStorageKey(key),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: children,
      ),
    ),
  );

  /// Emerald intro banner that opens each tab.
  Widget _hero(IconData icon, String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: AppPageHeader(title: title, subtitle: subtitle, icon: icon),
  );

  Widget _card({required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.dividerColor),
      ),
      child: child,
    );
  }

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        height: 1.6,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );

  Widget _reference(WorshipReference reference) => TextButton.icon(
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(_t('Source reference', 'اصل حوالہ', 'المصدر')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(reference.label),
            const SizedBox(height: 12),
            Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(reference.url),
            ),
            if (reference.note != null) _note(_copy(reference.note!)),
            _note(
              _t(
                'Hadith and Quran references identify the source. Learning notes are summaries, not verbatim translations.',
                'حدیث اور قرآن کے حوالے اصل ماخذ بتاتے ہیں۔ تعلیمی نوٹس خلاصے ہیں، لفظی ترجمہ نہیں۔',
                'المراجع تحدد المصدر. الملاحظات التعليمية ملخصات وليست ترجمات حرفية.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _run(
              () => Clipboard.setData(ClipboardData(text: reference.url)),
            ),
            child: Text(_t('Copy link', 'لنک کاپی کریں', 'نسخ الرابط')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('Close', 'بند کریں', 'إغلاق')),
          ),
        ],
      ),
    ),
    icon: const Icon(Icons.menu_book_outlined, size: 17),
    label: Text(reference.label),
  );

  Widget _surahActions(int id) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          if (widget.onReadSurah != null)
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      await _stopAudio();
                      await widget.onReadSurah!(id);
                    }),
              icon: const Icon(Icons.auto_stories_outlined),
              label: Text(_t('Read Surah', 'سورت پڑھیں', 'قراءة السورة')),
            ),
          if (widget.onPlaySurah != null)
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      _stopDeviceSpeech();
                      await widget.onPlaySurah!(id);
                    }),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                _t('Listen to qari', 'قاری کو سنیں', 'الاستماع للقارئ'),
              ),
            ),
          if (widget.onStopAudio != null)
            TextButton.icon(
              onPressed: _stopAudio,
              icon: const Icon(Icons.stop_rounded),
              label: Text(_t('Stop audio', 'آواز روکیں', 'إيقاف الصوت')),
            ),
        ],
      ),
      _note(
        widget.onPlaySurah == null
            ? _t(
                'Recitation audio is unavailable in this view.',
                'اس حصے میں تلاوت کی آواز دستیاب نہیں۔',
                'التلاوة الصوتية غير متاحة في هذا العرض.',
              )
            : _t(
                'Uses the app’s existing Quran recitation. Internet is needed unless the recitation was downloaded.',
                'ایپ کی موجودہ قرآن تلاوت استعمال ہوتی ہے۔ ڈاؤن لوڈ نہ ہو تو انٹرنیٹ درکار ہے۔',
                'تُستخدم تلاوة القرآن الموجودة في التطبيق. يلزم الإنترنت ما لم تُنزّل التلاوة.',
              ),
      ),
    ],
  );

  Widget _azkar() => _page('worship-azkar', [
    _hero(
      Icons.spa_outlined,
            _t('A moment of remembrance', 'ذکر کے چند لمحے', 'لحظات من الذكر'),
            _t(
              'Referenced morning, evening, after-prayer and bedtime practice.',
              'حوالوں کے ساتھ صبح، شام، نماز کے بعد اور سونے سے پہلے کے اذکار۔',
              'أذكار موثقة للصباح والمساء وبعد الصلاة وقبل النوم.',
            ),
    ),
    _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _note(
            _t(
              'Counters save your current practice session on this profile. Reset for another session; they do not reset automatically each day.',
              'گنتی اس پروفائل میں موجودہ مشق کے لیے محفوظ ہوتی ہے۔ نئی نشست کے لیے ری سیٹ کریں؛ یہ روزانہ خودکار طور پر صفر نہیں ہوتی۔',
              'تُحفظ العدادات لهذه الجلسة في ملفك. صفّرها لجلسة جديدة؛ لا تُصفّر تلقائيًا كل يوم.',
            ),
          ),
        ],
      ),
    ),
    Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: _group,
        decoration: InputDecoration(labelText: _t('When', 'وقت', 'الوقت')),
        isExpanded: true,
        items: [
          for (final entry in worshipDhikrGroups.entries)
            DropdownMenuItem(value: entry.key, child: Text(_copy(entry.value))),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _group = value);
        },
      ),
    ),
    for (final dhikr in worshipAzkar.where((item) => item.group == _group))
      _dhikr(dhikr),
  ]);

  Widget _dhikr(WorshipDhikr item) {
    final count = widget.store.tasbeehCounts[item.id] ?? 0;
    final done = count >= item.target;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(_copy(item.title)),
          SizedBox(
            width: double.infinity,
            child: SelectableText(
              item.arabic,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 30, height: 1.8),
            ),
          ),
          _note(_copy(item.meaning)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (count / item.target).clamp(0, 1),
            borderRadius: BorderRadius.circular(8),
            minHeight: 6,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                key: ValueKey('dhikr-count-${item.id}'),
                onPressed: _busy || done
                    ? null
                    : () => _run(
                        () => widget.store.setTasbeeh(item.id, count + 1),
                      ),
                icon: Icon(done ? Icons.check_rounded : Icons.add_rounded),
                label: Text(
                  '${done ? _t('Completed', 'مکمل', 'اكتمل') : _t('Count', 'گنیں', 'عدّ')} · $count/${item.target}',
                ),
              ),
              IconButton(
                tooltip: _t('Undo one', 'ایک کم کریں', 'إنقاص واحد'),
                onPressed: _busy || count == 0
                    ? null
                    : () => _run(
                        () => widget.store.setTasbeeh(item.id, count - 1),
                      ),
                icon: const Icon(Icons.remove_rounded),
              ),
              TextButton(
                onPressed: _busy || count == 0
                    ? null
                    : () => _resetCounter(item),
                child: Text(_t('Reset', 'ری سیٹ', 'تصفير')),
              ),
            ],
          ),
          if (item.surahId != null) ...[
            const SizedBox(height: 10),
            _surahActions(item.surahId!),
          ] else
            _deviceVoiceControls(item.arabic),
          _reference(item.reference),
        ],
      ),
    );
  }

  Future<void> _resetCounter(WorshipDhikr item) async {
    final reset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _t('Start a new count?', 'نئی گنتی شروع کریں؟', 'بدء عدّ جديد؟'),
        ),
        content: Text(
          _t(
            'Only this saved counter will return to zero.',
            'صرف یہی محفوظ گنتی صفر ہوگی۔',
            'سيعود هذا العداد فقط إلى الصفر.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('Cancel', 'منسوخ', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('Reset', 'ری سیٹ', 'تصفير')),
          ),
        ],
      ),
    );
    if (reset == true && mounted)
      await _run(() => widget.store.setTasbeeh(item.id, 0));
  }

  Widget _kids() => _page('worship-kids', [
    _hero(
      Icons.school_outlined,
            _t(
              'Small steps, steady learning',
              'چھوٹے قدم، مسلسل سیکھنا',
              'خطوات صغيرة وتعلّم مستمر',
            ),
            _t(
              'Letter recognition, short Surahs and practice with a trusted adult.',
              'حروف کی پہچان، چھوٹی سورتیں اور بڑے کی نگرانی میں مشق۔',
              'تعرّف الحروف، والسور القصيرة، والتدرّب مع شخص موثوق.',
            ),
    ),
    _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _note(
            _t(
              'Tap a letter to hear its name with a device Arabic voice, where available. A teacher should model Quranic sounds. Lesson ticks record practice, not certified recitation ability.',
              'حرف دبائیں تو دستیاب ہونے پر آلے کی عربی آواز میں اس کا نام سنیں۔ قرآنی آواز استاد سے سیکھیں۔ سبق کا نشان مشق کا ریکارڈ ہے، قراءت کی سند نہیں۔',
              'اضغط حرفًا لسماع اسمه بصوت الجهاز العربي إن توفر. تعلّم الأصوات القرآنية من معلّم. علامة الدرس تسجل التدرّب ولا تشهد بإتقان التلاوة.',
            ),
          ),
          Text(
            '${widget.store.completedLessons.where((id) => worshipKidsLessons.any((lesson) => lesson.id == id)).length}/${worshipKidsLessons.length} ${_t('practised', 'مشق شدہ', 'تم التدرّب عليها')}',
          ),
        ],
      ),
    ),
    _letterQuiz(),
    for (final lesson in worshipKidsLessons)
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(_copy(lesson.title)),
            if (lesson.letters.isNotEmpty)
              Directionality(
                textDirection: TextDirection.rtl,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (final letter in lesson.letters)
                      InkWell(
                        onTap: worshipLetterNames.containsKey(letter)
                            ? () => _showLetter(letter)
                            : null,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            letter,
                            style: const TextStyle(fontSize: 34),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            _note(_copy(lesson.description)),
            if (lesson.surahId != null) _surahActions(lesson.surahId!),
            CheckboxListTile(
              key: ValueKey('lesson-${lesson.id}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                _t(
                  'I practised this lesson',
                  'میں نے اس سبق کی مشق کی',
                  'تدرّبت على هذا الدرس',
                ),
              ),
              value: widget.store.completedLessons.contains(lesson.id),
              onChanged: _busy
                  ? null
                  : (value) => _run(
                      () => widget.store.setLessonComplete(
                        lesson.id,
                        value == true,
                      ),
                    ),
            ),
            _reference(lesson.reference),
          ],
        ),
      ),
  ]);

  Widget _letterQuiz() {
    final target = worshipLetters[_quizIndex % worshipLetters.length];
    final choices = [
      for (var i = 0; i < 4; i++)
        worshipLetters[(_quizIndex + i * 7) % worshipLetters.length],
    ];
    choices.sort(
      (a, b) => worshipLetters.indexOf(a).compareTo(worshipLetters.indexOf(b)),
    );
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            _t(
              'Find the matching letter',
              'ملتا ہوا حرف تلاش کریں',
              'اختر الحرف المطابق',
            ),
          ),
          Center(
            child: Text(
              target,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontSize: 48),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final choice in choices)
                OutlinedButton(
                  onPressed: () => setState(() => _quizLetter = choice),
                  child: Text(choice, style: const TextStyle(fontSize: 28)),
                ),
            ],
          ),
          if (_quizLetter != null) ...[
            _note(
              _quizLetter == target
                  ? _t(
                      'That matches. Well done!',
                      'درست حرف ہے، شاباش!',
                      'إجابة مطابقة، أحسنت!',
                    )
                  : _t(
                      'Look at the shape and dots. Try again.',
                      'شکل اور نقطے دیکھیں۔ پھر کوشش کریں۔',
                      'انظر إلى الشكل والنقاط وحاول مجددًا.',
                    ),
            ),
            if (_quizLetter == target)
              TextButton.icon(
                onPressed: () => setState(() {
                  _quizIndex++;
                  _quizLetter = null;
                }),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(_t('Next letter', 'اگلا حرف', 'الحرف التالي')),
              ),
          ],
        ],
      ),
    );
  }

  Widget _guide() => _page('worship-guide', [
    _hero(
      Icons.menu_book_outlined,
            _t('Choose your school', 'اپنی فقہ منتخب کریں', 'اختر مذهبك'),
            _t(
              'No school is selected automatically. This choice is shared with your worship records.',
              'کوئی فقہ خودکار منتخب نہیں ہوتی۔ یہ انتخاب عبادت کے ریکارڈ میں بھی استعمال ہوتا ہے۔',
              'لا يُختار مذهب تلقائيًا. يُستخدم هذا الاختيار أيضًا في سجلات عبادتك.',
            ),
    ),
    _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey(widget.store.fiqh),
            initialValue: widget.store.fiqh,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _t('Fiqh', 'فقہ', 'المذهب'),
              hintText: _t('Select a school', 'فقہ منتخب کریں', 'اختر مذهبًا'),
            ),
            items: [
              for (final school in worshipSchools)
                DropdownMenuItem(
                  value: school,
                  child: Text(_schoolName(school)),
                ),
            ],
            onChanged: _busy
                ? null
                : (value) {
                    if (value != null) _run(() => widget.store.setFiqh(value));
                  },
          ),
        ],
      ),
    ),
    if (widget.store.fiqh == null)
      _note(
        _t(
          'Select a school to open the guide. Ask your family or teacher if you are unsure.',
          'رہنما کھولنے کے لیے فقہ منتخب کریں۔ معلوم نہ ہو تو گھر والوں یا استاد سے پوچھیں۔',
          'اختر مذهبًا لفتح الدليل. اسأل أهلك أو معلّمك إن لم تكن متأكدًا.',
        ),
      )
    else ...[
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(
              _t(
                'A referenced beginner overview',
                'حوالوں کے ساتھ ابتدائی رہنما',
                'مدخل موثق للمبتدئ',
              ),
            ),
            _note(
              _t(
                'The main sequence is shared foundational learning. Only the sourced head-wiping note varies by school here. This is not a complete fiqh manual or a ruling on an individual prayer.',
                'بنیادی ترتیب مشترک تعلیمی خاکہ ہے۔ یہاں صرف سر کے مسح کا حوالہ شدہ نوٹ فقہ کے مطابق بدلتا ہے۔ یہ مکمل فقہی کتاب یا کسی نماز پر فتویٰ نہیں ہے۔',
                'الترتيب الأساسي مدخل تعليمي مشترك. الذي يختلف هنا حسب المذهب هو ملاحظة مسح الرأس الموثقة فقط. ليس هذا دليلًا فقهيًا كاملًا أو حكمًا على صلاة بعينها.',
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(_t('Wuzu', 'وضو', 'الوضوء')),
                  selected: _wudu,
                  onSelected: (_) => setState(() => _wudu = true),
                ),
                ChoiceChip(
                  label: Text(_t('Namaz', 'نماز', 'الصلاة')),
                  selected: !_wudu,
                  onSelected: (_) => setState(() => _wudu = false),
                ),
              ],
            ),
          ],
        ),
      ),
      for (final step in _wudu ? worshipWuduSteps : worshipPrayerSteps)
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _heading(_copy(step.title)),
              _guidePicture(step),
              Text(
                _copy(step.description),
                style: const TextStyle(height: 1.6),
              ),
              _reference(step.reference),
            ],
          ),
        ),
      if (_wudu)
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _heading(_schoolName(widget.store.fiqh!)),
              Text(_copy(worshipFiqhHeadNotes[widget.store.fiqh!]!)),
              _reference(worshipFiqhReference),
            ],
          ),
        ),
    ],
  ]);

  String _schoolName(String school) => switch (school) {
    'hanafi' => _t('Hanafi', 'حنفی', 'حنفي'),
    'shafii' => _t('Shafi‘i', 'شافعی', 'شافعي'),
    'maliki' => _t('Maliki', 'مالکی', 'مالكي'),
    _ => _t('Hanbali', 'حنبلی', 'حنبلي'),
  };

  Future<void> _showLetter(String letter) async {
    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          final route = ModalRoute.of(context);
          if (route != null) _routeObserver.subscribe(this, route);
          return AlertDialog(
            scrollable: true,
            title: Text(_t('Letter name', 'حرف کا نام', 'اسم الحرف')),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    letter,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: 64),
                  ),
                  Text(
                    worshipLetterNames[letter]!,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: 28),
                  ),
                  _deviceVoiceControls(worshipLetterNames[letter]!),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _stopDeviceSpeech();
                  Navigator.pop(context);
                },
                child: Text(_t('Close', 'بند کریں', 'إغلاق')),
              ),
            ],
          );
        },
      );
    } finally {
      _stopDeviceSpeech();
      _routeObserver.unsubscribe(this);
      if (mounted && _route != null) _routeObserver.subscribe(this, _route!);
    }
  }

  Widget _guidePicture(WorshipGuideStep step) {
    if (_wudu) {
      final icons = [
        Icons.back_hand_outlined,
        Icons.water_drop_outlined,
        Icons.face_outlined,
        Icons.accessibility_new_rounded,
        Icons.person_outline_rounded,
        Icons.directions_walk_rounded,
      ];
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: SizedBox(
          width: double.infinity,
          child: Icon(
            icons[worshipWuduSteps.indexOf(step)],
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }
    final index = worshipPrayerSteps.indexOf(step);
    final poses = switch (index) {
      1 => ['standing'],
      2 => ['bowing'],
      3 => ['standing'],
      4 => ['prostration', 'sitting'],
      _ => <String>[],
    };
    if (poses.isEmpty)
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Icon(
          index == 0 ? Icons.water_drop_outlined : Icons.menu_book_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    return Column(
      children: [
        Semantics(
          label: _copy(step.title),
          image: true,
          child: ExcludeSemantics(
            child: SizedBox(
              height: 148,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final pose in poses)
                    Flexible(
                      child: SizedBox(
                        width: 160,
                        height: 140,
                        child: CustomPaint(
                          painter: _PrayerPosturePainter(
                            pose,
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        _note(
          _t(
            'Schematic learning picture: not a school-specific hand or limb placement instruction.',
            'یہ سیکھنے کی علامتی تصویر ہے؛ کسی مخصوص فقہ میں ہاتھ پاؤں کی جگہ کی ہدایت نہیں۔',
            'رسم تعليمي مبسّط، وليس تعليمًا لوضع اليدين أو الأطراف حسب مذهب معين.',
          ),
        ),
      ],
    );
  }
}

class _PrayerPosturePainter extends CustomPainter {
  const _PrayerPosturePainter(this.pose, this.color);
  final String pose;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    Offset point(double x, double y) => Offset(x * size.width, y * size.height);
    void line(List<Offset> points) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final next in points.skip(1)) {
        path.lineTo(next.dx, next.dy);
      }
      canvas.drawPath(path, paint);
    }

    canvas.drawLine(
      point(.08, .96),
      point(.92, .96),
      Paint()
        ..color = color.withValues(alpha: .25)
        ..strokeWidth = 2,
    );
    switch (pose) {
      case 'bowing':
        canvas.drawCircle(point(.81, .37), size.height * .065, paint);
        line([
          point(.72, .40),
          point(.40, .40),
          point(.39, .68),
          point(.34, .92),
        ]);
        line([point(.40, .40), point(.48, .68), point(.49, .92)]);
        line([point(.67, .43), point(.54, .69), point(.43, .69)]);
      case 'prostration':
        canvas.drawCircle(point(.79, .82), size.height * .06, paint);
        line([
          point(.70, .76),
          point(.49, .43),
          point(.24, .67),
          point(.22, .90),
          point(.08, .90),
        ]);
        line([point(.63, .64), point(.62, .89), point(.74, .89)]);
      case 'sitting':
        canvas.drawCircle(point(.54, .18), size.height * .065, paint);
        line([
          point(.53, .29),
          point(.51, .64),
          point(.29, .78),
          point(.67, .91),
        ]);
        line([point(.52, .39), point(.32, .71)]);
      default:
        canvas.drawCircle(point(.50, .14), size.height * .065, paint);
        line([point(.50, .25), point(.50, .62), point(.39, .92)]);
        line([point(.50, .62), point(.61, .92)]);
        line([point(.50, .34), point(.34, .55)]);
        line([point(.50, .34), point(.66, .55)]);
    }
  }

  @override
  bool shouldRepaint(_PrayerPosturePainter oldDelegate) =>
      oldDelegate.pose != pose || oldDelegate.color != color;
}
