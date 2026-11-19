// Visual QA harness: renders app screens to PNG so they can be reviewed.
//
// Lives outside `test/` on purpose so `flutter test` (CI) does not run it.
// Run with:
//   flutter test tool/ui_snapshots/ui_snapshots_test.dart
// Output: build/ui_snapshots/<screen>_<light|dark>_<en|ur>.png
// Layout errors (overflow etc.) are appended to build/ui_snapshots/_issues.txt
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_flutter_app/app/app_theme.dart';
import 'package:my_flutter_app/app/reader_localization.dart';
import 'package:my_flutter_app/core/prayer/prayer_calculator.dart';
import 'package:my_flutter_app/core/prayer/prayer_models.dart';
import 'package:my_flutter_app/core/prayer/prayer_reminder_service.dart';
import 'package:my_flutter_app/core/services/reader_recording_store.dart';
import 'package:my_flutter_app/core/services/reader_ustad_audio.dart';
import 'package:my_flutter_app/core/services/reader_voice_capture.dart';
import 'package:my_flutter_app/core/storage/reader_preferences.dart';
import 'package:my_flutter_app/core/worship/worship_store.dart';
import 'package:my_flutter_app/features/quran_reader/data/models/reader_launch_state.dart';
import 'package:my_flutter_app/features/quran_reader/data/repositories/quran_reader_repository.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/quran_audio_service.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/quran_reader_sync_service.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/reader_audio_practice.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/quran_page_insight.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/quran_page_verse.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/reader_account_service.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/reader_ustad_service.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/quran_asset_pack_download.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/quran_chapter_summary.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/quran_juz_navigation_entry.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/quran_navigation_marker.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/quran_page.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/quran_reciter.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/quran_spread.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/quran_surah_navigation_entry.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/reader_admin_config.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/reader_bookmark.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/reader_daily_progress_state.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/reader_growth_models.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/reader_history_entry.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/reader_settings.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/reader_sync_snapshot.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/controllers/quran_reader_controller.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/screens/prayer_settings_screen.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/screens/qibla_screen.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/screens/quran_ai_studio_screen.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/screens/quran_asset_packs_screen.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/screens/quran_bookmarks_screen.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/screens/quran_growth_hub_screen.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/screens/quran_onboarding_screen.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/screens/quran_search_screen.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/screens/quran_settings_screen.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/screens/quran_study_screen.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/screens/quran_ustad_screen.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/screens/worship_hub_screen.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/screens/worship_learning_screen.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/widgets/bootstrap_splash.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/widgets/jump_to_page_dialog.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/widgets/kanzul_iman_study_sheet.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/widgets/reader_app_bar.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/widgets/reader_audio_sheet.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/widgets/reader_bottom_dock.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/widgets/reader_compare_sheet.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/widgets/reader_dashboard_sheet.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/widgets/reader_hifz_trainer_sheet.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/widgets/reader_insights_sheet.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/widgets/reader_page_strip_sheet.dart';

import '../../test/reader_ustad_service_test.dart' as ustad_fixtures;

const _outDir = 'build/ui_snapshots';
const _flutterFonts = r'C:\dev\flutter\bin\cache\artifacts\material_fonts';
final _rootKey = GlobalKey();
final _issues = <String>[];

/// Which variants to render. Override with e.g.
/// `--dart-define=SNAP_VARIANTS=light_en` and `--dart-define=SNAP_ONLY=qibla`.
const _variantFilter = String.fromEnvironment('SNAP_VARIANTS');
const _only = String.fromEnvironment('SNAP_ONLY');

class _Variant {
  const _Variant(this.dark, this.language);
  final bool dark;
  final ReaderLanguage language;
  String get code => switch (language) {
        ReaderLanguage.urdu => 'ur',
        ReaderLanguage.arabic => 'ar',
        _ => 'en',
      };
  String get id => '${dark ? 'dark' : 'light'}_$code';
}

const _variants = <_Variant>[
  _Variant(false, ReaderLanguage.english),
  _Variant(true, ReaderLanguage.english),
  _Variant(false, ReaderLanguage.urdu),
];

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  var any = false;
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
    any = true;
  }
  if (any) await loader.load();
}

