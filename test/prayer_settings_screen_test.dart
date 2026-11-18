import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:my_flutter_app/app/app_theme.dart';
import 'package:my_flutter_app/app/prayer_translations.dart';
import 'package:my_flutter_app/app/reader_localization.dart';
import 'package:my_flutter_app/core/prayer/prayer_calculator.dart';
import 'package:my_flutter_app/core/prayer/prayer_models.dart';
import 'package:my_flutter_app/core/prayer/prayer_reminder_service.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/screens/prayer_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = PrayerReminderService.instance;
  const baseUrl = 'https://quran.opplexify.com';

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    PrayerCalculator.initialize();
    await ReaderLocalization.instance.load();
  });

  void resetFixture() {
    // Use the real service without starting its periodic delivery loop or
    // requesting device permissions. All reminders remain off in these checks.
    service.loaded = true;
    service.busy = false;
    service.baseUrl = baseUrl;
    service.error = null;
    service.currentEvent = null;
    service.nextEvent = null;
    service.settings = PrayerSettings(location: prayerCities.first);
    service.todayTimes = PrayerCalculator.timesForDate(
      service.settings,
      PrayerCalculator.dateInZone(DateTime.now(), service.settings),
    );
  }

  Future<void> finishServiceOperation(
    WidgetTester tester,
    Future<void> operation,
  ) async {
    var completed = false;
    Object? failure;
    operation.then<void>(
      (_) => completed = true,
      onError: (Object error, StackTrace _) {
        failure = error;
        completed = true;
      },
    );
    // Cached preferences use real async work; UI/service callbacks use this
    // test's fake async zone. Drain both before the singleton crosses fixtures.
    for (var attempt = 0; attempt < 100 && !completed; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(failure, isNull);
    expect(
      completed,
      isTrue,
      reason: 'The serialized prayer operation must finish',
    );
  }

  Future<void> open(
    WidgetTester tester,
    ReaderLanguage language, {
    double scale = 1,
  }) async {
    await tester.runAsync(
      () => ReaderLocalization.instance.setLanguage(language),
    );
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      ReaderLocalizationScope(
        localization: ReaderLocalization.instance,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: ReaderLocalization.instance.locale,
          supportedLocales: const [Locale('en'), Locale('ur'), Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const PrayerSettingsScreen(baseUrl: baseUrl),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await finishServiceOperation(tester, service.initialize(baseUrl: baseUrl));
  }

  testWidgets(
    '390px EN/UR/AR at two text scales and automatic-to-manual offset',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var checkedLayouts = 0;
      for (final language in [
        ReaderLanguage.english,
        ReaderLanguage.urdu,
        ReaderLanguage.arabic,
      ]) {
        for (final scale in [1.0, 1.6]) {
          resetFixture();
          await open(tester, language, scale: scale);
          final screenContext = tester.element(
            find.byType(PrayerSettingsScreen),
          );
          String t(String value) => prayerText(screenContext, value);
          expect(find.text(t('Namaz & Azan')), findsOneWidget);
          expect(service.settings.enabled, isFalse);
          expect(tester.takeException(), isNull);

          await tester.scrollUntilVisible(
            find.text(t('Manual location')).hitTestable(),
            200,
          );
          await tester.tap(find.text(t('Manual location')).hitTestable());
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(t('Cancel')));
          await tester.pumpAndSettle();

          for (final label in [
            'Today’s prayer times',
            'Alerts & audio',
            'Custom reminders',
          ]) {
            await tester.scrollUntilVisible(
              find.text(t(label)).hitTestable(),
              250,
            );
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason: '$label must not overflow',
            );
          }
          await tester.scrollUntilVisible(
            find.byIcon(Icons.add_rounded).hitTestable(),
            200,
          );
          await tester.tap(find.byIcon(Icons.add_rounded).hitTestable());
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(t('Save')));
          await tester.pumpAndSettle();
          expect(
            find.byType(AlertDialog),
            findsOneWidget,
            reason: 'An unnamed custom reminder must not be saved',
          );
          expect(service.settings.customReminders, isEmpty);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(t('Cancel')));
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          checkedLayouts++;
        }
      }

      expect(checkedLayouts, 6);
      resetFixture();
      service.settings = service.settings.copyWith(
        prayers: {PrayerId.fajr: const PrayerRule(offsetMinutes: 7)},
      );
      service.todayTimes = PrayerCalculator.timesForDate(
        service.settings,
        PrayerCalculator.dateInZone(DateTime.now(), service.settings),
      );
      final initial = service.todayTimes[PrayerId.fajr]!;
      final base = tz.TZDateTime.from(
        initial.subtract(const Duration(minutes: 7)),
        PrayerCalculator.zone(service.settings),
      );
      await open(tester, ReaderLanguage.english);
      await tester.scrollUntilVisible(find.text('Fajr').hitTestable(), 220);
      await tester.ensureVisible(find.byIcon(Icons.tune_rounded).first);
      await tester.tap(find.byIcon(Icons.tune_rounded).hitTestable().first);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Fajr'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(DropdownButtonFormField<bool>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manual').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Prayer time:'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await finishServiceOperation(tester, service.refresh());
      await tester.pumpAndSettle();
      expect(service.error, isNull);
      expect(service.busy, isFalse);
      expect(
        service.settings.rule(PrayerId.fajr).manualMinutes,
        base.hour * 60 + base.minute,
      );
      expect(service.settings.rule(PrayerId.fajr).offsetMinutes, 7);
      expect(service.todayTimes[PrayerId.fajr], initial);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
