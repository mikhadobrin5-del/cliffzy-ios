# Cliffzy iOS

Приложение для вертикальных AI-драм: лента эпизодов, сериалы, монеты и VIP.

## Запуск

Нужны Xcode 16+ и [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
open Cliffzy.xcodeproj
```

Схема `Cliffzy` уже подключает `StoreKit/Cliffzy.storekit`, поэтому покупки монет и VIP
работают в симуляторе без App Store Connect. Тесты: `Cmd+U`.

## Что внутри

| Папка | Что там |
| --- | --- |
| `Cliffzy/App` | Точка входа, вкладки, `AppModel` со всеми сервисами |
| `Cliffzy/Models` | `Series`, `Episode`, `MonetizationConfig` (цены и число бесплатных серий) |
| `Cliffzy/Services` | Каталог (пока демо), монеты/VIP/разблокировки, покупки StoreKit 2, "Мой список" |
| `Cliffzy/Player` | Пул AVPlayer с предзагрузкой и полноэкранный плеер эпизода |
| `Cliffzy/Features` | Экраны: лента, главная, плеер сериала, пейволл, мой список, профиль |

## Что дальше

- Каталог с Supabase вместо `MockCatalogService` (сейчас играют тестовые HLS-потоки).
- Кошелёк монет на сервере: локальный баланс легко подделать.
- RevenueCat вместо прямого StoreKit, вебхук начисляет монеты на сервере.
- Аналитика, локализация (en, ru), иконка и экраны для App Store.