Future<void> _loadFonts() async {
  await _loadFont('MaterialIcons', ['$_flutterFonts/MaterialIcons-Regular.otf']);
  await _loadFont('Roboto', [
    '$_flutterFonts/Roboto-Regular.ttf',
    '$_flutterFonts/Roboto-Medium.ttf',
    '$_flutterFonts/Roboto-Bold.ttf',
  ]);
  // The test engine has no platform font fallback, and the brand faces carry
  // no Arabic script. When a run renders only RTL variants
  // (--dart-define=SNAP_VARIANTS=light_ur), stand in a system face that has
  // Arabic glyphs for both brand families so Urdu/Arabic text is readable.
  final rtlOnly = _variantFilter.isNotEmpty &&
      _variantFilter.split(',').every((id) => id.endsWith('_ur') || id.endsWith('_ar'));
  const system = r'C:\Windows\Fonts';
  if (rtlOnly && File('$system/segoeui.ttf').existsSync()) {
    final faces = ['$system/segoeui.ttf', '$system/seguisb.ttf', '$system/segoeuib.ttf'];
    await _loadFont('Outfit', faces);
    await _loadFont('WorkSans', faces);
  } else {
    await _loadFont('Outfit', ['assets/fonts/Outfit.ttf']);
    await _loadFont('WorkSans', ['assets/fonts/WorkSans.ttf']);
  }
}

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

const _surahSeed = <(int, String, String, String, int, String, int)>[
  (1, 'Al-Fatihah', 'الفاتحة', 'The Opener', 1, 'makkah', 7),
  (2, 'Al-Baqarah', 'البقرة', 'The Cow', 2, 'madinah', 286),
  (3, 'Ali \'Imran', 'آل عمران', 'Family of Imran', 50, 'madinah', 200),
  (4, 'An-Nisa', 'النساء', 'The Women', 77, 'madinah', 176),
  (5, 'Al-Ma\'idah', 'المائدة', 'The Table Spread', 106, 'madinah', 120),
  (6, 'Al-An\'am', 'الأنعام', 'The Cattle', 128, 'makkah', 165),
  (7, 'Al-A\'raf', 'الأعراف', 'The Heights', 151, 'makkah', 206),
  (18, 'Al-Kahf', 'الكهف', 'The Cave', 293, 'makkah', 110),
  (36, 'Ya-Sin', 'يس', 'Ya Sin', 440, 'makkah', 83),
  (55, 'Ar-Rahman', 'الرحمن', 'The Beneficent', 531, 'madinah', 78),
  (67, 'Al-Mulk', 'الملك', 'The Sovereignty', 562, 'makkah', 30),
  (112, 'Al-Ikhlas', 'الإخلاص', 'The Sincerity', 604, 'makkah', 4),
];

final _surahs = [
  for (final s in _surahSeed)
    QuranSurahNavigationEntry(
      id: s.$1,
      nameSimple: s.$2,
      nameComplex: s.$2,
      nameArabic: s.$3,
      translatedName: s.$4,
      standardStartPage: s.$5,
      tajScanStartPage: s.$5,
    ),
];

final _chapters = [
  for (final s in _surahSeed)
    QuranChapterSummary(
      id: s.$1,
      nameSimple: s.$2,
      nameArabic: s.$3,
      translatedName: s.$4,
      revelationPlace: s.$6,
      versesCount: s.$7,
      pages: [s.$5, s.$5 + 4],
    ),
];

const _juzNames = ['Alif Lam Meem', 'Sayaqool', 'Tilkal Rusul', 'Lan Tana Loo', 'Wal Mohsanat', 'La Yuhibbullah'];
final _juzs = [
  for (var i = 1; i <= 30; i++)
    QuranJuzNavigationEntry(
      number: i,
      name: _juzNames[(i - 1) % _juzNames.length],
      nameArabic: 'الجزء $i',
      standardStartPage: (i - 1) * 20 + 2,
      tajScanStartPage: (i - 1) * 20 + 2,
    ),
];

