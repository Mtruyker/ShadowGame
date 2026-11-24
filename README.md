# Прыжок по тени

Браузерный платформер на Flutter Web и Flame. Курьер несёт фонарь по крышам ночного города и переключает свет, чтобы активировать нужные платформы.

## Запуск и проверки

```powershell
flutter pub get
flutter run -d chrome
flutter analyze
flutter test
```

На компьютере движение управляется клавишами A и D или стрелками. Пробел отвечает за прыжок, Shift переключает свет, R перезапускает трассу, Esc открывает паузу. На телефоне используются экранные кнопки в альбомной ориентации.

Расстановка крыш, движение платформ, старт и финиш описаны в `lib/levels.dart`. Рекорды, открытые трассы и звук сохраняются в хранилище браузера. В черновике язык берётся из SDK Яндекс Игр. При локальном запуске без SDK используется язык браузера.

## Сборка для Яндекс Игр

```powershell
flutter build web --release --no-web-resources-cdn
Compress-Archive -Path 'build/web/*' -DestinationPath 'build/shadow-jump-yandex.zip' -Force
```

Загрузите ZIP с `index.html` в корне в черновик игры. Выберите альбомную ориентацию и проверьте русский и английский интерфейсы, сигнал готовности и паузу через отладочную панель Яндекс Игр. Для мобильной приёмки проверьте управление на Android Chrome и iPhone Safari. [Загрузка игры](https://yandex.ru/dev/games/doc/ru/console/add-new-game/draft) · [Тестирование](https://yandex.ru/dev/games/doc/ru/console/test-game)
