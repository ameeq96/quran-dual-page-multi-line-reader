import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../app/app_theme.dart';
import '../../../../../app/reader_localization.dart';
import '../../../domain/models/reader_settings.dart';
import '../app_motion.dart';
import 'home_hero_card.dart';

const List<FontFeature> _figures = <FontFeature>[FontFeature.tabularFigures()];

/// Resting card surface shared by the calmer home sections.
class HomeSurfaceCard extends StatelessWidget {
  const HomeSurfaceCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
        boxShadow: AppDecor.of(context).cardShadow,
      ),
      child: child,
    );
  }
}

/// Emerald logo tile with a fine gold inner frame.
class HomeLogoBadge extends StatelessWidget {
  const HomeLogoBadge({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) {
    final decor = AppDecor.of(context);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        gradient: decor.heroGradient,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: decor.cardShadow,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.md - 3),
          border: Border.all(color: decor.gold.withValues(alpha: 0.45)),
        ),
        child: Icon(
          Icons.menu_book_rounded,
          color: decor.gold,
          size: size * 0.48,
        ),
      ),
    );
  }
}

/// A khatam star flanked by hairlines that fade out: a quiet ornamental rule.
class HomeOrnamentDivider extends StatelessWidget {
  const HomeOrnamentDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    Widget line(AlignmentGeometry begin, AlignmentGeometry end) => Expanded(
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: end,
            colors: [color.withValues(alpha: 0.5), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
    return ExcludeSemantics(
      child: Row(
        children: [
          HomeKhatamMark(size: 12, color: color),
          const SizedBox(width: 4),
          HomeKhatamMark(size: 7, color: color.withValues(alpha: 0.6)),
          const SizedBox(width: 10),
          line(AlignmentDirectional.centerStart, AlignmentDirectional.centerEnd),
        ],
      ),
    );
  }
}

/// A small filled eight-point star.
class HomeKhatamMark extends StatelessWidget {
  const HomeKhatamMark({super.key, required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _KhatamPainter(color: color, filled: true),
    );
  }
}

class _KhatamPainter extends CustomPainter {
  const _KhatamPainter({required this.color, this.filled = false});
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    if (filled) {
      canvas.drawPath(
        homeKhatamPath(center, radius, inset: 0.62),
        Paint()..color = color,
      );
      return;
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawPath(homeKhatamPath(center, radius), stroke);
    canvas.drawPath(homeKhatamPath(center, radius * 0.66), stroke);
    canvas.drawCircle(center, radius * 1.24, stroke);
  }

  @override
  bool shouldRepaint(covariant _KhatamPainter old) =>
      old.color != color || old.filled != filled;
}

/// Outlined khatam used as a faint corner watermark on cards.
class _CornerKhatam extends StatelessWidget {
  const _CornerKhatam({
    required this.size,
    required this.color,
    this.bottom = false,
  });
  final double size;
  final Color color;
  final bool bottom;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      top: bottom ? null : -size * 0.42,
      bottom: bottom ? -size * 0.42 : null,
      end: -size * 0.42,
      child: IgnorePointer(
        child: CustomPaint(
          size: Size.square(size),
          painter: _KhatamPainter(color: color),
        ),
      ),
    );
  }
}

class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, title),
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr(context, subtitle),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        const HomeOrnamentDivider(),
      ],
    );
  }
}

/// Mushaf edition picker: a single scrolling row of pills with soft fade
/// edges, plus the app theme toggle.
class HomeEditionSelector extends StatefulWidget {
  const HomeEditionSelector({
    super.key,
    required this.editions,
    required this.selectedEdition,
    required this.isEditionReady,
    required this.isEditionDownloading,
    required this.downloadProgressForEdition,
    required this.onSelectEdition,
    required this.onDownloadEdition,
    required this.nightMode,
    required this.onToggleNightMode,
  });

  final List<MushafEdition> editions;
  final MushafEdition selectedEdition;
  final bool Function(MushafEdition edition) isEditionReady;
  final bool Function(MushafEdition edition) isEditionDownloading;
  final double Function(MushafEdition edition) downloadProgressForEdition;
  final Future<void> Function(MushafEdition edition) onSelectEdition;
  final Future<void> Function(MushafEdition edition) onDownloadEdition;
  final bool nightMode;
  final Future<void> Function(bool enabled) onToggleNightMode;

  @override
  State<HomeEditionSelector> createState() => _HomeEditionSelectorState();
}

