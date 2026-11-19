// Visual snapshot harness for the home screen. Lives outside test/ so CI
// does not run it. Run with:
//   flutter test tool/home_snapshots/home_snapshots_test.dart
//   flutter test tool/home_snapshots/home_snapshots_test.dart --dart-define=HOME_SNAPSHOT_ARABIC=true
// PNGs are written to build/home_snapshots/ (override the sub-folder with
// --dart-define=HOME_SNAPSHOT_SET=before).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:my_flutter_app/app/app_theme.dart';
import 'package:my_flutter_app/app/reader_localization.dart';
import 'package:my_flutter_app/core/storage/reader_preferences.dart';
import 'package:my_flutter_app/features/quran_reader/data/models/reader_launch_state.dart';
import 'package:my_flutter_app/features/quran_reader/data/repositories/quran_reader_repository.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/quran_audio_service.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/quran_reader_sync_service.dart';
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
import 'package:my_flutter_app/features/quran_reader/presentation/screens/quran_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _set = String.fromEnvironment('HOME_SNAPSHOT_SET', defaultValue: 'after');
// Run a second time with --dart-define=HOME_SNAPSHOT_ARABIC=true to render
// the Urdu configurations with an Arabic-script font.
const _arabicFonts = bool.fromEnvironment('HOME_SNAPSHOT_ARABIC');
const _flutterFonts = r'C:\dev\flutter\bin\cache\artifacts\material_fonts';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  var any = false;
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    any = true;
  }
  if (any) await loader.load();
}

class _Config {
  const _Config(
    this.name,
    this.size, {
    this.dark = false,
    this.language = ReaderLanguage.english,
    this.textScale = 1,
    this.reduceMotion = false,
  });
  final String name;
  final Size size;
  final bool dark;
  final ReaderLanguage language;
  final double textScale;
  final bool reduceMotion;
}

const _phone = Size(390, 844);
const _small = Size(360, 640);
const _desktop = Size(1280, 800);

