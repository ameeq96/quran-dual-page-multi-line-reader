import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';

/// Emerald hero header shared by the secondary screens and sheets.
///
/// Carries an optional back button, a gold icon badge, an eyebrow, the page
/// title, a subtitle and trailing action buttons. Every colour comes from
/// [AppDecor], so it reads the same in light and dark themes, and the layout
/// falls back to a stacked arrangement when the title would be squeezed
/// (narrow phones, large text).
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.icon,
    this.onBack,
    this.backTooltip,
    this.actions = const <Widget>[],
    this.compact = false,
    this.bottom,
  });

  /// Page title, already localized by the caller.
  final String title;

  /// Small gold label above the title.
  final String? eyebrow;

  /// Supporting line under the title.
  final String? subtitle;

  /// Glyph shown in the gold badge.
  final IconData? icon;

  /// Shows a back button when non-null.
  final VoidCallback? onBack;

  /// Overrides the platform back tooltip (for app-localized text).
  final String? backTooltip;

  /// Trailing buttons. Plain [IconButton]s are restyled for the hero surface.
  final List<Widget> actions;

  /// Single-row variant for screens where vertical room matters.
  final bool compact;

  /// Extra content placed under the text block, on the hero surface.
  final Widget? bottom;

  /// A back callback that mirrors what a Material app bar would offer: null
  /// when the enclosing route cannot be dismissed, otherwise a `maybePop`.
  static VoidCallback? popAction(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route == null || !route.impliesAppBarDismissal) {
      return null;
    }
    final navigator = Navigator.of(context);
    return () => navigator.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = AppDecor.of(context);
    final onHero = decor.onHero;
    final gold = decor.gold;
    final direction = Directionality.of(context);
    final isLtr = direction == TextDirection.ltr;
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8);

    final buttonStyle = IconButton.styleFrom(
      foregroundColor: onHero,
      disabledForegroundColor: onHero.withValues(alpha: 0.38),
      backgroundColor: onHero.withValues(alpha: 0.1),
      disabledBackgroundColor: onHero.withValues(alpha: 0.05),
      highlightColor: gold.withValues(alpha: 0.18),
      minimumSize: const Size(48, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: BorderSide(color: gold.withValues(alpha: 0.28)),
      ),
    );

    final Widget? backButton = onBack == null
        ? null
        : IconButton(
            style: buttonStyle,
            tooltip:
                backTooltip ??
                MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: onBack,
            // Mirrors automatically under RTL (matchTextDirection).
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
          );

    final badgeSize = compact ? 42.0 : 48.0;
    final Widget? badge = icon == null
        ? null
        : ExcludeSemantics(
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadii.sm + 2),
                border: Border.all(color: gold.withValues(alpha: 0.34)),
              ),
              child: Icon(icon, color: gold, size: compact ? 22 : 24),
            ),
          );

    final titleStyle =
        (compact ? theme.textTheme.titleLarge : theme.textTheme.headlineSmall)
            ?.copyWith(color: onHero, fontWeight: FontWeight.w700);

    final Widget texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eyebrow != null && eyebrow!.isNotEmpty) ...[
          Text(
            // Eyebrows are set as tracked capitals wherever the script has
            // case, so every screen's label reads the same.
            isLtr ? eyebrow!.toUpperCase() : eyebrow!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: gold,
              fontWeight: FontWeight.w700,
              // Tracking breaks the joins of Arabic-script text.
              letterSpacing: isLtr ? 1.4 : 0,
            ),
          ),
          SizedBox(height: compact ? 2 : 6),
        ],
        Semantics(
          header: true,
          child: Text(title, style: titleStyle),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          SizedBox(height: compact ? 2 : 6),
          Text(
            subtitle!,
            style:
                (compact
                        ? theme.textTheme.bodySmall
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(color: onHero.withValues(alpha: 0.8)),
          ),
        ],
      ],
    );

    final padding = compact ? 14.0 : 20.0;

    Widget stacked({required bool withBadge}) {
      final hasBar = backButton != null || actions.isNotEmpty;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasBar) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (backButton != null) backButton,
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: actions,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 10 : 14),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (withBadge && badge != null) ...[
                badge,
                const SizedBox(width: 14),
              ],
              Expanded(child: texts),
            ],
          ),
        ],
      );
    }

    Widget inline({required bool withBadge}) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (backButton != null) ...[backButton, const SizedBox(width: 12)],
          if (withBadge && badge != null) ...[badge, const SizedBox(width: 12)],
          Expanded(child: texts),
          for (final action in actions) ...[const SizedBox(width: 8), action],
        ],
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: decor.heroGradient,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: gold.withValues(alpha: 0.22)),
        boxShadow: decor.floatShadow,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: _HeaderMotif(color: gold, direction: direction),
                ),
              ),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: IconButtonTheme(
              data: IconButtonThemeData(style: buttonStyle),
              child: IconTheme.merge(
                data: IconThemeData(color: onHero),
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Width the title keeps once the fixed parts are placed.
                      double textRoom({required bool withBadge}) {
                        var fixed = actions.length * 56.0;
                        if (backButton != null) {
                          fixed += 60;
                        }
                        if (withBadge && badge != null) {
                          fixed += badgeSize + 12;
                        }
                        return constraints.maxWidth - fixed;
                      }

                      final needed = 150 * textScale;
                      final narrow = constraints.maxWidth < 300;
                      Widget head;
                      if (!compact) {
                        head = stacked(withBadge: !narrow);
                      } else if (textRoom(withBadge: true) >= needed) {
                        head = inline(withBadge: true);
                      } else if (textRoom(withBadge: false) >= needed) {
                        head = inline(withBadge: false);
                      } else {
                        head = stacked(withBadge: !narrow);
                      }
                      if (bottom == null) {
                        return head;
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          head,
                          SizedBox(height: compact ? 12 : 16),
                          DefaultTextStyle.merge(
                            style: TextStyle(color: onHero),
                            child: bottom!,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Eight-point star lattice with a soft glow in the top-end corner, matching
/// the home screen hero.
class _HeaderMotif extends CustomPainter {
  const _HeaderMotif({required this.color, required this.direction});

  final Color color;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final glowX = direction == TextDirection.ltr
        ? size.width * 0.9
        : size.width * 0.1;
    final glowCenter = Offset(glowX, size.height * 0.08);
    final glowRadius = (size.shortestSide * 1.3).clamp(90.0, 260.0);
    canvas.drawCircle(
      glowCenter,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: glowRadius)),
    );

    final stroke = Paint()
      ..color = color.withValues(alpha: 0.08)
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
        canvas.drawPath(path, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeaderMotif oldDelegate) =>
      oldDelegate.color != color || oldDelegate.direction != direction;
}
