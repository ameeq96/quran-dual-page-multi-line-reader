import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_flutter_app/app/app_theme.dart';
import 'package:my_flutter_app/app/reader_localization.dart';
import 'package:my_flutter_app/core/prayer/prayer_models.dart';
import 'package:my_flutter_app/core/prayer/prayer_reminder_service.dart';
import 'package:my_flutter_app/core/worship/worship_content.dart';
import 'package:my_flutter_app/core/worship/worship_store.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/screens/qibla_screen.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/screens/worship_learning_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Azkar counts and references preserve distinct morning/evening and narrated33/33/34 sessions',
    () {
      expect(worshipAzkar.length, 12);
      expect(worshipAzkar.map((item) => item.id).toSet().length, 12);
      expect(
        worshipAzkar
            .where((item) => item.surahId == null)
            .map((item) => item.arabic)
            .toSet(),
        {'سُبْحَانَ اللَّهِ', 'الْحَمْدُ لِلَّهِ', 'اللَّهُ أَكْبَرُ'},
        reason:
            'Device speech uses non-Quran dhikr; Quran cards retain Surah IDs.',
      );
      for (final group in ['morning', 'evening']) {
        final items = worshipAzkar
            .where((item) => item.group == group)
            .toList();
        expect(items.map((item) => item.surahId), [112, 113, 114]);
        expect(
          items.every(
            (item) =>
                item.target == 3 &&
                item.reference.url == 'https://sunnah.com/abudawud:5082',
          ),
          isTrue,
        );
      }
      for (final group in ['after_prayer', 'bedtime']) {
        final items = worshipAzkar
            .where((item) => item.group == group)
            .toList();
        expect(items.map((item) => item.target), [33, 33, 34]);
        expect(items.every((item) => item.surahId == null), isTrue);
      }
      expect(
        worshipAzkar
            .where((item) => item.group == 'bedtime')
            .every(
              (item) => item.reference.url == 'https://sunnah.com/muslim:2727a',
            ),
        isTrue,
      );
    },
  );

  test(
    'lessons cover28differentletters once and guide notes preserve all4school choices',
    () {
      expect(worshipLetters.length, 28);
      expect(worshipLetters.toSet().length, 28);
      expect(worshipLetterNames.keys.toSet(), worshipLetters.toSet());
      final alphabet = worshipKidsLessons
          .where((lesson) => lesson.id.startsWith('letters_'))
          .expand((lesson) => lesson.letters);
      expect(alphabet, worshipLetters);
      expect(
        worshipKidsLessons.map((lesson) => lesson.id).toSet().length,
        worshipKidsLessons.length,
      );
      expect(
        worshipKidsLessons
            .where((lesson) => lesson.surahId != null)
            .map((lesson) => lesson.surahId),
        [1, 112, 113, 114],
      );
      expect(worshipFiqhHeadNotes.keys.toSet(), worshipSchools.toSet());
      for (final text in [
        ...worshipKidsLessons.expand(
          (lesson) => [lesson.title, lesson.description],
        ),
        ...worshipWuduSteps.expand((step) => [step.title, step.description]),
        ...worshipPrayerSteps.expand((step) => [step.title, step.description]),
        ...worshipFiqhHeadNotes.values,
      ]) {
        expect(
          [text.en, text.ur, text.ar].every((value) => value.trim().isNotEmpty),
          isTrue,
        );
      }
    },
  );

  testWidgets(
    '390px EN UR AR learning, explicit fiqh and persisted counter/lesson actions',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await tester.runAsync(SharedPreferences.getInstance);
      await tester.runAsync(() => ReaderLocalization.instance.load());
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var checkedViews = 0;

      Future<void> waitFor(bool Function() done) async {
        for (var i = 0; i < 100 && !done(); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(done(), isTrue);
      }

      for (final language in [
        ReaderLanguage.english,
        ReaderLanguage.urdu,
        ReaderLanguage.arabic,
      ]) {
        await tester.runAsync(
          () => ReaderLocalization.instance.setLanguage(language),
        );
        await tester.runAsync(() => prefs!.remove('reader.worship.v1'));
        final store = WorshipStore(profileId: 'default', preferences: prefs);
        await tester.runAsync(store.load);
        expect(store.fiqh, isNull);
        for (var tab = 0; tab < 3; tab++) {
          await tester.pumpWidget(
            ReaderLocalizationScope(
              localization: ReaderLocalization.instance,
              child: MaterialApp(
                theme: AppTheme.light(),
                navigatorObservers: [worshipLearningObserverFor('default')],
                locale: ReaderLocalization.instance.locale,
                supportedLocales: const [
                  Locale('en'),
                  Locale('ur'),
                  Locale('ar'),
                ],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(1.6)),
                  child: child!,
                ),
                home: WorshipLearningScreen(store: store, initialTab: tab),
              ),
            ),
          );
          await waitFor(
            () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${language.name} tab$tab must fit390px at1.6scale',
          );
          final verticalScroll = find
              .descendant(
                of: find.byKey(
                  PageStorageKey(
                    ['worship-azkar', 'worship-kids', 'worship-guide'][tab],
                  ),
                ),
                matching: find.byType(Scrollable),
              )
              .first;
          if (tab == 0) {
            final counter = find.byKey(
              const ValueKey('dhikr-count-morning_ikhlas'),
            );
            await tester.scrollUntilVisible(
              counter.hitTestable(),
              180,
              scrollable: verticalScroll,
            );
            await tester.tap(counter.hitTestable());
            await waitFor(() => store.tasbeehCounts['morning_ikhlas'] == 1);
            expect(store.tasbeehCounts['evening_ikhlas'], isNull);
          } else if (tab == 1) {
            final lesson = find.byKey(const ValueKey('lesson-letters_1'));
            await tester.scrollUntilVisible(
              lesson.hitTestable(),
              180,
              scrollable: verticalScroll,
            );
            await tester.tap(lesson.hitTestable());
            await waitFor(() => store.completedLessons.contains('letters_1'));
            final letter = find.widgetWithText(InkWell, 'ا').last;
            await tester.scrollUntilVisible(
              letter.hitTestable(),
              -180,
              scrollable: verticalScroll,
            );
            await tester.tap(letter.hitTestable());
            await tester.pumpAndSettle();
            expect(find.byType(AlertDialog), findsOneWidget);
            expect(tester.takeException(), isNull);
            final close = language == ReaderLanguage.urdu
                ? 'بند کریں'
                : language == ReaderLanguage.arabic
                ? 'إغلاق'
                : 'Close';
            await tester.tap(find.text(close));
            await tester.pumpAndSettle();
          } else {
            expect(
              find.byType(DropdownButtonFormField<String>),
              findsOneWidget,
            );
            expect(
              find.text('1 · Hands'),
              findsNothing,
              reason: 'Guide stays gated until user selects a school',
            );
            await tester.tap(find.byType(DropdownButtonFormField<String>));
            await tester.pumpAndSettle();
            final label = language == ReaderLanguage.urdu
                ? 'حنفی'
                : language == ReaderLanguage.arabic
                ? 'حنفي'
                : 'Hanafi';
            await tester.tap(find.text(label).last);
            await waitFor(() => store.fiqh == 'hanafi');
            final headNote = worshipFiqhHeadNotes['hanafi']!.inLanguage(
              ReaderLocalization.instance.locale.languageCode,
            );
            await tester.scrollUntilVisible(
              find.text(headNote).hitTestable(),
              250,
              scrollable: verticalScroll,
            );
            expect(find.text(headNote).hitTestable(), findsOneWidget);
            final namaz = language == ReaderLanguage.urdu
                ? 'نماز'
                : language == ReaderLanguage.arabic
                ? 'الصلاة'
                : 'Namaz';
            final namazChip = find.widgetWithText(ChoiceChip, namaz);
            await tester.scrollUntilVisible(
              namazChip.hitTestable(),
              -250,
              scrollable: verticalScroll,
            );
            await tester.tap(namazChip.hitTestable());
            await tester.pumpAndSettle();
            for (final step in worshipPrayerSteps.skip(1).take(4)) {
              await tester.scrollUntilVisible(
                find
                    .text(
                      step.title.inLanguage(
                        ReaderLocalization.instance.locale.languageCode,
                      ),
                    )
                    .hitTestable(),
                220,
                scrollable: verticalScroll,
              );
              expect(
                tester.takeException(),
                isNull,
                reason: 'Illustrated posture must render without overflow',
              );
            }
          }
          expect(tester.takeException(), isNull);
          checkedViews++;
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
        final reloaded = WorshipStore(profileId: 'default', preferences: prefs);
        await tester.runAsync(reloaded.load);
        expect(reloaded.fiqh, 'hanafi');
        expect(reloaded.completedLessons, contains('letters_1'));
        expect(reloaded.tasbeehCounts['morning_ikhlas'], 1);
      }
      expect(checkedViews, 9);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'Qibla manual coordinates survive dialog dismissal and repeated reopening',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() => ReaderLocalization.instance.load());
      await tester.runAsync(
        () => ReaderLocalization.instance.setLanguage(ReaderLanguage.english),
      );
      final prayers = PrayerReminderService.instance;
      final previousLoaded = prayers.loaded;
      final previousSettings = prayers.settings;
      prayers.loaded = true;
      prayers.settings = const PrayerSettings();
      addTearDown(() {
        prayers.loaded = previousLoaded;
        prayers.settings = previousSettings;
      });
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ReaderLocalizationScope(
          localization: ReaderLocalization.instance,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const QiblaScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> openCoordinates() async {
        await tester.scrollUntilVisible(
          find.text('Enter coordinates').hitTestable(),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Enter coordinates').hitTestable());
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
      }

      await openCoordinates();
      await tester.enterText(find.byType(TextFormField).at(0), '24.8607');
      await tester.enterText(find.byType(TextFormField).at(1), '67.0011');
      await tester.tap(find.text('Use location'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('267.7°'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await openCoordinates();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(0))
            .controller!
            .text,
        '24.8607',
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        '67.0011',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('267.7°'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
