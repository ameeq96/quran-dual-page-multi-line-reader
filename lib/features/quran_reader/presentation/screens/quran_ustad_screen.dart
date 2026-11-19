import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/reader_localization.dart';
import '../../../../core/services/reader_recording_store.dart';
import '../../../../core/services/reader_ustad_audio.dart';
import '../../../../core/services/reader_voice_capture.dart';
import '../../../../core/storage/reader_preferences.dart';
import '../../data/services/reader_ustad_service.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import '../widgets/app_page_header.dart';

String readerUstadText(BuildContext context, String english) {
  const labels = <String, List<String>>{
    'Private Ustad & student': [
      'نجی استاد اور طالب علم',
      'المعلم والطالب الخاص'
    ],
    'Refresh': ['تازہ کریں', 'تحديث'],
    'Teacher': ['استاد', 'المعلم'],
    'Student': ['طالب علم', 'الطالب'],
    'Create invite': ['دعوت بنائیں', 'إنشاء دعوة'],
    'Accept invite': ['دعوت قبول کریں', 'قبول الدعوة'],
    'Your display name': ['آپ کا نمایاں نام', 'اسمك المعروض'],
    'Private invite code': ['نجی دعوت کا کوڈ', 'رمز الدعوة الخاص'],
    'Preview invite': ['دعوت پہلے دیکھیں', 'معاينة الدعوة'],
    'Invite expires': ['دعوت کی میعاد', 'انتهاء الدعوة'],
    'Share this code privately with your student.': [
      'یہ کوڈ صرف اپنے طالب علم کو نجی طور پر دیں۔',
      'شارك هذا الرمز مع طالبك بشكل خاص.'
    ],
    'I consent to sharing only the clips I choose to send with this teacher.': [
      'میں صرف اپنی بھیجی گئی ریکارڈنگ اس استاد سے شیئر کرنے پر راضی ہوں۔',
      'أوافق على مشاركة المقاطع التي أختار إرسالها مع هذا المعلم فقط.'
    ],
    'Registered accounts only. Your Quran backup is not shared here.': [
      'صرف رجسٹرڈ اکاؤنٹس۔ قرآن کا بیک اپ یہاں شیئر نہیں ہوتا۔',
      'للحسابات المسجلة فقط. لا تُشارك نسختك الاحتياطية هنا.'
    ],
    'Connection': ['رابطہ', 'الرابط'],
    'active': ['فعال', 'نشط'],
    'pending': ['منتظر', 'معلق'],
    'revoked': ['ختم شدہ', 'ملغى'],
    'Revoke connection': ['رابطہ ختم کریں', 'إلغاء الرابط'],
    'Delete lesson recordings and revoke access': [
      'سبق کی ریکارڈنگ حذف اور رسائی ختم کریں',
      'حذف تسجيلات الدروس وإلغاء الوصول'
    ],
    'Stop sharing with this participant? Student clips remain private until deleted or expired.':
        [
      'اس فرد سے اشتراک روک دیں؟ طالب علم کے کلپ حذف ہونے یا میعاد تک نجی رہیں گے۔',
      'إيقاف المشاركة؟ تبقى مقاطع الطالب خاصة حتى حذفها أو انتهاء مدتها.'
    ],
    'Delete your clips and revoke this connection? This cannot be undone.': [
      'اپنے کلپ حذف کرکے رابطہ ختم کریں؟ یہ واپس نہیں ہوگا۔',
      'حذف مقاطعك وإلغاء هذا الرابط؟ لا يمكن التراجع.'
    ],
    'Cancel': ['منسوخ', 'إلغاء'],
    'Confirm': ['تصدیق', 'تأكيد'],
    'Close': ['بند کریں', 'إغلاق'],
    'Copy code': ['کوڈ نقل کریں', 'نسخ الرمز'],
    'New assignment': ['نیا سبق', 'واجب جديد'],
    'Title': ['عنوان', 'العنوان'],
    'Instructions': ['ہدایات', 'التعليمات'],
    'Edition': ['نسخہ', 'الطبعة'],
    'Start page': ['پہلا صفحہ', 'صفحة البداية'],
    'End page': ['آخری صفحہ', 'صفحة النهاية'],
    'Teacher-selected page range': [
      'استاد کے منتخب کردہ صفحات',
      'نطاق الصفحات الذي حدده المعلم'
    ],
    'Sabaq': ['سبق', 'الدرس الجديد'],
    'Sabqi': ['سبقی', 'المراجعة القريبة'],
    'Manzil': ['منزل', 'المراجعة السابقة'],
    'Choose due date': ['آخری تاریخ منتخب کریں', 'اختيار الموعد'],
    'No due date': ['کوئی آخری تاریخ نہیں', 'بلا موعد'],
    'Send assignment': ['سبق بھیجیں', 'إرسال الواجب'],
    'Cancel assignment': ['سبق منسوخ کریں', 'إلغاء الواجب'],
    'Cancel this assignment?': ['یہ سبق منسوخ کریں؟', 'إلغاء هذا الواجب؟'],
    'assigned': ['دیا گیا', 'مُكلّف'],
    'cancelled': ['منسوخ', 'ملغى'],
    'Record lesson': ['سبق ریکارڈ کریں', 'تسجيل الدرس'],
    'Stop recording': ['ریکارڈنگ روکیں', 'إيقاف التسجيل'],
    'Saved locally before sending. Maximum 60 seconds and 8 MiB.': [
      'بھیجنے سے پہلے مقامی طور پر محفوظ ہوگا۔ حد ۶۰ سیکنڈ اور ۸ MiB ہے۔',
      'يُحفظ محليًا قبل الإرسال. الحد 60 ثانية و8 MiB.'
    ],
    'Saved lesson drafts': ['محفوظ سبق کی ریکارڈنگ', 'مسودات الدروس المحفوظة'],
    'Preview': ['پہلے سنیں', 'معاينة'],
    'Send clip': ['کلپ بھیجیں', 'إرسال المقطع'],
    'Sent': ['بھیج دیا گیا', 'تم الإرسال'],
    'Delete local clip': ['مقامی کلپ حذف کریں', 'حذف المقطع المحلي'],
    'Delete this local draft?': [
      'یہ مقامی ریکارڈنگ حذف کریں؟',
      'حذف هذه المسودة المحلية؟'
    ],
    'Preview before sending.': ['بھیجنے سے پہلے سنیں۔', 'عاين قبل الإرسال.'],
    'Previewed; sending is your choice.': [
      'سن لیا گیا؛ بھیجنا آپ کا انتخاب ہے۔',
      'تمت المعاينة؛ الإرسال باختيارك.'
    ],
    'Stop audio': ['آواز روکیں', 'إيقاف الصوت'],
    'Submissions': ['بھیجی گئی ریکارڈنگ', 'التسجيلات المرسلة'],
    'Play private clip': ['نجی کلپ سنیں', 'تشغيل المقطع الخاص'],
    'Delete sent clip': ['بھیجا گیا کلپ حذف کریں', 'حذف المقطع المرسل'],
    'Delete this sent clip? This cannot be undone.': [
      'یہ بھیجا گیا کلپ حذف کریں؟ یہ واپس نہیں ہوگا۔',
      'حذف هذا المقطع المرسل؟ لا يمكن التراجع.'
    ],
    'Teacher feedback': ['استاد کی رائے', 'ملاحظات المعلم'],
    'Feedback note': ['رائے کی تفصیل', 'تفاصيل الملاحظات'],
    'complete': ['مکمل', 'مكتمل'],
    'repeat': ['دوبارہ پڑھیں', 'أعد القراءة'],
    'Save feedback': ['رائے محفوظ کریں', 'حفظ الملاحظات'],
    'Deleted': ['حذف شدہ', 'محذوف'],
    'Expired': ['میعاد ختم', 'منتهي الصلاحية'],
    'Storage': ['اسٹوریج', 'التخزين'],
    'Clips expire after 30 days. Student storage: 100 MiB.': [
      'کلپ ۳۰ دن بعد ختم ہوں گے۔ طالب علم کی اسٹوریج: ۱۰۰ MiB۔',
      'تنتهي المقاطع بعد 30 يومًا. تخزين الطالب: 100 MiB.'
    ],
    'Recorder duration only; no Tajweed or memorization score.': [
      'دورانیہ ریکارڈر کا ہے؛ تجوید یا حفظ کا اسکور نہیں۔',
      'المدة من المسجل فقط؛ بلا تقييم للتجويد أو الحفظ.'
    ],
    'Working': ['کام جاری ہے', 'جارٍ العمل'],
    'Cancel request': ['درخواست روکیں', 'إلغاء الطلب'],
    'Sign in with your own registered account in reader settings, then reopen.':
        [
      'ریڈر کی ترتیبات میں اپنے رجسٹرڈ اکاؤنٹ سے سائن ان کرکے دوبارہ کھولیں۔',
      'سجل الدخول بحسابك المسجل في إعدادات القارئ ثم أعد الفتح.'
    ],
    'Private lessons are unavailable on this server, or the item no longer exists. Local drafts are preserved.':
        [
      'اس سرور پر نجی اسباق یا مطلوبہ چیز دستیاب نہیں۔ مقامی ریکارڈنگ محفوظ ہے۔',
      'الدروس الخاصة أو العنصر غير متاح على هذا الخادم. تم الاحتفاظ بالمسودات.'
    ],
    'Access denied. A registered account and active invitation are required. Local drafts are preserved.':
        [
      'رسائی بند ہے۔ رجسٹرڈ اکاؤنٹ اور فعال دعوت ضروری ہیں۔ مقامی ریکارڈنگ محفوظ ہے۔',
      'الوصول مرفوض. يلزم حساب مسجل ودعوة نشطة. تم الاحتفاظ بالمسودات.'
    ],
    'Account or server changed. Reopen; saved clips stay local.': [
      'اکاؤنٹ یا سرور بدل گیا۔ دوبارہ کھولیں؛ کلپ مقامی محفوظ ہیں۔',
      'تغير الحساب أو الخادم. أعد الفتح؛ تبقى المقاطع محلية.'
    ],
    'No confirmation received. Draft preserved; refresh or retry the same request.':
        [
      'تصدیق نہیں ملی۔ مسودہ محفوظ ہے؛ تازہ کریں یا اسی درخواست کو دوبارہ بھیجیں۔',
      'لم يصل تأكيد. المسودة محفوظة؛ حدّث أو أعد نفس الطلب.'
    ],
    'Check names, page range, dates and text length.': [
      'نام، صفحات، تاریخ اور متن کی لمبائی دیکھیں۔',
      'تحقق من الأسماء والصفحات والتواريخ وطول النص.'
    ],
    'Clip or storage limit reached. Delete your own old clips or record a shorter clip.':
        [
      'کلپ یا اسٹوریج کی حد پوری ہے۔ اپنے پرانے کلپ حذف کریں یا مختصر ریکارڈ کریں۔',
      'تم بلوغ حد المقطع أو التخزين. احذف مقاطعك القديمة أو سجل مقطعًا أقصر.'
    ],
    'Too many requests. Wait and retry.': [
      'درخواستیں زیادہ ہیں۔ انتظار کرکے دوبارہ کوشش کریں۔',
      'طلبات كثيرة. انتظر وحاول مجددًا.'
    ],
    'Recording or playback unavailable. Check microphone permission and local storage.':
        [
      'ریکارڈنگ یا آواز دستیاب نہیں۔ مائیکروفون کی اجازت اور مقامی اسٹوریج دیکھیں۔',
      'التسجيل أو التشغيل غير متاح. تحقق من إذن الميكروفون والتخزين المحلي.'
    ],
    'No assignments for this connection.': [
      'اس رابطے کا کوئی سبق نہیں۔',
      'لا توجد واجبات لهذا الرابط.'
    ],
    'No connections yet.': ['ابھی کوئی رابطہ نہیں۔', 'لا توجد روابط بعد.'],
    'Previous': ['پچھلا', 'السابق'],
    'Next': ['اگلا', 'التالي'],
    'Assignments': ['اسباق', 'الواجبات'],
    'Shared recordings': ['مشترکہ ریکارڈنگ', 'التسجيلات المشتركة'],
    'Recent submissions': ['حالیہ ریکارڈنگ', 'التسجيلات الحديثة'],
    'Older clips are in Shared recordings.': [
      'پرانی ریکارڈنگ مشترکہ ریکارڈنگ میں ہے۔',
      'المقاطع الأقدم في التسجيلات المشتركة.'
    ],
    'Shared audio is deleted; assignment, feedback and relationship history remain.':
        [
      'مشترکہ آواز حذف ہوگی؛ سبق، رائے اور رابطے کی تاریخ باقی رہے گی۔',
      'يُحذف الصوت المشترك؛ يبقى سجل الواجبات والملاحظات والعلاقة.'
    ],
  };
  final language = ReaderLocalizationScope.of(context).language;
  if (language != ReaderLanguage.urdu && language != ReaderLanguage.arabic) {
    return english;
  }
  return labels[english]?[language == ReaderLanguage.arabic ? 1 : 0] ?? english;
}