class _HomeEditionSelectorState extends State<HomeEditionSelector> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _selectedKey = GlobalKey();
  bool _fadeStart = false;
  bool _fadeEnd = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_syncFades);
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
  }

  @override
  void didUpdateWidget(covariant HomeEditionSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedEdition != widget.selectedEdition ||
        oldWidget.editions.length != widget.editions.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _revealSelected() {
    if (!mounted || !_scroll.hasClients) {
      return;
    }
    final target = _selectedKey.currentContext?.findRenderObject();
    final position = _scroll.position;
    if (target != null && position.maxScrollExtent > 0) {
      // Centre the active edition without animating: this runs on first
      // layout, so it must not look like the row is moving by itself.
      position.ensureVisible(target, alignment: 0.5);
    }
    _syncFades();
  }

  void _syncFades() {
    if (!mounted || !_scroll.hasClients) {
      return;
    }
    final position = _scroll.position;
    final start = position.pixels > 4;
    final end = position.pixels < position.maxScrollExtent - 4;
    if (start != _fadeStart || end != _fadeEnd) {
      setState(() {
        _fadeStart = start;
        _fadeEnd = end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final nightMode = widget.nightMode;

    final pills = <Widget>[
      for (final (index, edition) in widget.editions.indexed) ...[
        if (index > 0) const SizedBox(width: 8),
        _EditionPill(
          key: edition == widget.selectedEdition ? _selectedKey : null,
          label: tr(
            context,
            widget.isEditionDownloading(edition)
                ? '${edition.label} '
                      '${(widget.downloadProgressForEdition(edition) * 100).round()}%'
                : edition.label,
          ),
          selected: edition == widget.selectedEdition,
          ready: widget.isEditionReady(edition),
          downloadProgress: widget.isEditionDownloading(edition)
              ? widget.downloadProgressForEdition(edition)
              : null,
          onTap: () => widget.isEditionReady(edition)
              ? widget.onSelectEdition(edition)
              : widget.onDownloadEdition(edition),
        ),
      ],
    ];

    // Mask colours: only their alpha is used.
    final opaque = scheme.onSurface;
    final clear = scheme.onSurface.withValues(alpha: 0);
    return HomeSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 6, 2),
            child: Row(
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  color: scheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr(context, 'Choose your Mushaf'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: tr(
                    context,
                    nightMode ? 'Use light app theme' : 'Use dark app theme',
                  ),
                  onPressed: () => widget.onToggleNightMode(!nightMode),
                  icon: Icon(
                    nightMode
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              final startFade = rtl ? _fadeEnd : _fadeStart;
              final endFade = rtl ? _fadeStart : _fadeEnd;
              final edge = (36 / math.max(bounds.width, 1)).clamp(0.0, 0.4);
              return LinearGradient(
                colors: [
                  startFade ? clear : opaque,
                  opaque,
                  opaque,
                  endFade ? clear : opaque,
                ],
                stops: [0, edge, 1 - edge, 1],
              ).createShader(bounds);
            },
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 16, 16),
              child: Row(children: pills),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditionPill extends StatelessWidget {
  const _EditionPill({
    super.key,
    required this.label,
    required this.selected,
    required this.ready,
    required this.downloadProgress,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool ready;
  final double? downloadProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final decor = AppDecor.of(context);
    final foreground = selected
        ? decor.onHero
        : ready
        ? scheme.onSurface
        : scheme.onSurfaceVariant;
    final progress = downloadProgress;
    return Semantics(
      button: true,
      selected: selected,
      child: AppPressable(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: StadiumBorder(
              side: BorderSide(
                color: selected
                    ? decor.gold.withValues(alpha: 0.5)
                    : theme.dividerColor,
              ),
            ),
            gradient: selected ? decor.heroGradient : null,
            color: selected ? null : scheme.surfaceContainerLow,
            shadows: selected ? decor.cardShadow : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 16, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? decor.gold
                                    : ready
                                    ? scheme.primaryContainer
                                    : scheme.surface,
                                border: selected || ready
                                    ? null
                                    : Border.all(color: theme.dividerColor),
                              ),
                              child: Icon(
                                selected
                                    ? Icons.check_circle_outline_rounded
                                    : ready
                                    ? Icons.menu_book_outlined
                                    : Icons.download_outlined,
                                size: 17,
                                color: selected
                                    ? decor.onGold
                                    : ready
                                    ? scheme.onPrimaryContainer
                                    : scheme.primary,
                              ),
                            ),
                            if (progress != null)
                              CircularProgressIndicator(
                                value: progress <= 0 || progress >= 1
                                    ? 0
                                    : progress,
                                strokeWidth: 2.5,
                                color: scheme.primary,
                                backgroundColor: scheme.primaryContainer,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontFeatures: _figures,
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

/// One of the three index shortcuts under the hero.
class HomeQuickAction extends StatelessWidget {
  const HomeQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final decor = AppDecor.of(context);
    final caption = switch (label) {
      'Surah' => '114 chapters',
      'Juz' => '30 sections',
      _ => 'Find an ayah',
    };
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.7)),
    );
    return AppPressable(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: decor.cardShadow,
        ),
        child: Material(
          color: scheme.surface,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          scheme.secondaryContainer.withValues(alpha: 0.5),
                          scheme.secondaryContainer.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.7],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: decor.heroGradient,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: decor.gold.withValues(alpha: 0.55),
                            ),
                            boxShadow: decor.cardShadow,
                          ),
                          child: Icon(icon, color: decor.gold, size: 22),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr(context, label),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr(context, caption),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          fontFeatures: _figures,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Today's rhythm": daily target ring, page count and streak.
class HomeDailyFocusCard extends StatelessWidget {
  const HomeDailyFocusCard({
    super.key,
    required this.pages,
    required this.completedPages,
    required this.streakDays,
    required this.compact,
    required this.onTap,
  });

  final int pages;
  final int completedPages;
  final int streakDays;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final progress = pages <= 0
        ? 0.0
        : (completedPages / pages).clamp(0.0, 1.0);
    final ringSize = compact ? 76.0 : 92.0;

    final ring = SizedBox(
      width: ringSize,
      height: ringSize,
      child: Semantics(
        label: tr(context, "Today's rhythm"),
        value: '${(progress * 100).round()}%',
        child: ExcludeSemantics(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: reduced ? progress : 0, end: progress),
            duration: reduced ? Duration.zero : homeProgressFill,
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => CustomPaint(
              painter: _RingPainter(
                value: value,
                track: scheme.primaryContainer,
                start: scheme.primary,
                end: scheme.secondary,
              ),
              child: Center(
                child: Text(
                  '${(value * 100).round()}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                    fontFeatures: _figures,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final streak = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            color: scheme.onSecondaryContainer,
            size: 16,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              tr(
                context,
                '$streakDays ${tr(context, streakDays == 1 ? 'day' : 'days')} of consistency',
              ),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSecondaryContainer,
                fontFeatures: _figures,
              ),
            ),
          ),
        ],
      ),
    );

    return HomeSurfaceCard(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Stack(
          children: [
            _CornerKhatam(
              size: 132,
              color: scheme.secondary.withValues(alpha: 0.15),
              bottom: true,
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                compact ? 16 : 24,
                compact ? 8 : 16,
                compact ? 8 : 16,
                compact ? 16 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.wb_sunny_rounded,
                        color: scheme.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tr(context, "Today's rhythm"),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: tr(context, 'View reading dashboard'),
                        onPressed: onTap,
                        icon: const Icon(Icons.north_east_rounded, size: 18),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 4 : 16),
                  Row(
                    children: [
                      ring,
                      SizedBox(width: compact ? 16 : 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: tr(context, '$completedPages'),
                                    style: theme.textTheme.displaySmall
                                        ?.copyWith(
                                          color: scheme.onSurface,
                                          height: 1,
                                          fontFeatures: _figures,
                                        ),
                                  ),
                                  TextSpan(
                                    text: tr(context, ' / $pages pages'),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontFeatures: _figures,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            streak,
                          ],
                        ),
                      ),
                      SizedBox(width: compact ? 8 : 0),
                    ],
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 16),
                    Text(
                      tr(context, 'Small steps make a beautiful habit.'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.track,
    required this.start,
    required this.end,
  });

  final double value;
  final Color track;
  final Color start;
  final Color end;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, paint..color = track);
    final v = value.clamp(0.0, 1.0);
    if (v <= 0) {
      return;
    }
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 2);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi * v,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [start, Color.lerp(start, end, 0.85) ?? end, start],
          stops: const [0, 0.92, 1],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value ||
      old.track != track ||
      old.start != start ||
      old.end != end;
}

/// Lays tiles out in equal-height rows without a fixed row extent, so long
/// translations and large text never overflow.
class HomeTileGrid extends StatelessWidget {
  const HomeTileGrid({
    super.key,
    required this.columns,
    required this.children,
    this.spacing = 12,
  });

  final int columns;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += columns) {
      final end = math.min(start + columns, children.length);
      if (rows.isNotEmpty) {
        rows.add(SizedBox(height: spacing));
      }
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A short last row shares the full width instead of leaving
              // empty cells behind.
              for (var i = start; i < end; i++) ...[
                if (i > start) SizedBox(width: spacing),
                Expanded(child: children[i]),
              ],
            ],
          ),
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

/// A feature entry on the home screen. Rendered either as a regular tile or,
/// with [featured], as a larger illustrated card.
class HomeMenuTile extends StatelessWidget {
  const HomeMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accentIndex = 0,
    this.horizontal = false,
    this.featured = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int accentIndex;
  final bool horizontal;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final decor = AppDecor.of(context);
    final accent = decor.accentAt(accentIndex);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final chevron = rtl
        ? Icons.chevron_left_rounded
        : Icons.chevron_right_rounded;
    final radius = BorderRadius.circular(AppRadii.lg);

    final copy = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, title),
          style:
              (featured
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.titleSmall)
                  ?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          tr(context, subtitle),
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    final Widget body;
    if (featured) {
      body = Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [
                    accent.background.withValues(alpha: 0.95),
                    accent.background.withValues(alpha: 0.25),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _FeatureArtPainter(
                  color: accent.foreground,
                  rtl: rtl,
                  variant: accentIndex,
                ),
              ),
            ),
          ),
          PositionedDirectional(
            end: -16,
            bottom: -20,
            child: IgnorePointer(
              child: Icon(
                icon,
                size: 88,
                color: accent.foreground.withValues(alpha: 0.07),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.foreground,
                        borderRadius: BorderRadius.circular(AppRadii.sm + 2),
                        boxShadow: decor.cardShadow,
                      ),
                      child: Icon(icon, color: accent.background, size: 23),
                    ),
                    const Spacer(),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(chevron, size: 18, color: accent.foreground),
                    ),
                  ],
                ),
                SizedBox(height: horizontal ? 20 : 16),
                copy,
              ],
            ),
          ),
        ],
      );
    } else {
      final badge = Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              accent.background,
              Color.lerp(accent.background, accent.foreground, 0.2) ??
                  accent.background,
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadii.sm + 2),
        ),
        child: Icon(icon, color: accent.foreground, size: 23),
      );
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: horizontal
            ? Row(
                children: [
                  badge,
                  const SizedBox(width: 14),
                  Expanded(child: copy),
                  const SizedBox(width: 8),
                  Icon(chevron, size: 20, color: scheme.onSurfaceVariant),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [badge, const SizedBox(height: 12), copy],
              ),
      );
    }

    return AppPressable(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: decor.cardShadow,
        ),
        child: Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: featured
                  ? accent.foreground.withValues(alpha: 0.16)
                  : theme.dividerColor.withValues(alpha: 0.7),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: body),
        ),
      ),
    );
  }
}

