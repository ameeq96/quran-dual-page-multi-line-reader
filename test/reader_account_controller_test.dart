import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:my_flutter_app/core/storage/reader_preferences.dart';
import 'package:my_flutter_app/features/quran_reader/data/models/reader_launch_state.dart';
import 'package:my_flutter_app/features/quran_reader/data/repositories/quran_reader_repository.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/quran_audio_service.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/quran_reader_sync_service.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/reader_account_service.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Fixture fixture;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        SystemChannels.platform, (_) async => null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (_) async => null,
    );
    fixture = await _Fixture.create();
  });

  tearDown(() async {
    fixture.preferences.releaseIdentitySave();
    fixture.controller.dispose();
    await Future<void>.delayed(Duration.zero);
  });
  test('concurrent favorite removals keep both removals after restore-point writes', () async {
    await fixture.controller.toggleFavoritePage(1);
    await fixture.controller.toggleFavoritePage(2);
    expect(fixture.controller.favoritePages, containsAll([1, 2]));
    await Future.wait([fixture.controller.toggleFavoritePage(1), fixture.controller.toggleFavoritePage(2)]);
    expect(fixture.controller.favoritePages, isEmpty);
  });

  test('preparing a checked account keeps local data until adoption', () async {
    final prepared = await fixture.prepare();
    expect(fixture.controller.noteForPage(1), 'original local note');
    expect(fixture.controller.syncClientId, _Fixture.local.deviceId);
    expect(fixture.controller.readerAccountBusy, isTrue);
    await fixture.controller.adoptReaderAccount(prepared);
    expect(fixture.controller.noteForPage(1), 'remote account note');
    expect(fixture.controller.syncClientId, _Fixture.remote.deviceId);
    expect(
        (await fixture.preferences.loadOrCreateSyncIdentity(_Fixture.base))
            .token,
        _Fixture.remote.token);
    expect(fixture.controller.readerAccountBusy, isFalse);
    expect(fixture.controller.hasUnsyncedReaderChanges, isFalse);
  });

  test('editing after preparation rejects adoption without losing the new note',
      () async {
    final prepared = await fixture.prepare();
    await fixture.controller.saveNoteForCurrentPage('new local note');
    await expectLater(fixture.controller.adoptReaderAccount(prepared),
        throwsA(isA<ReaderAccountFailure>()));
    fixture.controller.cancelReaderAccountOperation();
    expect(fixture.controller.noteForPage(1), 'new local note');
    expect(fixture.controller.syncClientId, _Fixture.local.deviceId);
    expect(fixture.controller.hasUnsyncedReaderChanges, isTrue);
  });

  test(
      'a local edit during credential persistence is not rolled back or marked synced',
      () async {
    final prepared = await fixture.prepare();
    fixture.preferences.holdNextIdentitySave();
    final adopting = fixture.controller.adoptReaderAccount(prepared);
    final rejected =
        expectLater(adopting, throwsA(isA<ReaderAccountFailure>()));
    await fixture.preferences.identitySaveEntered!.future
        .timeout(const Duration(seconds: 2));
    await fixture.controller.saveNoteForCurrentPage('edit while connecting');
    fixture.preferences.releaseIdentitySave();
    await rejected;
    expect(fixture.controller.noteForPage(1), 'edit while connecting');
    expect(fixture.controller.hasUnsyncedReaderChanges, isTrue);
    expect(fixture.controller.readerAccountBusy, isFalse);
  });

  test(
      'cancelling during credential persistence cannot adopt an account into another backend',
      () async {
    final prepared = await fixture.prepare();
    fixture.preferences.holdNextIdentitySave();
    final adopting = fixture.controller.adoptReaderAccount(prepared);
    final rejected =
        expectLater(adopting, throwsA(isA<ReaderAccountFailure>()));
    await fixture.preferences.identitySaveEntered!.future
        .timeout(const Duration(seconds: 2));
    fixture.repository.baseUrl = 'https://other.example.com';
    fixture.controller.cancelReaderAccountOperation();
    fixture.preferences.releaseIdentitySave();
    await rejected;
    expect(fixture.controller.syncClientId, isNot(_Fixture.remote.deviceId));
    final other = await fixture.preferences
        .loadOrCreateSyncIdentity(fixture.repository.baseUrl);
    expect(other.deviceId, isNot(_Fixture.remote.deviceId));
    expect(fixture.controller.readerAccountBusy, isFalse);
  });

  test(
      'a snapshot persistence failure restores the original local data and identity',
      () async {
    final prepared = await fixture.prepare();
    fixture.repository.failSettingsWrites = 1;
    await expectLater(
        fixture.controller.adoptReaderAccount(prepared), throwsA(anything));
    expect(fixture.controller.noteForPage(1), 'original local note');
    expect(fixture.controller.syncClientId, _Fixture.local.deviceId);
    expect(
        (await fixture.preferences.loadOrCreateSyncIdentity(_Fixture.base))
            .token,
        _Fixture.local.token);
    expect(fixture.controller.readerAccountBusy, isFalse);
    expect(fixture.controller.hasUnsyncedReaderChanges, isTrue);
  });

  test(
      'failure while saving the rollback still releases the account transition',
      () async {
    final prepared = await fixture.prepare();
    fixture.repository.failSettingsWrites = 2;
    await expectLater(
        fixture.controller.adoptReaderAccount(prepared), throwsA(anything));
    expect(fixture.controller.noteForPage(1), 'original local note');
    expect(fixture.controller.syncClientId, _Fixture.local.deviceId);
    expect(fixture.controller.readerAccountBusy, isFalse);
    expect(fixture.controller.hasUnsyncedReaderChanges, isTrue);
  });

  test(
      'rotated registration credentials can be saved again after a storage failure',
      () async {
    fixture.preferences.failIdentityWrites = 1;
    final keys = <String>[];
    final prepared = await fixture.controller.prepareReaderAccount(
      email: 'reader@example.com',
      password: 'safe-test-password-123',
      register: true,
      onRecoveryKey: (key) async => keys.add(key),
    );
    expect(keys, [_Accounts.recoveryKey]);
    expect(fixture.controller.noteForPage(1), 'original local note');
    if (!prepared.alreadyConnected)
      await fixture.controller.adoptReaderAccount(prepared);
    expect(
        (await fixture.preferences.loadOrCreateSyncIdentity(_Fixture.base))
            .token,
        _Accounts.rotated.token);
    expect(fixture.controller.noteForPage(1), 'original local note');
    expect(fixture.controller.readerAccountBusy, isFalse);
  });

  test(
      'a cancelled request cannot discard registration credentials already rotated by the server',
      () async {
    fixture.accounts.holdRegistration();
    final keys = <String>[];
    final registering = fixture.controller.prepareReaderAccount(
      email: 'reader@example.com',
      password: 'safe-test-password-123',
      register: true,
      onRecoveryKey: (key) async => keys.add(key),
    );
    await fixture.accounts.registrationEntered!.future
        .timeout(const Duration(seconds: 2));
    fixture.controller.cancelReaderAccountOperation();
    fixture.accounts.registrationResult!.complete(ReaderAccountIdentity(
      identity: _Accounts.rotated,
      email: 'reader@example.com',
      recoveryKey: _Accounts.recoveryKey,
    ));
    try {
      await registering;
    } on ReaderAccountFailure {
      // The UI transition may be cancelled; the rotated credential must survive.
    }
    expect(
        (await fixture.preferences.loadOrCreateSyncIdentity(_Fixture.base))
            .token,
        _Accounts.rotated.token);
    expect((await fixture.controller.readerIdentityForFeature()).token,
        _Accounts.rotated.token);
    expect(keys, [_Accounts.recoveryKey]);
    expect(fixture.controller.noteForPage(1), 'original local note');
    expect(fixture.controller.readerAccountBusy, isFalse);
  });
}