const _configs = <_Config>[
  _Config('phone_light_en', _phone),
  _Config('phone_dark_en', _phone, dark: true),
  _Config('phone_light_en_reduced_motion', _phone, reduceMotion: true),
  _Config('phone_light_ur', _phone, language: ReaderLanguage.urdu),
  _Config('phone_dark_ur', _phone, dark: true, language: ReaderLanguage.urdu),
  _Config('small_light_en', _small),
  _Config('small_dark_ur', _small, dark: true, language: ReaderLanguage.urdu),
  _Config('small_light_en_bigtext', _small, textScale: 1.6),
  _Config('desktop_light_en', _desktop),
  _Config('desktop_dark_en', _desktop, dark: true),
  _Config('desktop_light_ur', _desktop, language: ReaderLanguage.urdu),
  _Config('tablet_light_en', Size(900, 1100)),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (_arabicFonts) {
      // The test engine has no per-glyph system fallback, and the screen
      // builds its own Theme, so for Urdu runs an Arabic-capable system font
      // stands in for both brand families. Metrics differ slightly from a
      // device, but text is real and RTL layout can be judged.
      const segoe = [
        r'C:\Windows\Fonts\segoeui.ttf',
        r'C:\Windows\Fonts\segoeuib.ttf',
      ];
      await _loadFont('Outfit', segoe);
      await _loadFont('WorkSans', segoe);
    } else {
      await _loadFont('Outfit', ['assets/fonts/Outfit.ttf']);
      await _loadFont('WorkSans', ['assets/fonts/WorkSans.ttf']);
    }
    await _loadFont('MaterialIcons', [
      '$_flutterFonts\\MaterialIcons-Regular.otf',
    ]);
    await _loadFont('Roboto', [
      '$_flutterFonts\\Roboto-Regular.ttf',
      '$_flutterFonts\\Roboto-Medium.ttf',
      '$_flutterFonts\\Roboto-Bold.ttf',
    ]);
    // Arabic-script fallback for Urdu / Arabic UI strings.
    await _loadFont('SegoeUI', [
      r'C:\Windows\Fonts\segoeui.ttf',
      r'C:\Windows\Fonts\segoeuib.ttf',
    ]);
  });

  for (final config in _configs.where(
    (c) => (c.language != ReaderLanguage.english) == _arabicFonts,
  )) {
    testWidgets('home ${config.name}', (tester) async {
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
        (_) async => null,
      );

      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = config.size * 2;
      addTearDown(tester.view.reset);

      late QuranReaderController controller;
      await tester.runAsync(() async {
        await ReaderLocalization.instance.setLanguage(config.language);
        controller = QuranReaderController(
          repository: _Repository(),
          audioService: _Audio(),
          readerSyncService: _Sync(),
          preferences: ReaderPreferences(),
        );
        await controller.initialize();
        await Future<void>.delayed(Duration.zero);
        for (final page in [188, 189, 190, 191, 187]) {
          await controller.jumpToPage(page);
        }
        if (config.dark) {
          await controller.toggleNightMode(true);
        }
        // Decode the page preview ahead of the first frame.
        final page = controller.currentPage;
        if (page.assetPath != null) {
          final bytes = await File(page.assetPath!).readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          await codec.getNextFrame();
        }
      });
      addTearDown(controller.dispose);

      final boundaryKey = GlobalKey();
      const fallback = ['SegoeUI', 'Roboto'];
      ThemeData withFallback(ThemeData theme) => theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamilyFallback: fallback),
      );

      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: ReaderLocalizationScope(
            localization: ReaderLocalization.instance,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: withFallback(AppTheme.light()),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(config.textScale),
                  disableAnimations: config.reduceMotion,
                  padding: config.size.width < 700
                      ? const EdgeInsets.only(top: 28, bottom: 16)
                      : EdgeInsets.zero,
                ),
                child: Directionality(
                  textDirection: ReaderLocalization.instance.textDirection,
                  child: DefaultTextStyle.merge(
                    style: TextStyle(fontFamilyFallback: fallback),
                    child: child!,
                  ),
                ),
              ),
              home: QuranHomeScreen(controller: controller),
            ),
          ),
        ),
      );

      Future<void> settle() async {
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump(const Duration(milliseconds: 300));
        }
      }

      Future<void> capture(String suffix) async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/home_snapshots/$_set/${config.name}_$suffix.png',
          );
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(data!.buffer.asUint8List());
        });
      }

      await settle();
      await capture('1_top');

      ScrollableState? scrollable;
      for (final state in tester.stateList<ScrollableState>(
        find.byType(Scrollable),
      )) {
        if (state.position.axis == Axis.vertical &&
            (scrollable == null ||
                state.position.maxScrollExtent >
                    scrollable.position.maxScrollExtent)) {
          scrollable = state;
        }
      }
      if (scrollable != null) {
        final position = scrollable.position;
        final step = config.size.height * 0.82;
        var shot = 2;
        var offset = step;
        while (shot <= 5) {
          final target = offset.clamp(0.0, position.maxScrollExtent);
          position.jumpTo(target);
          await settle();
          await capture('${shot}_scroll');
          if (target >= position.maxScrollExtent) break;
          offset += step;
          shot++;
        }
      }

      // Overflow and other layout errors must fail the snapshot run.
      expect(tester.takeException(), isNull);
    });
  }
}

