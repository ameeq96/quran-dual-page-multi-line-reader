import 'package:flutter/material.dart';

class ReaderZoomViewport extends StatefulWidget {
  const ReaderZoomViewport({
    super.key,
    required this.child,
    required this.onZoomChanged,
  });

  final Widget child;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<ReaderZoomViewport> createState() => _ReaderZoomViewportState();
}

class _ReaderZoomViewportState extends State<ReaderZoomViewport> {
  static const double _minZoomScale = 1;
  static const double _maxZoomScale = 4;
  static const double _zoomEpsilon = 0.01;

  late final TransformationController _transformationController;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController()
      ..addListener(_handleTransformChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleTransformChanged);
    if (_isZoomed) {
      widget.onZoomChanged(false);
    }
    _transformationController.dispose();
    super.dispose();
  }

  void _handleTransformChanged() {
    final nextZoomed =
        _transformationController.value.getMaxScaleOnAxis() > 1 + _zoomEpsilon;
    if (_isZoomed == nextZoomed) {
      return;
    }
    _isZoomed = nextZoomed;
    widget.onZoomChanged(nextZoomed);
  }

  void _resetZoom() {
    if (!_isZoomed) {
      return;
    }
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _resetZoom,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: _minZoomScale,
        maxScale: _maxZoomScale,
        panEnabled: false,
        scaleEnabled: true,
        clipBehavior: Clip.none,
        boundaryMargin: const EdgeInsets.all(160),
        child: widget.child,
      ),
    );
  }
}