class _Fixture {
  _Fixture(this.controller, this.repository, this.preferences, this.accounts);
  static const base = 'https://reader.example.com';
  static final local =
      ReaderSyncIdentity(deviceId: 'reader_${'a' * 32}', token: 'b' * 43);
  static final remote =
      ReaderSyncIdentity(deviceId: 'reader_${'c' * 32}', token: 'd' * 43);
  final QuranReaderController controller;
  final _Repository repository;
  final _Preferences preferences;
  final _Accounts accounts;

  static Future<_Fixture> create() async {
    final preferences = _Preferences();
    await preferences.saveSyncIdentity(base, local);
    final repository = _Repository();
    final accounts = _Accounts();
    final controller = QuranReaderController(
        repository: repository,
        audioService: _Audio(),
        readerSyncService: _Sync(),
        preferences: preferences,
        accountService: accounts);
    await controller.initialize();
    await Future<void>.delayed(Duration.zero);
    await controller.saveNoteForCurrentPage('original local note');
    final payload =
        jsonDecode(controller.buildStateBackupJson()) as Map<String, dynamic>;
    accounts.backup = {
      ...payload,
      'deviceId': remote.deviceId,
      'pageNotes': {'1': 'remote account note'},
      'editionPageNotes': {
        '16_lines': {'1': 'remote account note'}
      },
    };
    return _Fixture(controller, repository, preferences, accounts);
  }

  Future<ReaderPreparedAccount> prepare() => controller.prepareReaderAccount(
        email: 'reader@example.com',
        password: 'safe-test-password-123',
      );
}

