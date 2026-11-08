import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/reader_page_pin_store.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/widgets/reader_page_pin_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('contain geometry excludes horizontal and vertical letterboxing', () {
    final tall = ReaderPinGeometry.imageRect(const Size(200, 400), const Size(400, 400));
    expect(tall, const Rect.fromLTWH(100, 0, 200, 400));
    expect(ReaderPinGeometry.normalizedPoint(const Offset(50, 200), tall), isNull);
    expect(ReaderPinGeometry.normalizedPoint(const Offset(200, 100), tall), const Offset(.5, .25));
    final wide = ReaderPinGeometry.imageRect(const Size(400, 200), const Size(400, 400));
    expect(wide, const Rect.fromLTWH(0, 100, 400, 200));
    expect(ReaderPinGeometry.normalizedPoint(const Offset(200, 50), wide), isNull);
    expect(ReaderPinGeometry.normalizedPoint(const Offset(100, 200), wide), const Offset(.25, .5));
  });

  test('normalized image coordinates preserve exact location after resizing', () {
    const point = Offset(.22, .73);
    for (final canvas in [const Size(320, 550), const Size(900, 600), const Size(1200, 1800)]) {
      final rect = ReaderPinGeometry.imageRect(const Size(730, 1100), canvas);
      final local = ReaderPinGeometry.localPoint(point, rect);
      final restored = ReaderPinGeometry.normalizedPoint(local, rect)!;
      expect(restored.dx, closeTo(point.dx, .0000001));
      expect(restored.dy, closeTo(point.dy, .0000001));
    }
  });

  testWidgets('inverse render transform keeps pin placement correct while zoomed and translated', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft,
      child: Transform(transform: Matrix4.identity()..translateByDouble(35, 20, 0, 1)..scaleByDouble(2.5, 2.5, 1, 1),
        child: SizedBox(key: key, width: 200, height: 300)))));
    final box = key.currentContext!.findRenderObject()! as RenderBox;
    const local = Offset(70, 165);
    final global = box.localToGlobal(local);
    final canvasPoint = box.globalToLocal(global);
    final rect = ReaderPinGeometry.imageRect(const Size(200, 300), box.size);
    final normalized = ReaderPinGeometry.normalizedPoint(canvasPoint, rect)!;
    expect(normalized.dx, closeTo(.35, .000001));
    expect(normalized.dy, closeTo(.55, .000001));
  });

  test('empty/non-finite canvas geometry cannot create a manual pin', () {
    expect(ReaderPinGeometry.imageRect(Size.zero, const Size(500, 500)), Rect.zero);
    expect(ReaderPinGeometry.imageRect(const Size(double.infinity, 200), const Size(500, 500)), Rect.zero);
    expect(ReaderPinGeometry.normalizedPoint(const Offset(0, 0), Rect.zero), isNull);
    expect(ReaderPinGeometry.normalizedPoint(const Offset(double.nan, 0), const Rect.fromLTWH(0, 0, 1, 1)), isNull);
  });

  test('image fingerprint is stable across providers but changes when scan pixels change', () async {
    Future<ui.Image> image(Color color) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 4, 6), Paint()..color = color);
      final picture = recorder.endRecording();
      try { return await picture.toImage(4, 6); }
      finally { picture.dispose(); }
    }
    final original = await image(Colors.white);
    final same = await image(Colors.white);
    final replacement = await image(Colors.black);
    try {
      expect(await fingerprintReaderScan(original), await fingerprintReaderScan(same));
      expect(await fingerprintReaderScan(original), isNot(await fingerprintReaderScan(replacement)));
    } finally { original.dispose(); same.dispose(); replacement.dispose(); }
  });

  testWidgets('normal page taps pass through and manual mode can add, edit and delete a pin', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final image = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 20, 30), Paint()..color = Colors.white);
      final picture = recorder.endRecording();
      try { return await picture.toImage(20, 30); }
      finally { picture.dispose(); }
    });
    final provider = _PinImageProvider(image!);
    var pageTaps = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Align(alignment: Alignment.topLeft,
      child: SizedBox(width: 200, height: 300, child: GestureDetector(onTap: () => pageTaps++,
        child: ReaderPagePinOverlay(pageNumber: 1, edition: '16_lines', sourceKey: 'blob:test-session',
          imageProvider: provider, originalImageProvider: provider, child: const ColoredBox(color: Colors.white))))))));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(100, 150));
    expect(pageTaps, 1);
    final button = tester.widget<IconButton>(find.byWidgetPredicate((widget) =>
        widget is IconButton && widget.tooltip == 'Manual notes and mistake pins'));
    await tester.runAsync(() async {
      final result = Function.apply(button.onPressed!, const []);
      if (result is Future) await result;
    });
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(100, 150));
    await tester.pumpAndSettle();
    expect(find.text('Add manual pin'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'A personal scan note');
    await tester.tap(find.text('Save pin'));
    await tester.pumpAndSettle();
    final store = ReaderPagePinStore(profileId: 'default', edition: '16_lines', page: 1, activeProfileId: () => 'default');
    expect((await store.load()).single.note, 'A personal scan note');
    expect((await store.load()).single.x, closeTo(.5, .001));
    expect((await store.load()).single.y, closeTo(.5, .001));
    await tester.tap(find.byTooltip('Manual note pin'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Edited note');
    await tester.tap(find.text('Save pin'));
    await tester.pumpAndSettle();
    expect((await store.load()).single.note, 'Edited note');
    await tester.tap(find.byTooltip('Manual note pin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete pin'));
    await tester.pumpAndSettle();
    expect(await store.load(), isEmpty);
    await tester.tap(find.byTooltip('Finish placing pins'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(100, 150));
    expect(pageTaps, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    image.dispose();
  });

  testWidgets('replacing decoded pixels at the same source path cannot reuse old scan pins', (tester) async {
    SharedPreferences.setMockInitialValues({});
    Future<ui.Image> image(Color color) async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 20, 30), Paint()..color = color);
      final picture = recorder.endRecording();
      try { return await picture.toImage(20, 30); }
      finally { picture.dispose(); }
    }
    final original = (await tester.runAsync(() => image(Colors.white)))!;
    final replacement = (await tester.runAsync(() => image(Colors.black)))!;
    final originalHash = await tester.runAsync(() => fingerprintReaderScan(original));
    final store = ReaderPagePinStore(profileId: 'default', edition: '16_lines', page: 1, activeProfileId: () => 'default');
    await store.save(ReaderPagePin(id: 'abcdefghijklmnop', imageIdentity: originalHash!, x: .5, y: .5,
      kind: ReaderPagePinKind.note, note: 'Original scan note',
      createdAt: '2026-11-08T12:00:00Z', updatedAt: '2026-11-08T12:00:00Z'));
    Widget content(ImageProvider<Object> provider) => MaterialApp(home: Scaffold(body: Align(alignment: Alignment.topLeft,
      child: SizedBox(width: 200, height: 300, child: ReaderPagePinOverlay(
        pageNumber: 1, edition: '16_lines', sourceKey: 'https://example.com/scan/001.webp',
        imageProvider: provider, originalImageProvider: provider, child: const ColoredBox(color: Colors.white))))));
    Future<void> enterManualMode() async {
      final button = tester.widget<IconButton>(find.byWidgetPredicate((widget) =>
          widget is IconButton && widget.tooltip == 'Manual notes and mistake pins'));
      await tester.runAsync(() async {
        final result = Function.apply(button.onPressed!, const []);
        if (result is Future) await result;
      });
      await tester.pumpAndSettle();
    }
    final originalProvider = _PinImageProvider(original, cacheKey: 'same-remote-path');
    await tester.runAsync(() => tester.pumpWidget(content(originalProvider)));
    await tester.pumpAndSettle();
    await enterManualMode();
    expect(find.byTooltip('Manual note pin'), findsOneWidget);
    await originalProvider.evict();
    await tester.runAsync(() => tester.pumpWidget(content(_PinImageProvider(replacement, cacheKey: 'same-remote-path'))));
    await tester.pumpAndSettle();
    await enterManualMode();
    expect(find.byTooltip('Manual note pin'), findsNothing);
    expect((await store.load()).single.imageIdentity, originalHash);
    await tester.pumpWidget(const SizedBox.shrink());
    original.dispose(); replacement.dispose();
  });
}

class _PinImageProvider extends ImageProvider<_PinImageProvider> {
  const _PinImageProvider(this.image, {this.cacheKey});
  final ui.Image image;
  final String? cacheKey;
  @override
  bool operator ==(Object other) => identical(this, other) ||
      cacheKey != null && other is _PinImageProvider && other.cacheKey == cacheKey;
  @override
  int get hashCode => cacheKey?.hashCode ?? identityHashCode(this);
  @override
  Future<_PinImageProvider> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(_PinImageProvider key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(SynchronousFuture(ImageInfo(image: image.clone())));
}
