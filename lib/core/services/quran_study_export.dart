import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';

import '../../features/quran_reader/domain/models/quran_study_models.dart';

class QuranStudyCard {
  const QuranStudyCard({required this.png, required this.rgb, required this.width, required this.height});
  final Uint8List png;
  final Uint8List rgb;
  final int width;
  final int height;
}

class QuranStudyExport {
  static Future<QuranStudyCard> render(QuranStudyVerse verse, {bool urdu = false,
      String notes = '', String noteLabel = 'Personal study note'}) async {
    if (notes.characters.length > 2000) throw const FormatException('Personal study notes are limited to 2000 characters.');
    const width = 1080;
    const inset = 76.0;
    const textWidth = width - inset * 2;
    TextPainter paragraph(String text, double size, Color color, {bool rtl = false, FontWeight? weight}) =>
        TextPainter(text: TextSpan(text: text, style: TextStyle(fontSize: size, height: 1.6,
          color: color, fontWeight: weight)), textDirection: rtl ? TextDirection.rtl : TextDirection.ltr)
          ..layout(maxWidth: textWidth);
    final title = paragraph('Quran · ${verse.reference} · ${verse.chapterName}', 30, const Color(0xFF6D634D), weight: FontWeight.w600);
    final arabic = paragraph(verse.arabic, 52, const Color(0xFF153D34), rtl: true);
    final translation = paragraph(urdu ? verse.urdu : verse.english, urdu ? 38 : 32,
      const Color(0xFF253C35), rtl: urdu);
    final note = notes.trim();
    final noteTitle = note.isEmpty ? null : paragraph(noteLabel, 26, const Color(0xFF6D634D), weight: FontWeight.w600);
    final noteBody = note.isEmpty ? null : paragraph(note, 28, const Color(0xFF253C35),
      rtl: RegExp(r'[\u0600-\u06FF]').hasMatch(note));
    final noteHeight = noteTitle == null ? 0 : noteTitle.height + noteBody!.height + 64;
    final source = paragraph('Arabic: Tanzil.info (Uthmani v1.0.2), © 2008–2009; CC BY-ND 3.0.\n'
      'Quranic Arabic Corpus, © 2011 Kais Dukes; corpus.quran.com\n'
      'Translation: Quran.com resource ${urdu ? 97 : 84}. Full notices in the app.',
      20, const Color(0xFF6D634D));
    final height = math.max(700, (inset * 2 + title.height + arabic.height + translation.height + noteHeight + source.height + 160).ceil());
    if (height > 8192) throw StateError('This Ayah and note are too long for a single card.');
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = const Color(0xFFFCF8EE));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(28, 28, width - 56, height - 56), const Radius.circular(28)),
      Paint()..color = const Color(0xFFD0B67A)..style = PaintingStyle.stroke..strokeWidth = 3);
    var y = inset;
    title.paint(canvas, Offset(inset, y)); y += title.height + 40;
    canvas.drawLine(Offset(inset, y - 12), Offset(width - inset, y - 12), Paint()..color = const Color(0xFFD0B67A)..strokeWidth = 2);
    arabic.paint(canvas, Offset(inset, y)); y += arabic.height + 40;
    translation.paint(canvas, Offset(inset, y)); y += translation.height + 52;
    if (noteTitle != null && noteBody != null) {
      canvas.drawLine(Offset(inset, y - 20), Offset(width - inset, y - 20), Paint()..color = const Color(0xFFD0B67A));
      noteTitle.paint(canvas, Offset(inset, y)); y += noteTitle.height + 12;
      noteBody.paint(canvas, Offset(inset, y)); y += noteBody.height + 52;
    }
    source.paint(canvas, Offset(inset, y));
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (png == null || rgba == null) throw StateError('Study export could not be rendered.');
      final raw = rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes);
      final rgb = Uint8List(width * height * 3);
      for (var input = 0, output = 0; input < raw.length; input += 4) {
        rgb[output++] = raw[input]; rgb[output++] = raw[input + 1]; rgb[output++] = raw[input + 2];
      }
      return QuranStudyCard(png: png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes), rgb: rgb, width: width, height: height);
    } finally { image.dispose(); }
  }

  static Uint8List pdf(List<QuranStudyCard> cards) {
    if (cards.isEmpty || cards.length > 32) throw const FormatException('Choose between 1 and 32 study cards.');
    final output = BytesBuilder(copy: false);
    final offsets = <int>[0];
    void write(String text) => output.add(latin1.encode(text));
    void object(int id, void Function() contents) {
      offsets.add(output.length);
      write('$id 0 obj\n'); contents(); write('\nendobj\n');
    }
    write('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n');
    object(1, () => write('<< /Type /Catalog /Pages 2 0 R >>'));
    object(2, () => write('<< /Type /Pages /Count ${cards.length} /Kids [${List.generate(cards.length, (index) => '${5 + index * 3} 0 R').join(' ')}] >>'));
    for (var index = 0; index < cards.length; index++) {
      final card = cards[index];
      if (card.width < 1 || card.width > 4096 || card.height < 1 || card.height > 8192 ||
          card.rgb.length != card.width * card.height * 3) {
        throw const FormatException('Invalid study image dimensions.');
      }
      final id = 3 + index * 3;
      final compressed = const ZLibEncoder().encode(card.rgb);
      object(id, () {
        write('<< /Type /XObject /Subtype /Image /Width ${card.width} /Height ${card.height} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode /Length ${compressed.length} >>\nstream\n');
        output.add(compressed); write('\nendstream');
      });
      const pageWidth = 595.28;
      final imageHeight = card.height * pageWidth / card.width;
      final pageHeight = math.max(841.89, imageHeight);
      final content = 'q\n$pageWidth 0 0 $imageHeight 0 ${pageHeight - imageHeight} cm\n/Im0 Do\nQ\n';
      object(id + 1, () => write('<< /Length ${content.length} >>\nstream\n${content}endstream'));
      object(id + 2, () => write('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $pageWidth $pageHeight] '
        '/Resources << /XObject << /Im0 $id 0 R >> >> /Contents ${id + 1} 0 R >>'));
    }
    final startXref = output.length;
    write('xref\n0 ${offsets.length}\n0000000000 65535 f \n');
    for (final offset in offsets.skip(1)) {
      write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    write('trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\nstartxref\n$startXref\n%%EOF\n');
    return output.takeBytes();
  }
}
