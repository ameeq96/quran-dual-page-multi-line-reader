import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_flutter_app/app/reader_localization.dart';
import 'package:my_flutter_app/core/services/reader_recording_store.dart';
import 'package:my_flutter_app/core/services/reader_ustad_audio.dart';
import 'package:my_flutter_app/core/services/reader_voice_capture.dart';
import 'package:my_flutter_app/core/storage/reader_preferences.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/reader_ustad_service.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/screens/quran_ustad_screen.dart';

import 'reader_ustad_service_test.dart' as fixtures;

class _Capture extends ReaderVoiceCapture {
  _Capture() : super.base();
  ReaderVoiceCapturePhase current = ReaderVoiceCapturePhase.idle;
  int revision = 0;
  Completer<Uint8List>? readGate;
  @override
  bool get supported => true;
  @override
  bool get speechSupported => false;
  @override
  ReaderVoiceCapturePhase get phase => current;
  @override
  bool get isTranscribing => false;
  @override
  String get transcript => '';
  @override
  Duration get elapsed => const Duration(seconds: 1);
  @override
  String? get errorMessage => null;
  @override
  bool get hasRecording => current == ReaderVoiceCapturePhase.ready;
  @override
  bool get isPlaying => false;
  @override
  int get recordingRevision => revision;
  @override
  String get recordingMimeType => 'audio/webm';
  @override
  Future<Uint8List> readRecordingBytes() async =>
      readGate == null ? Uint8List.fromList([1, 2, 3]) : await readGate!.future;
  @override
  Future<void> start(
      {String language = 'ar-SA', bool transcribe = false}) async {
    current = ReaderVoiceCapturePhase.recording;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    current = ReaderVoiceCapturePhase.ready;
    revision++;
    notifyListeners();
  }

  @override
  void cancel() {
    current = ReaderVoiceCapturePhase.idle;
    notifyListeners();
  }

  @override
  Future<void> togglePlayback() async {}
  @override
  void download() {}
}

class _Store extends ReaderRecordingStore {
  _Store()
      : super.base(profileId: 'default', limits: const ReaderRecordingLimits());
  final items = <ReaderLocalRecording>[];
  String? playing;
  @override
  bool get supported => true;
  @override
  bool get busy => false;
  @override
  List<ReaderLocalRecording> get recordings => List.unmodifiable(items);
  @override
  String? get playingId => playing;
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
      int? chapterId}) async {
    final item = ReaderLocalRecording(
        id: 'A' * 22,
        profileId: profileId,
        createdAt: DateTime.now(),
        durationMillis: duration.inMilliseconds,
        bytes: bytes.length,
        mimeType: mimeType,
        label: label,
        reference: reference);
    items.add(item);
    notifyListeners();
    return item;
  }

  @override
  Future<Uint8List> readBytes(String id) async => Uint8List.fromList([1, 2, 3]);
  @override
  Future<void> play(String id) async {
    playing = id;
    notifyListeners();
  }

  @override
  Future<void> delete(String id) async {
    items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  @override
  Future<void> compare(String first, String second) async {}
  @override
  void stopPlayback() {
    playing = null;
    notifyListeners();
  }
}

class _Audio extends ReaderUstadAudio {
  _Audio() : super.base();
  int playCalls = 0;
  @override
  bool get playing => false;
  @override
  String? get errorMessage => null;
  @override
  Future<void> play(Uint8List bytes, String mimeType) async {
    playCalls++;
  }

  @override
  Future<void> stop() async {}
}

