---
tags: [decision, nspanel, nswindow, appkit, floating]
date: 2026-05-03
---

# NSPanel выбран вместо NSWindow

## Решение

`FloatingPanelWindow` наследует от `NSPanel`, а не `NSWindow`.

## Почему NSPanel

`NSPanel` — специализированный подкласс `NSWindow` для вспомогательных интерфейсов:

| Поведение | NSWindow | NSPanel |
|-----------|----------|---------|
| Скрывается при `⌘H` | Да | Нет (с `.nonactivatingPanel`) |
| Остаётся в полноэкранном режиме | Нет | Да (с `.fullScreenAuxiliary`) |
| Присутствует на всех Spaces | Нет | Да (с `.canJoinAllSpaces`) |
| Можно сделать non-activating | Нет | Да |

## Конфигурация StyleMask

```swift
FloatingPanelWindow(
    contentRect: windowRect,
    styleMask: [.borderless, .nonactivatingPanel],
    ...
)
```

- `.borderless` — без стандартной рамки/заголовка
- `.nonactivatingPanel` — клик по панели не активирует приложение, Finder остаётся активным

## Уровень окна

```swift
self.level = .statusBar
```

Окно находится выше обычных приложений, но ниже системных элементов (Spotlight, уведомления).

## CollectionBehavior

```swift
self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
```

- `.canJoinAllSpaces` — видна на всех Spaces (виртуальных рабочих столах)
- `.fullScreenAuxiliary` — видна поверх полноэкранных приложений
- `.stationary` — не участвует в анимациях переключения Spaces

## Компромисс

`canBecomeKey = true` и `canBecomeMain = true` переопределены, хотя панель `nonactivating`. Это позволяет принимать клавиатурный ввод если нужно, но противоречит non-activating поведению. Пока не используется.

## Связи

- [[Архитектура приложения]]
- [[Стек технологий]]
