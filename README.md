# Cliffzy iOS

Приложение для вертикальных мини-сериалов: лента, сериалы, VIP-подписка. Работает на том же сервере, что и Android
(`cliffzy-api`, репозиторий `cliffzy-backend-android`), см. [решение 2026-11-25](wiki/decisions/2026-11-25-shared-backend.md).

## Запуск в симуляторе

Нужен Mac с Xcode 16 или новее (App Store → Xcode) и Homebrew (https://brew.sh).

1. Открой Терминал и выполни:
   ```bash
   brew install xcodegen
   git clone https://github.com/mikhadobrin5-del/cliffzy-ios.git
   cd cliffzy-ios
   git checkout claude/ios-mvp-scaffold   # пока PR не влит в main
   xcodegen generate
   open Cliffzy.xcodeproj
   ```
2. В Xcode сверху выбери схему **Cliffzy** и симулятор, например **iPhone 16 Pro**.
3. Нажми **Run** (▶ или `Cmd+R`). Первая сборка занимает пару минут, потом откроется симулятор.

Обычный запуск берёт сериалы с настоящего сервера. Покупка VIP в симуляторе идёт через файл
`StoreKit/Cliffzy.storekit` (деньги не списываются), но сервер принимает только настоящие покупки Apple,
поэтому полностью VIP проверяется в TestFlight. С аргументом запуска `-CliffzyScreen feed` (или series, locked,
episodes, paywall, discover, mylist, profile) приложение работает с демо-сервером в памяти, там VIP бесплатный.
Юнит-тесты: `Cmd+U`.

Без Xcode-проекта: в GitHub → Actions → последний зелёный запуск → артефакт **Cliffzy-Simulator**.
Распакуй и выполни `xcrun simctl install booted Cliffzy.app` при запущенном симуляторе
(покупки в этом режиме недоступны).

## TestFlight

Каждый push в `main` (и ручной запуск Actions → iOS → Run workflow) собирает подписанную сборку и выкладывает
её в TestFlight, когда в секретах репозитория есть ключ App Store Connect API: `ASC_KEY_ID`, `ASC_ISSUER_ID`,
`ASC_KEY_P8` (содержимое .p8), а Team ID записан в `DEVELOPMENT_TEAM` в `project.yml`. Номер сборки = номер запуска.

## Что внутри

| Папка | Что там |
| --- | --- |
| `Cliffzy/App` | Точка входа, вкладки, `AppModel` со всеми сервисами |
| `Cliffzy/Networking` | Клиент API (`RemoteAPI`), вход по устройству, Keychain, демо-сервер (`DemoAPI`) |
| `Cliffzy/Models` | `Series`, `Episode` с доступом FREE/VIP/LOCKED от сервера |
| `Cliffzy/Services` | Аккаунт и VIP, покупки StoreKit 2 с проверкой на сервере, «Мой список» и история |
| `Cliffzy/Player` | Пул AVPlayer: подписанные ссылки с сервера, предзагрузка соседних серий |
| `Cliffzy/DesignSystem` | Цвета, кнопки, бейджи по спецификации из Figma |
| `Cliffzy/Features` | Экраны: лента, главная и поиск, плеер сериала, серии, пейволл, мой список, профиль |
| `Cliffzy/Resources` | Иконка, экран запуска, Info.plist, PrivacyInfo.xcprivacy |

## Что дальше

- Bunny CDN и HLS для видео, когда вырастет трафик (заготовка в бэкенде).
- Вход через Apple, чтобы VIP и история переезжали на новый телефон.
- Аналитика, push-уведомления о новых сериях, локализация (en, ru), экраны для App Store.
