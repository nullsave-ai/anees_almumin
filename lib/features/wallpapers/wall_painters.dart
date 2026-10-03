import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// تصاميم الخلفيات تُرسم برمجيًا (بدون صور) فلا حقوق نشر ولا حجم إضافي.
/// sky للمعاينة الحية فقط (لقطة بحسب وقت اليوم).
enum WallDesign { sky, grass, dawn, night, pattern, sunset, crescent }

const wallNames = {
  WallDesign.sky: 'سماء الصلاة',
  WallDesign.grass: 'عشب',
  WallDesign.dawn: 'الفجر',
  WallDesign.night: 'ليل ونجوم',
  WallDesign.pattern: 'زخرفة',
  WallDesign.sunset: 'الغروب',
  WallDesign.crescent: 'هلال',
};

class WallPainter extends CustomPainter {
  const WallPainter(this.design);
  final WallDesign design;

  @override
  void paint(Canvas canvas, Size size) => paintWall(canvas, size, design);

  @override
  bool shouldRepaint(WallPainter old) => old.design != design;
}

void _grad(Canvas c, Size s, List<Color> colors, [List<double>? stops]) {
  c.drawRect(
    Offset.zero & s,
    Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, s.height), colors, stops),
  );
}

void _glow(Canvas c, Offset o, double r, Color color, int alpha) {
  c.drawCircle(o, r, Paint()..shader = ui.Gradient.radial(o, r, [color.withAlpha(alpha), color.withAlpha(0)]));
}

void _stars(Canvas c, Size s, int n, int seed, {double maxY = .75}) {
  final r = math.Random(seed);
  final k = s.width / 1080;
  final p = Paint();
  for (var i = 0; i < n; i++) {
    p.color = Colors.white.withAlpha(90 + r.nextInt(160));
    c.drawCircle(Offset(r.nextDouble() * s.width, r.nextDouble() * s.height * maxY), (.7 + r.nextDouble() * 1.8) * k, p);
  }
}

void _crescent(Canvas c, Offset o, double r, Color color) {
  _glow(c, o, r * 2.2, color, 70);
  final a = Path()..addOval(Rect.fromCircle(center: o, radius: r));
  final b = Path()..addOval(Rect.fromCircle(center: o.translate(r * .45, -r * .15), radius: r * .86));
  c.drawPath(Path.combine(PathOperation.difference, a, b), Paint()..color = color);
}

void _blades(Canvas c, Size s, {int n = 70, int seed = 3}) {
  final r = math.Random(seed);
  final k = s.width / 1080;
  const shades = [Color(0xFF4F9D2D), Color(0xFF5CAA30), Color(0xFF3F8A22), Color(0xFF6BB83A)];
  final p = Paint();
  for (var i = 0; i < n; i++) {
    final x = r.nextDouble() * s.width;
    final ht = (.12 + r.nextDouble() * .18) * s.height;
    final lean = (r.nextDouble() - .5) * ht * .3;
    final path = Path()
      ..moveTo(x - 7 * k, s.height)
      ..quadraticBezierTo(x + lean * .4, s.height - ht * .55, x + lean, s.height - ht)
      ..quadraticBezierTo(x + lean * .4 + 4 * k, s.height - ht * .5, x + 7 * k, s.height)
      ..close();
    p.color = shades[i % shades.length];
    c.drawPath(path, p);
  }
}

void _dunes(Canvas c, Size s, List<Color> layers, double baseY) {
  for (var i = 0; i < layers.length; i++) {
    final y = s.height * (baseY + i * .07);
    final path = Path()..moveTo(0, s.height)..lineTo(0, y);
    for (var x = 0.0; x <= s.width; x += 12) {
      path.lineTo(x, y + math.sin(x / s.width * math.pi * (1.4 + i * .5) + i) * s.height * .03);
    }
    path
      ..lineTo(s.width, s.height)
      ..close();
    c.drawPath(path, Paint()..color = layers[i]);
  }
}

void _pattern(Canvas c, Size s) {
  final cell = s.width / 3.5;
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = s.width / 360
    ..color = const Color(0xFF7CC24A).withAlpha(90);
  final gold = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = s.width / 420
    ..color = const Color(0xFFDDB75A).withAlpha(120);
  for (var gy = -.5; gy * cell < s.height + cell; gy += 1) {
    for (var gx = -.5; gx * cell < s.width + cell; gx += 1) {
      final o = Offset(gx * cell + cell / 2, gy * cell + cell / 2);
      c.save();
      c.translate(o.dx, o.dy);
      for (var k = 0; k < 2; k++) {
        c.save();
        c.rotate(k * math.pi / 4);
        c.drawRect(Rect.fromCenter(center: Offset.zero, width: cell * .62, height: cell * .62), line);
        c.restore();
      }
      c.drawCircle(Offset.zero, cell * .17, gold);
      c.restore();
    }
  }
}