final _bookmarks = [
  ReaderBookmark(pageNumber: 12, label: 'Ayat al-Kursi revision', folder: 'Hifz', createdAtIso: DateTime(2026, 11, 12, 6, 30).toIso8601String()),
  ReaderBookmark(pageNumber: 293, label: 'Friday reading', folder: 'Weekly', createdAtIso: DateTime(2026, 11, 13, 13).toIso8601String()),
  ReaderBookmark(pageNumber: 440, label: 'Ya-Sin', folder: 'Hifz', createdAtIso: DateTime(2026, 11, 15, 21, 15).toIso8601String()),
  ReaderBookmark(pageNumber: 562, label: 'Before sleep: a longer label that should wrap or ellipsize gracefully', folder: 'Daily', createdAtIso: DateTime(2026, 11, 18, 22).toIso8601String()),
];

final _history = [
  for (final (i, p) in [12, 13, 293, 440, 562].indexed)
    ReaderHistoryEntry(pageNumber: p, viewedAtIso: DateTime(2026, 11, 19, 8).subtract(Duration(hours: i * 7)).toIso8601String()),
];

final _hifz = [
  ReaderHifzReviewEntry(pageNumber: 12, strength: HifzPageStrength.values.first, updatedAtIso: DateTime(2026, 11, 10).toIso8601String(), reviewCount: 2),
  ReaderHifzReviewEntry(pageNumber: 440, strength: HifzPageStrength.values.last, updatedAtIso: DateTime(2026, 11, 17).toIso8601String(), reviewCount: 6),
];

const _reciters = [
  QuranReciter(id: 7, name: 'Mishari Rashid al-Afasy', style: 'Murattal'),
  QuranReciter(id: 2, name: 'AbdulBaset AbdulSamad', style: 'Mujawwad'),
  QuranReciter(id: 3, name: 'Abdur-Rahman as-Sudais', style: null),
];