Future<void> _open(WidgetTester tester,
    {required http.Client client,
    _Capture? capture,
    _Store? store,
    _Audio? audio,
    ReaderLanguage language = ReaderLanguage.english,
    Future<ReaderSyncIdentity> Function()? actor}) async {
  SharedPreferences.setMockInitialValues({});
  final localization =
      ReaderLocalization(preferences: await SharedPreferences.getInstance());
  await localization.setLanguage(language);
  final service = ReaderUstadService(
      baseUrl: 'https://reader.example',
      identity: fixtures.identity,
      client: client);
  await tester.pumpWidget(ReaderLocalizationScope(
      localization: localization,
      child: MaterialApp(
        locale: Locale(language == ReaderLanguage.arabic
            ? 'ar'
            : language == ReaderLanguage.urdu
                ? 'ur'
                : 'en'),
        supportedLocales: const [Locale('en'), Locale('ar'), Locale('ur')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: QuranUstadScreen(
            identityProvider: actor ?? () async => fixtures.identity,
            baseUrl: 'https://reader.example',
            profileId: 'default',
            service: service,
            capture: capture ?? _Capture(),
            recordingStore: store ?? _Store(),
            audio: audio ?? _Audio()),
      )));
  await tester.pumpAndSettle();
}

http.Response lists(http.Request request,
    {String role = 'student',
    bool revoked = false,
    List<Object?> recordings = const []}) {
  if (request.url.path.endsWith('/links')) {
    return fixtures.jsonResponse({
      ...fixtures.overview(),
      'links': [
        {...fixtures.link(role: role), if (revoked) 'status': 'revoked'}
      ]
    });
  }
  if (request.url.path.endsWith('/assignments')) {
    return fixtures.jsonResponse({
      'success': true,
      'assignments': [fixtures.assignment(role: role)],
      'meta': fixtures.meta()
    });
  }
  return fixtures.jsonResponse(
      {'success': true, 'submissions': recordings, 'meta': fixtures.meta()});
}

void main() {
  testWidgets(
      'unavailable backend shows an honest error and never uploads or replaces reader data',
      (tester) async {
    final methods = <String>[];
    await _open(tester, client: MockClient((request) async {
      methods.add(request.method);
      return fixtures.jsonResponse({}, status: 503);
    }));
    expect(
        find.textContaining('Private lessons are unavailable'), findsOneWidget,
        reason: find
            .byType(Text)
            .evaluate()
            .map((element) => (element.widget as Text).data ?? '')
            .join(' | '));
    expect(methods, ['GET']);
    final create = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create invite'));
    expect(create.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a new student clip stays local until preview and explicit Send; failed upload preserves it',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _Store();
    var uploads = 0;
    await _open(tester, store: store, client: MockClient((request) async {
      if (request.method == 'POST') {
        uploads++;
        return fixtures.jsonResponse({}, status: 503);
      }
      return lists(request);
    }));
    await tester.ensureVisible(find.text('Record lesson'));
    await tester.tap(find.text('Record lesson'));
    await tester.pumpAndSettle();
    expect(uploads, 0);
    await tester.ensureVisible(find.text('Stop recording'));
    await tester.tap(find.text('Stop recording'));
    await tester.pumpAndSettle();
    expect(store.items, hasLength(1));
    expect(uploads, 0);
    await tester.ensureVisible(find.text('Send clip'));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Send clip'))
            .onPressed,
        isNull);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Preview'));
    await tester.pumpAndSettle();
    expect(uploads, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Send clip'));
    await tester.pumpAndSettle();
    expect(uploads, 1);
    expect(store.items, hasLength(1));
    expect(find.text('Sent'), findsNothing);
    expect(find.textContaining('Local drafts are preserved'), findsOneWidget);
  });

  testWidgets(
      'a gated draft save prevents a second capture from relabeling the first assignment',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final capture = _Capture()..readGate = Completer<Uint8List>();
    final store = _Store();
    await _open(tester,
        capture: capture,
        store: store,
        client: MockClient((request) async => lists(request)));
    await tester.ensureVisible(find.text('Record lesson'));
    await tester.tap(find.text('Record lesson'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Stop recording'));
    await tester.tap(find.text('Stop recording'));
    await tester.pump();
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Record lesson'))
            .onPressed,
        isNull);
    capture.readGate!.complete(Uint8List.fromList([1, 2, 3]));
    await tester.pumpAndSettle();
    expect(store.items, hasLength(1));
    expect(store.items.single.reference, endsWith(':${fixtures.assignmentId}'));
    expect(store.items.single.durationMillis, 1000);
  });

  testWidgets(
      'teacher controls do not expose student recording or student deletion actions',
      (tester) async {
    await _open(tester,
        client: MockClient((request) async => lists(request, role: 'teacher')));
    expect(find.text('New assignment'), findsOneWidget);
    expect(find.text('Record lesson'), findsNothing);
    expect(
        find.text('Delete lesson recordings and revoke access'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'invite acceptance requires visible teacher preview and separate consent',
      (tester) async {
    var accepted = 0;
    await _open(tester, client: MockClient((request) async {
      if (request.url.path.endsWith('/preview')) {
        return fixtures.jsonResponse({
          'success': true,
          'invite': {
            'teacherName': 'Trusted Teacher',
            'expiresAt': fixtures.date
          }
        });
      }
      if (request.url.path.endsWith('/accept')) {
        accepted++;
        return fixtures
            .jsonResponse({'success': true, 'link': fixtures.link()});
      }
      return lists(request);
    }));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Accept invite'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Student');
    await tester.enterText(fields.at(1), 'A' * 43);
    await tester.tap(find.widgetWithText(FilledButton, 'Preview invite'));
    await tester.pumpAndSettle();
    expect(find.text('Teacher: Trusted Teacher'), findsOneWidget);
    expect(accepted, 0);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Accept invite'))
            .onPressed,
        isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Accept invite'));
    await tester.pumpAndSettle();
    expect(accepted, 1);
  });

  testWidgets(
      'identity changes lock the screen instead of sending a draft to a new actor',
      (tester) async {
    var actor = fixtures.identity;
    final requests = <http.Request>[];
    await _open(tester,
        actor: () async => actor,
        client: MockClient((request) async {
          requests.add(request);
          return lists(request);
        }));
    actor = ReaderSyncIdentity(
        deviceId: fixtures.identity.deviceId, token: 'Z' * 43);
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Account or server changed'), findsOneWidget);
    expect(requests.where((request) => request.method != 'GET'), isEmpty);
    expect(
        requests.every((request) =>
            request.headers['Authorization'] ==
            'Bearer ${fixtures.identity.token}'),
        isTrue);
  });

  for (final background in [false, true]) {
    testWidgets(
        '${background ? 'background' : 'Cancel'} invalidates a private clip waiting after download',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final audio = _Audio();
      final waiting = Completer<ReaderSyncIdentity>();
      final guardStarted = Completer<void>();
      var downloaded = false;
      final recording = {
        ...fixtures.submission(),
        'role': 'student',
        'linkId': fixtures.linkId,
        'assignmentTitle': 'Private recording',
        'teacherName': 'Teacher',
        'studentName': 'Student'
      };
      await _open(tester, audio: audio, actor: () {
        if (downloaded) {
          if (!guardStarted.isCompleted) guardStarted.complete();
          return waiting.future;
        }
        return Future.value(fixtures.identity);
      }, client: MockClient((request) async {
        if (request.url.path.endsWith('/audio')) {
          downloaded = true;
          return http.Response.bytes([1, 2, 3], 200,
              headers: {
                'content-type': 'audio/webm',
                'cache-control': 'private, no-store'
              });
        }
        return lists(request, recordings: [recording]);
      }));
      await tester.ensureVisible(find.text('Shared recordings'));
      await tester.tap(find.text('Shared recordings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Play private clip'));
      await tester.tap(find.text('Play private clip'));
      for (var i = 0; i < 20 && !guardStarted.isCompleted; i++) {
        await tester.pump();
      }
      expect(guardStarted.isCompleted, isTrue);
      if (background) {
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      } else {
        await tester.ensureVisible(find.text('Cancel request'));
        await tester.tap(find.text('Cancel request'));
      }
      waiting.complete(fixtures.identity);
      await tester.pumpAndSettle();
      expect(audio.playCalls, 0);
      if (background) {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }
    });
  }

  testWidgets('editing a Repeat feedback note preserves Repeat',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map? updated;
    final recording = {
      ...fixtures.submission(),
      'role': 'teacher',
      'linkId': fixtures.linkId,
      'assignmentTitle': 'Private recording',
      'teacherName': 'Teacher',
      'studentName': 'Student',
      'feedbackStatus': 'repeat',
      'feedbackNote': 'Existing note'
    };
    await _open(tester, client: MockClient((request) async {
      if (request.method == 'PATCH') {
        updated = jsonDecode(request.body) as Map;
        return fixtures.jsonResponse({
          'success': true,
          'submission': {
            ...fixtures.submission(),
            'feedbackStatus': updated!['status'],
            'feedbackNote': updated!['note'],
            'reviewedAt': fixtures.date
          }
        });
      }
      return lists(request, role: 'teacher', recordings: [recording]);
    }));
    await tester.ensureVisible(find.text('Shared recordings'));
    await tester.tap(find.text('Shared recordings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Teacher feedback'));
    await tester.tap(find.text('Teacher feedback'));
    await tester.pumpAndSettle();
    final dropdown = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(DropdownButtonFormField<String>));
    expect(
        tester.widget<DropdownButtonFormField<String>>(dropdown).initialValue,
        'repeat');
    await tester.enterText(find.byType(TextField), 'Updated note');
    await tester.tap(find.text('Save feedback'));
    await tester.pumpAndSettle();
    expect(updated?['status'], 'repeat');
    expect(updated?['note'], 'Updated note');
  });

  for (final language in [ReaderLanguage.urdu, ReaderLanguage.arabic]) {
    testWidgets('narrow $language layout remains readable and direction-aware',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _open(tester,
          language: language,
          client: MockClient((request) async => lists(request)));
      expect(tester.takeException(), isNull);
      expect(
          find.text(language == ReaderLanguage.arabic
              ? 'المعلم والطالب الخاص'
              : 'نجی استاد اور طالب علم'),
          findsOneWidget);
      final context = tester.element(find.byType(QuranUstadScreen));
      expect(
          ReaderLocalizationScope.of(context).textDirection, TextDirection.rtl);
    });
  }
}
