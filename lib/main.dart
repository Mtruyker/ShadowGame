import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'browser.dart' as browser;
import 'levels.dart';
import 'scenery.dart';
import 'shadow_game.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final language =
      await browser.sdkLanguage() ??
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  runApp(ShadowApp(russian: language == 'ru'));
}

String timeLabel(int milliseconds) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(milliseconds ~/ 60000)}:${two(milliseconds ~/ 1000 % 60)}'
      '.${two(milliseconds ~/ 10 % 100)}';
}

class ShadowApp extends StatelessWidget {
  const ShadowApp({super.key, required this.russian});

  final bool russian;

  @override
  Widget build(BuildContext context) {
    const foreground = Color(0xfff4e9e3);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: russian ? 'Прыжок по тени' : 'Shadow Leap',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: amber,
          onPrimary: midnight,
          secondaryContainer: Color(0xff403656),
          onSecondaryContainer: foreground,
          surface: midnight,
          onSurface: foreground,
        ),
        scaffoldBackgroundColor: midnight,
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'Roboto',
          bodyColor: foreground,
          displayColor: foreground,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(110, 46),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: foreground,
            minimumSize: const Size(110, 46),
            padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 11),
            side: const BorderSide(color: Color(0xff675874)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: _GameScreen(russian: russian),
    );
  }
}

enum _Screen { home, routes, play, pause, finish, totals }

enum _Control { left, right, jump, flip }

class _GameScreen extends StatefulWidget {
  const _GameScreen({required this.russian});

  final bool russian;

