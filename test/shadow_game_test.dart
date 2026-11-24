import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_jump/levels.dart';
import 'package:shadow_jump/shadow_game.dart';

ShadowGame _start(Level level, [void Function(int)? finish]) {
  final game = ShadowGame(onFinish: finish ?? (_) {}, onSound: (_) {});
  game.onGameResize(Vector2(960, 540));
  game.begin(level);
  return game..playing = true;
}

void _advance(ShadowGame game, int frames) {
  for (var frame = 0; frame < frames; frame++) {
    game.update(ShadowGame.step);
  }
}

void _until(
  ShadowGame game,
  bool Function() condition, {
  int limit = 360,
  String? reason,
}) {
  for (var frame = 0; frame < limit && !condition(); frame++) {
    _advance(game, 1);
  }
  expect(condition(), isTrue, reason: reason);
}

void main() {
  for (final level in levels) {
    test('${level.en} can be completed in its target time', () {
      int? time;
      final game = _start(level, (value) => time = value);
      game.move(1);
      final mainRoute = level.platforms.where((roof) => roof.y >= 350).toList();
      for (final (index, roof) in mainRoute.skip(1).indexed) {
        final previous = mainRoute[index];
        _until(
          game,
          () => game.x >= game.platformRect(previous, game.elapsed).right - 24,
          reason: 'Reach the edge before roof ${index + 1}',
        );
        final needsFlip = !game.active(roof);
        if (needsFlip && previous.surface == Surface.stone) game.flip();
        game.jump();
        _advance(game, 25);
        if (needsFlip && previous.surface != Surface.stone) game.flip();
        _until(
          game,
          () => game.ground == roof || time != null,
          limit: 110,
          reason: 'Land on roof ${index + 1}',
        );
      }
      _until(game, () => time != null, reason: 'Deliver the lantern');
      expect(time, inInclusiveRange(20000, 45000));
    });
  }

  test('Lighthouse high route reaches the lighthouse sooner', () {
    final level = levels.last;
    int? time;
    final game = _start(level, (value) => time = value);
    game.move(1);
    for (final (index, roof) in level.platforms.skip(1).take(9).indexed) {
      final previous = level.platforms[index];
      _until(game, () => game.x >= previous.x + previous.width - 24);
      game.jump();
      _advance(game, 25);
      _until(game, () => game.ground == roof);
    }
    _until(game, () => game.x >= 6310);
    game.flip();
    game.jump();
    final highRoute = level.platforms.where((roof) => roof.y < 350).toList();
    _advance(game, 25);
    _until(game, () => game.ground == highRoute.first);
    for (final (index, roof) in highRoute.skip(1).indexed) {
      final previous = highRoute[index];
      _until(
        game,
        () => game.x >= game.platformRect(previous, game.elapsed).right - 17,
      );
      game.jump();
      _advance(game, 25);
      if (!game.active(roof)) game.flip();
      _until(game, () => game.ground == roof);
    }
    _until(game, () => time != null);
    expect(time, inInclusiveRange(20000, 23800));
  });

  test('Alley shadow bridge remains intangible until the airborne switch', () {
    final level = levels[1];
    final lightRoof = level.platforms[2];
    final shadowRoof = level.platforms[3];
    final game = _start(level);
    game.x = lightRoof.x + lightRoof.width - 24;
    game.y = lightRoof.y;
    game.ground = lightRoof;
    game.move(1);
    game.jump();
    _advance(game, 25);
    final twin = _start(level);
    twin.x = lightRoof.x + lightRoof.width - 24;
    twin.y = lightRoof.y;
    twin.ground = lightRoof;
    twin.move(1);
    twin.jump();
    _advance(twin, 25);
    twin.flip();
    _advance(game, 1);
    _advance(twin, 1);
    expect(twin.x, game.x);
    expect(twin.y, game.y);
    expect(twin.vy, game.vy);
    _until(twin, () => twin.ground == shadowRoof);
    _until(game, () => !game.started);
    expect(game.x, level.startX);
    expect(game.y, level.startY);
    expect(game.elapsed, 0);
    expect(game.light, level.startsInLight);
    expect(game.direction, 0);
  });

  test('Pause freezes the character, timer and moving platforms', () {
    final level = levels[2];
    final game = _start(level);
    final moving = level.platforms.firstWhere((roof) => roof.travel != 0);
    game.move(1);
    _advance(game, 50);
    game.jump();
    _advance(game, 20);
    game.playing = false;
    final state = (
      game.x,
      game.y,
      game.elapsed,
      game.platformRect(moving, game.elapsed),
    );
    _advance(game, 120);
    expect((
      game.x,
      game.y,
      game.elapsed,
      game.platformRect(moving, game.elapsed),
    ), state);
    game.begin(level, newVisit: false);
    expect(game.platformRect(moving, game.elapsed).left, moving.x);
    expect(game.platformRect(moving, game.elapsed).top, moving.y);
  });
}
