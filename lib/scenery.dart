import 'dart:math' as math;
import 'dart:ui';

import 'levels.dart';

const amber = Color(0xffffc477);
const violet = Color(0xffb9a3ff);
const midnight = Color(0xff101125);

Paint _ink(Color color) => Paint()..color = color;

List<Offset> _makeStars() {
  final random = math.Random(43);
  return List.generate(
    78,
    (_) => Offset(random.nextDouble(), random.nextDouble()),
  );
}

final _stars = _makeStars();

void paintCity(
  Canvas canvas,
  double width,
  double height,
  double camera,
  double shadow,
) {
  final sky = Rect.fromLTWH(0, 0, width, height);
  canvas.drawRect(
    sky,
    Paint()
      ..shader = Gradient.linear(
        Offset.zero,
        Offset(width * .77, height),
        [
          const Color(0xff111429),
          const Color(0xff23203d),
          Color.lerp(const Color(0xff4e3440), const Color(0xff372e59), shadow)!,
        ],
        [0, .55, 1],
      ),
  );

  final moon = Offset(
    width * .76 - (camera * .035) % (width * .35),
    height * .28,
  );
  final radius = height * .105;
  final halo = Color.lerp(amber, violet, shadow)!;
  canvas.drawCircle(
    moon,
    radius * 2.8,
    Paint()
      ..shader = Gradient.radial(moon, radius * 2.8, [
        halo.withValues(alpha: .23),
        halo.withValues(alpha: 0),
      ]),
  );
  final disc = Color.lerp(
    const Color(0xfff8bd87),
    const Color(0xffc7b8e9),
    shadow,
  )!;
  canvas.drawCircle(moon, radius, _ink(disc));
  canvas.save();
  canvas.clipPath(
    Path()..addOval(Rect.fromCircle(center: moon, radius: radius)),
  );
  for (var band = 1; band < 5; band++) {
    final y = moon.dy + radius * (.32 + band * .15);
    canvas.drawRect(
      Rect.fromLTWH(moon.dx - radius, y, radius * 2, band * .80),
      _ink(const Color(0xff41334d).withValues(alpha: .18)),
    );
  }
  canvas.restore();
  for (final (index, star) in _stars.indexed) {
    final x = (star.dx * width - camera * .035) % width;
    final y = star.dy * height * .60;
    if ((Offset(x, y) - moon).distanceSquared < radius * radius * 1.25) {
      continue;
    }
    canvas.drawCircle(
      Offset(x, y),
      index % 13 == 0 ? 1.55 : .78,
      _ink(const Color(0xffeee8ff).withValues(alpha: .20 + (index % 5) * .10)),
    );
  }

  _skyline(
    canvas,
    width,
    height,
    camera * .15,
    76,
    .55,
    const Color(0xff35304c),
    const Color(0xff876164),
    11,
  );
  _skyline(
    canvas,
    width,
    height,
    camera * .28,
    113,
    .68,
    const Color(0xff25243f),
    const Color(0xff805959),
    29,
  );
  _skyline(
    canvas,
    width,
    height,
    camera * .48,
    151,
    .81,
    const Color(0xff1a1b33),
    const Color(0xff855c60),
    62,
  );
  final haze = Rect.fromLTWH(0, height * .65, width, height * .35);
  canvas.drawRect(
    haze,
    Paint()
      ..shader = Gradient.linear(haze.topCenter, haze.bottomCenter, [
        const Color(0x00101224),
        const Color(0xe9101124),
      ]),
  );
}

