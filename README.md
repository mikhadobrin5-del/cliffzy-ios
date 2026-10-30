# Cliffzy iOS

Приложение для вертикальных AI-драм: лента эпизодов, сериалы, монеты и VIP.

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

Покупки монет и VIP в симуляторе работают через файл `StoreKit/Cliffzy.storekit`, деньги не списываются.
Для тестов без покупок открой **Profile → Developer**: +500 монет, VIP вкл/выкл, сброс разблокировок и бонуса.
Юнит-тесты: `Cmd+U`.

Без Xcode-проекта: в GitHub → Actions → последний зелёный запуск → артефакт **Cliffzy-Simulator**.
Распакуй и выполни `xcrun simctl install booted Cliffzy.app` при запущенном симуляторе
(покупки в этом режиме недоступны, пользуйся разделом Developer).

## Что внутри

| Папка | Что там |
| --- | --- |
| `Cliffzy/App` | Точка входа, вкладки, `AppModel` со всеми сервисами |
| `Cliffzy/Models` | `Series`, `Episode`, `MonetizationConfig` (цены и число бесплатных серий) |
| `Cliffzy/Services` | Каталог (пока демо), монеты/VIP/разблокировки, покупки StoreKit 2, "Мой список" |
| `Cliffzy/Player` | Пул AVPlayer с предзагрузкой и полноэкранный плеер эпизода |
| `Cliffzy/DesignSystem` | Цвета, кнопки, бейджи по спецификации из Figma |
| `Cliffzy/Features` | Экраны: лента, главная и поиск, плеер сериала, серии, пейволл, мой список, профиль |
| `Cliffzy/Resources` | Иконка, экран запуска, Info.plist |

## Что дальше

- Каталог с Supabase вместо `MockCatalogService` (сейчас играют тестовые HLS-потоки).
- Кошелёк монет на сервере: локальный баланс легко подделать.
- RevenueCat вместо прямого StoreKit, вебхук начисляет монеты на сервере.
- Аналитика, локализация (en, ru), иконка и экраны для App Store.