  @override
  State<_GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<_GameScreen> {
  final _records = List<int?>.filled(levels.length, null);
  final _keys = <PhysicalKeyboardKey>{};
  final _pointers = <int, _Control>{};
  late final ShadowGame _game;
  late final Widget _scene;
  late final VoidCallback _stopObserving;
  final _touch = browser.touchScreen;
  var _screen = _Screen.home;
  var _index = 0;
  var _lastTime = 0;
  var _record = false;
  var _sound = true;
  var _portrait = false;
  var _markedPlaying = false;

  String tr(String ru, String en) => widget.russian ? ru : en;
  String name(int index) => tr(levels[index].ru, levels[index].en);

  int get _next => _records.indexOf(null);

  @override
  void initState() {
    super.initState();
    _restore();
    _game = ShadowGame(
      onFinish: _finish,
      onFall: _clearInput,
      onSound: (sound) {
        if (_sound) browser.playEffect(sound.name);
      },
    );
    _scene = GameWidget(game: _game);
    _stopObserving = browser.observePage(() {
      browser.silenceAudio();
      _pause();
    });
    HardwareKeyboard.instance.addHandler(_onKey);
    WidgetsBinding.instance.addPostFrameCallback((_) => browser.gameReady());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _stopObserving();
    _setPlaying(false);
    _game.hud.dispose();
    super.dispose();
  }

  void _restore() {
    try {
      final stored = browser.loadProgress();
      if (stored == null) return;
      final data = jsonDecode(stored);
      if (data is! Map<String, dynamic>) return;
      final times = data['times'];
      if (times is List) {
        for (var i = 0; i < _records.length && i < times.length; i++) {
          final time = times[i];
          if (time is! int || time <= 0) break;
          _records[i] = time;
        }
      }
      _sound = data['sound'] != false;
    } on FormatException {
      // A damaged save leaves the default progress available.
    }
  }

  void _save() =>
      browser.saveProgress(jsonEncode({'times': _records, 'sound': _sound}));

  void _setPlaying(bool active) {
    _game.playing = active;
    if (_markedPlaying == active) return;
    _markedPlaying = active;
    browser.markGameplay(active);
  }

  void _clearInput() {
    _keys.clear();
    _pointers.clear();
    _game.clearInput();
  }

  void _show(_Screen screen) {
    _clearInput();
    _setPlaying(false);
    browser.silenceAudio();
    setState(() => _screen = screen);
  }

  void _openLevel(int index, {bool retry = false}) {
    browser.unlockAudio();
    browser.silenceAudio();
    _clearInput();
    _game.begin(levels[index], newVisit: !retry);
    setState(() {
      _index = index;
      _screen = _portrait ? _Screen.pause : _Screen.play;
    });
    _setPlaying(!_portrait);
  }

  void _pause() {
    if (!mounted || _screen != _Screen.play) return;
    _show(_Screen.pause);
  }

  void _continue() {
    if (_portrait) return;
    browser.unlockAudio();
    _clearInput();
    setState(() => _screen = _Screen.play);
    _setPlaying(true);
  }

  void _finish(int time) {
    final best = _records[_index];
    _record = best == null || time < best;
    if (_record) _records[_index] = time;
    _save();
    _clearInput();
    _setPlaying(false);
    setState(() {
      _lastTime = time;
      _screen = _Screen.finish;
    });
  }

  static final _keyboardControls = {
    PhysicalKeyboardKey.keyA: _Control.left,
    PhysicalKeyboardKey.arrowLeft: _Control.left,
    PhysicalKeyboardKey.keyD: _Control.right,
    PhysicalKeyboardKey.arrowRight: _Control.right,
    PhysicalKeyboardKey.space: _Control.jump,
    PhysicalKeyboardKey.shiftLeft: _Control.flip,
    PhysicalKeyboardKey.shiftRight: _Control.flip,
  };

  bool _onKey(KeyEvent event) {
    final key = event.physicalKey;
    if (event is KeyDownEvent && key == PhysicalKeyboardKey.escape) {
      if (_screen == _Screen.play) {
        _pause();
        return true;
      }
      if (_screen == _Screen.pause) {
        _continue();
        return true;
      }
    }
    if (_screen != _Screen.play) return false;
    if (key == PhysicalKeyboardKey.keyR) {
      if (event is KeyDownEvent) _openLevel(_index, retry: true);
      return true;
    }
    final control = _keyboardControls[key];
    if (control == null) return false;
    if (event is KeyDownEvent && _keys.add(key)) {
      _press(control);
    } else if (event is KeyUpEvent) {
      _keys.remove(key);
    }
    _updateDirection();
    return true;
  }

  void _press(_Control control) {
    browser.unlockAudio();
    switch (control) {
      case _Control.jump:
        _game.jump();
      case _Control.flip:
        _game.flip();
      case _Control.left:
      case _Control.right:
        break;
    }
  }

  void _updateDirection() {
    final active = [
      ..._keys.map((key) => _keyboardControls[key]),
      ..._pointers.values,
    ];
    _game.move(
      (active.contains(_Control.right) ? 1 : 0) -
          (active.contains(_Control.left) ? 1 : 0),
    );
  }

  void _touchDown(int pointer, _Control control) {
    _pointers[pointer] = control;
    _press(control);
    _updateDirection();
  }

  void _touchUp(int pointer) {
    _pointers.remove(pointer);
    _updateDirection();
  }

  void _mainPlay() {
    if (_next < 0) {
      _show(_Screen.routes);
    } else {
      _openLevel(_next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, layout) {
          _portrait = layout.maxWidth < layout.maxHeight;
          if (_portrait && _screen == _Screen.play) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _pause());
          }
          final menu =
              _screen == _Screen.home ||
              _screen == _Screen.routes ||
              _screen == _Screen.totals;
          return Stack(
            fit: StackFit.expand,
            children: [
              Offstage(offstage: menu, child: _scene),
              if (menu) const CustomPaint(painter: _MenuArt()),
              if (menu && _screen == _Screen.home) _home(),
              if (_screen == _Screen.routes) _routeList(),
              if (_screen == _Screen.totals) _routeList(totals: true),
              if (!menu && !_portrait) _hud(),
              if (_screen == _Screen.play && !_portrait && _touch)
                _touchControls(),
              if (_screen == _Screen.play && !_portrait && !_touch)
                _keyboardGuide(),
              if (_screen == _Screen.pause && !_portrait) _pausePanel(),
              if (_screen == _Screen.finish) _finishPanel(),
              if (_portrait &&
                  (_screen == _Screen.play || _screen == _Screen.pause))
                _rotatePanel(),
            ],
          );
        },
      ),
    );
  }

  Widget _home() {
    final completed = _records.whereType<int>().length;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, layout) {
          final compact = layout.maxWidth < 650 || layout.maxHeight < 440;
          final padding = compact
              ? 23.0
              : (layout.maxWidth * .08).clamp(45.0, 122.0);
          return Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 495),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr('Прыжок\nпо тени', 'Shadow\nLeap'),
                      style: TextStyle(
                        fontSize: compact ? 46 : 81,
                        height: .92,
                        letterSpacing: compact ? -2 : -4,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: compact ? 14 : 23),
                    Text(
                      tr(
                        'Доставь фонарь на крышу.\nМеняй свет, чтобы проложить путь.',
                        'Carry the lantern across the rooftops.\nSwitch the light to open a path.',
                      ),
                      style: TextStyle(
                        color: const Color(0xffded0e1),
                        fontSize: compact ? 14 : 17,
                        height: 1.45,
                      ),
                    ),
                    SizedBox(height: compact ? 17 : 27),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _mainPlay,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(tr('Играть', 'Play')),
                        ),
                        OutlinedButton(
                          onPressed: () => _show(_Screen.routes),
                          child: Text(tr('Выбор трассы', 'Select a route')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      tr(
                        'Пройдено $completed из ${levels.length}',
                        '$completed of ${levels.length} routes complete',
                      ),
                      style: const TextStyle(
                        color: Color(0xffbdacca),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _routeList({bool totals = false}) => _overlay(
    title: totals
        ? tr('Итоги', 'Results')
        : tr('Выбор трассы', 'Select a route'),
    content: [
      for (final (index, record) in _records.indexed)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Material(
            color: const Color(0xff29243d),
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              dense: true,
              enabled: _next < 0 || index <= _next,
              onTap: _next < 0 || index <= _next
                  ? () => _openLevel(index)
                  : null,
              leading: Icon(
                record != null
                    ? Icons.check_circle_outline
                    : index == _next
                    ? Icons.play_circle_outline
                    : Icons.lock_outline,
                size: 20,
                color: index == _next || record != null ? amber : violet,
              ),
              title: Text('${index + 1}. ${name(index)}'),
              trailing: Text(
                record != null
                    ? timeLabel(record)
                    : index == _next
                    ? '—'
                    : '',
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
    ],
    actions: [
      OutlinedButton(
        onPressed: () => _show(_Screen.home),
        child: Text(tr('В главное меню', 'Main menu')),
      ),
    ],
  );

  Widget _hud() => SafeArea(
    minimum: const EdgeInsets.fromLTRB(12, 9, 12, 0),
    child: Align(
      alignment: Alignment.topCenter,
      child: ValueListenableBuilder(
        valueListenable: _game.hud,
        builder: (context, status, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _badge(
                      Text(
                        '${_index + 1} / ${levels.length}  ·  ${name(_index)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                _badge(
                  Text(
                    timeLabel(status.ms),
                    style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                _badge(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        status.light
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        color: status.light ? amber : violet,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        status.light
                            ? tr('Свет', 'Light')
                            : tr('Тень', 'Shadow'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                IconButton.filledTonal(
                  onPressed: _screen == _Screen.play ? _pause : null,
                  icon: const Icon(Icons.pause_rounded),
                  tooltip: tr('Пауза', 'Pause'),
                ),
              ],
            ),
            if (status.hint && _screen == _Screen.play)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: _badge(
                  Text(
                    _touch
                        ? tr(
                            'Включи теневой мост кнопкой с лампой',
                            'Tap the lamp to activate the shadow bridge',
                          )
                        : tr(
                            'Нажми Shift, чтобы включить теневой мост',
                            'Press Shift to activate the shadow bridge',
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _badge(Widget child) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(9),
      color: const Color(0xe51b1c33),
      border: Border.all(color: const Color(0xff4c4563)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        child: child,
      ),
    ),
  );

  Widget _keyboardGuide() => IgnorePointer(
    child: SafeArea(
      minimum: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: _badge(
          Text(
            tr(
              'A / D или стрелки  ·  Пробел  ·  Shift  ·  R',
              'A / D or arrows  ·  Space  ·  Shift  ·  R',
            ),
          ),
        ),
      ),
    ),
  );

  Widget _touchControls() => SafeArea(
    minimum: const EdgeInsets.fromLTRB(13, 0, 13, 8),
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Row(
        children: [
          _touchButton(
            _Control.left,
            Icons.arrow_back_rounded,
            tr('Влево', 'Left'),
          ),
          const SizedBox(width: 8),
          _touchButton(
            _Control.right,
            Icons.arrow_forward_rounded,
            tr('Вправо', 'Right'),
          ),
          const Spacer(),
          _touchButton(
            _Control.flip,
            Icons.lightbulb_outline_rounded,
            tr('Переключить свет', 'Switch light'),
            color: amber,
          ),
          const SizedBox(width: 8),
          _touchButton(
            _Control.jump,
            Icons.arrow_upward_rounded,
            tr('Прыжок', 'Jump'),
          ),
        ],
      ),
    ),
  );

  Widget _touchButton(
    _Control control,
    IconData icon,
    String label, {
    Color? color,
  }) => _PointerButton(
    label: label,
    icon: icon,
    color: color,
    onDown: (pointer) => _touchDown(pointer, control),
    onUp: _touchUp,
  );

  Widget _pausePanel() => _overlay(
    title: tr('Пауза', 'Paused'),
    content: [
      SwitchListTile(
        value: _sound,
        title: Text(tr('Звук', 'Sound')),
        contentPadding: EdgeInsets.zero,
        onChanged: (value) {
          setState(() => _sound = value);
          if (!value) browser.silenceAudio();
          _save();
        },
      ),
    ],
    actions: [
      FilledButton(
        onPressed: _continue,
        child: Text(tr('Продолжить', 'Resume')),
      ),
      OutlinedButton(
        onPressed: () => _openLevel(_index, retry: true),
        child: Text(tr('Перезапуск', 'Restart')),
      ),
      OutlinedButton(
        onPressed: () => _show(_Screen.routes),
        child: Text(tr('К выбору трасс', 'Route selection')),
      ),
    ],
  );

  Widget _finishPanel() => _overlay(
    title: tr('Фонарь доставлен', 'Lantern delivered'),
    content: [
      Text(
        timeLabel(_lastTime),
        style: const TextStyle(
          color: amber,
          fontSize: 40,
          fontWeight: FontWeight.w800,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      Text(
        _record
            ? tr('Новый личный рекорд', 'New personal best')
            : tr(
                'Личный рекорд ${timeLabel(_records[_index]!)}',
                'Personal best ${timeLabel(_records[_index]!)}',
              ),
      ),
    ],
    actions: [
      FilledButton(
        onPressed: _index + 1 < levels.length
            ? () => _openLevel(_index + 1)
            : () => _show(_Screen.totals),
        child: Text(
          _index + 1 < levels.length
              ? tr('Следующая трасса', 'Next route')
              : tr('Итоги', 'Results'),
        ),
      ),
      OutlinedButton(
        onPressed: () => _openLevel(_index, retry: true),
        child: Text(tr('Повторить', 'Retry')),
      ),
      OutlinedButton(
        onPressed: () => _show(_Screen.routes),
        child: Text(tr('К выбору трасс', 'Route selection')),
      ),
    ],
  );

  Widget _rotatePanel() => _overlay(
    title: tr('Поверни устройство', 'Rotate your device'),
    content: [
      const Icon(Icons.screen_rotation_outlined, color: amber, size: 35),
      const SizedBox(height: 10),
      Text(
        tr(
          'Для прыжков нужен альбомный режим.',
          'Play in landscape to see your next landing.',
        ),
      ),
    ],
    actions: [
      OutlinedButton(
        onPressed: () => _show(_Screen.home),
        child: Text(tr('В главное меню', 'Main menu')),
      ),
    ],
  );

  Widget _overlay({
    required String title,
    required List<Widget> content,
    required List<Widget> actions,
  }) => ColoredBox(
    color: const Color(0xa8101125),
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            width: double.infinity,
            padding: const EdgeInsets.all(21),
            decoration: BoxDecoration(
              color: const Color(0xf21d1b32),
              border: Border.all(color: const Color(0xff5f4e70)),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                ...content,
                const SizedBox(height: 15),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PointerButton extends StatefulWidget {
  const _PointerButton({
    required this.label,
    required this.icon,
    required this.onDown,
    required this.onUp,
    this.color,
  });

  final String label;
  final IconData icon;
  final ValueChanged<int> onDown, onUp;
  final Color? color;

  @override
  State<_PointerButton> createState() => _PointerButtonState();
}

class _PointerButtonState extends State<_PointerButton> {
  final _active = <int>{};

  void _release(PointerEvent event) {
    setState(() => _active.remove(event.pointer));
    widget.onUp(event.pointer);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? const Color(0xffe2d3ef);
    return Semantics(
      button: true,
      label: widget.label,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          setState(() => _active.add(event.pointer));
          widget.onDown(event.pointer);
        },
        onPointerUp: _release,
        onPointerCancel: _release,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: _active.isEmpty
                ? const Color(0xc923203d)
                : const Color(0xff534368),
            border: Border.all(color: color.withValues(alpha: .6)),
          ),
          child: Icon(widget.icon, color: color, size: 27),
        ),
      ),
    );
  }
}

class _MenuArt extends CustomPainter {
  const _MenuArt();

  @override
  void paint(Canvas canvas, Size size) {
    paintCity(canvas, size.width, size.height, 0, 0);
    final horizontal = size.width >= size.height;
    final scale = (size.shortestSide / 430).clamp(.55, 2.7);
    final hero = Offset(
      size.width * (horizontal ? .75 : .68),
      size.height * .74,
    );
    canvas.save();
    canvas.translate(hero.dx, hero.dy);
    canvas.scale(scale);
    paintRoof(
      canvas,
      const Rect.fromLTWH(-87, 0, 180, 23),
      Surface.stone,
      true,
    );
    paintRoof(
      canvas,
      const Rect.fromLTWH(112, -65, 156, 15),
      Surface.shadow,
      true,
    );
    paintRoof(
      canvas,
      const Rect.fromLTWH(-199, 73, 95, 15),
      Surface.light,
      false,
    );
    canvas.save();
    canvas.scale(2.4);
    paintCourier(canvas, Offset.zero, facing: 1, stride: 0, inLight: true);
    canvas.restore();
    canvas.restore();
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xee101125), Color(0xb7101125), Color(0x00101125)],
          stops: [0, .43, .89],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(covariant _MenuArt oldDelegate) => false;
}