void _skySnapshot(Canvas c, Size s) {
  final now = DateTime.now();
  final h = now.hour + now.minute / 60;
  if (h >= 5 && h < 7) {
    paintWall(c, s, WallDesign.dawn);
  } else if (h >= 17 && h < 19.5) {
    paintWall(c, s, WallDesign.sunset);
  } else if (h >= 7 && h < 17) {
    _grad(c, s, const [Color(0xFF2F80D8), Color(0xFF8CC8F0), Color(0xFFCBE3F0)]);
    _glow(c, Offset(s.width * .78, s.height * .22), s.width * .3, const Color(0xFFFFE9A8), 150);
    c.drawCircle(Offset(s.width * .78, s.height * .22), s.width * .07, Paint()..color = const Color(0xFFFFF1B8));
    final cloud = Paint()..color = Colors.white.withAlpha(70);
    for (var i = 0; i < 4; i++) {
      c.drawOval(Rect.fromLTWH(s.width * (.1 + i * .22), s.height * (.18 + (i % 2) * .12), s.width * .3, s.width * .08), cloud);
    }
  } else {
    paintWall(c, s, WallDesign.night);
  }
}

void paintWall(Canvas c, Size s, WallDesign d) {
  switch (d) {
    case WallDesign.sky:
      _skySnapshot(c, s);
    case WallDesign.grass:
      _grad(c, s, const [Color(0xFFCDEFA9), Color(0xFF7FC24A), Color(0xFF2F7A1E)], const [0, .55, 1]);
      _glow(c, Offset(s.width * .82, s.height * .14), s.width * .5, const Color(0xFFFFF6C8), 150);
      _blades(c, s);
    case WallDesign.dawn:
      _grad(c, s, const [Color(0xFF2B2F6B), Color(0xFF8A5A9C), Color(0xFFF5A96B), Color(0xFFFFE3A6)], const [0, .4, .72, 1]);
      _glow(c, Offset(s.width * .5, s.height * .66), s.width * .6, const Color(0xFFFFE3A6), 160);
      _dunes(c, s, const [Color(0xFF3A2F55), Color(0xFF241C3D)], .72);
    case WallDesign.night:
      _grad(c, s, const [Color(0xFF050816), Color(0xFF0E1633)]);
      _stars(c, s, 160, 7);
      _crescent(c, Offset(s.width * .72, s.height * .2), s.width * .1, const Color(0xFFFFE9A8));
    case WallDesign.pattern:
      _grad(c, s, const [Color(0xFF0F2A14), Color(0xFF1C4A1E)]);
      _pattern(c, s);
    case WallDesign.sunset:
      _grad(c, s, const [Color(0xFF2B1B4D), Color(0xFF9C3D6B), Color(0xFFFF7A45), Color(0xFFFFC16B)], const [0, .35, .7, 1]);
      _glow(c, Offset(s.width * .5, s.height * .68), s.width * .55, const Color(0xFFFFC16B), 150);
      _dunes(c, s, const [Color(0xFF3B1E3F), Color(0xFF241228), Color(0xFF130A18)], .74);
    case WallDesign.crescent:
      _grad(c, s, const [Color(0xFF0A2411), Color(0xFF154D1F)]);
      _stars(c, s, 40, 21, maxY: .6);
      _crescent(c, Offset(s.width * .5, s.height * .33), s.width * .2, const Color(0xFFDDB75A));
  }
}

/// يرسم التصميم إلى ملف PNG بدقة الشاشة (بحد أقصى 1440 بكسل عرضًا) ويعيد مساره.
Future<String> renderWallToFile(WallDesign d, Size px) async {
  final scale = px.width > 1440 ? 1440 / px.width : 1.0;
  final size = Size((px.width * scale).roundToDouble(), (px.height * scale).roundToDouble());
  final rec = ui.PictureRecorder();
  paintWall(Canvas(rec), size, d);
  final img = await rec.endRecording().toImage(size.width.toInt(), size.height.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/wall_${d.name}.png');
  await f.writeAsBytes(data!.buffer.asUint8List(), flush: true);
  return f.path;
}
