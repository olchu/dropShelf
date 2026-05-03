---
tags: [decision, drag-drop, architecture, overlapstackview]
date: 2026-05-03
---

# OverlapStackView управляет всем DnD

## Решение

Весь Drag & Drop (как источник, так и цель) централизован в `OverlapStackView`. `FileItemView` намеренно **не** является ни источником, ни целью DnD.

## Почему не FileItemView

Каждый `FileItemView` показывает один файл, но при drag пользователь ожидает вытащить **все файлы** одновременно (как стопку). Если drag инициировать в `FileItemView`, нужно как-то коммуницировать с родителем для группового drag — это усложнение.

## Реализация hitTest Override

```swift
// В OverlapStackView:
override func hitTest(_ point: NSPoint) -> NSView? { self }
```

Без этого `mouseDown` уходил бы в `FileItemView`, а не в `OverlapStackView`. С override все события мыши всегда перехватывает контейнер.

**Побочный эффект**: `FileItemView` никогда не получает события мыши. Это нормально — он только отображает, не взаимодействует.

```swift
// В FileItemView — явно отключаем DnD в imageView:
imageView.unregisterDraggedTypes()
```

Без этого `NSImageView` по умолчанию регистрирует собственные типы для drop изображений, что перехватывало бы события.

## Групповой drag из OverlapStackView

```swift
override func mouseDown(with event: NSEvent) {
    beginGroupDrag(event: event)
}

private func beginGroupDrag(event: NSEvent) {
    let items = subviews.compactMap { $0 as? FileItemView }
    // Создаём NSDraggingItem для каждого с snapshot-изображением
    // Запускаем beginDraggingSession
}
```

## Приём drop в OverlapStackView

`OverlapStackView` также реализует `NSDraggingDestination` — так файлы можно кидать прямо на стопку, не промахиваясь мимо иконок.

## Связи

- [[Drag and Drop API в macOS]]
- [[Архитектура приложения]]
- [[Паттерн глобального мониторинга событий]]
