import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';

import '../../../../app/app_theme.dart';
import '../controllers/quran_reader_controller.dart';
import '../widgets/app_motion.dart';

class QuranOnboardingScreen extends StatefulWidget {
  const QuranOnboardingScreen({
    super.key,
    required this.controller,
    required this.onComplete,
  });

  final QuranReaderController controller;
  final Future<void> Function() onComplete;

  @override
  State<QuranOnboardingScreen> createState() => _QuranOnboardingScreenState();
}

class _QuranOnboardingScreenState extends State<QuranOnboardingScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _finishing = false;

  /// The first page staggers in once; it must not replay when swiping back.
  bool _introPlayed = false;

  static const List<_OnboardingItem> _items = <_OnboardingItem>[
    _OnboardingItem(
      title: 'Read your way',
      subtitle:
          'Switch between multiple Mushaf editions, portrait and landscape reading, and paper-style day or night mode.',
      icon: Icons.auto_stories_rounded,
      highlights: <String>[
        '10, 13, 14, 15, 16, and 17 line Mushaf support',
        'Portrait single-page and landscape spread reading',
        'Day mode, night mode, and reading surface controls',
      ],
    ),
    _OnboardingItem(
      title: 'Jump anywhere fast',
      subtitle:
          'Find what you need quickly from Surah index, Juz index, exact page jump, bookmarks, and page thumbnails.',
      icon: Icons.travel_explore_rounded,
      highlights: <String>[
        'Surah, Juz, Ayah, and text search',
        'Go to page and thumbnail preview navigation',
        'Resume reading and saved bookmarks',
      ],
    ),
    _OnboardingItem(
      title: 'Study and listen',
      subtitle:
          'Use audio recitation, insights, Kanzul Iman study mode, and compare editions side by side for deeper study.',
      icon: Icons.headphones_rounded,
      highlights: <String>[
        'Qari selection, play, pause, stop, and repeat',
        'Insights, notes, favorites, and daily target tracking',
        'Compare editions and Kanzul Iman study pages',
      ],
    ),
    _OnboardingItem(
      title: 'Use AI study tools',
      subtitle:
          'Open AI Studio for page explanations, study notes, semantic search, memorization review, and quick tafsir help.',
      icon: Icons.auto_awesome_rounded,
      highlights: <String>[
        'Explain the current page in simple language',
        'Generate notes, reflections, and teaching points',
        'Use AI smart search, hifz coach, and tajweed guidance',
      ],
    ),
    _OnboardingItem(
      title: 'Plan, revise, and scale',
      subtitle:
          'Use the new plans hub for reading goals, hifz revision, accessibility, and backup-ready sync settings.',
      icon: Icons.insights_outlined,
      highlights: <String>[
        'Reading plans for steady flow, Ramadan, 30-day khatam, and custom goals',
        'Weak-page hifz tracking and quick revision queue',
        'AI depth modes, larger text, and backup export',
      ],
    ),
    _OnboardingItem(
      title: 'Built for daily use',
      subtitle:
          'Track streaks, continue from your last page, and keep everything ready from the home menu.',
      icon: Icons.verified_rounded,
      highlights: <String>[
        'Daily target and khatam progress',
        'Reader dashboard and quick access tools',
        'Optimized reader flow for fast opening and smooth navigation',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) {
      return;
    }
    setState(() {
      _finishing = true;
    });
    await widget.onComplete();
    if (mounted) {
      setState(() {
        _finishing = false;
      });
    }
  }

  Future<void> _next() async {
    if (_currentIndex >= _items.length - 1) {
      await _finish();
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(_currentIndex + 1);
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        widget.controller.settingsListenable,
        widget.controller.contentListenable,
      ]),
      builder: (context, _) {
        final settings = widget.controller.settings;
        final experience = widget.controller.experienceSettings;
        final themeData = settings.nightMode
            ? AppTheme.dark(
                highContrast: experience.highContrastMode,
                largerText: experience.largerTextMode,
              )
            : AppTheme.light(
                highContrast: experience.highContrastMode,
                largerText: experience.largerTextMode,
              );
        return Theme(
          data: themeData,
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final size = MediaQuery.sizeOf(context);
              final compact = size.width < 420 || size.height < 760;
              // Landscape phones: too little height to stack everything.
              final short = size.height < 500;
              final reducedMotion = MediaQuery.disableAnimationsOf(context);
              final gutter = compact ? 16.0 : 24.0;
              final isLast = _currentIndex == _items.length - 1;

              final dots = _PageDots(
                count: _items.length,
                current: _currentIndex,
                reducedMotion: reducedMotion,
              );
              final button = AppPressable(
                child: FilledButton.icon(
                  onPressed: _finishing ? null : _next,
                  style: FilledButton.styleFrom(
                    minimumSize: Size(short ? 208 : 64, 56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: const StadiumBorder(),
                    textStyle: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: Icon(
                    isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    size: 20,
                  ),
                  label: Text(
                    tr(context, isLast ? 'Start using the app' : 'Next'),
                  ),
                ),
              );

              return Scaffold(
                backgroundColor: theme.scaffoldBackgroundColor,
                body: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              theme.scaffoldBackgroundColor,
                              theme.colorScheme.surfaceContainerLowest
                                  .withValues(
                                    alpha: theme.brightness == Brightness.dark
                                        ? 0.92
                                        : 1,
                                  ),
                              theme.colorScheme.surface,
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: ExcludeSemantics(child: _OnboardingAura()),
                      ),
                    ),
                    SafeArea(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: short ? 980 : 640,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                  gutter,
                                  short ? 8 : (compact ? 12 : 18),
                                  // Skip carries its own inner padding.
                                  gutter - 8,
                                  short ? 6 : (compact ? 12 : 16),
                                ),
                                child: AppStagger(
                                  index: 0,
                                  // Keep the header from eating the page at
                                  // very large text sizes; the page itself
                                  // scrolls at the full scale.
                                  child: MediaQuery.withClampedTextScaling(
                                    maxScaleFactor: 1.3,
                                    child: _OnboardingHeader(
                                      compact: compact,
                                      short: short,
                                      onSkip: _finishing ? null : _finish,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: PageView.builder(
                                  controller: _pageController,
                                  itemCount: _items.length,
                                  onPageChanged: (index) {
                                    setState(() {
                                      _currentIndex = index;
                                      if (index != 0) {
                                        _introPlayed = true;
                                      }
                                    });
                                  },
                                  itemBuilder: (context, index) {
                                    // The gutter lives inside the page so the
                                    // card's shadow and rounded corners are
                                    // never clipped by the PageView viewport.
                                    return Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                        gutter,
                                        4,
                                        gutter,
                                        short ? 12 : 20,
                                      ),
                                      child: _OnboardingCard(
                                        item: _items[index],
                                        index: index,
                                        compact: compact,
                                        pageController: _pageController,
                                        reducedMotion: reducedMotion,
                                        intro: index == 0 && !_introPlayed,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                  gutter,
                                  0,
                                  gutter,
                                  short ? 10 : (compact ? 14 : 20),
                                ),
                                child: AppStagger(
                                  index: 7,
                                  child: short
                                      ? Row(
                                          children: [
                                            dots,
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Align(
                                                alignment: AlignmentDirectional
                                                    .centerEnd,
                                                child: button,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Center(child: dots),
                                            SizedBox(height: compact ? 14 : 18),
                                            button,
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Soft emerald and gold light behind the top of the screen, matching home.
class _OnboardingAura extends StatelessWidget {
  const _OnboardingAura();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final decor = AppDecor.of(context);
    Widget glow(Color color, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        PositionedDirectional(
          top: -170,
          start: -130,
          child: glow(
            theme.colorScheme.primary.withValues(alpha: dark ? 0.22 : 0.13),
            460,
          ),
        ),
        PositionedDirectional(
          top: -120,
          end: -150,
          child: glow(decor.gold.withValues(alpha: dark ? 0.12 : 0.26), 400),
        ),
      ],
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.compact,
    required this.short,
    required this.onSkip,
  });

  final bool compact;
  final bool short;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = AppDecor.of(context);
    final badgeSize = short ? 44.0 : (compact ? 48.0 : 56.0);
    return Row(
      children: [
        Container(
          width: badgeSize,
          height: badgeSize,
          decoration: BoxDecoration(
            gradient: decor.heroGradient,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: decor.gold.withValues(alpha: 0.28)),
            boxShadow: decor.cardShadow,
          ),
          child: Icon(
            Icons.menu_book_rounded,
            color: decor.gold,
            size: short ? 22 : 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr(context, 'Welcome to Quran Pak Dual Page Reader'),
                style:
                    (short
                            ? theme.textTheme.titleSmall
                            : compact
                            ? theme.textTheme.titleMedium
                            : theme.textTheme.titleLarge)
                        ?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
              ),
              SizedBox(height: short ? 1 : 3),
              Text(
                tr(context, 'A quick overview of what you can use in the app.'),
                style:
                    (compact
                            ? theme.textTheme.bodySmall
                            : theme.textTheme.bodyMedium)
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            minimumSize: const Size(56, 48),
            tapTargetSize: MaterialTapTargetSize.padded,
            shape: const StadiumBorder(),
          ),
          child: Text(tr(context, 'Skip')),
        ),
      ],
    );
  }
}

/// Animated pill indicator: the active dot stretches into a pill.
class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.current,
    required this.reducedMotion,
  });

  final int count;
  final int current;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(count, (index) {
        final active = index == current;
        return AnimatedContainer(
          duration: reducedMotion ? Duration.zero : AppMotion.enter,
          curve: AppMotion.enterCurve,
          margin: const EdgeInsets.symmetric(horizontal: 3.5),
          width: active ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.item,
    required this.index,
    required this.compact,
    required this.pageController,
    required this.reducedMotion,
    required this.intro,
  });

  final _OnboardingItem item;
  final int index;
  final bool compact;
  final PageController pageController;
  final bool reducedMotion;

  /// Whether this card's elements stagger in (first page, first showing).
  final bool intro;

  /// Gap between the card edge and the hero panel; the card corner is the
  /// hero corner plus this gap so the two curves stay concentric.
  static const double _inset = 10;

  Widget _enter(int step, Widget child) =>
      intro ? AppStagger(index: step, child: child) : child;

  Widget _shift({
    required Widget child,
    double distance = 26,
    double fade = 0,
    double shrink = 0,
  }) {
    return _PageShift(
      controller: pageController,
      index: index,
      enabled: !reducedMotion,
      distance: distance,
      fade: fade,
      shrink: shrink,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = AppDecor.of(context);
    const radius = AppRadii.xl + _inset;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
        boxShadow: decor.cardShadow,
      ),
      // The card always keeps its full rounded outline; anything that does
      // not fit scrolls inside it instead of pushing past the bottom edge.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide =
                constraints.maxWidth >= 520 && constraints.maxHeight < 380;

            final hero = _enter(
              1,
              _OnboardingHero(
                icon: item.icon,
                variant: index,
                wrapMedallion: (medallion) =>
                    _shift(child: medallion, distance: 44, shrink: 0.14),
              ),
            );

            final copy = _shift(
              fade: 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _enter(
                    2,
                    Text(
                      tr(context, item.title),
                      style:
                          (compact
                                  ? theme.textTheme.titleLarge
                                  : theme.textTheme.headlineSmall)
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _enter(
                    3,
                    Text(
                      tr(context, item.subtitle),
                      style:
                          (compact
                                  ? theme.textTheme.bodyMedium
                                  : theme.textTheme.bodyLarge)
                              ?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                    ),
                  ),
                  SizedBox(height: compact ? 14 : 18),
                  for (var i = 0; i < item.highlights.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i == item.highlights.length - 1 ? 0 : 8,
                      ),
                      child: _enter(
                        4 + i,
                        _HighlightRow(
                          text: item.highlights[i],
                          accent: decor.accentAt(index + i),
                        ),
                      ),
                    ),
                ],
              ),
            );

            if (sideBySide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      _inset,
                      _inset,
                      0,
                      _inset,
                    ),
                    child: SizedBox(
                      width: (constraints.maxWidth * 0.34).clamp(170.0, 300.0),
                      child: hero,
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        20,
                        16,
                        20,
                        16,
                      ),
                      child: copy,
                    ),
                  ),
                ],
              );
            }

            final heroHeight = (constraints.maxHeight * 0.32).clamp(
              112.0,
              300.0,
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.all(_inset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: heroHeight, child: hero),
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      compact ? 8 : 14,
                      compact ? 18 : 24,
                      compact ? 8 : 14,
                      compact ? 8 : 14,
                    ),
                    child: copy,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Emerald illustration panel: star lattice, halo rings and a gold medallion
/// carrying the page's icon.
class _OnboardingHero extends StatelessWidget {
  const _OnboardingHero({
    required this.icon,
    required this.variant,
    required this.wrapMedallion,
  });

  final IconData icon;
  final int variant;
  final Widget Function(Widget medallion) wrapMedallion;

  @override
  Widget build(BuildContext context) {
    final decor = AppDecor.of(context);
    final gold = decor.gold;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return ExcludeSemantics(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: decor.heroGradient,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: gold.withValues(alpha: 0.22)),
          boxShadow: decor.floatShadow,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shortest = math.min(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final medallion = (shortest * 0.54).clamp(52.0, 136.0);
            return Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _HeroMotifPainter(
                        color: gold,
                        medallion: medallion,
                        variant: variant,
                        rtl: rtl,
                      ),
                    ),
                  ),
                ),
                wrapMedallion(
                  Container(
                    width: medallion,
                    height: medallion,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: gold.withValues(alpha: 0.1),
                      border: Border.all(color: gold.withValues(alpha: 0.34)),
                    ),
                    child: Container(
                      width: medallion * 0.76,
                      height: medallion * 0.76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: AlignmentDirectional.topStart,
                          end: AlignmentDirectional.bottomEnd,
                          colors: [
                            gold.withValues(alpha: 0.34),
                            gold.withValues(alpha: 0.1),
                          ],
                        ),
                        border: Border.all(
                          color: gold.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(icon, size: medallion * 0.4, color: gold),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroMotifPainter extends CustomPainter {
  const _HeroMotifPainter({
    required this.color,
    required this.medallion,
    required this.variant,
    required this.rtl,
  });

  final Color color;
  final double medallion;
  final int variant;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final center = size.center(Offset.zero);

    // Corner light on the trailing edge, as on the home hero.
    final cornerCenter = Offset(
      size.width * (rtl ? 0.1 : 0.9),
      size.height * 0.06,
    );
    final cornerRadius = size.shortestSide * 1.05;
    canvas.drawCircle(
      cornerCenter,
      cornerRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0)],
        ).createShader(
          Rect.fromCircle(center: cornerCenter, radius: cornerRadius),
        ),
    );

    // Eight-point star lattice, the classic Islamic geometric tile.
    final lattice = Paint()
      ..color = color.withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const cell = 44.0;
    const half = cell / 2;
    const inner = half * 0.42;
    for (var y = -half; y < size.height + cell; y += cell) {
      for (var x = -half; x < size.width + cell; x += cell) {
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
        canvas.drawPath(path, lattice);
      }
    }

    // Warm halo that lifts the medallion off the lattice.
    final haloRadius = medallion * 1.25;
    canvas.drawCircle(
      center,
      haloRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.26), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: haloRadius)),
    );

    // Rosette: two squares forming an eight-point star behind the medallion.
    final rosette = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeJoin = StrokeJoin.round;
    final rosetteRadius = medallion * 0.74;
    final tilt = variant * math.pi / 12;
    for (final turn in [0.0, math.pi / 4]) {
      final path = Path();
      for (var corner = 0; corner < 4; corner++) {
        final angle = tilt + turn + corner * math.pi / 2;
        final point =
            center +
            Offset(math.cos(angle), math.sin(angle)) * rosetteRadius;
        if (corner == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path..close(), rosette);
    }

    // Orbit rings with a few gold beads.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final orbit = medallion * 0.92;
    canvas.drawCircle(
      center,
      orbit,
      ring..color = color.withValues(alpha: 0.2),
    );
    canvas.drawCircle(
      center,
      medallion * 1.16,
      ring..color = color.withValues(alpha: 0.1),
    );
    final bead = Paint()..color = color.withValues(alpha: 0.85);
    for (var i = 0; i < 3; i++) {
      final angle = variant * 0.9 + i * (math.pi * 2 / 3) - math.pi / 5;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * orbit,
        i == 0 ? 3.2 : 2.2,
        bead,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeroMotifPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.medallion != medallion ||
      oldDelegate.variant != variant ||
      oldDelegate.rtl != rtl;
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({required this.text, required this.accent});

  final String text;
  final AppAccent accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 14, 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [
                    accent.background,
                    Color.lerp(accent.background, accent.foreground, 0.22) ??
                        accent.background,
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadii.sm - 2),
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: accent.foreground,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr(context, text),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ties [child] to the [PageView] scroll: as the page leaves the centre the
/// child drifts a little further, shrinks and fades, so neighbouring pages
/// cross-fade instead of sliding as flat slabs. Disabled for reduced motion.
class _PageShift extends StatelessWidget {
  const _PageShift({
    required this.controller,
    required this.index,
    required this.enabled,
    required this.child,
    this.distance = 26,
    this.fade = 0,
    this.shrink = 0,
  });

  final PageController controller;
  final int index;
  final bool enabled;
  final Widget child;
  final double distance;
  final double fade;
  final double shrink;

  double _delta() {
    if (!controller.hasClients) {
      return 0;
    }
    final position = controller.position;
    if (!position.haveDimensions) {
      return 0;
    }
    final page = controller.page ?? index.toDouble();
    return (page - index).clamp(-1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final delta = _delta();
        final away = delta.abs();
        // Positive when this page sits after the current one.
        final towardsEnd = -delta * distance;
        return Opacity(
          opacity: (1 - away * fade).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(rtl ? -towardsEnd : towardsEnd, 0),
            child: Transform.scale(scale: 1 - away * shrink, child: child),
          ),
        );
      },
    );
  }
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.highlights,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> highlights;
}
