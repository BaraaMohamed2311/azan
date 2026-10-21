import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_ui.dart';
import '../core/theme.dart';
import '../logic/prayer.dart';
import '../services/compass_service.dart';
import '../services/location_service.dart';
import '../state/app_settings.dart';

/// Ported from app/(tabs)/qibla.tsx — qibla compass with live heading when
/// the device/browser orientation sensor is available.
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  double? _heading;
  String _status = 'فعّل البوصلة لمعرفة اتجاه القبلة مباشرة.';
  bool _tracking = false;
  bool _gpsBusy = false;
  StreamSubscription<double>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _toggleCompass() {
    if (_tracking) {
      _subscription?.cancel();
      _subscription = null;
      setState(() {
        _tracking = false;
        _heading = null;
        _status = 'تم إيقاف حساس الاتجاه. زاوية القبلة محسوبة من الشمال الجغرافي.';
      });
      return;
    }
    setState(() {
      _heading = null;
      _tracking = true;
      _status = 'جارٍ تفعيل حساس الاتجاه…';
    });
    _subscription = CompassService.headingStream().listen(
      (heading) {
        if (mounted) {
          setState(() {
            _heading = heading;
            _status = kIsWeb
                ? 'حرّك الهاتف ببطء لمعايرة البوصلة.'
                : 'حرّك الهاتف بشكل رقم ٨ لمعايرة البوصلة.';
          });
        }
      },
      onError: (Object _) {
        if (mounted) {
          setState(() {
            _tracking = false;
            _status = kIsWeb
                ? 'هذا المتصفح لا يتيح حساس الاتجاه. زاوية القبلة محسوبة من الشمال الجغرافي.'
                : 'حساس الاتجاه غير متاح على هذا الجهاز. زاوية القبلة محسوبة من الشمال الجغرافي.';
          });
        }
      },
    );
  }

  Future<void> _requestLocation() async {
    setState(() {
      _gpsBusy = true;
      _status = 'جارٍ تحديد موقعك…';
    });
    try {
      final position = await LocationService.getCurrentPosition();
      if (!mounted) return;
      context
          .read<AppSettings>()
          .useGpsPlace(position.latitude, position.longitude);
      setState(() => _status = 'تم تحديث اتجاه القبلة بناءً على موقعك الحالي.');
    } catch (_) {
      if (mounted) {
        setState(
            () => _status = 'تعذّر تحديد الموقع. تحقق من الإذن وخدمات الموقع.');
      }
    } finally {
      if (mounted) setState(() => _gpsBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final place = context.watch<AppSettings>().place;
    final bearing = qiblaBearing(place.latitude, place.longitude);
    final relative =
        _heading == null ? bearing : (bearing - _heading! + 360) % 360;

    return Screen(
      children: [
        PageTitle(
          title: 'اتجاه القبلة',
          subtitle: 'من ${place.name} إلى الكعبة المشرفة',
        ),
        CardX(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 4,
            children: [
              SizedBox(
                width: 270,
                height: 286,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(270, 286),
                      painter: _CompassPainter(
                        colors: colors,
                        heading: _heading ?? 0,
                        bearing: bearing,
                        relative: relative,
                        hasHeading: _heading != null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Text(
                '${bearing.toStringAsFixed(1)}°',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                  fontFamily: 'Inter',
                  fontFamilyFallback: const ['NotoSansArabic'],
                ),
              ),
              Text(
                'من الشمال باتجاه عقارب الساعة',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.mutedForeground,
                  fontFamily: 'Inter',
                  fontFamilyFallback: const ['NotoSansArabic'],
                ),
              ),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 20 / 13,
                  color: colors.mutedForeground,
                  fontFamily: 'Inter',
                  fontFamilyFallback: const ['NotoSansArabic'],
                ),
              ),
              const SizedBox(height: 6),
              ActionButton(
                label: 'تحديث موقعي',
                busy: _gpsBusy,
                icon: Icons.near_me_outlined,
                onPress: _requestLocation,
              ),
              if (_heading != null)
                Text(
                  'قراءة البوصلة: ${_heading!.toStringAsFixed(0)}°',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.mutedForeground,
                    fontFamily: 'Inter',
                    fontFamilyFallback: const ['NotoSansArabic'],
                  ),
                ),
              const SizedBox(height: 6),
              OutlinedButton(
                onPressed: _toggleCompass,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                ),
                child: Text(
                  _tracking ? 'إيقاف البوصلة' : 'تفعيل حساس الاتجاه',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                    fontFamily: 'Inter',
                    fontFamilyFallback: const ['NotoSansArabic'],
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          'دقة البوصلة تعتمد على حساس الجهاز والمعايرة، وقد تتأثر بالمعادن أو الأغطية المغناطيسية.',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 12,
            height: 19 / 12,
            color: colors.mutedForeground,
            fontFamily: 'Inter',
            fontFamilyFallback: const ['NotoSansArabic'],
          ),
        ),
      ],
    );
  }
}

