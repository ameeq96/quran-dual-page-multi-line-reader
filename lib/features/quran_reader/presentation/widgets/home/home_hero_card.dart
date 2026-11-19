import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../app/app_theme.dart';
import '../../../../../app/reader_localization.dart';
import '../../../domain/models/quran_page.dart';
import '../app_motion.dart';
import '../quran_page_image_provider.dart';

/// Duration of the one-shot progress fills on the home screen.
const Duration homeProgressFill = Duration(milliseconds: 900);

/// Path of the eight-point star (khatam) used as the home screen's motif.
Path homeKhatamPath(Offset center, double radius, {double inset = 0.72}) {
  final path = Path();
  for (var i = 0; i < 16; i++) {
    final r = i.isEven ? radius : radius * inset;
    final angle = -math.pi / 2 + i * math.pi / 8;
    final point = center + Offset(math.cos(angle), math.sin(angle)) * r;
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}

/// The emerald "continue reading" hero: the focal point of the home screen.
class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.page,
    required this.compact,
    required this.onResume,
    required this.currentPage,
    required this.totalPages,
    this.progress = 0,
  });

  final double progress;
  final String title;
  final String subtitle;
  final QuranPage page;
  final bool compact;
  final VoidCallback onResume;
  final int currentPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = AppDecor.of(context);
    final cream = decor.onHero;
    final gold = decor.gold;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final pad = compact ? 20.0 : 32.0;
    final textScaler = MediaQuery.textScalerOf(context);
    final largeText = textScaler.scale(1) > 1.3;
    final bookWidth = compact ? (largeText ? 72.0 : 92.0) : 148.0;
    final bookHeight = compact ? (largeText ? 105.0 : 134.0) : 214.0;
    const figures = <FontFeature>[FontFeature.tabularFigures()];

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(largeText ? AppRadii.md : 999),
        border: Border.all(color: gold.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_rounded, size: 14, color: gold),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              tr(context, 'Continue your reading'),
              maxLines: largeText ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: gold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [Flexible(child: pill)]),
        SizedBox(height: compact ? 16 : 24),
        Text(
          tr(context, title),
          // Display-size type is already large; cap its scaling so long
          // surah names keep to a line or two beside the page preview.
          textScaler: textScaler.clamp(maxScaleFactor: 1.3),
          style: theme.textTheme.headlineLarge?.copyWith(
            color: cream,
            fontSize:
                (theme.textTheme.headlineLarge?.fontSize ?? 32) *
                (compact ? 0.94 : 1.2),
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(context, subtitle),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cream.withValues(alpha: 0.84),
          ),
        ),
      ],
    );

    final percent = '${(progress * 100).round()}%';
    final progressBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: tr(context, subtitle),
          value: percent,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: reduced ? progress : 0, end: progress),
            duration: reduced ? Duration.zero : homeProgressFill,
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => CustomPaint(
              size: const Size(double.infinity, 14),
              painter: _HeroProgressPainter(
                value: value,
                rtl: rtl,
                track: cream.withValues(alpha: 0.16),
                fillStart: Color.lerp(gold, cream, 0.45) ?? gold,
                fillEnd: gold,
                knob: cream,
                glow: gold.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$currentPage',
                        style: TextStyle(
                          color: cream,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: ' / $totalPages'),
                    ],
                  ),
                  textDirection: TextDirection.ltr,
                  textAlign: rtl ? TextAlign.right : TextAlign.left,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cream.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                    fontFeatures: figures,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                percent,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: gold,
                  fontWeight: FontWeight.w700,
                  fontFeatures: figures,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final book = Semantics(
      label: tr(context, 'Preview of your original Mushaf page'),
      image: true,
      child: _BookStack(
        page: page,
        width: bookWidth,
        height: bookHeight,
        rtl: rtl,
      ),
    );

    final button = _ResumeButton(onPressed: onResume, expand: compact);

    // Where the page preview sits, so the painted halo lines up behind it.
    final focalFromEnd = pad + bookWidth / 2 + 6;
    final focalFromTop = pad + bookHeight / 2 + 4;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: decor.heroGradient,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: decor.floatShadow,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: gold.withValues(alpha: 0.28)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: HomeHeroMotif(
                  gold: gold,
                  light: cream,
                  rtl: rtl,
                  focalFromEnd: focalFromEnd,
                  focalFromTop: focalFromTop,
                  haloRadius: bookHeight * 0.6,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(pad),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: heading),
                          const SizedBox(width: 12),
                          book,
                        ],
                      ),
                      const SizedBox(height: 20),
                      progressBlock,
                      const SizedBox(height: 20),
                      button,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            heading,
                            const SizedBox(height: 24),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: progressBlock,
                            ),
                            const SizedBox(height: 28),
                            button,
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      book,
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// A small stack of pages: the live Mushaf page on top of two resting leaves,
/// so the preview reads as a real book rather than a flat thumbnail.
class _BookStack extends StatelessWidget {
  const _BookStack({
    required this.page,
    required this.width,
    required this.height,
    required this.rtl,
  });

