enum Surface { stone, light, shadow }

class PlatformSpec {
  const PlatformSpec(
    this.x,
    this.y,
    this.width,
    this.surface, {
    this.travel = 0,
    this.rise = 0,
    this.period = 3.2,
  });

  final double x, y, width, travel, rise, period;
  final Surface surface;
}

class Level {
  const Level({
    required this.ru,
    required this.en,
    required this.platforms,
    required this.finishes,
    this.startX = 80,
    this.startY = 398,
    this.fallY = 630,
    this.startsInLight = true,
  });

  final String ru, en;
  final List<PlatformSpec> platforms;
  final List<({double x, double y})> finishes;
  final double startX, startY, fallY;
  final bool startsInLight;
}

const _stone = Surface.stone;
const _light = Surface.light;
const _shadow = Surface.shadow;

// Each row gives the gap, width, top and surface of the next roof.
typedef _Roof = (double, double, double, Surface);

Level _route(
  String ru,
  String en,
  List<_Roof> roofs, {
  Map<int, (double, double, double)> motion = const {},
  List<PlatformSpec> alternatives = const [],
  ({double x, double y})? shortcutFinish,
}) {
  var right = 460.0;
  final platforms = [const PlatformSpec(-90, 398, 550, _stone)];
  for (final (index, (gap, width, top, surface)) in roofs.indexed) {
    final x = right + gap;
    final (travel, rise, period) = motion[index] ?? (0.0, 0.0, 3.2);
    platforms.add(
      PlatformSpec(
        x,
        top,
        width,
        surface,
        travel: travel,
        rise: rise,
        period: period,
      ),
    );
    right = x + width;
  }
  final last = platforms.last;
  return Level(
    ru: ru,
    en: en,
    platforms: List.unmodifiable([...platforms, ...alternatives]),
    finishes: List.unmodifiable([(x: right - 77, y: last.y), ?shortcutFinish]),
  );
}

final levels = [
  _route('Мастерская', 'Workshop', const [
    (105, 420, 398, _stone),
    (145, 400, 394, _shadow),
    (120, 510, 383, _stone),
    (150, 365, 367, _light),
    (135, 505, 398, _stone),
    (160, 360, 378, _shadow),
    (145, 530, 398, _stone),
    (185, 440, 380, _light),
    (140, 535, 358, _stone),
    (175, 390, 369, _shadow),
    (170, 600, 391, _stone),
    (155, 400, 370, _light),
    (160, 520, 390, _stone),
  ]),
  _route('Переулок', 'Alley', const [
    (115, 410, 392, _stone),
    (160, 160, 380, _light),
    (220, 170, 373, _shadow),
    (175, 735, 398, _stone),
    (145, 210, 380, _shadow),
    (220, 205, 369, _light),
    (170, 670, 387, _stone),
    (165, 200, 365, _light),
    (230, 160, 372, _shadow),
    (180, 630, 398, _stone),
    (185, 190, 374, _shadow),
    (220, 180, 384, _light),
    (170, 550, 394, _stone),
    (192, 480, 370, _stone),
    (176, 510, 386, _stone),
  ]),
  _route(
    'Часовая башня',
    'Clock Tower',
    const [
      (165, 610, 398, _stone),
      (185, 170, 372, _shadow),
      (170, 555, 352, _stone),
      (170, 170, 365, _light),
      (170, 570, 389, _stone),
      (195, 160, 365, _shadow),
      (165, 620, 350, _stone),
      (192, 190, 376, _light),
      (178, 630, 390, _stone),
      (196, 168, 370, _shadow),
      (166, 680, 357, _stone),
      (185, 181, 375, _light),
      (170, 590, 387, _stone),
      (195, 570, 370, _stone),
    ],
    motion: const {
      1: (49, 12, 2.8),
      3: (45, 16, 3.1),
      5: (57, 13, 3.4),
      7: (52, 13, 3),
      9: (55, 17, 3.7),
      11: (51, 14, 3.4),
    },
  ),
  _route('Крыши', 'Rooftops', const [
    (170, 190, 380, _light),
    (219, 150, 365, _shadow),
    (218, 160, 353, _light),
    (180, 750, 392, _stone),
    (170, 160, 376, _shadow),
    (225, 140, 364, _light),
    (220, 150, 356, _shadow),
    (190, 750, 395, _stone),
    (182, 158, 365, _light),
    (220, 156, 359, _shadow),
    (220, 165, 373, _light),
    (192, 740, 391, _stone),
    (173, 170, 375, _shadow),
    (225, 155, 364, _light),
    (225, 156, 370, _shadow),
    (190, 710, 388, _stone),
    (180, 620, 375, _stone),
  ]),
  _route(
    'Маяк',
    'Lighthouse',
    const [
      (180, 585, 395, _stone),
      (192, 380, 398, _stone),
      (194, 345, 408, _stone),
      (192, 500, 397, _stone),
      (182, 660, 391, _stone),
      (182, 380, 399, _stone),
      (190, 350, 405, _stone),
      (195, 540, 392, _stone),
      (185, 630, 398, _stone),
      (186, 400, 405, _stone),
      (184, 350, 403, _stone),
      (182, 550, 395, _stone),
      (190, 650, 375, _stone),
    ],
    alternatives: const [
      PlatformSpec(6480, 330, 210, _shadow),
      PlatformSpec(6894, 264, 216, _light, travel: 23),
      PlatformSpec(7310, 260, 215, _shadow),
      PlatformSpec(7738, 253, 230, _light),
      PlatformSpec(8180, 245, 320, _stone),
    ],
    shortcutFinish: (x: 8430, y: 245),
  ),
];
