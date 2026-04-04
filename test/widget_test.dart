import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_flutter_app/features/quran_reader/domain/models/quran_page.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/quran_spread.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/reader_settings.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/widgets/dual_page_spread.dart';

void main() {
  testWidgets('renders a dual-page Mushaf spread with placeholders',
      (WidgetTester tester) async {
    const spread = QuranSpread(
      index: 0,
      rightPage: QuranPage(
        number: 1,
        isLeftPage: false,
        contentType: QuranPageContentType.placeholder,
      ),
      leftPage: QuranPage(
        number: 2,
        isLeftPage: true,
        contentType: QuranPageContentType.placeholder,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DualPageSpread(
            spread: spread,
            settings: ReaderSettings.defaults(),
          ),
        ),
      ),
    );

    expect(find.text('Placeholder'), findsNWidgets(2));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });
}
