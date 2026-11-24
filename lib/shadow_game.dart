import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'levels.dart';
import 'scenery.dart';

enum GameSound { step, jump, land, flip, fall, finish }

class ShadowGame extends FlameGame {
  ShadowGame({required this.onFinish, required this.onSound, this.onFall});

  static const step = 1 / 120;
  static const speed = 365.0;
  static const gravity = 1300.0;
  static const jumpSpeed = 560.0;
  static const playerHalfWidth = 12.0;

  final void Function(int milliseconds) onFinish;
  final void Function(GameSound sound) onSound;
  final VoidCallback? onFall;
  final hud = ValueNotifier((ms: 0, light: true, hint: false));

  Level level = levels.first;
  bool playing = false;
  bool light = true;
  bool started = false;
  bool showHint = false;
  bool _seenWorkshopHint = false;
  int direction = 0;
  int facing = 1;
  double x = 80, y = 398, vy = 0, elapsed = 0, cameraX = 0;
  double flash = 0, landing = 0, runPhase = 0;
  double _shadowBlend = 0;
  double _accumulator = 0, _buffer = 0, _coyote = 0;
  bool _flip = false;
  PlatformSpec? ground;

  double get viewScale => math.min(size.x / 960, size.y / 540);
  double get viewWidth => size.x > 0 && size.y > 0 ? size.x / viewScale : 960;
  double get viewHeight => size.x > 0 && size.y > 0 ? size.y / viewScale : 540;

  void begin(Level next, {bool newVisit = true}) {
    level = next;
    if (newVisit) _seenWorkshopHint = false;
    x = next.startX;
    y = next.startY;
    ground = next.platforms.first;
    light = next.startsInLight;
    _shadowBlend = light ? 0 : 1;
    started = false;
    elapsed = vy = flash = landing = runPhase = _accumulator = _coyote = 0;
    cameraX = 0;
    facing = 1;
    clearInput();
    _publish();
  }

  void clearInput() {
    direction = 0;
    _buffer = 0;
    _flip = false;
  }

  void move(int value) {
    if (!playing) return;
    direction = value;
    if (value != 0) started = true;
  }

  void jump() {
    if (!playing) return;
    started = true;
    _buffer = .12;
  }

  void flip() {
    if (!playing) return;
    started = true;
    _flip = !_flip;
  }

  bool active(PlatformSpec roof) => switch (roof.surface) {
    Surface.stone => true,
    Surface.light => light,
    Surface.shadow => !light,
  };

  Rect platformRect(PlatformSpec roof, double time) {
    final phase = time * 2 * math.pi / roof.period;
    return Rect.fromLTWH(
      roof.x + roof.travel * math.sin(phase),
      roof.y + roof.rise * math.sin(phase),
      roof.width,
      roof.surface == Surface.stone ? 23 : 15,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!playing) return;
    _accumulator += math.min(dt, .125);
    while (_accumulator >= step && playing) {
      _accumulator -= step;
      _simulate();
    }
    _publish();
  }

  void _simulate() {
    final before = elapsed;
    if (started) elapsed += step;
    flash = math.max(0, flash - step);
    landing = math.max(0, landing - step);

    if (_flip) {
      _flip = false;
      light = !light;
      _seenWorkshopHint = true;
      flash = .22;
      onSound(GameSound.flip);
    }
    _shadowBlend += ((light ? 0 : 1) - _shadowBlend) * step * 11;

    final standing = ground;
    if (standing != null) {
      final now = platformRect(standing, elapsed);
      if (active(standing)) {
        x += now.left - platformRect(standing, before).left;
        y = now.top;
        _coyote = .10;
      } else {
        ground = null;
        _coyote = 0;
      }
    }

    if (direction != 0) {
      facing = direction;
      x = math.max(-40, x + direction * speed * step);
    }
    if (ground case final roof?) {
      if (!_overlaps(x, platformRect(roof, elapsed))) ground = null;
    }

    if (_buffer > 0 && (ground != null || _coyote > 0)) {
      _buffer = _coyote = 0;
      ground = null;
      vy = -jumpSpeed;
      onSound(GameSound.jump);
    }

    if (ground == null) {
      final previousY = y;
      y += vy * step + gravity * step * step / 2;
      vy += gravity * step;
      if (vy >= 0) _land(previousY, before);
    } else if (direction != 0) {
      final previousStride = (runPhase * 2).floor();
      runPhase += step * 3.7;
      if ((runPhase * 2).floor() != previousStride) onSound(GameSound.step);
    }

    _buffer = math.max(0, _buffer - step);
    _coyote = math.max(0, _coyote - step);
    if (y > level.fallY) {
      onSound(GameSound.fall);
      begin(level, newVisit: false);
      onFall?.call();
      return;
    }
    if (ground != null &&
        level.finishes.any(
          (finish) => (x - finish.x).abs() < 33 && (y - finish.y).abs() < 12,
        )) {
      playing = false;
      clearInput();
      onSound(GameSound.finish);
      onFinish((elapsed * 1000).round());
      return;
    }

    final target = math.max(0, x - math.min(viewWidth * .31, 325));
    cameraX += (target - cameraX) * (1 - math.exp(-step * 10));
  }

  bool _overlaps(double center, Rect roof) =>
      center + playerHalfWidth > roof.left &&
      center - playerHalfWidth < roof.right;

  void _land(double previousY, double before) {
    PlatformSpec? support;
    var top = double.infinity;
    for (final roof in level.platforms) {
      if (!active(roof)) continue;
      final now = platformRect(roof, elapsed);
      if (now.top < top &&
          previousY <= platformRect(roof, before).top &&
          y >= now.top &&
          _overlaps(x, now)) {
        support = roof;
        top = now.top;
      }
    }
    if (support == null) return;
    ground = support;
    y = top;
    vy = 0;
    landing = .14;
    onSound(GameSound.land);
  }

  void _publish() {
    showHint =
        level == levels.first && !_seenWorkshopHint && x > 640 && x < 1040;
    hud.value = (
      ms: (elapsed * 100).floor() * 10,
      light: light,
      hint: showHint,
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0 || size.y <= 0) return;
    final scale = viewScale;
    final height = viewHeight;
    canvas.save();
    canvas.scale(scale);
    paintCity(canvas, viewWidth, height, cameraX, _shadowBlend);
    canvas.translate(-cameraX, (height - 540) * .5);
    for (final roof in level.platforms) {
      final rect = platformRect(roof, elapsed);
      if (rect.right >= cameraX && rect.left <= cameraX + viewWidth) {
        paintRoof(canvas, rect, roof.surface, active(roof));
      }
    }
    for (final finish in level.finishes) {
      if (finish.x >= cameraX - 100 && finish.x <= cameraX + viewWidth + 100) {
        paintBeacon(canvas, Offset(finish.x, finish.y), elapsed);
      }
    }
    paintCourier(
      canvas,
      Offset(x, y),
      facing: facing,
      stride: ground == null
          ? null
          : direction == 0
          ? 0
          : runPhase,
      inLight: light,
      landing: landing,
    );
    canvas.restore();
    if (flash > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()
          ..color = (light ? const Color(0xffffc477) : const Color(0xffa68bff))
              .withValues(alpha: flash * .69),
      );
    }
  }
}