class _CompassPainter extends CustomPainter {
  final AppColors colors;
  final double heading;
  final double bearing;
  final double relative;
  final bool hasHeading;

  _CompassPainter({
    required this.colors,
    required this.heading,
    required this.bearing,
    required this.relative,
    required this.hasHeading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 14);
    const radius = 129.0;

    // Top pointer triangle
    final pointer = Path()
      ..moveTo(center.dx - 9, center.dy - radius - 6)
      ..lineTo(center.dx + 9, center.dy - radius - 6)
      ..lineTo(center.dx, center.dy - radius + 9)
      ..close();
    canvas.drawPath(pointer, Paint()..color = colors.primary);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (hasHeading) canvas.rotate(-heading * math.pi / 180);

    // Dial
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = colors.secondary
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Direction labels
    const labels = [
      ('شمال', 0.0),
      ('شرق', 90.0),
      ('جنوب', 180.0),
      ('غرب', 270.0),
    ];
    for (final (label, angle) in labels) {
      final a = angle * math.pi / 180 - math.pi / 2;
      final offset = Offset(math.cos(a), math.sin(a)) * (radius - 20);
      final isNorth = angle == 0;
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isNorth ? colors.foreground : colors.mutedForeground,
            fontFamily: 'Inter',
            fontFamilyFallback: const ['NotoSansArabic'],
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, offset - Offset(tp.width / 2, tp.height / 2));
    }

    // Qibla needle (rotated by bearing within the dial)
    canvas.rotate(bearing * math.pi / 180);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-1.5, -radius + 31, 1.5, -radius + 98),
        const Radius.circular(2),
      ),
      Paint()..color = colors.primary,
    );
    final kaabaRect = RRect.fromRectAndRadius(
      const Rect.fromLTRB(-17, -radius + 31 - 34, 17, -radius + 31),
      const Radius.circular(11),
    );
    canvas.drawRRect(kaabaRect, Paint()..color = colors.primary);
    // Kaaba cube icon
    final cube = Path()
      ..moveTo(-8, -radius + 31 - 26)
      ..lineTo(0, -radius + 31 - 30)
      ..lineTo(8, -radius + 31 - 26)
      ..lineTo(8, -radius + 31 - 14)
      ..lineTo(0, -radius + 31 - 9)
      ..lineTo(-8, -radius + 31 - 14)
      ..close();
    canvas.drawPath(cube, Paint()..color = colors.primaryForeground);
    canvas.restore();

    // Center hub
    canvas.drawCircle(
      center,
      7.5,
      Paint()..color = colors.card,
    );
    canvas.drawCircle(
      center,
      7.5,
      Paint()
        ..color = colors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_CompassPainter oldDelegate) =>
      oldDelegate.heading != heading ||
      oldDelegate.bearing != bearing ||
      oldDelegate.relative != relative ||
      oldDelegate.hasHeading != hasHeading ||
      oldDelegate.colors != colors;
}
