import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/reader_localization.dart';

import '../../domain/models/reader_settings.dart';

import '../controllers/quran_reader_controller.dart';

enum ReaderMoreAction {
  dashboard,
  growthHub,
  insights,
  audio,
  aiStudio,
  pageStrip,
  compare,
  manualPins,
  pageReport,
  kanzulStudy,
  settings,
}

class ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ReaderAppBar({
    super.key,
    required this.controller,
    required this.portraitMode,
    required this.onOpenSearch,
    required this.onOpenDashboard,
    required this.onOpenGrowthHub,
    required this.onOpenInsights,
    required this.onOpenAudio,
    required this.onOpenAiStudio,
    required this.onOpenPageStrip,
    required this.onOpenCompare,
    required this.onOpenKanzulStudy,
    required this.onOpenSettings,
    this.onOpenManualPins,
    this.onOpenPageReport,
    this.onToggleFullscreen,
    this.bottom,
  });

  final QuranReaderController controller;
  final bool portraitMode;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenDashboard;
  final VoidCallback onOpenGrowthHub;
  final VoidCallback onOpenInsights;
  final VoidCallback onOpenAudio;
  final VoidCallback onOpenAiStudio;
  final VoidCallback onOpenPageStrip;
  final VoidCallback onOpenCompare;
  final VoidCallback onOpenKanzulStudy;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenManualPins;
  final VoidCallback? onOpenPageReport;
  final VoidCallback? onToggleFullscreen;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
    (portraitMode ? 88 : 76) + (bottom == null ? 0 : bottom!.preferredSize.height + 7),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final compact = size.width < 420 || size.height < 720;
    final decor = AppDecor.of(context);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 8 : 12,
          compact ? 6 : 8,
          compact ? 8 : 12,
          0,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.7),
            ),
            boxShadow: decor.floatShadow,
          ),
          child: Padding(
            // Buttons carry their own 48dp touch area, so the card padding
            // stays small and the visible pills still sit on a 10/12dp gutter.
            padding: EdgeInsetsDirectional.fromSTEB(
              compact ? 6 : 10,
              compact ? 4 : 6,
              compact ? 6 : 10,
              compact ? 4 : 6,
            ),
            child: Column(children: [
              Expanded(child: Row(
              children: [
                IconButton(
                  tooltip: tr(context, 'Back'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: _PillFace(
                    icon: Icons.arrow_back_rounded,
                    compact: compact,
                  ),
                ),
                SizedBox(width: compact ? 6 : 12),
                if (size.width >= 600) ...[
                  Container(
                    width: 1,
                    height: 30,
                    color: theme.colorScheme.secondary.withValues(alpha: 0.36),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: controller.pageListenable,
                    builder: (context, _, __) {
                      final secondaryLabel = portraitMode
                          ? controller.pageProgressLabel
                          : controller.spreadProgressLabel;
                      final title = controller.currentChapterSummary?.nameSimple ?? 'Quran Reader';

                      final progressText = tr(context, secondaryLabel);
                      final editionText = tr(context, controller.settings.preferImageMode ? controller.settings.mushafEdition.label : 'Arabic text');
                      final detailStyle = theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      );
                      final textScaler = MediaQuery.textScalerOf(context);

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final detail = '$progressText • $editionText';
                          final painter = TextPainter(
                            text: TextSpan(text: detail, style: detailStyle),
                            textDirection: Directionality.of(context),
                            textScaler: textScaler,
                            maxLines: 1,
                          )..layout();
                          // On phones the four actions leave little room: give
                          // the page and edition a line each instead of cutting
                          // the edition off, as long as both lines still fit.
                          final stackDetail = portraitMode &&
                              painter.width > constraints.maxWidth &&
                              textScaler.scale(1) <= 1.3;
                          painter.dispose();

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr(context, title),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: (portraitMode
                                        ? theme.textTheme.titleMedium
                                        : theme.textTheme.titleLarge)
                                    ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              SizedBox(height: stackDetail ? 1 : 2),
                              if (stackDetail) ...[
                                Text(
                                  progressText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: detailStyle,
                                ),
                                Text(
                                  editionText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: detailStyle,
                                ),
                              ] else
                                Text(
                                  detail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: detailStyle,
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                SizedBox(width: compact ? 4 : 8),
                if (onToggleFullscreen != null) ...[
                  ReaderFullscreenButton(
                    fullscreenReading: controller.settings.fullscreenReading,
                    onPressed: onToggleFullscreen!,
                    compact: compact,
                  ),
                ],
                _ActionPill(
                  icon: controller.settings.pageNightMode
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  tooltip: tr(context, controller.settings.pageNightMode
                      ? 'Use light Quran page'
                      : 'Use dark Quran page'),
                  onPressed: () => controller.togglePageNightMode(
                    !controller.settings.pageNightMode,
                  ),
                  compact: compact,
                ),
                _ActionPill(
                  icon: Icons.search_rounded,
                  tooltip: tr(context, 'Search'),
                  onPressed: onOpenSearch,
                  compact: compact,
                ),
                PopupMenuButton<ReaderMoreAction>(
                  tooltip: tr(context, 'More'),
                  padding: EdgeInsets.zero,
                  position: PopupMenuPosition.under,
                  onSelected: (value) {
                    switch (value) {
                      case ReaderMoreAction.dashboard:
                        onOpenDashboard();
                        break;
                      case ReaderMoreAction.growthHub:
                        onOpenGrowthHub();
                        break;
                      case ReaderMoreAction.insights:
                        onOpenInsights();
                        break;
                      case ReaderMoreAction.audio:
                        onOpenAudio();
                        break;
                      case ReaderMoreAction.aiStudio:
                        onOpenAiStudio();
                        break;
                      case ReaderMoreAction.pageStrip:
                        onOpenPageStrip();
                        break;
                      case ReaderMoreAction.compare:
                        onOpenCompare();
                        break;
                      case ReaderMoreAction.kanzulStudy:
                        onOpenKanzulStudy();
                        break;
                      case ReaderMoreAction.settings:
                        onOpenSettings();
                        break;
                      case ReaderMoreAction.pageReport:
                        onOpenPageReport?.call();
                        break;
                      case ReaderMoreAction.manualPins:
                        onOpenManualPins?.call();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: ReaderMoreAction.dashboard,
                      child: _MenuRow(
                        icon: Icons.dashboard_customize_outlined,
                        label: tr(context, 'Dashboard'),
                      ),
                    ),
                    if (controller.isPlansPacksEnabled)
                      PopupMenuItem(
                        value: ReaderMoreAction.growthHub,
                        child: _MenuRow(
                          icon: Icons.insights_outlined,
                          label: tr(context, 'Plans & Packs'),
                        ),
                      ),
                    if (controller.isInsightsEnabled)
                      PopupMenuItem(
                        value: ReaderMoreAction.insights,
                        child: _MenuRow(
                          icon: Icons.auto_stories_outlined,
                          label: tr(context, 'Insights'),
                        ),
                      ),
                    if (controller.isAudioEnabled)
                      PopupMenuItem(
                        value: ReaderMoreAction.audio,
                        child: _MenuRow(
                          icon: Icons.headphones_rounded,
                          label: tr(context, 'Audio'),
                        ),
                      ),
                    if (controller.isAiStudioEnabled)
                      PopupMenuItem(
                        value: ReaderMoreAction.aiStudio,
                        child: _MenuRow(
                          icon: Icons.auto_awesome_rounded,
                          label: tr(context, 'AI Studio'),
                        ),
                      ),
                    if (controller.isPageStripEnabled)
                      PopupMenuItem(
                        value: ReaderMoreAction.pageStrip,
                        child: _MenuRow(
                          icon: Icons.photo_library_outlined,
                          label: tr(context, 'Pages'),
                        ),
                      ),
                    if (controller.isCompareEnabled)
                      PopupMenuItem(
                        value: ReaderMoreAction.compare,
                        child: _MenuRow(
                          icon: Icons.compare_rounded,
                          label: tr(context, 'Compare'),
                        ),
                      ),
                    if (controller.isKanzulStudyEnabled)
                      PopupMenuItem(
                        value: ReaderMoreAction.kanzulStudy,
                        child: _MenuRow(
                          icon: Icons.translate_rounded,
                          label: tr(context, 'Kanzul study'),
                        ),
                      ),
                    if (onOpenPageReport != null) PopupMenuItem(
                      value: ReaderMoreAction.pageReport,
                      child: _MenuRow(icon: Icons.flag_outlined,
                        label: switch (ReaderLocalizationScope.of(context).language) {
                          ReaderLanguage.urdu => 'صفحے کے مسئلے کی اطلاع',
                          ReaderLanguage.arabic => 'الإبلاغ عن مشكلة في الصفحة',
                          _ => 'Report a page problem',
                        }),
                    ),
                    if (onOpenManualPins != null) PopupMenuItem(
                      value: ReaderMoreAction.manualPins,
                      child: _MenuRow(icon: Icons.add_location_alt_outlined,
                          label: tr(context, 'Manual notes and mistake pins')),
                    ),
                    PopupMenuItem(
                      value: ReaderMoreAction.settings,
                      child: _MenuRow(
                        icon: Icons.tune_rounded,
                        label: tr(context, 'Settings'),
                      ),
                    ),
                  ],
                  child: _MorePill(compact: compact),
                ),
              ],
              )),
              if (bottom != null)
                SizedBox(
                  height: bottom!.preferredSize.height + 7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(border: Border(top: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
                    ))),
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        top: 6,
                        start: compact ? 6 : 8,
                        end: compact ? 6 : 8,
                      ),
                      child: bottom!,
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class ReaderFullscreenButton extends StatelessWidget {
  const ReaderFullscreenButton({
    super.key,
    required this.fullscreenReading,
    required this.onPressed,
    this.compact = true,
    this.showLabel = false,
  });

  final bool fullscreenReading;
  final VoidCallback onPressed;
  final bool compact;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final icon = fullscreenReading ? Icons.fullscreen_exit : Icons.fullscreen;
    final label = switch (ReaderLocalizationScope.of(context).language) {
      ReaderLanguage.urdu => fullscreenReading ? 'پوری اسکرین بند کریں' : 'پوری اسکرین',
      ReaderLanguage.arabic => fullscreenReading ? 'إنهاء ملء الشاشة' : 'ملء الشاشة',
      _ => fullscreenReading ? 'Exit fullscreen' : 'Full screen',
    };
    if (showLabel) {
      return FilledButton.tonalIcon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
        icon: Icon(icon, size: compact ? 20 : 22),
        label: Text(label),
      );
    }
    return _ActionPill(icon: icon, tooltip: label, onPressed: onPressed, compact: compact);
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.compact,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: _PillFace(icon: icon, compact: compact),
        ),
      ),
    );
  }
}

class _MorePill extends StatelessWidget {
  const _MorePill({
    required this.compact,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _PillFace(
      icon: Icons.more_horiz_rounded,
      compact: compact,
      outlined: true,
    );
  }
}

/// A 48dp touch area with a smaller rounded pill drawn inside it, so the bar
/// keeps comfortable targets without crowding the title on narrow phones.
class _PillFace extends StatelessWidget {
  const _PillFace({
    required this.icon,
    required this.compact,
    this.outlined = false,
  });

  final IconData icon;
  final bool compact;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final face = compact ? 40.0 : 44.0;
    return SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: Container(
          width: face,
          height: face,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: outlined
                ? Border.all(color: theme.dividerColor.withValues(alpha: 0.8))
                : null,
          ),
          child: Icon(
            icon,
            size: compact ? 20 : 22,
            color: outlined
                ? theme.colorScheme.onSurface
                : theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            tr(context, label),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Shared header for the reader's bottom sheets: drag handle, title, optional
/// subtitle and a close button. [title] and [subtitle] are shown as given, so
/// pass them already localized.
class ReaderSheetHeader extends StatelessWidget {
  const ReaderSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showHandle = true,
  });

  final String title;
  final String? subtitle;

  /// True when shown inside a modal sheet: draws the drag handle and the close
  /// button. Full-screen hosts pass false and keep their own back navigation.
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHandle)
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (showHandle) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: tr(context, 'Close'),
                onPressed: () => Navigator.of(context).maybePop(),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerLow,
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
                icon: const Icon(Icons.close_rounded, size: 22),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The surface used for a section inside a reader sheet.
class ReaderSheetCard extends StatelessWidget {
  const ReaderSheetCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.highlighted = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Draws the border in the primary colour, for the selected card of a set.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppDecor.of(context).cardShadow,
        border: Border.all(
          color: highlighted
              ? theme.colorScheme.primary.withValues(alpha: 0.55)
              : theme.dividerColor.withValues(alpha: 0.7),
          width: highlighted ? 1.4 : 1,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Small rounded icon badge in one of the theme's accent pairs, matching the
/// feature tiles on the home screen. Index 1 is the gold pair.
class ReaderAccentBadge extends StatelessWidget {
  const ReaderAccentBadge({
    super.key,
    required this.icon,
    this.accentIndex = 1,
    this.size = 40,
  });

  final IconData icon;
  final int accentIndex;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = AppDecor.of(context).accentAt(accentIndex);
    return Container(
      width: size,
      height: size,
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
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: accent.foreground, size: size * 0.54),
    );
  }
}

/// Compact icon + label pill for read-only status inside reader sheets.
class ReaderInfoPill extends StatelessWidget {
  const ReaderInfoPill({super.key, required this.icon, required this.label});

  final IconData icon;

  /// Shown as given, so pass it already localized.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
