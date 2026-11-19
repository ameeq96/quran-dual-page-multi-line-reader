import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/reader_localization.dart';
import '../../../../core/prayer/prayer_models.dart';
import '../../../../core/prayer/prayer_reminder_service.dart';
import '../../../../core/worship/qibla_service.dart';
import '../widgets/app_page_header.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> with WidgetsBindingObserver {
  final _service = QiblaService();
  bool _resumeCompassOnForeground = false;
  PrayerLocation? _compassResumeLocation;
  Future<void>? _compassPause;
  int _compassResumeGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_usePrayerLocation());
  }

  Future<void> _usePrayerLocation() async {
    final prayers = PrayerReminderService.instance;
    if (!prayers.loaded) await prayers.initialize();
    final location = prayers.settings.location;
    if (mounted && _service.location == null && location != null) {
      _service.setLocation(location);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_resumeCompassOnForeground) {
        unawaited(_resumeCompassAfterPause(++_compassResumeGeneration));
      }
      return;
    }
    ++_compassResumeGeneration;
    if (_service.compassEnabled) {
      _resumeCompassOnForeground = true;
      _compassResumeLocation = _service.location;
    }
    _compassPause = _service.stopCompass();
  }

  Future<void> _resumeCompassAfterPause(int generation) async {
    await _compassPause;
    if (!mounted ||
        generation != _compassResumeGeneration ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final resume = _resumeCompassOnForeground &&
        identical(_compassResumeLocation, _service.location) &&
        !_service.locating;
    _resumeCompassOnForeground = false;
    if (resume) await _service.startCompass();
  }

  @override
  void dispose() {
    _resumeCompassOnForeground = false;
    ++_compassResumeGeneration;
    WidgetsBinding.instance.removeObserver(this);
    _service.dispose();
    super.dispose();
  }

  String _t(String source) {
    final translation = _translations[source];
    return switch (ReaderLocalizationScope.of(context).language) {
      ReaderLanguage.urdu => translation?.$1 ?? source,
      ReaderLanguage.arabic => translation?.$2 ?? source,
      _ => source,
    };
  }

  Future<void> _manualLocation() async {
    final result = await showDialog<PrayerLocation>(
      context: context,
      builder: (_) => _QiblaLocationDialog(initialLocation: _service.location),
    );
    if (mounted && result != null) _service.setLocation(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_t('Qibla direction'))),
      body: AnimatedBuilder(
        animation: _service,
        builder: (context, _) {
          final location = _service.location;
          final bearing = _service.bearing;
          final heading = _service.heading;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Same emerald hero as Namaz & Azan and the other
                      // worship screens.
                      AppPageHeader(
                        title: _t('Face the Qibla'),
                        subtitle: _t(
                          'Use your location to find the direction of the Kaaba.',
                        ),
                        icon: Icons.explore_outlined,
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(
                                location == null
                                    ? Icons.location_off_outlined
                                    : Icons.location_on_outlined,
                                color: colors.primary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                location == null
                                    ? _t('Choose a location')
                                    : _t(location.label),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium,
                              ),
                              if (location != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                                  textDirection: TextDirection.ltr,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 20),
                              SizedBox(
                                width: 310,
                                height: 310,
                                child: Semantics(
                                  label: bearing == null
                                      ? _t('Choose a location')
                                      : '${_t('Qibla bearing')}: ${bearing.toStringAsFixed(1)}°',
                                  child: CustomPaint(
                                    painter: _QiblaDial(
                                      bearing: bearing,
                                      heading: heading,
                                      primary: _service.compassUnreliable
                                          ? colors.error
                                          : colors.primary,
                                      outline: colors.outlineVariant,
                                      textColor: colors.onSurface,
                                      north: _t('N'),
                                      east: _t('E'),
                                      south: _t('S'),
                                      west: _t('W'),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                bearing == null
                                    ? '—'
                                    : '${bearing.toStringAsFixed(1)}°',
                                textDirection: TextDirection.ltr,
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.primary,
                                ),
                              ),
                              Text(
                                _t('Clockwise from geographic north'),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _service.compassUnreliable
                                      ? colors.errorContainer
                                      : colors.secondaryContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _t(
                                    _service.compassUnreliable
                                        ? 'Unreliable compass'
                                        : _service.live
                                        ? 'Live compass'
                                        : 'Manual north reference',
                                  ),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: _service.compassUnreliable
                                        ? colors.onErrorContainer
                                        : colors.onSecondaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _t(
                                  _service.compassUnreliable
                                      ? 'Calibration only. Do not use this arrow to determine Qibla while the sensor is unreliable.'
                                      : _service.live
                                      ? 'Hold your phone flat in portrait orientation, away from metal. Turn until the arrow points to the Kaaba marker.'
                                      : 'Align N with geographic north to use this fixed reference arrow.',
                                ),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium,
                              ),
                              if (_service.live && !_service.trueNorth) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _t(
                                    'This browser reports magnetic north. The live arrow is approximate.',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                              if (_service.compassMessage != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _t(_service.compassMessage!),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed:
                                    location == null ||
                                        _service.locating ||
                                        _service.stopping
                                    ? null
                                    : () {
                                        _resumeCompassOnForeground = false;
                                        ++_compassResumeGeneration;
                                        if (_service.compassEnabled) {
                                          unawaited(_service.stopCompass());
                                        } else {
                                          unawaited(_service.startCompass());
                                        }
                                      },
                                icon: Icon(
                                  _service.compassEnabled
                                      ? Icons.pause_rounded
                                      : Icons.explore_outlined,
                                ),
                                label: Text(
                                  _t(
                                    _service.compassEnabled
                                        ? 'Stop compass'
                                        : 'Enable live compass',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _service.locating
                                ? null
                                : () =>
                                      unawaited(_service.useCurrentLocation()),
                            icon: _service.locating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location_rounded),
                            label: Text(
                              _t(
                                _service.locating
                                    ? 'Finding location…'
                                    : 'Use current location',
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _manualLocation,
                            icon: const Icon(Icons.edit_location_alt_outlined),
                            label: Text(_t('Enter coordinates')),
                          ),
                        ],
                      ),
                      if (_service.locationError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _t(_service.locationError!),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        _t(
                          'Location is used on this device to calculate the direction. It is not sent to a Qibla server.',
                        ),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QiblaLocationDialog extends StatefulWidget {
  const _QiblaLocationDialog({this.initialLocation});

  final PrayerLocation? initialLocation;

  @override
  State<_QiblaLocationDialog> createState() => _QiblaLocationDialogState();
}

class _QiblaLocationDialogState extends State<_QiblaLocationDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;

  @override
  void initState() {
    super.initState();
    _latitude = TextEditingController(
      text: widget.initialLocation?.latitude.toString() ?? '',
    );
    _longitude = TextEditingController(
      text: widget.initialLocation?.longitude.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  String _t(String source) {
    final translation = _translations[source];
    return switch (ReaderLocalizationScope.of(context).language) {
      ReaderLanguage.urdu => translation?.$1 ?? source,
      ReaderLanguage.arabic => translation?.$2 ?? source,
      _ => source,
    };
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_t('Enter coordinates')),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_t('Coordinates stay on this device.')),
          const SizedBox(height: 16),
          for (final field in [
            (_latitude, 'Latitude', 89),
            (_longitude, 'Longitude', 180),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: field.$1,
                textDirection: TextDirection.ltr,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: _t(field.$2),
                  border: const OutlineInputBorder(),
                ),
                validator: (raw) {
                  final value = double.tryParse(
                    (raw ?? '').trim().replaceAll(',', '.'),
                  );
                  return value == null ||
                          !value.isFinite ||
                          value.abs() > field.$3
                      ? _t('Enter valid coordinates.')
                      : null;
                },
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(_t('Cancel')),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState?.validate() != true) return;
          Navigator.pop(
            context,
            PrayerLocation(
              label: 'Manual location',
              latitude: double.parse(
                _latitude.text.trim().replaceAll(',', '.'),
              ),
              longitude: double.parse(
                _longitude.text.trim().replaceAll(',', '.'),
              ),
              zone: 'UTC',
            ),
          );
        },
        child: Text(_t('Use location')),
      ),
    ],
  );
}

class _QiblaDial extends CustomPainter {
  const _QiblaDial({
    required this.bearing,
    required this.heading,
    required this.primary,
    required this.outline,
    required this.textColor,
    required this.north,
    required this.east,
    required this.south,
    required this.west,
  });
  final double? bearing, heading;
  final Color primary, outline, textColor;
  final String north, east, south, west;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final rotation = (heading ?? bearing ?? 0) * math.pi / 180;
    for (var i = 0; i < 60; i++) {
      final angle = i * math.pi / 30 - math.pi / 2 - rotation;
      final outer = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + outer * (radius - 6),
        center + outer * (radius - (i % 5 == 0 ? 18 : 11)),
        Paint()
          ..color = i % 5 == 0 ? textColor : outline
          ..strokeWidth = i % 5 == 0 ? 2 : 1,
      );
    }
    for (final cardinal in [
      (north, 0),
      (east, 90),
      (south, 180),
      (west, 270),
    ]) {
      final angle = cardinal.$2 * math.pi / 180 - math.pi / 2 - rotation;
      final position =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius - 37);
      final label = TextPainter(
        text: TextSpan(
          text: cardinal.$1,
          style: TextStyle(
            color: cardinal.$2 == 0 ? primary : textColor,
            // Painted text does not inherit the theme: name the brand face.
            fontFamily: AppTheme.displayFontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, position - Offset(label.width / 2, label.height / 2));
    }
    if (bearing != null) {
      final direction = (bearing! - (heading ?? bearing!)) * math.pi / 180;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(direction);
      final arrow = Path()
        ..moveTo(0, -radius * .61)
        ..lineTo(radius * .12, radius * .26)
        ..lineTo(0, radius * .12)
        ..lineTo(-radius * .12, radius * .26)
        ..close();
      canvas.drawPath(
        arrow,
        Paint()
          ..color = primary
          ..style = heading == null ? PaintingStyle.stroke : PaintingStyle.fill
          ..strokeWidth = 2,
      );
      canvas.drawCircle(Offset.zero, 5, Paint()..color = textColor);
      canvas.restore();
      final markerRadius = radius * .14;
      final orbit = math.min(
        radius * .4,
        math.max(0.0, radius - 37 - markerRadius - 18),
      );
      _paintKaaba(
        canvas,
        center + Offset(0, -orbit),
        markerRadius,
      );
    }
  }

  void _paintKaaba(Canvas canvas, Offset position, double radius) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()..color = const Color(0xfffff8e7),
    );
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = const Color(0xffb99a48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.scale(radius / 20);
    canvas.translate(-16, -16);
    void face(List<Offset> points, Color color) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path..close(), Paint()..color = color);
    }

    face(const [
      Offset(4, 8),
      Offset(19, 3),
      Offset(29, 7),
      Offset(14, 12),
    ], const Color(0xff383f3a));
    face(const [
      Offset(4, 8),
      Offset(14, 12),
      Offset(14, 30),
      Offset(4, 25),
    ], const Color(0xff242c27));
    face(const [
      Offset(14, 12),
      Offset(29, 7),
      Offset(29, 25),
      Offset(14, 30),
    ], const Color(0xff121716));
    face(const [
      Offset(4, 12),
      Offset(14, 16),
      Offset(14, 19),
      Offset(4, 15),
    ], const Color(0xffb99a48));
    face(const [
      Offset(14, 16),
      Offset(29, 11),
      Offset(29, 14),
      Offset(14, 19),
    ], const Color(0xffe1c46e));
    face(const [
      Offset(23, 18),
      Offset(27, 16.7),
      Offset(27, 24.5),
      Offset(23, 25.8),
    ], const Color(0xffc1a557));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_QiblaDial old) =>
      old.bearing != bearing ||
      old.heading != heading ||
      old.primary != primary ||
      old.outline != outline ||
      old.textColor != textColor ||
      old.north != north ||
      old.east != east ||
      old.south != south ||
      old.west != west;
}

const _translations = <String, (String, String)>{
  'Qibla direction': ('قبلے کی سمت', 'اتجاه القبلة'),
  'Face the Qibla': ('قبلے کا رخ معلوم کریں', 'توجّه إلى القبلة'),
  'Use your location to find the direction of the Kaaba.': (
    'اپنے مقام سے کعبے کی سمت معلوم کریں۔',
    'استخدم موقعك لمعرفة اتجاه الكعبة.',
  ),
  'Choose a location': ('اپنا مقام منتخب کریں', 'اختر موقعًا'),
  'Current location': ('موجودہ مقام', 'الموقع الحالي'),
  'Manual location': ('درج کردہ مقام', 'الموقع المُدخل'),
  'Qibla bearing': ('قبلے کا زاویہ', 'زاوية القبلة'),
  'Clockwise from geographic north': (
    'جغرافیائی شمال سے گھڑی کی سمت زاویہ',
    'الزاوية مع عقارب الساعة من الشمال الجغرافي',
  ),
  'Live compass': ('براہ راست کمپاس', 'البوصلة المباشرة'),
  'Unreliable compass': ('کمپاس قابلِ اعتماد نہیں', 'البوصلة غير موثوقة'),
  'Calibration only. Do not use this arrow to determine Qibla while the sensor is unreliable.': (
    'صرف کمپاس کی درستی کے لیے۔ جب سینسر قابلِ اعتماد نہ ہو تو اس تیر سے قبلے کی سمت متعین نہ کریں۔',
    'للمعايرة فقط. لا تستخدم هذا السهم لتحديد القبلة ما دام المستشعر غير موثوق.',
  ),
  'North-referenced bearing': ('شمال کے مطابق سمت', 'الاتجاه المرجعي للشمال'),
  'Manual north reference': ('شمال کے مطابق دستی سمت', 'اتجاه يدوي مرجعه الشمال'),
  'Align N with geographic north to use this fixed reference arrow.': (
    'اس ساکن رہنما تیر کو استعمال کرنے کے لیے شمال کے نشان کو جغرافیائی شمال کے مطابق رکھیں۔',
    'حاذِ علامة الشمال مع الشمال الجغرافي لاستخدام سهم الاتجاه الثابت هذا.',
  ),
  'Hold your phone flat in portrait orientation, away from metal. Turn until the arrow points to the Kaaba marker.': (
    'فون سیدھا اور ہموار رکھیں، دھات سے دور۔ فون گھمائیں یہاں تک کہ تیر کعبے کے نشان کی طرف آ جائے۔',
    'ضع الهاتف أفقيًا بوضع عمودي للشاشة، بعيدًا عن المعادن. استدر حتى يشير السهم إلى علامة الكعبة.',
  ),
  'Enable the live compass for a direction arrow, or align N with geographic north.': (
    'سمت کا تیر دیکھنے کے لیے براہ راست کمپاس چلائیں یا شمال کے نشان کو جغرافیائی شمال کے مطابق رکھیں۔',
    'فعّل البوصلة المباشرة لإظهار سهم الاتجاه، أو حاذِ علامة الشمال مع الشمال الجغرافي.',
  ),
  'This browser reports magnetic north. The live arrow is approximate.': (
    'یہ براؤزر مقناطیسی شمال بتاتا ہے۔ متحرک تیر کی سمت تقریبی ہے۔',
    'يعرض هذا المتصفح الشمال المغناطيسي. اتجاه السهم المباشر تقريبي.',
  ),
  'Stop compass': ('کمپاس روکیں', 'إيقاف البوصلة'),
  'Enable live compass': ('کمپاس چلائیں', 'تفعيل البوصلة المباشرة'),
  'Finding location…': ('مقام معلوم ہو رہا ہے…', 'جارٍ تحديد الموقع…'),
  'Use current location': ('موجودہ مقام استعمال کریں', 'استخدام الموقع الحالي'),
  'Enter coordinates': ('طول و عرض بلد درج کریں', 'إدخال الإحداثيات'),
  'Coordinates stay on this device.': (
    'طول و عرض بلد اسی ڈیوائس پر رہتے ہیں۔',
    'تبقى الإحداثيات على هذا الجهاز.',
  ),
  'Latitude': ('عرض بلد', 'خط العرض'),
  'Longitude': ('طول بلد', 'خط الطول'),
  'Enter valid coordinates.': (
    'درست طول و عرض بلد درج کریں۔',
    'أدخل إحداثيات صحيحة.',
  ),
  'Cancel': ('منسوخ', 'إلغاء'),
  'Use location': ('یہ مقام استعمال کریں', 'استخدام الموقع'),
  'N': ('ش', 'ش'),
  'E': ('م', 'ق'),
  'S': ('ج', 'ج'),
  'W': ('مغ', 'غ'),
  'Waiting for the compass…': ('کمپاس کا انتظار ہے…', 'في انتظار البوصلة…'),
  'Hold your phone flat in portrait orientation.': (
    'فون سیدھا اور ہموار رکھیں۔',
    'ضع الهاتف أفقيًا بوضع عمودي للشاشة.',
  ),
  'Move away from metal and calibrate your compass.': (
    'دھات سے دور جائیں اور کمپاس درست کریں۔',
    'ابتعد عن المعادن وعاير البوصلة.',
  ),
  'Compass accuracy is low. Move away from metal and calibrate your compass.': (
    'کمپاس کی درستگی کم ہے۔ دھات سے دور جائیں اور کمپاس درست کریں۔',
    'دقة البوصلة منخفضة. ابتعد عن المعادن وعاير البوصلة.',
  ),
  'Live compass is unavailable. Align N with geographic north to use the bearing.': (
    'کمپاس دستیاب نہیں۔ شمال کے نشان کو جغرافیائی شمال کے مطابق رکھیں۔',
    'البوصلة المباشرة غير متاحة. حاذِ علامة الشمال مع الشمال الجغرافي لاستخدام الاتجاه.',
  ),
  'No reliable compass reading. Hold your phone flat or use the north-referenced bearing.': (
    'کمپاس کا معتبر نتیجہ نہیں ملا۔ فون ہموار رکھیں یا شمال کے مطابق سمت دیکھیں۔',
    'لا توجد قراءة موثوقة للبوصلة. ضع هاتفك أفقيًا أو استخدم الاتجاه المرجعي للشمال.',
  ),
  'Compass permission or sensors are unavailable. Use the north-referenced bearing.':
      (
        'کمپاس کی اجازت یا سینسر دستیاب نہیں۔ شمال کے مطابق سمت دیکھیں۔',
        'إذن البوصلة أو مستشعراتها غير متاحة. استخدم الاتجاه المرجعي للشمال.',
      ),
  'Location is unavailable. Allow location access or enter coordinates manually.':
      (
        'مقام دستیاب نہیں۔ مقام کی اجازت دیں یا طول و عرض بلد درج کریں۔',
        'الموقع غير متاح. اسمح بالوصول إلى الموقع أو أدخل الإحداثيات يدويًا.',
      ),
  'Location is used on this device to calculate the direction. It is not sent to a Qibla server.': (
    'سمت اسی ڈیوائس پر معلوم کی جاتی ہے۔ مقام قبلہ سرور کو نہیں بھیجا جاتا۔',
    'يُستخدم الموقع على هذا الجهاز لحساب الاتجاه، ولا يُرسل إلى خادم للقبلة.',
  ),
};
