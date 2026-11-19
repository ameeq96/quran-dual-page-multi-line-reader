import 'dart:async';

import 'package:flutter/material.dart';

/// Shared motion tokens so every screen moves on the same rhythm.
abstract final class AppMotion {
  static const Duration press = Duration(milliseconds: 110);
  static const Duration release = Duration(milliseconds: 180);
  static const Duration enter = Duration(milliseconds: 360);
  static const Duration staggerStep = Duration(milliseconds: 55);
  static const Curve enterCurve = Curves.easeOutCubic;
}

/// Fades and lifts [child] into place once, [index] steps after its siblings.
///
/// Skipped entirely when the platform asks for reduced motion.
class AppStagger extends StatefulWidget {
  const AppStagger({
    super.key,
    required this.index,
    required this.child,
    this.distance = 18,
  });

  final int index;
  final Widget child;
  final double distance;

  @override
  State<AppStagger> createState() => _AppStaggerState();
}

class _AppStaggerState extends State<AppStagger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.enter,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.enterCurve,
  );
  Timer? _delay;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    // Cap the delay so long lists never feel like they are loading.
    final steps = widget.index.clamp(0, 8);
    if (steps == 0) {
      _controller.forward();
    } else {
      _delay = Timer(AppMotion.staggerStep * steps, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) {
        final value = _curve.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * widget.distance),
            child: child,
          ),
        );
      },
    );
  }
}

/// Gives any tappable surface a soft press-in. The scale is a paint-only
/// transform, so neighbours never shift.
class AppPressable extends StatefulWidget {
  const AppPressable({super.key, required this.child, this.pressedScale = 0.97});

  final Widget child;
  final double pressedScale;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value && mounted) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed && !reduced ? widget.pressedScale : 1,
        duration: _pressed ? AppMotion.press : AppMotion.release,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