/// Quiet line art in the far corner of a featured card. Each accent gets a
/// different figure so the four cards do not look stamped from one mould.
class _FeatureArtPainter extends CustomPainter {
  const _FeatureArtPainter({
    required this.color,
    required this.rtl,
    required this.variant,
  });

  final Color color;
  final bool rtl;
  final int variant;

  @override
  void paint(Canvas canvas, Size size) {
    final corner = Offset(rtl ? 0 : size.width, 0);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round;
    final unit = math.min(size.width, size.height);
    switch (variant % 4) {
      case 0:
        // Rippling arcs.
        for (var i = 1; i <= 4; i++) {
          canvas.drawCircle(
            corner,
            unit * 0.2 * i,
            stroke..color = color.withValues(alpha: 0.2 - i * 0.035),
          );
        }
      case 1:
        // Nested khatam stars.
        for (var i = 1; i <= 3; i++) {
          canvas.drawPath(
            homeKhatamPath(corner, unit * 0.24 * i),
            stroke..color = color.withValues(alpha: 0.22 - i * 0.045),
          );
        }
      case 2:
        // Diamond lattice.
        final step = unit * 0.17;
        for (var i = 1; i <= 4; i++) {
          final r = step * i;
          canvas.drawPath(
            Path()
              ..moveTo(corner.dx, corner.dy - r)
              ..lineTo(corner.dx + r, corner.dy)
              ..lineTo(corner.dx, corner.dy + r)
              ..lineTo(corner.dx - r, corner.dy)
              ..close(),
            stroke..color = color.withValues(alpha: 0.2 - i * 0.035),
          );
        }
      default:
        // Sound-wave rings, offset from the corner.
        final origin = corner + Offset(rtl ? unit * 0.12 : -unit * 0.12, 0);
        for (var i = 1; i <= 5; i++) {
          canvas.drawCircle(
            origin,
            unit * 0.14 * i,
            stroke
              ..strokeWidth = i.isEven ? 1 : 1.6
              ..color = color.withValues(alpha: 0.2 - i * 0.03),
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant _FeatureArtPainter old) =>
      old.color != color || old.rtl != rtl || old.variant != variant;
}
