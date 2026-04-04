import 'package:flutter/material.dart';

class ReaderSheetFrame extends StatefulWidget {
  const ReaderSheetFrame({
    super.key,
    required this.child,
    this.dismissThreshold = 96,
  });

  final Widget child;
  final double dismissThreshold;

  @override
  State<ReaderSheetFrame> createState() => _ReaderSheetFrameState();
}

class _ReaderSheetFrameState extends State<ReaderSheetFrame> {
  double _dragOffset = 0;
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _entered = true;
      });
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is OverscrollNotification &&
        notification.overscroll < 0 &&
        notification.metrics.pixels <=
            notification.metrics.minScrollExtent + 1) {
      final nextOffset = (_dragOffset + (-notification.overscroll))
          .clamp(0.0, widget.dismissThreshold * 1.45);
      if ((_dragOffset - nextOffset).abs() > 0.5) {
        setState(() {
          _dragOffset = nextOffset;
        });
      }
      return false;
    }

    if (notification is ScrollEndNotification && _dragOffset > 0) {
      _handleDragRelease();
      return false;
    }

    return false;
  }

  void _handleDragRelease() {
    if (_dragOffset >= widget.dismissThreshold) {
      Navigator.of(context).maybePop();
      return;
    }
    if (_dragOffset == 0) {
      return;
    }
    setState(() {
      _dragOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dragProgress =
        (_dragOffset / (widget.dismissThreshold * 1.5)).clamp(0.0, 1.0);

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        onVerticalDragUpdate: (details) {
          final delta = details.primaryDelta ?? 0;
          if (delta == 0) {
            return;
          }
          final nextOffset = (_dragOffset + delta)
              .clamp(0.0, widget.dismissThreshold * 1.45);
          if ((_dragOffset - nextOffset).abs() > 0.5) {
            setState(() {
              _dragOffset = nextOffset;
            });
          }
        },
        onVerticalDragEnd: (_) => _handleDragRelease(),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          opacity: _entered ? (1 - (dragProgress * 0.18)) : 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            offset: _entered ? Offset.zero : const Offset(0, 0.06),
            child: AnimatedContainer(
              duration: _dragOffset == 0
                  ? const Duration(milliseconds: 180)
                  : Duration.zero,
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, _dragOffset, 0),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
