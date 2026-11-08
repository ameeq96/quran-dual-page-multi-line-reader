import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';

import '../../../../app/app_theme.dart';

class BootstrapSplash extends StatefulWidget {
  const BootstrapSplash({super.key, this.nightMode});

  final bool? nightMode;

  @override
  State<BootstrapSplash> createState() => _BootstrapSplashState();
}

class _BootstrapSplashState extends State<BootstrapSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useDark = widget.nightMode ?? false;
    return Theme(
      data: useDark ? AppTheme.dark() : AppTheme.light(),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _SplashFramePainter(
                            color: theme.colorScheme.secondary,
                            dark: useDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final short = constraints.maxHeight < 500;
                      final padding = constraints.maxWidth < 380 ? 20.0 : 28.0;
                      final artworkWidth = math.min(
                        short ? 128.0 : 236.0,
                        math.max(80.0, constraints.maxWidth - padding * 2) *
                            0.72,
                      );
                      return SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: padding,
                          vertical: short ? 16 : 24,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(
                              0,
                              constraints.maxHeight - (short ? 32 : 48),
                            ),
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IgnorePointer(
                                    child: ExcludeSemantics(
                                      child: RepaintBoundary(
                                        child: CustomPaint(
                                          size: Size(
                                            artworkWidth,
                                            artworkWidth * 1.125,
                                          ),
                                          isComplex: true,
                                          willChange: !_reducedMotion,
                                          painter: _MushafEmblemPainter(
                                            progress: _controller,
                                            reducedMotion: _reducedMotion,
                                            accent: theme.colorScheme.secondary,
                                            halo: theme
                                                .colorScheme
                                                .secondaryContainer,
                                            dark: useDark,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: short ? 8 : 20),
                                  Text(
                                    tr(context, 'Quran Pak'),
                                    textAlign: TextAlign.center,
                                    style:
                                        (short
                                                ? theme.textTheme.headlineSmall
                                                : theme.textTheme.headlineLarge)
                                            ?.copyWith(
                                              color:
                                                  theme.colorScheme.onSurface,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: -0.8,
                                            ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    tr(context, 'DUAL PAGE READER'),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.secondary,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 2.5,
                                      fontSize: 10,
                                    ),
                                  ),
                                  SizedBox(height: short ? 18 : 30),
                                  Semantics(
                                    liveRegion: true,
                                    label: tr(context, 'Preparing your Mushaf'),
                                    child: ExcludeSemantics(
                                      child: Text(
                                        tr(context, 'Preparing your Mushaf…'),
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  ExcludeSemantics(
                                    child: RepaintBoundary(
                                      child: SizedBox(
                                        width: 156,
                                        height: 4,
                                        child: CustomPaint(
                                          painter: _LoadingRailPainter(
                                            progress: _controller,
                                            reducedMotion: _reducedMotion,
                                            accent: theme.colorScheme.secondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (!short) ...[
                                    const SizedBox(height: 30),
                                    Text(
                                      tr(context, 'Read. Reflect. Return.'),
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                            letterSpacing: 0.6,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SplashFramePainter extends CustomPainter {
  const _SplashFramePainter({required this.color, required this.dark});
  final Color color;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 80 || size.height < 80) return;
    final inset = size.width < 420 ? 12.0 : 22.0;
    final rect = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset,
    );
    final line = Paint()
      ..color = color.withValues(alpha: dark ? 0.2 : 0.17)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(26)),
      line,
    );
    final mark = Paint()..color = color.withValues(alpha: 0.5);
    for (final y in [rect.top, rect.bottom]) {
      final x = size.width / 2;
      canvas.drawPath(
        Path()
          ..moveTo(x, y - 3)
          ..lineTo(x + 3, y)
          ..lineTo(x, y + 3)
          ..lineTo(x - 3, y)
          ..close(),
        mark,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SplashFramePainter oldDelegate) =>
      color != oldDelegate.color || dark != oldDelegate.dark;
}

class _MushafEmblemPainter extends CustomPainter {
  _MushafEmblemPainter({
    required this.progress,
    required this.reducedMotion,
    required this.accent,
    required this.halo,
    required this.dark,
  }) : super(repaint: progress);
  final Animation<double> progress;
  final bool reducedMotion;
  final Color accent;
  final Color halo;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 240, size.height / 270);
    canvas.save();
    canvas.translate(
      (size.width - 240 * scale) / 2,
      (size.height - 270 * scale) / 2,
    );
    canvas.scale(scale);
    final phase = progress.value * math.pi * 2;
    final lift = reducedMotion ? 0.0 : math.sin(phase) * 2.5;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          halo.withValues(alpha: dark ? 0.24 : 0.45),
          halo.withValues(alpha: 0),
        ],
      ).createShader(const Rect.fromLTWH(12, 24, 216, 216));
    canvas.drawCircle(const Offset(120, 132), 108, glow);

    final frame = Path()
      ..moveTo(24, 232)
      ..lineTo(24, 108)
      ..quadraticBezierTo(24, 46, 120, 16)
      ..quadraticBezierTo(216, 46, 216, 108)
      ..lineTo(216, 232)
      ..close();
    final framePaint = Paint()
      ..color = accent.withValues(alpha: dark ? 0.28 : 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(frame, framePaint);
    final inner = Path()
      ..moveTo(34, 223)
      ..lineTo(34, 109)
      ..quadraticBezierTo(34, 54, 120, 27)
      ..quadraticBezierTo(206, 54, 206, 109)
      ..lineTo(206, 223);
    canvas.drawPath(inner, framePaint..color = accent.withValues(alpha: 0.12));
    final metric = frame.computeMetrics().first;
    final start = (reducedMotion ? 0.2 : progress.value) * metric.length;
    final end = start + metric.length * 0.18;
    final beam = Paint()
      ..color = accent.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      metric.extractPath(start, math.min(end, metric.length)),
      beam,
    );
    if (end > metric.length) {
      canvas.drawPath(metric.extractPath(0, end - metric.length), beam);
    }

    canvas.save();
    canvas.translate(0, lift);
    final cover = RRect.fromRectAndRadius(
      const Rect.fromLTWH(62, 61, 116, 160),
      const Radius.circular(8),
    );
    final coverPath = Path()..addRRect(cover);
    canvas.drawShadow(
      coverPath,
      Colors.black.withValues(alpha: dark ? 0.34 : 0.16),
      12,
      false,
    );
    final pages = RRect.fromRectAndRadius(
      const Rect.fromLTWH(65, 67, 113, 159),
      const Radius.circular(7),
    );
    canvas.drawRRect(pages, Paint()..color = const Color(0xFFE6DDC7));
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(71, 222 + i * 1.5),
        Offset(171, 222 + i * 1.5),
        Paint()
          ..color = const Color(0xFFB4A98D)
          ..strokeWidth = 0.6,
      );
    }
    canvas.drawRRect(
      cover,
      Paint()..color = dark ? const Color(0xFF204B3A) : const Color(0xFF163F35),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(62, 61, 10, 160),
        const Radius.circular(5),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.13),
    );
    final gold = Paint()
      ..color = const Color(0xFFE2C68B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(72, 70, 96, 142),
        const Radius.circular(3),
      ),
      gold,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(76, 74, 88, 134),
        const Radius.circular(2),
      ),
      gold..color = const Color(0xFFE2C68B).withValues(alpha: 0.45),
    );
    final ribbon = Path()
      ..moveTo(148, 61)
      ..lineTo(157, 61)
      ..lineTo(157, 87)
      ..lineTo(152.5, 83)
      ..lineTo(148, 87)
      ..close();
    canvas.drawPath(ribbon, Paint()..color = const Color(0xFFE2C68B));

    canvas.save();
    canvas.translate(120, 140);
    gold
      ..color = const Color(0xFFE2C68B).withValues(alpha: 0.72)
      ..strokeWidth = 0.9;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-26, -26, 52, 52),
        const Radius.circular(2),
      ),
      gold,
    );
    canvas.rotate(math.pi / 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-26, -26, 52, 52),
        const Radius.circular(2),
      ),
      gold,
    );
    canvas.restore();
    final book = Path()
      ..moveTo(103, 132)
      ..quadraticBezierTo(111, 128, 120, 134)
      ..quadraticBezierTo(129, 128, 137, 132)
      ..lineTo(137, 149)
      ..quadraticBezierTo(129, 145, 120, 151)
      ..quadraticBezierTo(111, 145, 103, 149)
      ..close()
      ..moveTo(120, 134)
      ..lineTo(120, 151);
    canvas.drawPath(
      book,
      gold
        ..color = const Color(0xFFF1DFB3)
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    for (final y in [89.0, 191.0]) {
      canvas.drawLine(
        Offset(105, y),
        Offset(135, y),
        gold
          ..color = const Color(0xFFE2C68B).withValues(alpha: 0.7)
          ..strokeWidth = 0.8,
      );
      canvas.drawCircle(
        Offset(120, y),
        2,
        Paint()..color = const Color(0xFFE2C68B),
      );
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MushafEmblemPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      reducedMotion != oldDelegate.reducedMotion ||
      accent != oldDelegate.accent ||
      halo != oldDelegate.halo ||
      dark != oldDelegate.dark;
}

class _LoadingRailPainter extends CustomPainter {
  _LoadingRailPainter({
    required this.progress,
    required this.reducedMotion,
    required this.accent,
  }) : super(repaint: progress);
  final Animation<double> progress;
  final bool reducedMotion;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = accent.withValues(alpha: 0.13),
    );
    final width = size.width * 0.3;
    final travel = size.width - width;
    final position = reducedMotion
        ? 0.5
        : (1 - math.cos(progress.value * math.pi * 2)) / 2;
    final rect = Rect.fromLTWH(travel * position, 0, width, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          accent.withValues(alpha: 0.15),
          accent,
          accent.withValues(alpha: 0.15),
        ],
      ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
  }

  @override
  bool shouldRepaint(covariant _LoadingRailPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      reducedMotion != oldDelegate.reducedMotion ||
      accent != oldDelegate.accent;
}
