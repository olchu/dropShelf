---
tags: [debugging, hitTest, AppKit, coordinates]
date: 2026-05-03
---

# CloseButton hitTest bounds vs frame

## Симптом
При клике на кнопку закрытия вместо закрытия окна появлялись drag-превью файлов из `OverlapStackView`.

## Причина

`NSView.hitTest(_ point:)` получает `point` в системе координат **superview** (родительского вью).

`bounds` — прямоугольник в системе координат **самого вью** (начинается с 0,0).

Использование `bounds.contains(point)` при point в координатах родителя — ошибочное сравнение. Для кнопки не в позиции (0,0) результат будет некорректным для кликов у правого/нижнего края.

## Цепочка падения событий

1. `CloseButton.hitTest(point)` → `bounds.contains(point)` → `nil` (неверно)
2. `OverlapStackView.hitTest(point)` → всегда `self` (override: `{ self }`)
3. `OverlapStackView.mouseDown` → `beginGroupDrag` → показ drag-миниатюр

## Исправление

```swift
// Было (неправильно):
override func hitTest(_ point: NSPoint) -> NSView? {
    bounds.contains(point) ? self : nil
}

// Стало (правильно):
override func hitTest(_ point: NSPoint) -> NSView? {
    frame.contains(point) ? self : nil
}
```

`frame` тоже в координатах superview — сравнение корректно.

## Правило

> В `hitTest(_ point:)`: используй `frame` (superview coords) для проверки попадания, или конвертируй `point` через `convert(point, from: superview)` перед сравнением с `bounds`.

## Почему OverlapStackView.hitTest { self }

Нужно чтобы drop работал по всей области стопки, включая область поверх дочерних `FileItemView`. Это намеренное решение. Но оно перехватывает все события, если братские (sibling) вью вернули nil из hitTest.
