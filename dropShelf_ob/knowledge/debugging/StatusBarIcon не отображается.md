---
tags: [debugging, statusbar, icon, assets]
date: 2026-05-03
---

# StatusBarIcon не отображается

## Симптом

Иконка в статус-баре пустая или показывает стандартный placeholder.

## Причина 1: Неправильное имя ассета

В `AppDelegate`:
```swift
let img = NSImage(named: "StatusBarIcon")
    ?? NSImage(named: "statusbar")
```

Есть два ассета: `StatusBarIcon` (imageset без изображений) и `statusbar` (imageset с PNG файлами). Если `StatusBarIcon` пуст — падаем на `statusbar`.

**Проверить**: в Xcode → Assets.xcassets убедиться что `StatusBarIcon` содержит изображение.

## Причина 2: isTemplate = true перекрашивает иконку

Если `button.image?.isTemplate = true`, macOS перекрасит иконку в белый/чёрный в зависимости от темы, теряя цвета.

**Решение**: держать `isTemplate = false`.

## Причина 3: contentTintColor перекрашивает

```swift
button.contentTintColor = nil  // убрать любой tint
```

Если `tintColor` задан, он накладывается поверх иконки.

## Текущее состояние

Два imageset с разными именами — архитектурный беспорядок. Рекомендуется объединить в один ассет и использовать одно имя.

## Связи

- [[NSStatusItem — иконка в статус-баре]]
- [[Сборка и деплой]]
