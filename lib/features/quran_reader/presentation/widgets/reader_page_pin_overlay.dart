import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';
import '../../../../core/storage/reader_profile_store.dart';
import '../../data/services/reader_page_pin_store.dart';

class ReaderPinGeometry {
  static Rect imageRect(Size imageSize, Size canvasSize) {
    if (imageSize.isEmpty || canvasSize.isEmpty || !imageSize.width.isFinite ||
        !imageSize.height.isFinite || !canvasSize.width.isFinite || !canvasSize.height.isFinite) {
      return Rect.zero;
    }
    final fitted = applyBoxFit(BoxFit.contain, imageSize, canvasSize);
    return Alignment.center.inscribe(fitted.destination, Offset.zero & canvasSize);
  }

  static Offset? normalizedPoint(Offset localPosition, Rect imageRect) {
    if (imageRect.isEmpty || !localPosition.dx.isFinite || !localPosition.dy.isFinite ||
        !imageRect.contains(localPosition)) {
      return null;
    }
    return Offset((localPosition.dx - imageRect.left) / imageRect.width,
        (localPosition.dy - imageRect.top) / imageRect.height);
  }

  static Offset localPoint(Offset normalized, Rect imageRect) => Offset(
      imageRect.left + normalized.dx * imageRect.width,
      imageRect.top + normalized.dy * imageRect.height);
}

Future<String> fingerprintReaderScan(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) throw StateError('Manual pins need a loaded scan image.');
  final pixels = sha256.convert(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  return sha256.convert(utf8.encode('${image.width}:${image.height}:$pixels')).toString();
}

class ReaderPagePinOverlay extends StatefulWidget {
  const ReaderPagePinOverlay({super.key, required this.child, required this.pageNumber,
    required this.edition, required this.sourceKey, required this.imageProvider,
    required this.originalImageProvider});
  final Widget child;
  final int pageNumber;
  final String edition;
  final String sourceKey;
  final ImageProvider<Object> imageProvider;
  final ImageProvider<Object> originalImageProvider;
  @override
  State<ReaderPagePinOverlay> createState() => _ReaderPagePinOverlayState();
}

class _ReaderPagePinOverlayState extends State<ReaderPagePinOverlay> {
  static Future<void> _fingerprintQueue = Future<void>.value();
  late String _profileId;
  ImageStream? _displayStream;
  ImageStreamListener? _displayListener;
  ui.Image? _displayImage;
  Size? _imageSize;
  String? _imageIdentity;
  List<ReaderPagePin> _pins = const [];
  ReaderPagePinKind _kind = ReaderPagePinKind.note;
  ReaderPagePin? _movingPin;
  bool _editing = false;
  bool _busy = false;
  int _generation = 0;

  ReaderPagePinStore get _store => ReaderPagePinStore(profileId: _profileId,
      edition: widget.edition, page: widget.pageNumber,
      activeProfileId: () => ReaderProfileStore.instance.activeId);
  String get _location => '$_profileId|${widget.edition}|${widget.pageNumber}|${widget.sourceKey}';

  @override
  void initState() {
    super.initState();
    _profileId = ReaderProfileStore.instance.activeId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveDisplayedImage();
  }

  @override
  void didUpdateWidget(covariant ReaderPagePinOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.sourceKey != widget.sourceKey || oldWidget.edition != widget.edition ||
        oldWidget.pageNumber != widget.pageNumber || _profileId != ReaderProfileStore.instance.activeId;
    if (changed) {
      _profileId = ReaderProfileStore.instance.activeId;
      _generation++;
      _imageIdentity = null;
      _pins = const [];
      _editing = false;
      _busy = false;
      _movingPin = null;
    }
    _resolveDisplayedImage(force: changed);
  }

