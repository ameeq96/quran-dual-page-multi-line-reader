import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/quran_constants.dart';
import '../../domain/models/quran_page.dart';
import '../../domain/models/reader_settings.dart';
import '../models/reader_page_appearance.dart';
import 'placeholder_quran_page.dart';
import 'quran_page_image_provider.dart';
import 'reader_hifz_line_mask.dart';
import 'reader_skeleton.dart';

class MushafPageWidget extends StatelessWidget {
  const MushafPageWidget({
    super.key,
    required this.page,
    required this.settings,
    required this.showPageNumbers,
    this.smartHifzHiddenLines = const <int>{},
    this.smartHifzManualMaskAnchors = const <double>[],
    this.onSmartHifzManualMaskAnchorChanged,
    this.smartHifzRevealed = false,
    this.smartHifzEdition,
    this.smartHifzLineCount,
    this.alignment = Alignment.center,
    this.turnAmount = 0,
  });

  final QuranPage page;
  final ReaderSettings settings;
  final bool showPageNumbers;
  final Set<int> smartHifzHiddenLines;
  final List<double> smartHifzManualMaskAnchors;
  final void Function(int index, double nextAnchor)?
      onSmartHifzManualMaskAnchorChanged;
  final bool smartHifzRevealed;
  final MushafEdition? smartHifzEdition;
  final int? smartHifzLineCount;
  final AlignmentGeometry alignment;
  final double turnAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appearance = ReaderPageAppearance.resolve(
      theme: theme,
      settings: settings,
    );
    final isImagePage = page.contentType == QuranPageContentType.image;
    final clampedTurn = turnAmount.clamp(-1.0, 1.0);
    final useLiteFrame = settings.lowMemoryMode;
    final hingeAlignment =
        page.isLeftPage ? Alignment.centerRight : Alignment.centerLeft;
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(page.isLeftPage ? 20 : 28),
      bottomLeft: Radius.circular(page.isLeftPage ? 20 : 28),
      topRight: Radius.circular(page.isLeftPage ? 28 : 20),
      bottomRight: Radius.circular(page.isLeftPage ? 28 : 20),
    );
    final transform = useLiteFrame || clampedTurn.abs() < 0.001
        ? Matrix4.identity()
        : (Matrix4.identity()
          ..setEntry(3, 2, 0.0011)
          ..translateByDouble(
            page.isLeftPage ? clampedTurn * 10.0 : clampedTurn * 6.0,
            0.0,
            page.isLeftPage ? clampedTurn.abs() * -6 : clampedTurn.abs() * -4,
            1.0,
          )
          ..rotateY(
            page.isLeftPage ? clampedTurn * 0.14 : clampedTurn * 0.1,
          ));

    return RepaintBoundary(
      child: Align(
        alignment: alignment,
        child: Transform(
          alignment: hingeAlignment,
          transform: transform,
          child: AspectRatio(
            aspectRatio: QuranConstants.pageAspectRatio(
              usesImage: isImagePage,
              assetPath: page.assetPath,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: appearance.baseColor,
                gradient: useLiteFrame
                    ? null
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          appearance.baseColor,
                          appearance.baseColorSecondary,
                        ],
                      ),
                borderRadius: borderRadius,
                border: Border.all(
                  color: appearance.borderColor,
                ),
                boxShadow: [
                  BoxShadow(
                    color: appearance.outerShadowColor,
                    blurRadius: useLiteFrame ? 10 : 22,
                    offset:
                        Offset(page.isLeftPage ? -4 : 4, useLiteFrame ? 8 : 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: borderRadius,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _PageSurface(
                        page: page,
                        appearance: appearance,
                        settings: settings,
                        smartHifzHiddenLines: smartHifzHiddenLines,
                        smartHifzManualMaskAnchors: smartHifzManualMaskAnchors,
                        onSmartHifzManualMaskAnchorChanged:
                            onSmartHifzManualMaskAnchorChanged,
                        smartHifzRevealed: smartHifzRevealed,
                        smartHifzEdition: smartHifzEdition,
                        smartHifzLineCount: smartHifzLineCount,
                      ),
                    ),
                    if (showPageNumbers && !isImagePage)
                      Positioned(
                        bottom: 14,
                        left: page.isLeftPage ? 16 : null,
                        right: page.isLeftPage ? null : 16,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: appearance.pageNumberBackgroundColor,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: appearance.borderColor
                                  .withValues(alpha: 0.74),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: Text(
                              page.number.toString(),
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: appearance.pageNumberForegroundColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageSurface extends StatefulWidget {
  const _PageSurface({
    required this.page,
    required this.appearance,
    required this.settings,
    required this.smartHifzHiddenLines,
    required this.smartHifzManualMaskAnchors,
    required this.onSmartHifzManualMaskAnchorChanged,
    required this.smartHifzRevealed,
    required this.smartHifzEdition,
    required this.smartHifzLineCount,
  });

  final QuranPage page;
  final ReaderPageAppearance appearance;
  final ReaderSettings settings;
  final Set<int> smartHifzHiddenLines;
  final List<double> smartHifzManualMaskAnchors;
  final void Function(int index, double nextAnchor)?
      onSmartHifzManualMaskAnchorChanged;
  final bool smartHifzRevealed;
  final MushafEdition? smartHifzEdition;
  final int? smartHifzLineCount;

  @override
  State<_PageSurface> createState() => _PageSurfaceState();
}

class _PageSurfaceState extends State<_PageSurface> {
  bool _isHifzRevealActive = false;
  List<double> _focusModeMaskAnchors = const <double>[];

  @override
  void initState() {
    super.initState();
    _syncFocusModeMaskAnchors(force: true);
  }

  @override
  void didUpdateWidget(covariant _PageSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!widget.settings.hifzFocusMode || !widget.settings.hifzRevealOnHold) &&
        _isHifzRevealActive) {
      _isHifzRevealActive = false;
    }
    final pageChanged = oldWidget.page.number != widget.page.number;
    final focusModeEnabledChanged =
        oldWidget.settings.hifzFocusMode != widget.settings.hifzFocusMode;
    final maskDensityChanged = oldWidget.settings.hifzMaskHeightFactor !=
        widget.settings.hifzMaskHeightFactor;
    if (pageChanged || focusModeEnabledChanged || maskDensityChanged) {
      _syncFocusModeMaskAnchors(
        force: pageChanged || focusModeEnabledChanged || maskDensityChanged,
      );
    }
  }

  bool get _allowHoldReveal =>
      widget.settings.hifzRevealOnHold &&
      (widget.settings.hifzFocusMode ||
          widget.smartHifzHiddenLines.isNotEmpty ||
          widget.smartHifzManualMaskAnchors.isNotEmpty);

  bool get _showHifzMask =>
      !_isHifzRevealActive &&
      (widget.settings.hifzFocusMode ||
          widget.smartHifzHiddenLines.isNotEmpty ||
          widget.smartHifzManualMaskAnchors.isNotEmpty) &&
      !widget.smartHifzRevealed;

  bool get _isSmartHifzChallengeActive =>
      widget.smartHifzHiddenLines.isNotEmpty ||
      widget.smartHifzManualMaskAnchors.isNotEmpty;

  MushafEdition get _effectiveHifzEdition =>
      widget.smartHifzEdition ??
      (widget.settings.mushafEdition == MushafEdition.kanzulIman
          ? MushafEdition.lines16
          : widget.settings.mushafEdition);

  int get _effectiveLineCount =>
      widget.smartHifzLineCount ??
      ReaderHifzLineMask.resolveLineCount(
        page: widget.page,
        edition: _effectiveHifzEdition,
      );

  List<double> get _effectiveManualMaskAnchors {
    if (widget.smartHifzManualMaskAnchors.isNotEmpty) {
      return widget.smartHifzManualMaskAnchors;
    }
    if (!widget.settings.hifzFocusMode) {
      return const <double>[];
    }
    return _focusModeMaskAnchors;
  }

  bool get _isFocusModeManualMaskActive =>
      widget.settings.hifzFocusMode &&
      widget.smartHifzManualMaskAnchors.isEmpty &&
      _focusModeMaskAnchors.isNotEmpty;

  double get _focusModePlateHeightFactor {
    final normalized =
        ((widget.settings.hifzMaskHeightFactor - 0.18) / (0.7 - 0.18))
            .clamp(0.0, 1.0);
    return 2.8 + (normalized * 4.2);
  }

  Set<int> get _effectiveHiddenLines {
    if (_effectiveManualMaskAnchors.isNotEmpty) {
      return const <int>{};
    }
    if (widget.smartHifzHiddenLines.isNotEmpty) {
      return widget.smartHifzHiddenLines;
    }
    return const <int>{};
  }

  void _setHifzReveal(bool value) {
    if (!_allowHoldReveal || _isHifzRevealActive == value) {
      return;
    }
    setState(() {
      _isHifzRevealActive = value;
    });
  }

  void _syncFocusModeMaskAnchors({bool force = false}) {
    if (!widget.settings.hifzFocusMode ||
        widget.smartHifzManualMaskAnchors.isNotEmpty) {
      if (_focusModeMaskAnchors.isNotEmpty) {
        _focusModeMaskAnchors = const <double>[];
      }
      return;
    }

    if (_focusModeMaskAnchors.isNotEmpty && !force) {
      return;
    }

    _focusModeMaskAnchors = _defaultFocusModeAnchors();
  }

  List<double> _defaultFocusModeAnchors() {
    return const <double>[0.56];
  }

  void _updateFocusModeMaskAnchor(int index, double nextAnchor) {
    if (index < 0 || index >= _focusModeMaskAnchors.length) {
      return;
    }
    final clampedAnchor = nextAnchor.clamp(0.0, 1.0).toDouble();
    if ((_focusModeMaskAnchors[index] - clampedAnchor).abs() < 0.0005) {
      return;
    }
    setState(() {
      final nextAnchors = List<double>.from(_focusModeMaskAnchors);
      nextAnchors[index] = clampedAnchor;
      _focusModeMaskAnchors = nextAnchors;
    });
  }

  void _selectFocusModeLineAtPosition(Offset localPosition, Size size) {
    if (!_isFocusModeManualMaskActive || _focusModeMaskAnchors.isEmpty) {
      return;
    }

    final geometry = ReaderHifzMaskGeometry.forEdition(
      _effectiveHifzEdition,
      isImagePage: widget.page.usesImage,
    );
    final topInset = size.height * geometry.topInsetFactor;
    final bottomInset = size.height * geometry.bottomInsetFactor;
    final usableHeight = math.max(0.0, size.height - topInset - bottomInset);
    if (usableHeight <= 0) {
      return;
    }

    final snappedAnchor = ReaderHifzManualMask.snappedAnchorForLocalDy(
      localDy: localPosition.dy,
      topInset: topInset,
      usableHeight: usableHeight,
      lineCount: _effectiveLineCount,
    );
    _updateFocusModeMaskAnchor(0, snappedAnchor);
  }

  void _selectFocusModeLineFromGlobalPosition(
    Offset globalPosition,
    RenderBox renderBox,
  ) {
    _selectFocusModeLineAtPosition(
      renderBox.globalToLocal(globalPosition),
      renderBox.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageBody = switch (widget.page.contentType) {
      QuranPageContentType.image => _ImagePageContent(
          page: widget.page,
          appearance: widget.appearance,
          lowMemoryMode: widget.settings.lowMemoryMode,
        ),
      QuranPageContentType.text => PlaceholderQuranPage(
          page: widget.page,
          appearance: widget.appearance,
        ),
      QuranPageContentType.placeholder => PlaceholderQuranPage(
          page: widget.page,
          appearance: widget.appearance,
          title: 'This edition is not downloaded',
          message:
              'Connect to the internet, or open Asset Packs and download this Quran edition for offline reading.',
        ),
    };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isFocusModeManualMaskActive ? () {} : null,
      onLongPressStart: _allowHoldReveal ? (_) => _setHifzReveal(true) : null,
      onLongPressEnd: _allowHoldReveal ? (_) => _setHifzReveal(false) : null,
      onLongPressCancel: _allowHoldReveal ? () => _setHifzReveal(false) : null,
      child: Stack(
        children: [
          Positioned.fill(child: pageBody),
          if (widget.appearance.showOverlay)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.05,
                      colors: [
                        widget.appearance.overlayColor.withValues(
                            alpha: widget.appearance.overlayOpacity),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (widget.appearance.showReflection)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: 26,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        widget.appearance.reflectionColor,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_showHifzMask && _effectiveHiddenLines.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: ReaderHifzLineMask(
                  page: widget.page,
                  edition: _effectiveHifzEdition,
                  lineCount: _effectiveLineCount,
                  hiddenLines: _effectiveHiddenLines,
                  maskColor: _isSmartHifzChallengeActive
                      ? const Color(0xFF111111)
                      : widget.appearance.baseColorSecondary,
                  maskOpacity: _isSmartHifzChallengeActive ? 0.84 : 0.992,
                  coverHeightFactorOverride:
                      _isSmartHifzChallengeActive ? null : 1.02,
                ),
              ),
            ),
          if (_effectiveManualMaskAnchors.isNotEmpty)
            Positioned.fill(
              child: ReaderHifzManualMask(
                page: widget.page,
                edition: _effectiveHifzEdition,
                lineCount: _effectiveLineCount,
                maskAnchors: _effectiveManualMaskAnchors,
                linesHidden: widget.smartHifzManualMaskAnchors.isNotEmpty
                    ? (!widget.smartHifzRevealed && !_isHifzRevealActive)
                    : !_isHifzRevealActive,
                onAnchorChanged: widget.smartHifzManualMaskAnchors.isNotEmpty
                    ? widget.onSmartHifzManualMaskAnchorChanged
                    : null,
                maskColor: _isFocusModeManualMaskActive
                    ? widget.appearance.baseColorSecondary
                    : const Color(0xFF090909),
                maskOpacity: _isFocusModeManualMaskActive ? 0.996 : 0.92,
                coverHeightFactorOverride: _isFocusModeManualMaskActive
                    ? _focusModePlateHeightFactor
                    : null,
              ),
            ),
          if (_isFocusModeManualMaskActive)
            Positioned.fill(
              child: Builder(
                builder: (context) {
                  return Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (event) {
                      final renderObject = context.findRenderObject();
                      if (renderObject is RenderBox) {
                        _selectFocusModeLineFromGlobalPosition(
                          event.position,
                          renderObject,
                        );
                      }
                    },
                    onPointerMove: (event) {
                      final renderObject = context.findRenderObject();
                      if (renderObject is RenderBox) {
                        _selectFocusModeLineFromGlobalPosition(
                          event.position,
                          renderObject,
                        );
                      }
                    },
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
          Positioned(
            top: 0,
            bottom: 0,
            left: widget.page.isLeftPage ? null : 0,
            right: widget.page.isLeftPage ? 0 : null,
            child: IgnorePointer(
              child: Container(
                width: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: widget.page.isLeftPage
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    end: widget.page.isLeftPage
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    colors: [
                      widget.appearance.sideShadowColor,
                      Colors.transparent,
                    ],
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

class _ImagePageContent extends StatelessWidget {
  const _ImagePageContent({
    required this.page,
    required this.appearance,
    required this.lowMemoryMode,
  });

  final QuranPage page;
  final ReaderPageAppearance appearance;
  final bool lowMemoryMode;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
        final cacheWidth = (constraints.maxWidth * devicePixelRatio)
            .round()
            .clamp(lowMemoryMode ? 360 : 480, lowMemoryMode ? 640 : 900)
            .toInt();
        final imageProvider = buildQuranPageImageProvider(
          page,
          cacheWidth: cacheWidth,
        );

        Widget image = Image(
          image: imageProvider,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          filterQuality: FilterQuality.none,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            final assetPath = page.assetPath ?? '';
            if (assetPath.startsWith('assets/asset_packs/')) {
              return child;
            }
            return const ReaderSkeletonPage();
          },
          errorBuilder: (_, __, ___) {
            return PlaceholderQuranPage(
              page: page,
              appearance: appearance,
              title: page.usesRemoteImage
                  ? 'Unable to load this page'
                  : 'This page file is missing',
              message: page.usesRemoteImage
                  ? 'You may be offline or the server may be unreachable. Connect to the internet, or download this edition from Asset Packs.'
                  : 'Download this Quran edition again from Asset Packs to restore the offline pages.',
            );
          },
        );

        if (appearance.nightMode) {
          image = ColorFiltered(
            colorFilter: const ColorFilter.matrix(
              ReaderPageAppearance.invertImageMatrix,
            ),
            child: image,
          );
        }

        if (appearance.needsBrightnessFilter) {
          image = ColorFiltered(
            colorFilter: ColorFilter.matrix(appearance.brightnessMatrix()),
            child: image,
          );
        }

        if (!appearance.hasImageTint) {
          return image;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            image,
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: appearance.imageTintColor.withValues(
                    alpha: appearance.imageTintOpacity,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