  final QuranPage page;
  final double width;
  final double height;
  final bool rtl;

  @override
  Widget build(BuildContext context) {
    final decor = AppDecor.of(context);
    final shadow = Theme.of(context).colorScheme.shadow;
    final cream = decor.onHero;
    final gold = decor.gold;
    final dir = rtl ? -1.0 : 1.0;
    final radius = BorderRadius.circular(width * 0.09);

    Widget leaf(double angle, Offset offset, double tone) {
      return Transform.translate(
        offset: Offset(offset.dx * dir, offset.dy),
        child: Transform.rotate(
          angle: angle * dir,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Color.lerp(cream, gold, tone),
              borderRadius: radius,
              border: Border.all(color: gold.withValues(alpha: 0.7)),
              boxShadow: [
                BoxShadow(
                  color: shadow.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final fallback = Icon(
      Icons.menu_book_outlined,
      color: decor.onGold,
      size: width * 0.36,
    );

    return SizedBox(
      width: width + 12,
      height: height + 8,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          leaf(-0.085, const Offset(-5, 3), 0.42),
          leaf(-0.02, const Offset(-1, 2), 0.24),
          Transform.rotate(
            angle: 0.05 * dir,
            child: Container(
              width: width,
              height: height,
              padding: EdgeInsets.all(width * 0.06),
              decoration: BoxDecoration(
                color: cream,
                borderRadius: radius,
                border: Border.all(color: gold, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: shadow.withValues(alpha: 0.42),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: shadow.withValues(alpha: 0.22),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: radius,
                // A faint shade along the binding edge.
                gradient: LinearGradient(
                  begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
                  end: rtl ? Alignment.centerLeft : Alignment.centerRight,
                  colors: [
                    decor.onGold.withValues(alpha: 0.16),
                    decor.onGold.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.16],
                ),
              ),
              child: page.assetPath == null
                  ? fallback
                  : Image(
                      image: buildQuranPageImageProvider(page, cacheWidth: 320),
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                      errorBuilder: (_, __, ___) => fallback,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The gold primary action on the hero.
class _ResumeButton extends StatelessWidget {
  const _ResumeButton({required this.onPressed, required this.expand});

  final VoidCallback onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = AppDecor.of(context);
    final gold = decor.gold;
    final label = Text(
      tr(context, 'Resume Reading'),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(
        color: decor.onGold,
        fontWeight: FontWeight.w700,
      ),
    );
    return AppPressable(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(gold, decor.onHero, 0.42) ?? gold, gold],
          ),
          shadows: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.34),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: gold.withValues(alpha: 0.22),
              blurRadius: 18,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            splashColor: decor.onGold.withValues(alpha: 0.12),
            highlightColor: decor.onGold.withValues(alpha: 0.06),
            child: Semantics(
              button: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(26, 8, 8, 8),
                  child: Row(
                    mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                    children: [
                      if (expand) Expanded(child: label) else Flexible(child: label),
                      const SizedBox(width: 18),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: decor.onGold,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: gold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroProgressPainter extends CustomPainter {
  const _HeroProgressPainter({
    required this.value,
    required this.rtl,
    required this.track,
    required this.fillStart,
    required this.fillEnd,
    required this.knob,
    required this.glow,
  });

  final double value;
  final bool rtl;
  final Color track;
  final Color fillStart;
  final Color fillEnd;
  final Color knob;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    const thickness = 8.0;
    final knobRadius = size.height / 2;
    final y = size.height / 2;
    final left = knobRadius;
    final right = size.width - knobRadius;
    if (right <= left) {
      return;
    }
    final line = Paint()
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(left, y), Offset(right, y), line..color = track);
    final v = value.clamp(0.0, 1.0);
    if (v <= 0) {
      return;
    }
    final from = rtl ? right : left;
    final to = rtl ? right - (right - left) * v : left + (right - left) * v;
    final rect = Rect.fromPoints(Offset(from, 0), Offset(to, size.height));
    canvas.drawLine(
      Offset(from, y),
      Offset(to, y),
      Paint()
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
          end: rtl ? Alignment.centerLeft : Alignment.centerRight,
          colors: [fillStart, fillEnd],
        ).createShader(rect.inflate(1)),
    );
    canvas.drawCircle(
      Offset(to, y),
      knobRadius + 3,
      Paint()
        ..color = glow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(Offset(to, y), knobRadius, Paint()..color = knob);
    canvas.drawCircle(Offset(to, y), knobRadius - 3, Paint()..color = fillEnd);
  }

  @override
  bool shouldRepaint(covariant _HeroProgressPainter old) =>
      old.value != value ||
      old.rtl != rtl ||
      old.track != track ||
      old.fillStart != fillStart ||
      old.fillEnd != fillEnd ||
      old.knob != knob;
}

/// Star lattice, halo and soft light painted behind the hero content.
class HomeHeroMotif extends CustomPainter {
  const HomeHeroMotif({
    required this.gold,
    required this.light,
    required this.rtl,
    required this.focalFromEnd,
    required this.focalFromTop,
    required this.haloRadius,
  });

  final Color gold;
  final Color light;
  final bool rtl;
  final double focalFromEnd;
  final double focalFromTop;
  final double haloRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final focal = Offset(
      rtl ? focalFromEnd : size.width - focalFromEnd,
      focalFromTop,
    );

    // Soft sheen from the top edge, like light falling on a cover.
    final sheen = Rect.fromLTWH(0, 0, size.width, size.height * 0.55);
    canvas.drawRect(
      sheen,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light.withValues(alpha: 0.09), light.withValues(alpha: 0)],
        ).createShader(sheen),
    );

    // Eight-point star lattice, strongest near the page and fading out
    // towards the text so the copy stays easy to read.
    const cell = 40.0;
    const half = cell / 2;
    const inner = half * 0.42;
    final reach = math.max(size.width, size.height) * 0.9;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height + cell; y += cell) {
      for (var x = 0.0; x < size.width + cell; x += cell) {
        final distance = (Offset(x, y) - focal).distance;
        final fade = (1 - distance / reach).clamp(0.0, 1.0);
        final alpha = 0.035 + 0.13 * fade * fade;
        final path = Path()
          ..moveTo(x, y - half)
          ..lineTo(x + inner, y - inner)
          ..lineTo(x + half, y)
          ..lineTo(x + inner, y + inner)
          ..lineTo(x, y + half)
          ..lineTo(x - inner, y + inner)
          ..lineTo(x - half, y)
          ..lineTo(x - inner, y - inner)
          ..close();
        canvas.drawPath(path, stroke..color = gold.withValues(alpha: alpha));
      }
    }

    // Warm glow and a khatam halo behind the page preview.
    final glowRadius = haloRadius * 1.9;
    canvas.drawCircle(
      focal,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [gold.withValues(alpha: 0.3), gold.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: focal, radius: glowRadius)),
    );
    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      homeKhatamPath(focal, haloRadius),
      halo
        ..strokeWidth = 1.2
        ..color = gold.withValues(alpha: 0.34),
    );
    canvas.drawPath(
      homeKhatamPath(focal, haloRadius * 1.2),
      halo
        ..strokeWidth = 1
        ..color = gold.withValues(alpha: 0.13),
    );
    canvas.drawCircle(
      focal,
      haloRadius * 1.42,
      halo
        ..strokeWidth = 1
        ..color = gold.withValues(alpha: 0.07),
    );
  }

  @override
  bool shouldRepaint(covariant HomeHeroMotif old) =>
      old.gold != gold ||
      old.light != light ||
      old.rtl != rtl ||
      old.focalFromEnd != focalFromEnd ||
      old.focalFromTop != focalFromTop ||
      old.haloRadius != haloRadius;
}