  void _resolveDisplayedImage({bool force = false}) {
    final stream = widget.imageProvider.resolve(createLocalImageConfiguration(context));
    if (!force && stream.key == _displayStream?.key) return;
    _removeDisplayListener();
    _imageSize = null;
    _displayStream = stream;
    _displayListener = ImageStreamListener((info, _) {
      if (!mounted || !identical(stream, _displayStream)) return;
      final imageChanged = _displayImage == null || !_displayImage!.isCloneOf(info.image);
      if (imageChanged) {
        _displayImage?.dispose();
        _displayImage = info.image.clone();
        unawaited(_loadPins(_generation));
      }
      final size = Size(info.image.width.toDouble(), info.image.height.toDouble());
      if (imageChanged || _imageSize != size) setState(() => _imageSize = size);
    }, onError: (_, __) {
      if (mounted && identical(stream, _displayStream)) {
        setState(() {
        _imageSize = null; _imageIdentity = null; _pins = const []; _editing = false;
        });
      }
    });
    stream.addListener(_displayListener!);
  }

  void _removeDisplayListener() {
    if (_displayListener != null) _displayStream?.removeListener(_displayListener!);
    _displayListener = null;
    _displayStream = null;
    _displayImage?.dispose();
    _displayImage = null;
  }

  Future<String> _resolveIdentity() {
    final provider = widget.originalImageProvider;
    final configuration = createLocalImageConfiguration(context);
    final result = Completer<String>();
    _fingerprintQueue = _fingerprintQueue.then((_) async {
      ImageStream? stream;
      ImageStreamListener? listener;
      ui.Image? image;
      try {
        final decoded = Completer<ui.Image>();
        stream = provider.resolve(configuration);
        listener = ImageStreamListener((info, _) {
          if (!decoded.isCompleted) decoded.complete(info.image.clone());
        }, onError: (Object error, StackTrace? stack) {
          if (!decoded.isCompleted) decoded.completeError(StateError('Manual pins need a loaded scan image.'));
        });
        stream.addListener(listener);
        image = await decoded.future.timeout(const Duration(seconds: 15));
        final identity = await fingerprintReaderScan(image);
        result.complete(identity);
      } catch (error) {
        result.completeError(error);
      } finally {
        if (listener != null) stream?.removeListener(listener);
        image?.dispose();
      }
    });
    return result.future;
  }

