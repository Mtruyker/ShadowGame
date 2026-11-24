import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('shadowSdk')
external JSPromise<_YandexSdk?> get _sdkPromise;

@JS('shadowUnlockAudio')
external void unlockAudio();

@JS('shadowSilenceAudio')
external void silenceAudio();

@JS('shadowEffect')
external void _playEffect(JSString effect);

extension type _YandexSdk(JSObject _) implements JSObject {
  external _Environment get environment;
  external _Features get features;
}

extension type _Environment(JSObject _) implements JSObject {
  external _Language get i18n;
}

extension type _Language(JSObject _) implements JSObject {
  external String get lang;
}

extension type _Features(JSObject _) implements JSObject {
  @JS('LoadingAPI')
  external _Loading? get loading;

  @JS('GameplayAPI')
  external _Gameplay? get gameplay;
}

extension type _Loading(JSObject _) implements JSObject {
  external void ready();
}

extension type _Gameplay(JSObject _) implements JSObject {
  external void start();
  external void stop();
}

_YandexSdk? _sdk;
bool _ready = false;
const _progressKey = 'shadow-jump.progress.v1';

Future<String?> sdkLanguage() async {
  try {
    _sdk = await _sdkPromise.toDart.timeout(const Duration(seconds: 6));
    return _sdk?.environment.i18n.lang;
  } catch (_) {
    return null;
  }
}

void gameReady() {
  if (_ready) return;
  _ready = true;
  _sdk?.features.loading?.ready();
}

void markGameplay(bool active) {
  final gameplay = _sdk?.features.gameplay;
  if (active) {
    gameplay?.start();
  } else {
    gameplay?.stop();
  }
}

bool get touchScreen => web.window.matchMedia('(pointer: coarse)').matches;

String? loadProgress() {
  try {
    return web.window.localStorage.getItem(_progressKey);
  } catch (_) {
    return null;
  }
}

void saveProgress(String value) {
  try {
    web.window.localStorage.setItem(_progressKey, value);
  } catch (_) {
    // The current session can keep playing when browser storage is disabled.
  }
}

void Function() observePage(void Function() onPause) {
  final visibility = ((web.Event _) {
    if (web.document.hidden) onPause();
  }).toJS;
  final blur = ((web.Event _) => onPause()).toJS;
  web.document.addEventListener('visibilitychange', visibility);
  web.window.addEventListener('blur', blur);
  web.window.addEventListener('pagehide', blur);
  return () {
    web.document.removeEventListener('visibilitychange', visibility);
    web.window.removeEventListener('blur', blur);
    web.window.removeEventListener('pagehide', blur);
  };
}

void playEffect(String effect) => _playEffect(effect.toJS);