void _skyline(
  Canvas canvas,
  double width,
  double height,
  double offset,
  int pitch,
  double baseline,
  Color wall,
  Color window,
  int seed,
) {
  final first = (offset / pitch).floor() - 1;
  final last = ((offset + width) / pitch).ceil();
  final floor = height * (baseline + .34);
  final body = _ink(wall);
  final lit = _ink(window);
  for (var block = first; block <= last; block++) {
    final pattern = (block * 167 + block * block * 31 + seed * 83) % 187;
    final left = block * pitch - offset;
    final top = height * baseline - (35 + pattern * .67);
    final edge = left + pitch - (7 + pattern % 15);
    canvas.drawRect(Rect.fromLTRB(left, top, edge, floor), body);
    canvas.drawRect(Rect.fromLTRB(left - 4, top - 5, edge + 4, top + 3), body);
    if (pattern % 3 == 0) {
      canvas.drawRect(
        Rect.fromLTWH(left + pitch * .49, top - 34, 13, 36),
        body,
      );
      canvas.drawRect(
        Rect.fromLTWH(left + pitch * .49 + 5, top - 51, 2, 18),
        body,
      );
    }
    for (var row = 0; row < 5; row++) {
      for (var col = 0; col < 5; col++) {
        final x = left + 12 + col * pitch * .16;
        final y = top + 20 + row * 23;
        if (x + 6 < edge &&
            y < floor &&
            (pattern + row * 17 + col * 13) % 8 < 3) {
          canvas.drawRect(Rect.fromLTWH(x, y, 4 + pitch * .021, 6), lit);
        }
      }
    }
  }
}

void paintRoof(Canvas canvas, Rect roof, Surface surface, bool solid) {
  if (surface == Surface.stone) {
    final facade = Rect.fromLTRB(
      roof.left + 4,
      roof.top + 8,
      roof.right - 4,
      roof.top + 140,
    );
    canvas.drawRect(
      facade,
      Paint()
        ..shader = Gradient.linear(facade.topCenter, facade.bottomCenter, [
          const Color(0xff232642),
          const Color(0x0014172c),
        ]),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(roof, const Radius.circular(3)),
      _ink(const Color(0xff383954)),
    );
    canvas.drawRect(
      Rect.fromLTWH(roof.left, roof.top, roof.width, 3),
      _ink(const Color(0xffa5a0bd)),
    );
    canvas.drawRect(
      Rect.fromLTWH(roof.left + 4, roof.top + 8, roof.width - 8, 1),
      _ink(const Color(0xff525273)),
    );
    for (var x = roof.left + 19; x < roof.right - 11; x += 39) {
      final lit = (x / 17).floor().isOdd;
      canvas.drawRect(
        Rect.fromLTWH(x, roof.top + 37, 12, 18),
        _ink(lit ? const Color(0xff79505b) : const Color(0xff171b33)),
      );
      if (lit) {
        canvas.drawRect(
          Rect.fromLTWH(x + 2, roof.top + 38, 8, 2),
          _ink(const Color(0xffb67d69)),
        );
      }
    }
    return;
  }

  final isLight = surface == Surface.light;
  final color = isLight ? amber : violet;
  final shape = RRect.fromRectAndRadius(roof, Radius.circular(isLight ? 6 : 0));
  if (solid) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(roof.inflate(4), const Radius.circular(8)),
      _ink(color.withValues(alpha: .22))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }
  canvas.drawRRect(shape, _ink(color.withValues(alpha: solid ? .24 : .05)));
  canvas.drawRRect(
    shape,
    _ink(color.withValues(alpha: solid ? .96 : .47))
      ..style = PaintingStyle.stroke
      ..strokeWidth = solid ? 2 : 1,
  );
  canvas.save();
  canvas.clipRRect(shape);
  for (var x = roof.left - 8; x <= roof.right; x += isLight ? 38 : 13) {
    final mark = _ink(color.withValues(alpha: solid ? .48 : .20));
    if (isLight) {
      canvas.drawLine(
        Offset(x, roof.center.dy),
        Offset(x + 12, roof.center.dy),
        mark,
      );
    } else {
      canvas.drawLine(Offset(x, roof.bottom), Offset(x + 13, roof.top), mark);
    }
  }
  canvas.restore();
  final icon = roof.center.translate(0, -13);
  final edge = _ink(color.withValues(alpha: solid ? 1 : .6));
  if (isLight) {
    canvas.drawCircle(icon, 3, edge);
    for (var i = 0; i < 8; i++) {
      final ray = Offset(math.cos(i * math.pi / 4), math.sin(i * math.pi / 4));
      canvas.drawLine(icon + ray * 5, icon + ray * 8, edge..strokeWidth = 1.4);
    }
  } else {
    canvas.drawPath(
      Path()
        ..moveTo(icon.dx + 4, icon.dy - 7)
        ..cubicTo(
          icon.dx - 11,
          icon.dy - 8,
          icon.dx - 9,
          icon.dy + 12,
          icon.dx + 7,
          icon.dy + 4,
        )
        ..quadraticBezierTo(icon.dx - 2, icon.dy + 4, icon.dx + 4, icon.dy - 7)
        ..close(),
      edge,
    );
  }
}