  Future<void> _loadPins(int generation) async {
    try {
      final pins = await _store.load();
      if (!mounted || generation != _generation || (pins.isEmpty && _imageIdentity == null)) return;
      final identity = await _resolveIdentity();
      if (!mounted || generation != _generation) return;
      setState(() {
        if (_imageIdentity != null && _imageIdentity != identity) {
          _editing = false;
          _busy = false;
          _movingPin = null;
          _generation++;
        }
        _imageIdentity = identity;
        _pins = pins.where((entry) => entry.imageIdentity == identity).toList();
      });
    } catch (_) { /* Existing annotations remain stored if a scan is unavailable. */ }
  }

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, text))));
  }

  Future<void> _startEditing() async {
    if (_busy) return;
    if (_imageSize == null) { _message('Manual pins need a loaded scan image.'); return; }
    final generation = _generation;
    setState(() => _busy = true);
    try {
      final pins = await _store.load();
      final identity = _imageIdentity ?? await _resolveIdentity();
      if (!mounted || generation != _generation || ReaderProfileStore.instance.activeId != _profileId) return;
      setState(() {
        _imageIdentity = identity;
        _pins = pins.where((entry) => entry.imageIdentity == identity).toList();
        _editing = true;
      });
    } catch (_) { _message('Manual pins could not be opened. Your saved pins were kept.'); }
    finally { if (mounted && generation == _generation) setState(() => _busy = false); }
  }

  Future<void> _editPin({ReaderPagePin? pin, Offset? point}) async {
    final identity = _imageIdentity;
    if (identity == null || _busy || !mounted) return;
    final location = _location;
    final store = _store;
    var note = pin?.note ?? '';
    var kind = pin?.kind ?? _kind;
    bool saving = false;
    String? error;
    setState(() => _busy = true);
    try {
      final result = await showDialog<String>(context: context, barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(builder: (context, update) => PopScope(canPop: !saving, child: AlertDialog(
          title: Text(tr(context, pin == null ? 'Add manual pin' : 'Edit manual pin')),
          content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(context, 'You chose this position manually. Pins do not identify an Ayah. Saved on this device for the current profile.')),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: ReaderPagePinKind.values.map((value) => ChoiceChip(
                label: Text(tr(context, value == ReaderPagePinKind.note ? 'Note pin' : 'Mistake pin')),
                selected: kind == value, onSelected: saving ? null : (_) => update(() => kind = value))).toList()),
              const SizedBox(height: 12),
              _PinNoteField(initialText: note, enabled: !saving, onChanged: (value) => note = value),
              if (error != null) Text(tr(context, error!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ]))),
          actions: [
            if (pin != null) TextButton(onPressed: saving ? null : () => Navigator.of(dialogContext).pop('move'), child: Text(tr(context, 'Move pin'))),
            if (pin != null) TextButton(onPressed: saving ? null : () async {
              update(() { saving = true; error = null; });
              try {
                if (_location != location || _imageIdentity != identity) throw StateError('Page changed.');
                await store.remove(pinId: pin.id, imageIdentity: identity);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop('changed');
                }
              } catch (_) { if (dialogContext.mounted) update(() { saving = false; error = 'Manual pin could not be saved. Try again.'; }); }
            }, child: Text(tr(context, 'Delete pin'))),
            TextButton(onPressed: saving ? null : () => Navigator.of(dialogContext).pop(), child: Text(tr(context, 'Cancel'))),
            FilledButton(onPressed: saving ? null : () async {
              update(() { saving = true; error = null; });
              try {
                if (_location != location || _imageIdentity != identity) throw StateError('Page changed.');
                final now = DateTime.now().toUtc().toIso8601String();
                await store.save(ReaderPagePin(id: pin?.id ?? ReaderPagePin.newId(), imageIdentity: identity,
                  x: pin?.x ?? point!.dx, y: pin?.y ?? point!.dy, kind: kind, note: note.trim(),
                  createdAt: pin?.createdAt ?? now, updatedAt: now));
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop('changed');
                }
              } catch (_) { if (dialogContext.mounted) update(() { saving = false; error = 'Manual pin could not be saved. Try again.'; }); }
            }, child: Text(tr(context, saving ? 'Saving…' : 'Save pin'))),
          ],
        ))));
      if (!mounted || _location != location || ReaderProfileStore.instance.activeId != _profileId) return;
      if (result == 'move') setState(() => _movingPin = pin);
      if (result == 'changed') {
        final pins = await store.load();
        if (mounted && _location == location) setState(() => _pins = pins.where((entry) => entry.imageIdentity == identity).toList());
      }
    } finally { if (mounted && _location == location) setState(() => _busy = false); }
  }

  Future<void> _place(Offset local, Rect rect) async {
    final normalized = ReaderPinGeometry.normalizedPoint(local, rect);
    if (normalized == null || _busy) return;
    final moving = _movingPin;
    if (moving == null) { await _editPin(point: normalized); return; }
    final location = _location;
    setState(() => _busy = true);
    try {
      final store = _store;
      await store.save(ReaderPagePin(id: moving.id, imageIdentity: moving.imageIdentity,
        x: normalized.dx, y: normalized.dy, kind: moving.kind, note: moving.note,
        createdAt: moving.createdAt, updatedAt: DateTime.now().toUtc().toIso8601String()));
      final pins = await store.load();
      if (mounted && _location == location) {
        setState(() {
        _movingPin = null;
        _pins = pins.where((entry) => entry.imageIdentity == _imageIdentity).toList();
        });
      }
    } catch (_) { _message('Manual pin could not be saved. Try again.'); }
    finally { if (mounted && _location == location) setState(() => _busy = false); }
  }

  @override
  void dispose() { _removeDisplayListener(); super.dispose(); }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final rect = ReaderPinGeometry.imageRect(_imageSize ?? Size.zero, constraints.biggest);
    return Stack(fit: StackFit.expand, children: [
      widget.child,
      if (_editing) Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque,
        onTapUp: _busy ? null : (details) => _place(details.localPosition, rect), child: const SizedBox.expand())),
      if (!rect.isEmpty) for (final pin in _pins)
        Positioned(left: ReaderPinGeometry.localPoint(Offset(pin.x, pin.y), rect).dx - 16,
          top: ReaderPinGeometry.localPoint(Offset(pin.x, pin.y), rect).dy - 16,
          child: IgnorePointer(ignoring: !_editing || _busy, child: SizedBox(width: 32, height: 32, child: IconButton(
            visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => _editPin(pin: pin), tooltip: tr(context, pin.kind == ReaderPagePinKind.note ? 'Manual note pin' : 'Manual mistake pin'),
            style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: pin.kind == ReaderPagePinKind.note ? const Color(0xFF146C5E) : const Color(0xFFAD3030)),
            icon: Icon(pin.kind == ReaderPagePinKind.note ? Icons.sticky_note_2_outlined : Icons.flag_rounded, size: 19))))),
      Positioned(top: 6, right: 6, child: Material(color: Theme.of(context).colorScheme.surface.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(20), child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!_editing) IconButton(visualDensity: VisualDensity.compact,
            tooltip: tr(context, 'Manual notes and mistake pins'), onPressed: _busy ? null : _startEditing,
            icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_location_alt_outlined, size: 20)),
          if (_editing) ...[
            IconButton(visualDensity: VisualDensity.compact, tooltip: tr(context, 'Note pin'),
              isSelected: _kind == ReaderPagePinKind.note, onPressed: _busy ? null : () => setState(() { _kind = ReaderPagePinKind.note; _movingPin = null; }),
              icon: const Icon(Icons.sticky_note_2_outlined, size: 18)),
            IconButton(visualDensity: VisualDensity.compact, tooltip: tr(context, 'Mistake pin'),
              isSelected: _kind == ReaderPagePinKind.mistake, onPressed: _busy ? null : () => setState(() { _kind = ReaderPagePinKind.mistake; _movingPin = null; }),
              icon: const Icon(Icons.flag_outlined, size: 18)),
            IconButton(visualDensity: VisualDensity.compact, tooltip: tr(context, 'Finish placing pins'),
              onPressed: _busy ? null : () => setState(() { _editing = false; _movingPin = null; }), icon: const Icon(Icons.check_rounded, size: 20)),
          ],
        ]))),
      if (_editing) Positioned(bottom: 6, left: 6, right: 6, child: IgnorePointer(child: DecoratedBox(
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withValues(alpha: .94), borderRadius: BorderRadius.circular(8)),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: Text(
          tr(context, _movingPin != null ? 'Tap the new position for this pin.' : 'Tap the scan to place a manual pin.'),
          textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall))))),
    ]);
  });
}

class _PinNoteField extends StatefulWidget {
  const _PinNoteField({required this.initialText, required this.enabled, required this.onChanged});
  final String initialText;
  final bool enabled;
  final ValueChanged<String> onChanged;
  @override
  State<_PinNoteField> createState() => _PinNoteFieldState();
}

class _PinNoteFieldState extends State<_PinNoteField> {
  late final TextEditingController _input = TextEditingController(text: widget.initialText);
  @override
  void dispose() { _input.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => TextField(controller: _input, enabled: widget.enabled,
    onChanged: widget.onChanged, maxLength: 2000, minLines: 3, maxLines: 7,
    decoration: InputDecoration(labelText: tr(context, 'Pin note (optional)'), alignLabelWithHint: true));
}
