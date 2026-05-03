---
tags: [integration, mouse, events, nsevent, drag-detection]
date: 2026-05-03
---

# Mouse Shake Detection

`DragDetector` отслеживает «встряхивание» мышью во время перетаскивания файла и показывает панель.

## Как работает

Мониторится глобальное событие `.leftMouseDragged` (только во время drag):

```swift
eventMonitor = NSEvent.addGlobalMonitorForEvents(
    matching: [.leftMouseDragged]
) { [weak self] event in
    self?.handleMouseDrag(event: event)
}
```

**Алгоритм определения встряхивания:**
1. Измеряем `deltaX = abs(currentX - lastX)`
2. Если `deltaX > 30pt` — считаем это одним «рывком»
3. Если 2+ рывка произошло за `< 0.3 секунды` → встряхивание обнаружено
4. Вызываем `onShakeDetected?()`

```swift
if deltaX > 30 {
    if now.timeIntervalSince(startTime) < 0.3 {
        shakeCount += 1
        if shakeCount >= 2 {
            onShakeDetected?()
            resetShakeDetection()
        }
    }
}
```

## Почему только `.leftMouseDragged`

Drag в Finder происходит с зажатой левой кнопкой. Мониторить `.mouseMoved` было бы избыточно — показывало бы панель без перетаскивания файла.

## Глобальный монитор vs локальный

- `addGlobalMonitorForEvents` — получает события из других приложений (нужен для Finder)
- `addLocalMonitorForEvents` — только события в своём приложении
- DropShelf использует глобальный, так как пользователь тащит файл из Finder

**Ограничение**: глобальный монитор не может перехватывать или модифицировать события, только наблюдать.

## Настройка чувствительности

Текущие пороги (захардкожены в `DragDetector.swift`):
- `deltaX > 30` — порог для «рывка»
- `< 0.3 sec` — окно времени для серии рывков
- `>= 2` рывков — считается встряхиванием

## Потенциальная проблема

Детектор запускает `onShakeDetected` несколько раз подряд, если мышь продолжает двигаться после встряхивания. `AppDelegate.showWindow()` вызывается повторно, что не критично но избыточно.

## Связи

- [[Архитектура приложения]]
- [[Паттерн глобального мониторинга событий]]