void paintBeacon(Canvas canvas, Offset foot, double t) {
  canvas.save();
  canvas.translate(foot.dx, foot.dy);
  final center = const Offset(0, -65);
  canvas.drawCircle(
    center,
    55,
    Paint()
      ..shader = Gradient.radial(center, 55, [
        amber.withValues(alpha: .26 + .08 * math.sin(t * 4)),
        const Color(0x00ffc477),
      ]),
  );
  canvas.drawRect(
    const Rect.fromLTWH(-16, -10, 32, 10),
    _ink(const Color(0xff605574)),
  );
  canvas.drawRect(
    const Rect.fromLTWH(-3, -63, 6, 54),
    _ink(const Color(0xff8d7992)),
  );
  final diamond = Path()
    ..moveTo(0, -87)
    ..lineTo(16, -66)
    ..lineTo(0, -46)
    ..lineTo(-16, -66)
    ..close();
  canvas.drawPath(diamond, _ink(const Color(0xff9c5d56)));
  canvas.drawPath(
    diamond,
    _ink(amber)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  canvas.drawCircle(center, 5, _ink(const Color(0xfffff0c8)));
  canvas.restore();
}

void paintCourier(
  Canvas canvas,
  Offset foot, {
  required int facing,
  required double? stride,
  required bool inLight,
  double landing = 0,
}) {
  canvas.save();
  canvas.translate(foot.dx, foot.dy);
  canvas.scale(facing.toDouble(), 1 - landing * .56);
  final swing = stride == null ? 5.8 : math.sin(stride * math.pi * 2) * 6.8;
  final lamp = Offset(17, -18 + swing * .18);
  final glow = inLight ? amber : violet;
  canvas.drawCircle(
    lamp,
    31,
    Paint()
      ..shader = Gradient.radial(lamp, 31, [
        glow.withValues(alpha: .48),
        glow.withValues(alpha: 0),
      ]),
  );
  final dark = _ink(const Color(0xff1d2039));
  final suit = _ink(const Color(0xff666785));
  final edge = _ink(const Color(0xffbdacce))..strokeWidth = 1.35;
  final boot = _ink(const Color(0xff201c35))
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(
    const Offset(-4, -13),
    Offset(-4 - swing, stride == null ? -5 : -2),
    boot,
  );
  canvas.drawLine(
    const Offset(4, -13),
    Offset(5 + swing, stride == null ? -7 : -2),
    boot,
  );
  final scarf = Path()
    ..moveTo(-6, -29)
    ..quadraticBezierTo(-17, -32 - swing / 2, -23, -28 - swing)
    ..lineTo(-17, -23 - swing)
    ..lineTo(-5, -26)
    ..close();
  canvas.drawPath(scarf, _ink(const Color(0xffde8a79)));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(-11, -26, 8, 15),
      const Radius.circular(3),
    ),
    _ink(const Color(0xff936b74)),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(-8, -28, 17, 17),
      const Radius.circular(5),
    ),
    suit,
  );
  canvas.drawCircle(const Offset(1, -34), 10, dark);
  canvas.drawArc(
    const Rect.fromLTWH(-9, -44, 20, 20),
    3.37,
    2.46,
    false,
    edge..style = PaintingStyle.stroke,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(1, -37, 11, 6),
      const Radius.circular(2),
    ),
    _ink(const Color(0xffa98191)),
  );
  canvas.drawLine(
    const Offset(0, -28),
    const Offset(9, -28),
    _ink(const Color(0xfff0a183))..strokeWidth = 2.8,
  );
  canvas.drawLine(
    const Offset(6, -23),
    lamp.translate(-1, -7),
    suit
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: lamp, width: 9, height: 12),
      const Radius.circular(2),
    ),
    dark,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: lamp, width: 6, height: 8),
      const Radius.circular(1.5),
    ),
    _ink(glow),
  );
  canvas.drawCircle(lamp, 1.5, _ink(const Color(0xfffff0d7)));
  canvas.restore();
}