class _Preferences extends ReaderPreferences {
  Completer<void>? identitySaveEntered;
  Completer<void>? _identityRelease;
  int failIdentityWrites = 0;

  void holdNextIdentitySave() {
    identitySaveEntered = Completer<void>();
    _identityRelease = Completer<void>();
  }

  void releaseIdentitySave() {
    final release = _identityRelease;
    if (release != null && !release.isCompleted) release.complete();
  }

  @override
  Future<void> saveSyncIdentity(
      String baseUrl, ReaderSyncIdentity identity) async {
    final release = _identityRelease;
    if (release != null && !identitySaveEntered!.isCompleted) {
      identitySaveEntered!.complete();
      await release.future;
    }
    if (failIdentityWrites > 0) {
      failIdentityWrites--;
      throw StateError('Test identity storage failure');
    }
    await super.saveSyncIdentity(baseUrl, identity);
  }
}

class _Accounts implements ReaderAccountService {
  static final rotated =
      ReaderSyncIdentity(deviceId: _Fixture.local.deviceId, token: 'e' * 43);
  static final recoveryKey = 'r' * 43;
  Completer<void>? registrationEntered;
  Completer<ReaderAccountIdentity>? registrationResult;
  late Map<String, dynamic> backup;

  void holdRegistration() {
    registrationEntered = Completer<void>();
    registrationResult = Completer<ReaderAccountIdentity>();
  }

  @override
  Future<ReaderAccountIdentity> register(
      String baseUrl, ReaderSyncIdentity identity,
      {required String email, required String password}) async {
    if (registrationResult != null) {
      registrationEntered!.complete();
      return registrationResult!.future;
    }
    return ReaderAccountIdentity(
        identity: rotated, email: email, recoveryKey: recoveryKey);
  }

  @override
  Future<ReaderAccountIdentity> login(String baseUrl,
          {required String email, required String password}) async =>
      ReaderAccountIdentity(identity: _Fixture.remote, email: email);
  @override
  Future<Map<String, dynamic>> fetchBackup(
          String baseUrl, ReaderSyncIdentity identity) async =>
      backup;
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
          required ReaderSyncSnapshot snapshot, int? baseRevision}) async =>
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
  String baseUrl = _Fixture.base;
  int failSettingsWrites = 0;
  @override
  String get adminConfigBaseUrl => baseUrl;
  @override
  ReaderAdminConfig get adminConfig => const ReaderAdminConfig.empty();
  @override
  Future<ReaderLaunchState> loadLaunchState() async => const ReaderLaunchState(
        initialPageNumber: 1,
        settings: ReaderSettings.defaults(),
      );
  @override
  Future<void> saveSettings(ReaderSettings settings) async {
    if (failSettingsWrites > 0) {
      failSettingsWrites--;
      throw StateError('Test storage failure');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #availableZipPacks:
        return <QuranZipAssetPack>[];
      case #availableImageEditions:
        return <MushafEdition>[MushafEdition.lines16];
      case #chapters:
        return <QuranChapterSummary>[];
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
        return true;
      case #loadPartialOfflinePacks:
        return Future<Map<MushafEdition, QuranPartialAssetPack>>.value({});
      case #loadDailyTargetPages:
        return Future<int>.value(8);
      case #loadDailyProgressState:
        return Future<ReaderDailyProgressState>.value(ReaderDailyProgressState(
          dateKey: invocation.namedArguments[#todayKey] as String,
          startPage: invocation.namedArguments[#fallbackStartPage] as int,
        ));
      case #loadReadingPlan:
        return Future<ReaderReadingPlan>.value(
            const ReaderReadingPlan.defaults());
      case #loadExperienceSettings:
        return Future<ReaderExperienceSettings>.value(
            const ReaderExperienceSettings.defaults());
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
      case #loadReadingStreakCount:
        return Future<int>.value(0);
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
        return QuranPage(
            number: invocation.positionalArguments.first as int,
            isLeftPage: invocation.namedArguments[#isLeftPage] as bool,
            contentType: QuranPageContentType.placeholder);
      case #spreadForIndex:
        return const QuranSpread(
            index: 0,
            rightPage: QuranPage(
                number: 1,
                isLeftPage: false,
                contentType: QuranPageContentType.placeholder),
            leftPage: QuranPage(
                number: 2,
                isLeftPage: true,
                contentType: QuranPageContentType.placeholder));
      case #pageInsightForPageNumber:
      case #chapterSummaryForPage:
      case #chapterSummaryForId:
      case #surahEntryForPage:
      case #juzEntryForPage:
        return null;
      case #setMushafEdition:
      case #warmSupplementalContent:
        return Future<void>.value();
      case #dispose:
        return null;
    }
    if (invocation.memberName.toString().startsWith('Symbol("save'))
      return Future<void>.value();
    return super.noSuchMethod(invocation);
  }
}
