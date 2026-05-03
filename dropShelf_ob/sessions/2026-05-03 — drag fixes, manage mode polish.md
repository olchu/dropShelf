---
tags: [session]
date: 2026-05-03
---

# Сессия: drag fixes, manage mode polish

## Что сделано

### Баги исправлены

- **Manage mode: drag файлов** — `OverlapStackView.hitTest` возвращал `self` даже когда `isHidden = true`, перехватывая события мыши под списком. Фикс: `isHidden ? nil : self`

- **addFile в manage mode** — `guard !isManaging, !fileItems.contains(url)` блокирует добавление файлов пока открыт список

- **layoutSubtreeIfNeeded рекурсия** — убран вызов `overlapView.layoutSubtreeIfNeeded()` в `addFile`, достаточно `needsLayout = true`

- **DragDetector ложные срабатывания** — полная переработка алгоритма:
  - Старый: считал любые два вертикальных движения > 20px за 0.7с
  - Новый: считает смены направления (`lastDeltaY * dy < 0`), требует 2 реверса за 0.5с
  - Использует `event.deltaY` вместо разницы абсолютных позиций
  - `leftMouseUp` сбрасывает состояние между нажатиями

- **Файлы удаляются при grab-and-release внутри панели** — трёхэтапное исправление:
  1. `OverlapStackView` флаг `isLocalDragActive`: пока drag активен, отклоняет входящие drops (`draggingEntered → []`, `prepareForDragOperation → false`)
  2. `DropTargetView` проверяет `sender.draggingSource is OverlapStackView` и отклоняет
  3. `draggingSession(_:endedAt:)` удаляет файлы если `!operation.isEmpty || endedOutsideWindow`
  
  Итог: grab+release внутри → никто не принимает → operation = .none → файлы остаются

## Ключевые уроки

### isHidden не защищает от hitTest при переопределении
Если `hitTest` переопределён и возвращает `self` безусловно — hidden view всё равно перехватывает события. Нужно явно проверять `isHidden`:
```swift
override func hitTest(_ point: NSPoint) -> NSView? { isHidden ? nil : self }
```

### DragDetector: смены направления, не расстояние
Правильный shake detection считает реверсы направления (`dy * lastDy < 0`), а не просто большие перемещения. Использовать `event.deltaY`, не абсолютные позиции.

### OverlapStackView как source+destination
Когда view является и источником drag, и потенциальным получателем — нужно явно блокировать самоприём через флаг `isLocalDragActive`. Иначе Cocoa может доставить drop обратно на тот же view (или на родительский DropTargetView).

### DropTargetView и источник drag
`NSDraggingInfo.draggingSource` позволяет определить источник и отклонить self-drop: `sender.draggingSource is OverlapStackView`.