class QuranUstadScreen extends StatefulWidget {
  const QuranUstadScreen(
      {super.key,
      this.controller,
      this.identityProvider,
      this.baseUrl,
      this.profileId,
      this.service,
      this.capture,
      this.recordingStore,
      this.audio})
      : assert(controller != null ||
            (identityProvider != null && baseUrl != null && profileId != null));
  final QuranReaderController? controller;
  final Future<ReaderSyncIdentity> Function()? identityProvider;
  final String? baseUrl;
  final String? profileId;
  final ReaderUstadService? service;
  final ReaderVoiceCapture? capture;
  final ReaderRecordingStore? recordingStore;
  final ReaderUstadAudio? audio;
  @override
  State<QuranUstadScreen> createState() => _QuranUstadScreenState();
}

class _QuranUstadScreenState extends State<QuranUstadScreen>
    with WidgetsBindingObserver {
  late final String _profile;
  late final String _base;
  late final ReaderVoiceCapture _capture;
  late final ReaderRecordingStore _store;
  late final ReaderUstadAudio _audio;
  ReaderSyncIdentity? _identity;
  ReaderUstadService? _service;
  ReaderUstadOverview? _overview;
  List<Map<String, dynamic>> _assignments = const [];
  String? _linkId;
  int _linksPage = 1;
  int _assignmentsPage = 1;
  int _assignmentsPages = 1;
  int _recordingsPage = 1;
  int _recordingsPages = 1;
  List<Map<String, dynamic>> _recordings = const [];
  bool _contextLocked = false;
  bool _foreground = true;
  int _operationGeneration = 0;
  int _playbackGeneration = 0;
  bool _checkingContext = false;
  String? _recordingAssignment;
  int _savedRevision = -1;
  bool _saving = false;
  bool _startingRecording = false;
  int _captureSession = 0;
  bool _busy = true;
  String? _error;
  String? _localError;
  final _previewed = <String>{};
  final _sent = <String>{};
  String _t(String value) => readerUstadText(context, value);
  String _errorText(String code) => _t(switch (code) {
        'auth_required' ||
        'identity_required' =>
          'Sign in with your own registered account in reader settings, then reopen.',
        'forbidden' =>
          'Access denied. A registered account and active invitation are required. Local drafts are preserved.',
        'unavailable' =>
          'Private lessons are unavailable on this server, or the item no longer exists. Local drafts are preserved.',
        'identity_changed' =>
          'Account or server changed. Reopen; saved clips stay local.',
        'invalid_input' => 'Check names, page range, dates and text length.',
        'quota' =>
          'Clip or storage limit reached. Delete your own old clips or record a shorter clip.',
        'rate_limited' => 'Too many requests. Wait and retry.',
        'recording' =>
          'Recording or playback unavailable. Check microphone permission and local storage.',
        _ =>
          'No confirmation received. Draft preserved; refresh or retry the same request.',
      });
  Future<ReaderSyncIdentity> _actor() =>
      widget.identityProvider?.call() ??
      widget.controller!.readerIdentityForFeature();
  String get _scope => sha256
      .convert(utf8.encode(jsonEncode([_base, _profile, _identity?.deviceId])))
      .toString()
      .substring(0, 16);
  String _reference(String id) => 'ustad:$_scope:$id';
  @override
  void initState() {
    super.initState();
    _profile = widget.profileId ?? widget.controller!.backupHistory.profileId;
    _base = widget.baseUrl ?? widget.controller!.adminSyncBaseUrl;
    _capture =
        widget.capture ?? ReaderVoiceCapture.forLesson(profileId: _profile);
    _store = widget.recordingStore ??
        ReaderRecordingStore.forLesson(profileId: _profile);
    _audio = widget.audio ?? ReaderUstadAudio(profileId: _profile);
    _capture.addListener(_captureChanged);
    _store.addListener(_changed);
    _audio.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    widget.controller?.addListener(_contextChanged);
    unawaited(_loadLocal());
    unawaited(_connect());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _loadLocal() async {
    try {
      await _store.refresh();
    } catch (_) {
      if (mounted) {
        setState(() {
          _localError = 'recording';
        });
      }
    }
  }

  Future<void> _connect() async {
    if (_contextLocked) {
      return;
    }
    if (mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      _identity = await _actor();
      if (!mounted) {
        return;
      }
      _service = widget.service ??
          ReaderUstadService(baseUrl: _base, identity: _identity!);
      await _guard();
      await _reload();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error =
              error is ReaderUstadFailure ? error.code : 'identity_required';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _guard() async {
    final identity = await _actor();
    if (!mounted ||
        _contextLocked ||
        identity.deviceId != _identity?.deviceId ||
        identity.token != _identity?.token ||
        (_service != null &&
            (_service!.identity.deviceId != identity.deviceId ||
                _service!.identity.token != identity.token ||
                _service!.baseUrl !=
                    ReaderPreferences.normalizeSyncBaseUrl(_base))) ||
        (widget.controller != null &&
            (widget.controller!.backupHistory.profileId != _profile ||
                ReaderPreferences.normalizeSyncBaseUrl(
                        widget.controller!.adminSyncBaseUrl) !=
                    ReaderPreferences.normalizeSyncBaseUrl(_base)))) {
      await _lockContext();
      throw const ReaderUstadFailure('identity_changed');
    }
  }

  Future<void> _lockContext() async {
    _contextLocked = true;
    _cancelRequest();
    await _audio.stop();
    _store.stopPlayback();
    if (_capture.phase == ReaderVoiceCapturePhase.recording) {
      await _capture.stop();
    }
    if (mounted) {
      setState(() {
        _error = 'identity_changed';
        _overview = null;
        _assignments = [];
        _recordings = [];
      });
    }
  }

  void _contextChanged() {
    if (_checkingContext || _identity == null || _contextLocked) {
      return;
    }
    _checkingContext = true;
    unawaited(_guard().catchError((Object _) async {
      await _lockContext();
    }).whenComplete(() {
      _checkingContext = false;
    }));
  }

  Future<void> _reload() async {
    final overview = await _service!.overview(page: _linksPage);
    final linkId = overview.links.any((item) => item['id'] == _linkId)
        ? _linkId
        : overview.links.firstOrNull?['id'] as String?;
    final assignments =
        await _service!.assignments(linkId: linkId, page: _assignmentsPage);
    final recordings = await _service!.recordings(page: _recordingsPage);
    await _guard();
    if (!mounted) {
      return;
    }
    setState(() {
      _overview = overview;
      _linkId = linkId;
      _linksPage = overview.page;
      _assignments = assignments.items;
      _assignmentsPage = assignments.page;
      _assignmentsPages = assignments.totalPages;
      _recordings = recordings.items;
      _recordingsPage = recordings.page;
      _recordingsPages = recordings.totalPages;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _service == null || _contextLocked) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final operation = _operationGeneration;
    try {
      await _guard();
      if (operation != _operationGeneration || !_foreground) {
        throw const ReaderUstadFailure('cancelled');
      }
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is ReaderUstadFailure ? error.code : 'network';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<bool> _confirm(String message) async =>
      await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text(_t('Confirm')),
                  content: Text(_t(message)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(_t('Cancel'))),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(_t('Confirm'))),
                  ])) ??
      false;

  Future<void> _showPortalDialog({required WidgetBuilder builder}) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        themes: InheritedTheme.capture(from: context, to: navigator.context),
        builder: builder);
    await navigator.push<void>(route);
    await route.completed;
  }

  Future<void> _invite({required bool accept}) async {
    final name = TextEditingController();
    final code = TextEditingController();
    Map<String, dynamic>? preview;
    Map<String, dynamic>? created;
    String? previewCode;
    bool consent = false;
    bool busy = false;
    String? error;
    try {
      await _showPortalDialog(
          builder: (_) => StatefulBuilder(
              builder: (context, update) => PopScope(
                  canPop: !busy,
                  child: AlertDialog(
                    title: Text(_t(accept ? 'Accept invite' : 'Create invite')),
                    content: SizedBox(
                        width: 480,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              if (created == null)
                                TextField(
                                    controller: name,
                                    enabled: !busy,
                                    maxLength: 80,
                                    decoration: InputDecoration(
                                        labelText: _t('Your display name'))),
                              if (accept)
                                TextField(
                                    controller: code,
                                    enabled: !busy,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    textDirection: TextDirection.ltr,
                                    onChanged: (_) => update(() {
                                          preview = null;
                                          consent = false;
                                          previewCode = null;
                                        }),
                                    decoration: InputDecoration(
                                        labelText: _t('Private invite code'))),
                              if (preview != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                    '${_t('Teacher')}: ${preview!['teacherName']}'),
                                Text(
                                    '${_t('Invite expires')}: ${preview!['expiresAt']}'),
                                CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: consent,
                                    onChanged: busy
                                        ? null
                                        : (value) => update(() {
                                              consent = value ?? false;
                                            }),
                                    title: Text(_t(
                                        'I consent to sharing only the clips I choose to send with this teacher.'))),
                              ],
                              if (created != null) ...[
                                Text(_t(
                                    'Share this code privately with your student.')),
                                const SizedBox(height: 12),
                                SelectableText(created!['code'] as String,
                                    textDirection: TextDirection.ltr),
                                Text(
                                    '${_t('Invite expires')}: ${created!['expiresAt']}'),
                                TextButton.icon(
                                    onPressed: () => Clipboard.setData(
                                        ClipboardData(
                                            text: created!['code'] as String)),
                                    icon: const Icon(Icons.copy),
                                    label: Text(_t('Copy code'))),
                              ],
                              if (error != null)
                                Text(_errorText(error!),
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)),
                              if (busy) const LinearProgressIndicator(),
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: busy ? null : () => Navigator.pop(context),
                          child: Text(_t('Close'))),
                      if (created == null)
                        FilledButton(
                            onPressed: busy ||
                                    (accept && preview != null && !consent)
                                ? null
                                : () async {
                                    update(() {
                                      busy = true;
                                      error = null;
                                    });
                                    try {
                                      await _guard();
                                      if (!accept) {
                                        final result = await _service!
                                            .createInvite(name.text);
                                        if (context.mounted) {
                                          update(() {
                                            created = result;
                                          });
                                        }
                                      } else if (preview == null) {
                                        final result = await _service!
                                            .previewInvite(code.text);
                                        if (context.mounted) {
                                          update(() {
                                            preview = result;
                                            previewCode = code.text.trim();
                                          });
                                        }
                                      } else {
                                        await _service!.acceptInvite(
                                            previewCode!, name.text,
                                            consent: consent);
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      }
                                    } catch (failure) {
                                      if (context.mounted) {
                                        update(() {
                                          error = failure is ReaderUstadFailure
                                              ? failure.code
                                              : 'network';
                                        });
                                      }
                                    } finally {
                                      if (context.mounted) {
                                        update(() {
                                          busy = false;
                                        });
                                      }
                                    }
                                  },
                            child: Text(_t(!accept
                                ? 'Create invite'
                                : preview == null
                                    ? 'Preview invite'
                                    : 'Accept invite'))),
                    ],
                  ))));
    } finally {
      name.dispose();
      code.dispose();
    }
    if (mounted) await _run(_reload);
  }

  Future<void> _assign(Map<String, dynamic> link) async {
    final title = TextEditingController();
    final instructions = TextEditingController();
    final start = TextEditingController(text: '1');
    final end = TextEditingController(text: '1');
    String kind = 'sabaq';
    String edition =
        widget.controller?.settings.mushafEdition.key ?? '16_lines';
    DateTime? due;
    String? fingerprint;
    String id = ReaderUstadService.requestId();
    bool busy = false;
    String? error;
    try {
      await _showPortalDialog(
          builder: (_) => StatefulBuilder(
              builder: (context, update) => PopScope(
                  canPop: !busy,
                  child: AlertDialog(
                    title: Text(_t('New assignment')),
                    content: SizedBox(
                        width: 520,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              TextField(
                                  controller: title,
                                  enabled: !busy,
                                  maxLength: 120,
                                  decoration:
                                      InputDecoration(labelText: _t('Title'))),
                              DropdownButtonFormField<String>(
                                  initialValue: kind,
                                  isExpanded: true,
                                  items: ['sabaq', 'sabqi', 'manzil']
                                      .map((value) => DropdownMenuItem(
                                          value: value,
                                          child: Text(_t(value == 'sabaq'
                                              ? 'Sabaq'
                                              : value == 'sabqi'
                                                  ? 'Sabqi'
                                                  : 'Manzil'))))
                                      .toList(),
                                  onChanged: busy
                                      ? null
                                      : (value) => update(() {
                                            kind = value!;
                                          })),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                  initialValue: edition,
                                  isExpanded: true,
                                  decoration:
                                      InputDecoration(labelText: _t('Edition')),
                                  items: MushafEdition.values
                                      .map((value) => DropdownMenuItem(
                                          value: value.key,
                                          child: Text(value.label)))
                                      .toList(),
                                  onChanged: busy
                                      ? null
                                      : (value) => update(() {
                                            edition = value!;
                                          })),
                              const SizedBox(height: 12),
                              Wrap(spacing: 12, runSpacing: 12, children: [
                                SizedBox(
                                    width: 150,
                                    child: TextField(
                                        controller: start,
                                        enabled: !busy,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly
                                        ],
                                        decoration: InputDecoration(
                                            labelText: _t('Start page')))),
                                SizedBox(
                                    width: 150,
                                    child: TextField(
                                        controller: end,
                                        enabled: !busy,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly
                                        ],
                                        decoration: InputDecoration(
                                            labelText: _t('End page')))),
                              ]),
                              Text(_t('Teacher-selected page range'),
                                  style: Theme.of(context).textTheme.bodySmall),
                              TextField(
                                  controller: instructions,
                                  enabled: !busy,
                                  maxLength: 1000,
                                  minLines: 2,
                                  maxLines: 5,
                                  decoration: InputDecoration(
                                      labelText: _t('Instructions'))),
                              Text(due == null
                                  ? _t('No due date')
                                  : MaterialLocalizations.of(context)
                                      .formatMediumDate(due!)),
                              TextButton(
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          final result = await showDatePicker(
                                              context: context,
                                              firstDate: DateTime.now(),
                                              lastDate: DateTime.now().add(
                                                  const Duration(days: 365)),
                                              initialDate:
                                                  due ?? DateTime.now());
                                          if (result != null &&
                                              context.mounted) {
                                            update(() {
                                              due = result;
                                            });
                                          }
                                        },
                                  child: Text(_t('Choose due date'))),
                              if (error != null)
                                Text(_errorText(error!),
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)),
                              if (busy) const LinearProgressIndicator(),
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: busy ? null : () => Navigator.pop(context),
                          child: Text(_t('Cancel'))),
                      FilledButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  update(() {
                                    busy = true;
                                    error = null;
                                  });
                                  try {
                                    await _guard();
                                    final first = int.tryParse(start.text) ?? 0;
                                    final last = int.tryParse(end.text) ?? 0;
                                    if (widget.controller != null &&
                                        widget.controller!.settings
                                                .mushafEdition.key ==
                                            edition &&
                                        last > widget.controller!.totalPages) {
                                      throw const ReaderUstadFailure(
                                          'invalid_input');
                                    }
                                    final value = jsonEncode([
                                      kind,
                                      edition,
                                      first,
                                      last,
                                      title.text,
                                      instructions.text,
                                      due?.toIso8601String()
                                    ]);
                                    if (fingerprint != null &&
                                        fingerprint != value) {
                                      id = ReaderUstadService.requestId();
                                    }
                                    fingerprint = value;
                                    await _service!.assign(
                                        linkId: link['id'] as String,
                                        clientRequestId: id,
                                        kind: kind,
                                        editionKey: edition,
                                        startPage: first,
                                        endPage: last,
                                        title: title.text,
                                        instructions: instructions.text,
                                        dueAt: due);
                                    if (context.mounted) Navigator.pop(context);
                                  } catch (failure) {
                                    if (context.mounted) {
                                      update(() {
                                        error = failure is ReaderUstadFailure
                                            ? failure.code
                                            : 'network';
                                      });
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      update(() {
                                        busy = false;
                                      });
                                    }
                                  }
                                },
                          child: Text(_t('Send assignment'))),
                    ],
                  ))));
    } finally {
      title.dispose();
      instructions.dispose();
      start.dispose();
      end.dispose();
    }
    if (mounted) await _run(_reload);
  }

  void _captureChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
    if (_capture.hasRecording &&
        _capture.phase == ReaderVoiceCapturePhase.ready &&
        _capture.recordingRevision != _savedRevision &&
        _recordingAssignment != null &&
        !_saving) {
      unawaited(_saveRecording());
    }
  }

  Future<void> _saveRecording() async {
    if (_saving || !_capture.hasRecording || _recordingAssignment == null) {
      return;
    }
    final assignment = _recordingAssignment!;
    final revision = _capture.recordingRevision;
    final duration = _capture.elapsed;
    final mime = _capture.recordingMimeType;
    final reference = _reference(assignment);
    final session = _captureSession;
    _saving = true;
    if (mounted) setState(() {});
    try {
      await _guard();
      final bytes = await _capture.readRecordingBytes();
      await _guard();
      await _store.save(
          bytes: bytes,
          mimeType: mime,
          duration: duration,
          label: assignment,
          reference: reference);
      await _guard();
      if (session == _captureSession &&
          assignment == _recordingAssignment &&
          revision == _capture.recordingRevision) {
        _savedRevision = revision;
      }
      if (mounted) {
        setState(() {
          _localError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _localError = 'recording';
        });
      }
    } finally {
      _saving = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _record(Map<String, dynamic> assignment) async {
    if (_saving || _startingRecording || _capture.isBusy || _contextLocked) {
      return;
    }
    setState(() {
      _startingRecording = true;
    });
    try {
      await _guard();
      await widget.controller?.pauseAudio();
      await _guard();
      await _audio.stop();
      _store.stopPlayback();
      _captureSession++;
      _recordingAssignment = assignment['id'] as String;
      _savedRevision = _capture.recordingRevision;
      await _capture.start(transcribe: false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _localError = 'recording';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _startingRecording = false;
        });
      }
    }
  }

  void _stopPlayback() {
    _playbackGeneration++;
    unawaited(_audio.stop());
    _store.stopPlayback();
  }

  void _cancelRequest() {
    _operationGeneration++;
    _service?.cancelPending();
    _stopPlayback();
  }

  Future<void> _preview(ReaderLocalRecording recording) async {
    final generation = ++_playbackGeneration;
    try {
      await _audio.stop();
      if (!mounted ||
          !_foreground ||
          _contextLocked ||
          generation != _playbackGeneration) {
        return;
      }
      await _store.play(recording.id);
      if (!mounted ||
          !_foreground ||
          _contextLocked ||
          generation != _playbackGeneration) {
        _store.stopPlayback();
        return;
      }
      setState(() {
        _previewed.add(recording.id);
        _localError = null;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _localError = 'recording';
        });
    }
  }

  Future<void> _send(
          ReaderLocalRecording recording, Map<String, dynamic> assignment) =>
      _run(() async {
        if (!_previewed.contains(recording.id) ||
            recording.reference != _reference(assignment['id'] as String)) {
          throw const ReaderUstadFailure('invalid_input');
        }
        final operation = _operationGeneration;
        final bytes = await _store.readBytes(recording.id);
        await _guard();
        if (operation != _operationGeneration || !_foreground) {
          throw const ReaderUstadFailure('cancelled');
        }
        final id = sha256
            .convert(utf8.encode(jsonEncode(
                [_base, _identity!.deviceId, assignment['id'], recording.id])))
            .toString()
            .substring(0, 32);
        await _service!.upload(
            assignmentId: assignment['id'] as String,
            clientUploadId: id,
            bytes: bytes,
            mimeType: recording.mimeType,
            durationMillis: recording.durationMillis);
        await _guard();
        if (mounted) {
          setState(() {
            _sent.add(recording.id);
          });
        }
        await _reload();
      });
  Future<void> _playSubmission(Map<String, dynamic> submission) =>
      _run(() async {
        final generation = ++_playbackGeneration;
        _store.stopPlayback();
        await _audio.stop();
        if (!mounted || !_foreground || generation != _playbackGeneration) {
          return;
        }
        final result = await _service!.audio(submission);
        if (!mounted || !_foreground || generation != _playbackGeneration) {
          return;
        }
        await _guard();
        if (!mounted || !_foreground || generation != _playbackGeneration) {
          return;
        }
        await _audio.play(result.bytes, result.mimeType);
        if (!mounted || !_foreground || generation != _playbackGeneration) {
          await _audio.stop();
        }
      });

  Future<void> _feedback(Map<String, dynamic> submission) async {
    final note =
        TextEditingController(text: submission['feedbackNote'] as String);
    String status =
        const {'complete', 'repeat'}.contains(submission['feedbackStatus'])
            ? submission['feedbackStatus'] as String
            : 'complete';
    bool busy = false;
    String? error;
    try {
      await _showPortalDialog(
          builder: (_) => StatefulBuilder(
              builder: (context, update) => PopScope(
                  canPop: !busy,
                  child: AlertDialog(
                    title: Text(_t('Teacher feedback')),
                    content: SizedBox(
                        width: 480,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              DropdownButtonFormField<String>(
                                  initialValue: status,
                                  isExpanded: true,
                                  items: ['complete', 'repeat']
                                      .map((value) => DropdownMenuItem(
                                          value: value, child: Text(_t(value))))
                                      .toList(),
                                  onChanged: busy
                                      ? null
                                      : (value) => update(() {
                                            status = value!;
                                          })),
                              TextField(
                                  controller: note,
                                  enabled: !busy,
                                  maxLength: 1000,
                                  minLines: 2,
                                  maxLines: 5,
                                  decoration: InputDecoration(
                                      labelText: _t('Feedback note'))),
                              if (error != null) Text(_errorText(error!)),
                              if (busy) const LinearProgressIndicator(),
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: busy ? null : () => Navigator.pop(context),
                          child: Text(_t('Cancel'))),
                      FilledButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  update(() {
                                    busy = true;
                                    error = null;
                                  });
                                  try {
                                    await _guard();
                                    await _service!.feedback(
                                        submission['id'] as String,
                                        status,
                                        note.text);
                                    if (context.mounted) Navigator.pop(context);
                                  } catch (failure) {
                                    if (context.mounted) {
                                      update(() {
                                        error = failure is ReaderUstadFailure
                                            ? failure.code
                                            : 'network';
                                      });
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      update(() {
                                        busy = false;
                                      });
                                    }
                                  }
                                },
                          child: Text(_t('Save feedback')))
                    ],
                  ))));
    } finally {
      note.dispose();
    }
    if (mounted) await _run(_reload);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _cancelRequest();
      if (_capture.phase == ReaderVoiceCapturePhase.recording) {
        unawaited(_capture.stop());
      }
    }
  }

  @override
  void dispose() {
    _operationGeneration++;
    _playbackGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?.removeListener(_contextChanged);
    _service?.dispose();
    _capture.removeListener(_captureChanged);
    _store.removeListener(_changed);
    _audio.removeListener(_changed);
    _capture.dispose();
    _store.dispose();
    _audio.dispose();
    super.dispose();
  }

  Widget _draft(
          ReaderLocalRecording recording, Map<String, dynamic>? assignment) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
                '${recording.label} · ${(recording.durationMillis / 1000).toStringAsFixed(1)}s · ${(recording.bytes / 1024).ceil()} KiB',
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            Wrap(spacing: 8, runSpacing: 6, children: [
              OutlinedButton.icon(
                  onPressed:
                      _busy || _saving ? null : () => _preview(recording),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(_t('Preview'))),
              if (assignment != null &&
                  assignment['role'] == 'student' &&
                  assignment['status'] == 'assigned' &&
                  _overview?.links.any((link) =>
                          link['id'] == assignment['linkId'] &&
                          link['status'] == 'active') ==
                      true)
                FilledButton.icon(
                    onPressed: _busy ||
                            !_previewed.contains(recording.id) ||
                            _sent.contains(recording.id)
                        ? null
                        : () => _send(recording, assignment),
                    icon: const Icon(Icons.send_outlined),
                    label: Text(_t(
                        _sent.contains(recording.id) ? 'Sent' : 'Send clip'))),
              TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          if (await _confirm('Delete this local draft?')) {
                            try {
                              await _store.delete(recording.id);
                            } catch (_) {
                              if (mounted) {
                                setState(() {
                                  _localError = 'recording';
                                });
                              }
                            }
                          }
                        },
                  child: Text(_t('Delete local clip'))),
            ]),
            Text(
                _t(_previewed.contains(recording.id)
                    ? 'Previewed; sending is your choice.'
                    : 'Preview before sending.'),
                style: Theme.of(context).textTheme.bodySmall),
          ]));

  Widget _assignmentCard(Map<String, dynamic> assignment) {
    final student = assignment['role'] == 'student';
    final active = _overview?.links.any((link) =>
            link['id'] == assignment['linkId'] && link['status'] == 'active') ==
        true;
    final assigned = assignment['status'] == 'assigned';
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(assignment['title'] as String,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                      '${_t(assignment['kind'] == 'sabaq' ? 'Sabaq' : assignment['kind'] == 'sabqi' ? 'Sabqi' : 'Manzil')} · ${assignment['editionKey']} · ${assignment['startPage']}–${assignment['endPage']} · ${_t(assignment['status'] as String)}'),
                  if (assignment['dueAt'] != null)
                    Text(MaterialLocalizations.of(context).formatMediumDate(
                        DateTime.parse(assignment['dueAt'] as String)
                            .toLocal())),
                  if ((assignment['instructions'] as String).isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: SelectableText(
                            assignment['instructions'] as String)),
                  if (active && assigned)
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      if (student)
                        FilledButton.icon(
                            onPressed: _busy ||
                                    _capture.isBusy ||
                                    _saving ||
                                    _startingRecording ||
                                    !_capture.supported ||
                                    !_store.supported
                                ? null
                                : () => _record(assignment),
                            icon: const Icon(Icons.mic_none),
                            label: Text(_t('Record lesson')))
                      else
                        OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () async {
                                    if (await _confirm(
                                        'Cancel this assignment?')) {
                                      await _run(() async {
                                        await _service!.cancelAssignment(
                                            assignment['id'] as String);
                                        await _reload();
                                      });
                                    }
                                  },
                            child: Text(_t('Cancel assignment'))),
                    ]),
                  Text(_t('Older clips are in Shared recordings.'),
                      style: Theme.of(context).textTheme.bodySmall),
                  ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                          '${_t('Recent submissions')} (${(assignment['submissions'] as List).length})'),
                      children: [
                        for (final raw in assignment['submissions'] as List)
                          Builder(builder: (context) {
                            final submission = raw as Map<String, dynamic>;
                            final expired = DateTime.parse(
                                    submission['expiresAt'] as String)
                                .isBefore(DateTime.now());
                            final deleted = submission['deleted'] == true;
                            return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                          '${_t(submission['feedbackStatus'] as String)} · ${(submission['durationMillis'] as int) ~/ 1000}s${deleted ? ' · ${_t('Deleted')}' : expired ? ' · ${_t('Expired')}' : ''}'),
                                      if ((submission['feedbackNote'] as String)
                                          .isNotEmpty)
                                        SelectableText(
                                            submission['feedbackNote']
                                                as String),
                                      Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            OutlinedButton.icon(
                                                onPressed: _busy ||
                                                        expired ||
                                                        deleted ||
                                                        submission[
                                                                'deliveryState'] !=
                                                            'ready'
                                                    ? null
                                                    : () => _playSubmission(
                                                        submission),
                                                icon: const Icon(
                                                    Icons.play_arrow),
                                                label: Text(
                                                    _t('Play private clip'))),
                                            if (!student && active && !deleted)
                                              TextButton(
                                                  onPressed: _busy
                                                      ? null
                                                      : () =>
                                                          _feedback(submission),
                                                  child: Text(
                                                      _t('Teacher feedback'))),
                                            if (student && !deleted)
                                              TextButton(
                                                  onPressed: _busy
                                                      ? null
                                                      : () async {
                                                          if (await _confirm(
                                                              'Delete this sent clip? This cannot be undone.')) {
                                                            await _run(
                                                                () async {
                                                              await _audio
                                                                  .stop();
                                                              await _service!
                                                                  .deleteSubmission(
                                                                      submission[
                                                                              'id']
                                                                          as String);
                                                              await _reload();
                                                            });
                                                          }
                                                        },
                                                  child: Text(
                                                      _t('Delete sent clip'))),
                                          ]),
                                    ]));
                          }),
                      ]),
                ])));
  }

  Widget _pager(int page, int totalPages, ValueChanged<int> select) => Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
                onPressed: _busy || page <= 1 ? null : () => select(page - 1),
                child: Text(_t('Previous'))),
            Text('$page / $totalPages'),
            TextButton(
                onPressed:
                    _busy || page >= totalPages ? null : () => select(page + 1),
                child: Text(_t('Next'))),
          ]);
  Widget _libraryRecording(Map<String, dynamic> recording) {
    final student = recording['role'] == 'student';
    final expired = DateTime.parse(recording['expiresAt'] as String)
        .isBefore(DateTime.now());
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(recording['assignmentTitle'] as String,
              style: Theme.of(context).textTheme.titleMedium),
          Text(
              '${_t(recording['feedbackStatus'] as String)} · ${recording['createdAt']}'),
          if ((recording['feedbackNote'] as String).isNotEmpty)
            SelectableText(recording['feedbackNote'] as String),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(
                onPressed: _busy ||
                        expired ||
                        recording['deleted'] == true ||
                        recording['deliveryState'] != 'ready'
                    ? null
                    : () => _playSubmission(recording),
                child: Text(_t('Play private clip'))),
            if (!student)
              TextButton(
                  onPressed: _busy ? null : () => _feedback(recording),
                  child: Text(_t('Teacher feedback'))),
            if (student)
              TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          if (await _confirm(
                              'Delete this sent clip? This cannot be undone.')) {
                            await _run(() async {
                              await _audio.stop();
                              await _service!
                                  .deleteSubmission(recording['id'] as String);
                              await _reload();
                            });
                          }
                        },
                  child: Text(_t('Delete sent clip'))),
          ]),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final links = _overview?.links ?? const <Map<String, dynamic>>[];
    final link = links.where((item) => item['id'] == _linkId).firstOrNull;
    final assignments = _assignments
        .where((item) => _linkId == null || item['linkId'] == _linkId)
        .toList();
    final drafts = _identity == null || _contextLocked
        ? const <ReaderLocalRecording>[]
        : _store.recordings
            .where((item) => item.reference.startsWith('ustad:$_scope:'))
            .toList();
    return Directionality(
        textDirection: ReaderLocalizationScope.of(context).textDirection,
        child: Scaffold(
          // Zero-height bar: keeps the status bar styling and top inset while
          // the hero header in the body carries title, back and actions.
          appBar: AppBar(toolbarHeight: 0, automaticallyImplyLeading: false),
          body: SafeArea(
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: CustomScrollView(slivers: [
                        SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            sliver: SliverToBoxAdapter(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                  Builder(
                                      // Resolved under the Directionality
                                      // above so the header mirrors in RTL.
                                      builder: (context) => AppPageHeader(
                                              title: _t(
                                                  'Private Ustad & student'),
                                              subtitle: _t(
                                                  'Registered accounts only. Your Quran backup is not shared here.'),
                                              icon: Icons.school_outlined,
                                              onBack: AppPageHeader.popAction(
                                                  context),
                                              actions: [
                                                IconButton(
                                                    tooltip: _t('Refresh'),
                                                    onPressed: _busy
                                                        ? null
                                                        : () => _service == null
                                                            ? _connect()
                                                            : _run(_reload),
                                                    icon: const Icon(
                                                        Icons.refresh))
                                              ])),
                                  const SizedBox(height: 14),
                                  SelectableText(_base,
                                      textDirection: TextDirection.ltr,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  const SizedBox(height: 12),
                                  Text(_t('Clips expire after 30 days. Student storage: 100 MiB.'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  if (_overview != null)
                                    Text(
                                        '${_t('Storage')}: ${(_overview!.usageBytes / 1048576).toStringAsFixed(1)} / 100 MiB'),
                                  if (_busy) ...[
                                    const SizedBox(height: 12),
                                    LinearProgressIndicator(
                                        semanticsLabel: _t('Working')),
                                    TextButton(
                                        onPressed: _cancelRequest,
                                        child: Text(_t('Cancel request')))
                                  ],
                                  if (_error != null)
                                    Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        child: Text(_errorText(_error!),
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error))),
                                  if (_localError != null ||
                                      _capture.errorMessage != null ||
                                      _audio.errorMessage != null)
                                    Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        child: Text(_errorText('recording'))),
                                  Wrap(spacing: 10, runSpacing: 8, children: [
                                    FilledButton.tonalIcon(
                                        onPressed: _busy || _overview == null
                                            ? null
                                            : () => _invite(accept: false),
                                        icon: const Icon(Icons.person_add_alt),
                                        label: Text(_t('Create invite'))),
                                    OutlinedButton.icon(
                                        onPressed: _busy || _overview == null
                                            ? null
                                            : () => _invite(accept: true),
                                        icon: const Icon(Icons.link),
                                        label: Text(_t('Accept invite'))),
                                    if (_audio.playing ||
                                        _store.playingId != null)
                                      OutlinedButton.icon(
                                          onPressed: () {
                                            _stopPlayback();
                                          },
                                          icon: const Icon(Icons.stop),
                                          label: Text(_t('Stop audio'))),
                                  ]),
                                  const SizedBox(height: 16),
                                  if (links.isEmpty && _overview != null)
                                    Text(_t('No connections yet.')),
                                  if (link != null) ...[
                                    DropdownButtonFormField<String>(
                                        key: ValueKey(_linkId),
                                        initialValue: _linkId,
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                            labelText: _t('Connection'),
                                            border: const OutlineInputBorder()),
                                        items: links
                                            .map((item) => DropdownMenuItem(
                                                value: item['id'] as String,
                                                child: Text(
                                                    '${_t(item['role'] == 'teacher' ? 'Teacher' : 'Student')} · ${item['role'] == 'teacher' ? item['studentName'] ?? '—' : item['teacherName']} · ${_t(item['status'] as String)}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis)))
                                            .toList(),
                                        onChanged: _busy
                                            ? null
                                            : (value) {
                                                _linkId = value;
                                                _assignmentsPage = 1;
                                                unawaited(_run(_reload));
                                              }),
                                    _pager(_linksPage, _overview!.totalPages,
                                        (page) {
                                      _linksPage = page;
                                      _linkId = null;
                                      _assignmentsPage = 1;
                                      unawaited(_run(_reload));
                                    }),
                                    const SizedBox(height: 10),
                                    Wrap(spacing: 8, runSpacing: 8, children: [
                                      if (link['role'] == 'teacher' &&
                                          link['status'] == 'active')
                                        FilledButton.icon(
                                            onPressed: _busy
                                                ? null
                                                : () => _assign(link),
                                            icon: const Icon(
                                                Icons.assignment_outlined),
                                            label: Text(_t('New assignment'))),
                                      if (link['status'] != 'revoked')
                                        TextButton(
                                            onPressed: _busy
                                                ? null
                                                : () async {
                                                    if (await _confirm(
                                                        'Stop sharing with this participant? Student clips remain private until deleted or expired.')) {
                                                      await _run(() async {
                                                        await _audio.stop();
                                                        _store.stopPlayback();
                                                        await _service!.revoke(
                                                            link['id']
                                                                as String);
                                                        await _reload();
                                                      });
                                                    }
                                                  },
                                            child:
                                                Text(_t('Revoke connection'))),
                                      if (link['role'] == 'student')
                                        TextButton(
                                            onPressed: _busy
                                                ? null
                                                : () async {
                                                    if (await _confirm(
                                                        'Delete your clips and revoke this connection? This cannot be undone.')) {
                                                      await _run(() async {
                                                        await _audio.stop();
                                                        _store.stopPlayback();
                                                        await _service!
                                                            .deleteLinkData(
                                                                link['id']
                                                                    as String);
                                                        await _reload();
                                                      });
                                                    }
                                                  },
                                            child: Text(_t(
                                                'Delete lesson recordings and revoke access'))),
                                    ]),
                                  ],
                                  if (_capture.phase ==
                                          ReaderVoiceCapturePhase.recording ||
                                      _capture.phase ==
                                          ReaderVoiceCapturePhase.stopping) ...[
                                    const SizedBox(height: 12),
                                    Text('${_capture.elapsed.inSeconds} / 60s'),
                                    FilledButton.icon(
                                        onPressed: _capture.phase ==
                                                ReaderVoiceCapturePhase
                                                    .recording
                                            ? () => _capture.stop()
                                            : null,
                                        icon: const Icon(Icons.stop),
                                        label: Text(_t('Stop recording'))),
                                  ],
                                  Text(_t('Shared audio is deleted; assignment, feedback and relationship history remain.'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  const SizedBox(height: 12),
                                  Text(_t('Saved locally before sending. Maximum 60 seconds and 8 MiB.'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  Text(_t('Recorder duration only; no Tajweed or memorization score.'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  if (drafts.isNotEmpty) ...[
                                    const SizedBox(height: 18),
                                    Text(_t('Saved lesson drafts'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    for (final recording in drafts)
                                      _draft(
                                          recording,
                                          _assignments
                                              .where((item) =>
                                                  recording.reference ==
                                                  _reference(
                                                      item['id'] as String))
                                              .firstOrNull),
                                  ],
                                  if (_overview != null)
                                    ExpansionTile(
                                        key: const ValueKey(
                                            'ustad-recording-library'),
                                        tilePadding: EdgeInsets.zero,
                                        title: Text(_t('Shared recordings')),
                                        children: [
                                          _pager(
                                              _recordingsPage, _recordingsPages,
                                              (page) {
                                            _recordingsPage = page;
                                            unawaited(_run(_reload));
                                          }),
                                          for (final recording in _recordings)
                                            _libraryRecording(recording),
                                        ]),
                                  Text(_t('Assignments'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  _pager(_assignmentsPage, _assignmentsPages,
                                      (page) {
                                    _assignmentsPage = page;
                                    unawaited(_run(_reload));
                                  }),
                                  if (_overview != null && assignments.isEmpty)
                                    Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        child: Text(_t(
                                            'No assignments for this connection.'))),
                                ]))),
                        SliverPadding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                            sliver: SliverList.builder(
                                itemCount: assignments.length,
                                itemBuilder: (context, index) =>
                                    _assignmentCard(assignments[index]))),
                      ])))),
        ));
  }
}