final _insight = QuranPageInsight(
  pageNumber: 12,
  chapterIds: const [2],
  juzNumbers: const [1],
  hizbNumbers: const [2],
  rubElHizbNumbers: const [5],
  rukuNumbers: const [9, 10],
  manzilNumbers: const [1],
  sajdahVerseKeys: const [],
  translationEn: 'O you who have believed, seek help through patience and prayer. Indeed, Allah is with the patient.',
  translationUr: 'اے ایمان والو! صبر اور نماز سے مدد چاہو، بیشک اللہ صابروں کے ساتھ ہے۔',
  verses: [
    for (var i = 153; i <= 157; i++)
      QuranPageVerse(
        verseKey: '2:$i',
        chapterId: 2,
        verseNumber: i,
        juzNumber: 2,
        hizbNumber: 3,
        rubElHizbNumber: 9,
        rukuNumber: 19,
        manzilNumber: 1,
        sajdahNumber: null,
        translationEn: 'O you who have believed, seek help through patience and prayer. Indeed, Allah is with the patient.',
        translationUr: 'اے ایمان والو! صبر اور نماز سے مدد چاہو، بیشک اللہ صابروں کے ساتھ ہے۔',
      ),
  ],
);

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _Repository implements QuranReaderRepository {
  _Repository({required this.nightMode});
  final bool nightMode;

  @override
  String get adminConfigBaseUrl => 'https://reader.example.com';
  @override
  ReaderAdminConfig get adminConfig => const ReaderAdminConfig.empty();
  @override
  Future<ReaderLaunchState> loadLaunchState() async => ReaderLaunchState(
        initialPageNumber: 12,
        settings: const ReaderSettings.defaults().copyWith(nightMode: nightMode),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final args = invocation.positionalArguments;
    switch (invocation.memberName) {
      case #availableZipPacks:
        return <QuranZipAssetPack>[];
      case #availableImageEditions:
      case #compareEditions:
        return <MushafEdition>[MushafEdition.lines16, MushafEdition.lines15, MushafEdition.lines13];
      case #chapters:
        return _chapters;
      case #surahs:
      case #standardSurahs:
        return _surahs;
      case #juzs:
      case #standardJuzs:
        return _juzs;
      case #fetchAvailableZipPacks:
        return Future<List<QuranZipAssetPack>>.value([]);
      case #hasOfflinePackForEdition:
        return Future<bool>.value(false);
      case #hasBundledPackForEdition:
      case #hasAssetsForEdition:
      case #hasAnyPageAssets:
        return true;
      case #loadPartialOfflinePacks:
        return Future<Map<MushafEdition, QuranPartialAssetPack>>.value({});
      case #loadDailyTargetPages:
        return Future<int>.value(8);
      case #loadDailyProgressState:
        return Future<ReaderDailyProgressState>.value(ReaderDailyProgressState(
          dateKey: invocation.namedArguments[#todayKey] as String,
          startPage: 9,
        ));
      case #loadReadingPlan:
        return Future<ReaderReadingPlan>.value(const ReaderReadingPlan.defaults());
      case #loadExperienceSettings:
        return Future<ReaderExperienceSettings>.value(const ReaderExperienceSettings.defaults());
      case #loadReadingHistory:
        return Future<List<ReaderHistoryEntry>>.value(_history);
      case #loadPageNotesByEdition:
        return Future<Map<String, Map<int, String>>>.value({
          '16_lines': {12: 'Revise the last three lines before Fajr.'}
        });
      case #loadFavoritePagesByEdition:
        return Future<Map<String, List<int>>>.value({
          '16_lines': [12, 293]
        });
      case #loadBookmarks:
        return Future<List<ReaderBookmark>>.value(_bookmarks);
      case #loadHifzRevisionEntries:
        return Future<List<ReaderHifzReviewEntry>>.value(_hifz);
      case #loadPreferredReciterId:
      case #loadAudioChapterId:
        return Future<int?>.value(null);
      case #loadAudioPositionMillis:
        return Future<int>.value(0);
      case #loadReadingStreakCount:
        return Future<int>.value(5);
      case #loadAudioRepeatEnabled:
        return Future<bool>.value(false);
      case #loadReadingStreakLastDate:
        return Future<String?>.value(null);
      case #markersForCategory:
        return <QuranNavigationMarker>[
          for (var i = 1; i <= 6; i++)
            QuranNavigationMarker(id: i, title: 'Marker $i', subtitle: 'Page ${i * 9}', pageNumber: i * 9, category: '${args.isEmpty ? 'ruku' : args.first}'),
        ];
      case #totalPagesForMode:
      case #totalPagesForEdition:
      case #imagePageCount:
        return 550;
      case #totalSpreadsForMode:
        return 275;
      case #spreadIndexFromPage:
        return ((args.first as int) - 1) ~/ 2;
      case #clampPage:
      case #standardPageForNavigationPage:
      case #navigationPageForStandardPage:
        return (args.first as int).clamp(1, 550);
      case #pageForNumber:
      case #pageForStandardPageInEdition:
      case #pageForCurrentReferenceInEdition:
        return QuranPage(
            number: args.first as int,
            isLeftPage: (invocation.namedArguments[#isLeftPage] as bool?) ?? false,
            contentType: QuranPageContentType.placeholder);
      case #spreadForIndex:
        return const QuranSpread(
            index: 5,
            rightPage: QuranPage(number: 11, isLeftPage: false, contentType: QuranPageContentType.placeholder),
            leftPage: QuranPage(number: 12, isLeftPage: true, contentType: QuranPageContentType.placeholder));
      case #chapterSummaryForPage:
        return _chapters[1];
      case #chapterSummaryForId:
        final id = args.first as int?;
        for (final chapter in _chapters) {
          if (chapter.id == id) return chapter;
        }
        return null;
      case #surahEntryForPage:
        return _surahs[1];
      case #juzEntryForPage:
        return _juzs[0];
      case #pageInsightForPageNumber:
        return _insight;
      case #navigationPageForCurrentReferenceInEdition:
      case #navigationPageForStandardPageInEdition:
        return (args.first as int).clamp(1, 550);
      case #navigationPageForSurah:
      case #navigationPageForJuz:
        return 12;
      case #imageLeadingPagesToSkip:
        return 0;
      case #resolveSupportedEdition:
        return args.isEmpty ? MushafEdition.lines16 : args.first;
      case #canonicalPageForVerse:
        return 12;
      case #offlinePackStorageInfo:
        return Future<QuranPackStorageInfo>.value(const QuranPackStorageInfo(
          installedBytes: 148 * 1024 * 1024,
          archiveBytes: 0,
          partialBytes: 12 * 1024 * 1024,
          editionBytes: {MushafEdition.lines16: 148 * 1024 * 1024},
        ));
      case #loadChapterInfoForPage:
        return Future<String?>.value(
            'Al-Baqarah is the longest surah of the Quran. It was revealed in Madinah and lays out guidance on faith, worship, family and community life.');
      case #loadTafsirExcerptForPage:
        return Future<String?>.value(
            'This passage calls the believers to patience and prayer, and reminds them that Allah is with those who are patient.');
      case #refreshAdminConfig:
        return Future<void>.value();
      case #setMushafEdition:
      case #warmSupplementalContent:
        return Future<void>.value();
      case #dispose:
        return null;
    }
    final name = invocation.memberName.toString();
    if (name.startsWith('Symbol("save')) return Future<void>.value();
    // ignore: avoid_print
    print('SNAPSHOT-FAKE: repository member not faked: $name');
    return super.noSuchMethod(invocation);
  }
}

class _Accounts implements ReaderAccountService {
  @override
  void cancelPending() {}
  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sync implements QuranReaderSyncService {
  @override
  Future<ReaderSyncPushResult> pushSnapshot(
          {required String baseUrl,
          required String deviceId,
          required String token,
          required ReaderSyncSnapshot snapshot,
          int? baseRevision}) async =>
      const ReaderSyncPushResult(status: ReaderSyncStatus.success);
  @override
  void cancelPending() {}
  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Audio implements QuranAudioService {
  @override
  List<QuranReciter> get fallbackReciters => _reciters;
  @override
  Stream<PlayerState> get playerStateStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<String> get playbackErrors => const Stream.empty();
  @override
  Future<void> setRepeatEnabled(bool enabled) async {}
  @override
  Future<void> resetPlayback() async {}
  @override
  Future<List<QuranReciter>> loadReciters() async => _reciters;
  @override
  Future<Set<String>> downloadedChapterKeys() async => const {};
  @override
  late final ReaderAudioPractice practice = ReaderAudioPractice(
    positions: const Stream.empty(),
    duration: () => null,
    source: () => null,
    playing: () => false,
    pause: () async {},
    seek: (_) async {},
    play: () {},
    loop: (_) async {},
    repeatChapter: () => false,
  );
  @override
  ({Duration start, Duration end})? practiceRangeForAyah(String key) => null;
  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // ignore: avoid_print
    print('SNAPSHOT-FAKE: audio member not faked: ${invocation.memberName}');
    return super.noSuchMethod(invocation);
  }
}

class _Capture extends ReaderVoiceCapture {
  _Capture() : super.base();
  @override
  bool get supported => true;
  @override
  bool get speechSupported => false;
  @override
  ReaderVoiceCapturePhase get phase => ReaderVoiceCapturePhase.idle;
  @override
  bool get isTranscribing => false;
  @override
  String get transcript => '';
  @override
  Duration get elapsed => Duration.zero;
  @override
  String? get errorMessage => null;
  @override
  bool get hasRecording => false;
  @override
  bool get isPlaying => false;
  @override
  int get recordingRevision => 0;
  @override
  String get recordingMimeType => 'audio/webm';
  @override
  Future<Uint8List> readRecordingBytes() async => Uint8List(0);
  @override
  Future<void> start({String language = 'ar-SA', bool transcribe = false}) async {}
  @override
  Future<void> stop() async {}
  @override
  void cancel() {}
  @override
  Future<void> togglePlayback() async {}
  @override
  void download() {}
}

class _Store extends ReaderRecordingStore {
  _Store() : super.base(profileId: 'default', limits: const ReaderRecordingLimits());
  @override
  bool get supported => true;
  @override
  bool get busy => false;
  @override
  List<ReaderLocalRecording> get recordings => const [];
  @override
  String? get playingId => null;
  @override
  int get comparisonIndex => 0;
  @override
  String? get errorMessage => null;
  @override
  Future<void> refresh() async {}
  @override
  Future<ReaderLocalRecording> save(
          {required Uint8List bytes,
          required String mimeType,
          required Duration duration,
          String label = '',
          String reference = '',
          int? chapterId}) =>
      throw UnimplementedError();
  @override
  Future<Uint8List> readBytes(String id) async => Uint8List(0);
  @override
  Future<void> play(String id) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> compare(String first, String second) async {}
  @override
  void stopPlayback() {}
}

class _UstadAudio extends ReaderUstadAudio {
  _UstadAudio() : super.base();
  @override
  bool get playing => false;
  @override
  String? get errorMessage => null;
  @override
  Future<void> play(Uint8List bytes, String mimeType) async {}
  @override
  Future<void> stop() async {}
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

class _Fx {
  _Fx(this.variant, this.controller);
  final _Variant variant;
  final QuranReaderController controller;
}

Future<_Fx> _fixture(WidgetTester tester, _Variant variant) async {
  late QuranReaderController controller;
  await tester.runAsync(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await ReaderLocalization.instance.load();
    await ReaderLocalization.instance.setLanguage(variant.language);
    controller = QuranReaderController(
      repository: _Repository(nightMode: variant.dark),
      audioService: _Audio(),
      readerSyncService: _Sync(),
      preferences: ReaderPreferences(),
      accountService: _Accounts(),
    );
    await controller.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  final prayers = PrayerReminderService.instance;
  prayers.loaded = true;
  prayers.busy = false;
  prayers.baseUrl = 'https://reader.example.com';
  prayers.error = null;
  prayers.currentEvent = null;
  prayers.nextEvent = null;
  prayers.settings = PrayerSettings(location: prayerCities.first, language: variant.code);
  prayers.todayTimes = PrayerCalculator.timesForDate(
    prayers.settings,
    PrayerCalculator.dateInZone(DateTime.now(), prayers.settings),
  );
  await tester.runAsync(() async {
    try {
      await prayers.initialize(baseUrl: prayers.baseUrl).timeout(const Duration(milliseconds: 400));
    } catch (_) {
      // The singleton's operation queue was last used inside an earlier
      // test's fake-async zone and cannot drain. Screens that wait on it
      // (Worship hub) only load in the first test of a process, which is
      // why each variant is rendered by its own `flutter test` run.
    }
  });
  return _Fx(variant, controller);
}

Widget _app(_Variant variant, Widget home) {
  final localization = ReaderLocalization.instance;
  return RepaintBoundary(
    key: _rootKey,
    child: ReaderLocalizationScope(
      localization: localization,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: variant.dark ? ThemeMode.dark : ThemeMode.light,
        locale: localization.locale,
        supportedLocales: const [Locale('en'), Locale('ur'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => Directionality(
          textDirection: localization.textDirection,
          child: child!,
        ),
        home: home,
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = _rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // Repaint everything first. Late relayouts in the test engine (the font
  // change notification arrives after the first frames) were seen to leave
  // an outdated picture for parts of a card even though layout was current.
  void repaint(RenderObject node) {
    node.markNeedsPaint();
    node.visitChildren(repaint);
  }

  repaint(boundary);
  await tester.pump();
  await tester.runAsync(() async {
    for (final (ratio, dir) in [(2.0, _outDir), (1.0, '$_outDir/thumbs')]) {
      final image = await boundary.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    }
  });
}

typedef _Build = Widget Function(BuildContext context, _Fx fx);
typedef _After = Future<void> Function(WidgetTester tester, _Fx fx, Future<void> Function(String suffix) shoot);

/// A blank page that opens something (sheet, dialog) once mounted.
class _Launcher extends StatefulWidget {
  const _Launcher({required this.open});
  final void Function(BuildContext context) open;
  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.open(context);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}

void _snap(String name, _Build build, {_After? after, List<_Variant> variants = _variants}) {
  if (_only.isNotEmpty && !_only.split(',').any(name.contains)) return;
  for (final variant in variants) {
    if (_variantFilter.isNotEmpty && !_variantFilter.split(',').contains(variant.id)) continue;
    testWidgets('$name ${variant.id}', (tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.padding = const FakeViewPadding(top: 56, bottom: 32);
      tester.view.viewPadding = const FakeViewPadding(top: 56, bottom: 32);
      addTearDown(tester.view.reset);

      final label = '${name}_${variant.id}';
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final text = details.exceptionAsString().split('\n').first;
        final where = details.context?.toDescription() ?? '';
        final widgetLine = details.informationCollector
                ?.call()
                .map((node) => node.toString())
                .where((line) => line.contains('.dart'))
                .take(2)
                .join(' | ') ??
            '';
        _issues.add('[$label] $text $where $widgetLine');
      };
      // Tests paint shadows as solid blocks by default; render the real blur.
      debugDisableShadows = false;
      try {
        final fx = await _fixture(tester, variant);
        await tester.pumpWidget(_app(variant, Builder(builder: (context) => build(context, fx))));
        await _settle(tester);
        await _capture(tester, label);
        if (after != null) {
          await after(tester, fx, (suffix) async {
            await _settle(tester);
            await _capture(tester, '${name}_${suffix}_${variant.id}');
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
        await tester.runAsync(() async {
          fx.controller.dispose();
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
      } catch (error, stack) {
        _issues.add('[$label] HARNESS FAILURE: $error\n${stack.toString().split('\n').take(6).join('\n')}');
      } finally {
        debugDisableShadows = true;
        FlutterError.onError = previousOnError;
      }
    });
  }
}

void _noop() {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Directory('$_outDir/thumbs').createSync(recursive: true);
    await _loadFonts();
    PrayerCalculator.initialize();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (_) async => null,
    );
  });

  tearDownAll(() {
    File('$_outDir/_issues.txt').writeAsStringSync(_issues.join('\n'));
    // ignore: avoid_print
    print('SNAPSHOT ISSUES (${_issues.length}):\n${_issues.join('\n')}');
  });

  _snap('splash', (context, fx) => BootstrapSplash(nightMode: fx.variant.dark));

  _snap('onboarding', (context, fx) => QuranOnboardingScreen(controller: fx.controller, onComplete: () async {}),
      after: (tester, fx, shoot) async {
    for (var i = 0; i < 6; i++) {
      await tester.fling(find.byType(PageView), Offset(fx.variant.language == ReaderLanguage.urdu ? 600 : -600, 0), 2000);
      await tester.pump(const Duration(milliseconds: 600));
    }
    await shoot('last');
  });

  _snap('settings', (context, fx) => QuranSettingsScreen(controller: fx.controller), after: (tester, fx, shoot) async {
    for (final (i, dy) in [-700.0, -700.0].indexed) {
      await tester.drag(find.byType(Scrollable).first, Offset(0, dy));
      await shoot('scroll${i + 1}');
    }
  });

  _snap('bookmarks', (context, fx) => QuranBookmarksScreen(controller: fx.controller));

  for (final tab in [0, 1]) {
    _snap(
        'search_${tab == 0 ? 'surah' : 'juz'}',
        (context, fx) => QuranSearchScreen(
              title: tr(context, 'Search'),
              initialTab: tab,
              nightMode: fx.variant.dark,
              surahs: _surahs,
              juzs: _juzs,
              surahPageResolver: (entry) => entry.standardStartPage,
              juzPageResolver: (entry) => entry.standardStartPage,
              surahSearch: (query) async => _surahs,
              juzSearch: (query) async => _juzs,
            ));
  }

  _snap(
      'dashboard',
      (context, fx) => QuranDashboardScreen(
            controller: fx.controller,
            onOpenGrowthHub: _noop,
            onOpenSearch: _noop,
            onOpenInsights: _noop,
            onOpenAudio: _noop,
            onOpenAiStudio: _noop,
            onOpenPageStrip: _noop,
            onOpenCompare: _noop,
            onOpenKanzulStudy: _noop,
          ), after: (tester, fx, shoot) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await shoot('scroll1');
  });

  _snap('growth_hub', (context, fx) => QuranGrowthHubScreen(controller: fx.controller), after: (tester, fx, shoot) async {
    for (final i in [1, 2]) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await shoot('scroll$i');
    }
  });

  _snap('asset_packs', (context, fx) => QuranAssetPacksScreen(controller: fx.controller));

  _snap('word_study', (context, fx) => QuranStudyScreen(controller: fx.controller), after: (tester, fx, shoot) async {
    // Study data is parsed from bundled assets on a background isolate.
    for (var i = 0; i < 100 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await shoot('loaded');
    await tester.dragFrom(const Offset(195, 700), const Offset(0, -600));
    await shoot('scroll1');
  });

  _snap('worship_hub', (context, fx) => WorshipHubScreen(controller: fx.controller), after: (tester, fx, shoot) async {
    for (var i = 0; i < 40 && find.byType(Scrollable).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await shoot('loaded');
    if (find.byType(Scrollable).evaluate().isEmpty) return;
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await shoot('scroll1');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
    await tester.pump(const Duration(milliseconds: 400));
    // First row of the overview opens the Namaz & Qaza diary section.
    await tester.tapAt(const Offset(195, 250));
    await shoot('diary');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await shoot('diary_scroll1');
  });

  _snap('worship_learning', (context, fx) {
    return WorshipLearningScreen(store: WorshipStore(profileId: 'default'));
  }, after: (tester, fx, shoot) async {
    await tester.dragFrom(const Offset(195, 700), const Offset(0, -600));
    await shoot('scroll1');
    for (final (i, x) in [200.0, 300.0].indexed) {
      await tester.tapAt(Offset(fx.variant.language == ReaderLanguage.urdu ? 390 - x : x, 108));
      await shoot('tab${i + 2}');
    }
  });

  _snap('ustad', (context, fx) {
    final service = ReaderUstadService(
      baseUrl: 'https://reader.example',
      identity: ustad_fixtures.identity,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/links')) {
          return ustad_fixtures.jsonResponse({
            ...ustad_fixtures.overview(),
            'links': [ustad_fixtures.link(role: 'student')]
          });
        }
        if (request.url.path.endsWith('/assignments')) {
          return ustad_fixtures.jsonResponse({
            'success': true,
            'assignments': [ustad_fixtures.assignment(role: 'student')],
            'meta': ustad_fixtures.meta()
          });
        }
        return ustad_fixtures.jsonResponse({'success': true, 'submissions': [], 'meta': ustad_fixtures.meta()});
      }),
    );
    return QuranUstadScreen(
      identityProvider: () async => ustad_fixtures.identity,
      baseUrl: 'https://reader.example',
      profileId: 'default',
      service: service,
      capture: _Capture(),
      recordingStore: _Store(),
      audio: _UstadAudio(),
    );
  }, after: (tester, fx, shoot) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await shoot('scroll1');
  });

  _snap('prayer_settings', (context, fx) => const PrayerSettingsScreen(baseUrl: 'https://reader.example.com'),
      after: (tester, fx, shoot) async {
    for (final i in [1, 2]) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await shoot('scroll$i');
    }
  });

  _snap('qibla', (context, fx) => const QiblaScreen());

  _snap('ai_studio', (context, fx) => QuranAiStudioScreen(controller: fx.controller), after: (tester, fx, shoot) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await shoot('scroll1');
  });

  _snap(
      'reader_chrome',
      (context, fx) => Scaffold(
            appBar: ReaderAppBar(
              controller: fx.controller,
              portraitMode: true,
              onOpenSearch: _noop,
              onOpenDashboard: _noop,
              onOpenGrowthHub: _noop,
              onOpenInsights: _noop,
              onOpenAudio: _noop,
              onOpenAiStudio: _noop,
              onOpenPageStrip: _noop,
              onOpenCompare: _noop,
              onOpenKanzulStudy: _noop,
              onOpenSettings: _noop,
              onToggleFullscreen: _noop,
            ),
            body: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ReaderBottomDock(
                    controller: fx.controller,
                    onOpenAudio: _noop,
                    onOpenInsights: _noop,
                    compact: true,
                  ),
                ),
              ],
            ),
          ));

  _snap('audio_sheet', (context, fx) => _Launcher(open: (context) => showReaderAudioSheet(context, controller: fx.controller)));
  _snap('audio_screen', (context, fx) => QuranAudioScreen(controller: fx.controller));
  _snap('insights_sheet', (context, fx) => _Launcher(open: (context) => showReaderInsightsSheet(context, controller: fx.controller)));
  _snap('insights_screen', (context, fx) => QuranInsightsScreen(controller: fx.controller));
  _snap('page_strip_sheet', (context, fx) => _Launcher(open: (context) => showReaderPageStripSheet(context, controller: fx.controller)));
  _snap('compare', (context, fx) => QuranCompareScreen(controller: fx.controller));
  _snap('hifz_trainer_sheet', (context, fx) => _Launcher(open: (context) => showReaderHifzTrainerSheet(context, controller: fx.controller)));
  _snap('kanzul_sheet', (context, fx) => _Launcher(open: (context) => showKanzulImanStudySheet(context, controller: fx.controller)));
  _snap('jump_dialog', (context, fx) => _Launcher(open: (context) => showJumpToPageDialog(context, currentPage: 12, maxPage: 550)));
}
