import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';

class BootstrapSplash extends StatefulWidget {
  const BootstrapSplash({
    super.key,
    this.nightMode,
  });

  final bool? nightMode;

  @override
  State<BootstrapSplash> createState() => _BootstrapSplashState();
}

class _BootstrapSplashState extends State<BootstrapSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final compact = size.width < 420 || size.height < 760;
    final shortHeight = size.height < 700;
    final ultraCompact = size.height < 620;
    final useDark = widget.nightMode ?? false;
    final effectiveTheme = useDark ? AppTheme.dark() : AppTheme.light();

    return Theme(
      data: effectiveTheme,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);

          return Scaffold(
            body: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_controller.value);

                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.scaffoldBackgroundColor,
                        theme.colorScheme.surface,
                        theme.colorScheme.surfaceContainer
                            .withValues(alpha: 0.96),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -140,
                        left: -90,
                        child: _SplashOrb(
                          size: compact ? 240 : 320,
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          driftX: -14 + (t * 20),
                          driftY: -8 + (t * 16),
                        ),
                      ),
                      Positioned(
                        right: -120,
                        bottom: -140,
                        child: _SplashOrb(
                          size: compact ? 260 : 360,
                          color: theme.colorScheme.secondary
                              .withValues(alpha: 0.08),
                          driftX: 16 - (t * 18),
                          driftY: 12 - (t * 14),
                        ),
                      ),
                      SafeArea(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final outerPadding =
                                ultraCompact ? 14.0 : (compact ? 18.0 : 24.0);
                            final innerHorizontal =
                                ultraCompact ? 18.0 : (compact ? 22.0 : 28.0);
                            final innerTop =
                                ultraCompact ? 18.0 : (compact ? 24.0 : 30.0);
                            final innerBottom =
                                ultraCompact ? 16.0 : (compact ? 22.0 : 26.0);

                            return SingleChildScrollView(
                              padding: EdgeInsets.all(outerPadding),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: math.max(
                                    0,
                                    constraints.maxHeight - (outerPadding * 2),
                                  ),
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 540,
                                    ),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            theme.colorScheme.surface
                                                .withValues(
                                              alpha: 0.96,
                                            ),
                                            theme.colorScheme.surfaceContainer
                                                .withValues(alpha: 0.9),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          compact ? 30 : 36,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: theme.colorScheme.shadow
                                                .withValues(alpha: 0.12),
                                            blurRadius: compact ? 26 : 36,
                                            offset: const Offset(0, 18),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          innerHorizontal,
                                          innerTop,
                                          innerHorizontal,
                                          innerBottom,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _SplashHeader(
                                              compact: compact,
                                              pulseValue: t,
                                            ),
                                            SizedBox(
                                              height: ultraCompact
                                                  ? 12
                                                  : (compact ? 18 : 24),
                                            ),
                                            Text(
                                              'Quran Pak Dual Page Reader',
                                              textAlign: TextAlign.center,
                                              style: (ultraCompact
                                                      ? theme
                                                          .textTheme.titleLarge
                                                      : theme.textTheme
                                                          .headlineSmall)
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -0.7,
                                              ),
                                            ),
                                            SizedBox(
                                              height: ultraCompact ? 8 : 10,
                                            ),
                                            Text(
                                              'Preparing your Quran library, reading tools, and recitation workspace.',
                                              textAlign: TextAlign.center,
                                              style: (ultraCompact
                                                      ? theme
                                                          .textTheme.bodyMedium
                                                      : theme
                                                          .textTheme.bodyLarge)
                                                  ?.copyWith(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                                height:
                                                    shortHeight ? 1.35 : 1.45,
                                              ),
                                            ),
                                            SizedBox(
                                              height: ultraCompact
                                                  ? 14
                                                  : (compact ? 18 : 22),
                                            ),
                                            const Wrap(
                                              alignment: WrapAlignment.center,
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _SplashFeatureChip(
                                                  icon: Icons
                                                      .auto_stories_rounded,
                                                  label: 'Mushaf editions',
                                                ),
                                                _SplashFeatureChip(
                                                  icon: Icons.search_rounded,
                                                  label: 'Search and jump',
                                                ),
                                                _SplashFeatureChip(
                                                  icon:
                                                      Icons.headphones_rounded,
                                                  label: 'Recitation ready',
                                                ),
                                              ],
                                            ),
                                            SizedBox(
                                              height: ultraCompact
                                                  ? 16
                                                  : (compact ? 20 : 24),
                                            ),
                                            _LoadingRail(
                                              progress: _controller.value,
                                            ),
                                            SizedBox(
                                              height: ultraCompact
                                                  ? 12
                                                  : (compact ? 14 : 18),
                                            ),
                                            if (!ultraCompact) ...[
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: theme
                                                      .colorScheme.surface
                                                      .withValues(alpha: 0.6),
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
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
        },
      ),
    );
  }
}

class _SplashHeader extends StatelessWidget {
  const _SplashHeader({
    required this.compact,
    required this.pulseValue,
  });

  final bool compact;
  final double pulseValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = Color.lerp(
      theme.colorScheme.primary.withValues(alpha: 0.16),
      theme.colorScheme.secondary.withValues(alpha: 0.12),
      pulseValue,
    )!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  theme.dividerColor.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          width: compact ? 84 : 96,
          height: compact ? 84 : 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 26 : 30),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent,
                theme.colorScheme.surface.withValues(alpha: 0.32),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                blurRadius: 20 + (pulseValue * 6),
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: compact ? 36 : 42,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.dividerColor.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingRail extends StatelessWidget {
  const _LoadingRail({
    required this.progress,
  });

  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 12,
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final beamWidth = math.max(78.0, width * 0.28);
          final travel = math.max(0.0, width - beamWidth);
          final left = travel * Curves.easeInOut.transform(progress);

          return Stack(
            children: [
              Positioned(
                left: left,
                top: 1,
                bottom: 1,
                child: Container(
                  width: beamWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.2),
                        theme.colorScheme.primary.withValues(alpha: 0.9),
                        theme.colorScheme.secondary.withValues(alpha: 0.55),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.24),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SplashFeatureChip extends StatelessWidget {
  const _SplashFeatureChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashOrb extends StatelessWidget {
  const _SplashOrb({
    required this.size,
    required this.color,
    required this.driftX,
    required this.driftY,
  });

  final double size;
  final Color color;
  final double driftX;
  final double driftY;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.translate(
        offset: Offset(driftX, driftY),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color,
                color.withValues(alpha: 0.04),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
