import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_flutter_app/app/reader_localization.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/quran_page.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/quran_spread.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/reader_settings.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/widgets/dual_page_spread.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/widgets/mushaf_page_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists only the selected interface language and restores it', () async {
    SharedPreferences.setMockInitialValues({'existing.reader.setting': true});
    final preferences = await SharedPreferences.getInstance();
    final localization = ReaderLocalization(preferences: preferences);
    await localization.load();
    expect(localization.language, ReaderLanguage.english);
    await localization.setLanguage(ReaderLanguage.romanUrdu);

    final restored = ReaderLocalization(preferences: preferences);
    await restored.load();
    expect(restored.language, ReaderLanguage.romanUrdu);
    expect(restored.locale, const Locale('en'));
    expect(restored.textDirection, TextDirection.ltr);
    expect(preferences.getBool('existing.reader.setting'), isTrue);
    localization.dispose();
    restored.dispose();
  });

  test('unknown stored language falls back to English', () async {
    SharedPreferences.setMockInitialValues({ReaderLocalization.storageKey: 'unknown'});
    final localization = ReaderLocalization();
    await localization.load();
    expect(localization.language, ReaderLanguage.english);
    localization.dispose();
  });

  test('formats UI placeholders while preserving Arabic and source responses', () async {
    SharedPreferences.setMockInitialValues({});
    final localization = ReaderLocalization();
    await localization.setLanguage(ReaderLanguage.urdu);
    expect(localization.translate('Page {page}', args: {'page': 12}), 'صفحہ 12');
    expect(localization.translate('Page 17'), 'صفحہ 17');
    const arabic = 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ';
    const response = 'Remote server response body stays original.';
    expect(localization.translate(arabic), arabic);
    expect(localization.translate(response), response);
    localization.dispose();
  });

  test('compact page and line labels do not rewrite full sentences', () async {
    SharedPreferences.setMockInitialValues({});
    final localization = ReaderLocalization();
    await localization.setLanguage(ReaderLanguage.urdu);
    expect(localization.translate('P12'), 'ص12');
    expect(localization.translate('L16'), 'س16');
    const response = 'Public API response remains original.';
    expect(localization.translate(response), response);
    expect(localization.translate(
      'Large script reading. Admin pack v1 with 1439 imported pages can be downloaded for offline use.'),
      startsWith('Large script reading۔'));
    localization.dispose();
  });

  testWidgets('updates interface language and direction without restarting', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final localization = ReaderLocalization();
    await localization.setLanguage(ReaderLanguage.urdu);
    await tester.pumpWidget(_LocalizedApp(
      localization: localization,
      child: Builder(builder: (context) => Text(tr(context, 'Settings'))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('ترتیبات'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('ترتیبات'))), TextDirection.rtl);

    await localization.setLanguage(ReaderLanguage.romanUrdu);
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('Settings'))), TextDirection.ltr);
    await tester.pumpWidget(const SizedBox.shrink());
    localization.dispose();
  });

  testWidgets('Urdu chrome preserves physical left and right Mushaf pages', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final localization = ReaderLocalization();
    await localization.setLanguage(ReaderLanguage.urdu);
    const spread = QuranSpread(
      index: 0,
      rightPage: QuranPage(number: 1, isLeftPage: false, contentType: QuranPageContentType.placeholder),
      leftPage: QuranPage(number: 2, isLeftPage: true, contentType: QuranPageContentType.placeholder),
    );
    await tester.pumpWidget(_LocalizedApp(
      localization: localization,
      child: const DualPageSpread(spread: spread, settings: ReaderSettings.defaults()),
    ));
    await tester.pumpAndSettle();
    final left = find.byWidgetPredicate((widget) => widget is MushafPageWidget && widget.page.number == 2);
    final right = find.byWidgetPredicate((widget) => widget is MushafPageWidget && widget.page.number == 1);
    expect(tester.getCenter(left).dx, lessThan(tester.getCenter(right).dx));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    localization.dispose();
  });
}

class _LocalizedApp extends StatelessWidget {
  const _LocalizedApp({required this.localization, required this.child});
  final ReaderLocalization localization;
  final Widget child;

  @override
  Widget build(BuildContext context) => ReaderLocalizationScope(
    localization: localization,
    child: AnimatedBuilder(
      animation: localization,
      builder: (context, _) => MaterialApp(
        locale: localization.locale,
        supportedLocales: const [Locale('en'), Locale('ur')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Directionality(
          textDirection: localization.textDirection,
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
}