class _Sync implements QuranReaderSyncService {
  @override
  Future<ReaderSyncPushResult> pushSnapshot({
    required String baseUrl,
    required String deviceId,
    required String token,
    required ReaderSyncSnapshot snapshot,
    int? baseRevision,
  }) async => const ReaderSyncPushResult(status: ReaderSyncStatus.success);
  @override
  void cancelPending() {}
  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Audio implements QuranAudioService {
  @override
  List<QuranReciter> get fallbackReciters => const [];
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
  Future<List<QuranReciter>> loadReciters() async => const [];
  @override
  Future<Set<String>> downloadedChapterKeys() async => const {};
  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository implements QuranReaderRepository {
  static const _chapter = QuranChapterSummary(
    id: 6,
    nameSimple: "Al-An'am",
    nameArabic: 'الأنعام',
    translatedName: 'The Cattle',
    revelationPlace: 'makkah',
    versesCount: 165,
    pages: [187, 188, 189, 190],
  );

  static String _pagePath(int number) {
    final name = number.clamp(1, 550).toString().padLeft(3, '0');
    return File(
      'assets/asset_packs/16_line/mobile-app-source/$name.webp',
    ).absolute.path;
  }

  @override
  String get adminConfigBaseUrl => 'https://reader.example.com';
  @override
  ReaderAdminConfig get adminConfig => const ReaderAdminConfig.empty();
  @override
  Future<ReaderLaunchState> loadLaunchState() async => const ReaderLaunchState(
    initialPageNumber: 187,
    settings: ReaderSettings.defaults(),
  );
  @override
  Future<void> saveSettings(ReaderSettings settings) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #availableZipPacks:
        return <QuranZipAssetPack>[];
      case #availableImageEditions:
      case #compareEditions:
        return MushafEdition.values.toList();
      case #chapters:
        return <QuranChapterSummary>[_chapter];
      case #surahs:
      case #standardSurahs:
        return <QuranSurahNavigationEntry>[];
      case #juzs:
      case #standardJuzs:
        return <QuranJuzNavigationEntry>[];
      case #fetchAvailableZipPacks:
        return Future<List<QuranZipAssetPack>>.value([]);
      case #hasOfflinePackForEdition:
        return Future<bool>.value(false);
      case #hasBundledPackForEdition:
      case #hasAssetsForEdition:
        final edition = invocation.positionalArguments.first as MushafEdition;
        return edition == MushafEdition.lines16 ||
            edition == MushafEdition.lines15 ||
            edition == MushafEdition.kanzulIman;
      case #loadPartialOfflinePacks:
        return Future<Map<MushafEdition, QuranPartialAssetPack>>.value({});
      case #loadDailyTargetPages:
        return Future<int>.value(8);
      case #loadDailyProgressState:
        return Future<ReaderDailyProgressState>.value(
          ReaderDailyProgressState(
            dateKey: invocation.namedArguments[#todayKey] as String,
            startPage: invocation.namedArguments[#fallbackStartPage] as int,
          ),
        );
      case #loadReadingPlan:
        return Future<ReaderReadingPlan>.value(
          const ReaderReadingPlan.defaults(),
        );
      case #loadExperienceSettings:
        return Future<ReaderExperienceSettings>.value(
          const ReaderExperienceSettings.defaults(),
        );
      case #loadReadingHistory:
        return Future<List<ReaderHistoryEntry>>.value([]);
      case #loadPageNotesByEdition:
        return Future<Map<String, Map<int, String>>>.value({});
      case #loadFavoritePagesByEdition:
        return Future<Map<String, List<int>>>.value({});
      case #loadBookmarks:
        return Future<List<ReaderBookmark>>.value([]);
      case #loadHifzRevisionEntries:
        return Future<List<ReaderHifzReviewEntry>>.value([]);
      case #loadPreferredReciterId:
      case #loadAudioChapterId:
        return Future<int?>.value(null);
      case #loadAudioPositionMillis:
        return Future<int>.value(0);
      case #loadReadingStreakCount:
        return Future<int>.value(12);
      case #loadAudioRepeatEnabled:
        return Future<bool>.value(false);
      case #loadReadingStreakLastDate:
        return Future<String?>.value(null);
      case #markersForCategory:
        return <QuranNavigationMarker>[];
      case #totalPagesForMode:
      case #totalPagesForEdition:
      case #imagePageCount:
        return 550;
      case #totalSpreadsForMode:
        return 275;
      case #spreadIndexFromPage:
        return ((invocation.positionalArguments.first as int) - 1) ~/ 2;
      case #clampPage:
      case #standardPageForNavigationPage:
      case #navigationPageForStandardPage:
        return (invocation.positionalArguments.first as int).clamp(1, 550);
      case #pageForNumber:
        final number = invocation.positionalArguments.first as int;
        return QuranPage(
          number: number,
          isLeftPage: invocation.namedArguments[#isLeftPage] as bool? ?? false,
          contentType: QuranPageContentType.image,
          assetPath: _pagePath(number),
        );
      case #spreadForIndex:
        final index = invocation.positionalArguments.first as int;
        return QuranSpread(
          index: index,
          rightPage: QuranPage(
            number: index * 2 + 1,
            isLeftPage: false,
            contentType: QuranPageContentType.image,
            assetPath: _pagePath(index * 2 + 1),
          ),
          leftPage: QuranPage(
            number: index * 2 + 2,
            isLeftPage: true,
            contentType: QuranPageContentType.image,
            assetPath: _pagePath(index * 2 + 2),
          ),
        );
      case #chapterSummaryForPage:
      case #chapterSummaryForId:
        return _chapter;
      case #pageInsightForPageNumber:
      case #surahEntryForPage:
      case #juzEntryForPage:
        return null;
      case #setMushafEdition:
      case #warmSupplementalContent:
        return Future<void>.value();
      case #dispose:
        return null;
    }
    if (invocation.memberName.toString().startsWith('Symbol("save')) {
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
