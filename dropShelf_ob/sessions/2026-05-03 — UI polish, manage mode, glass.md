---
tags: [session]
date: 2026-05-03
---

# Сессия: UI polish, manage mode, Liquid Glass

## Что сделано

### Баги
- **CloseButton не закрывал** — `hitTest` использовал `bounds.contains` вместо `frame.contains` → [[CloseButton hitTest bounds vs frame]]
- **Задержка drag** — добавлен pre-cache snapshot в `FileItemView.cacheDragSnapshot()`, вызывается async после layout
- **Drag не срабатывал с первого клика** — `acceptsFirstMouse → true` в `OverlapStackView`
- **Drag окна вместо файлов** — `mouseDown` проверяет `$0.frame.contains(localPoint)`, drag только по `FileItemView`
- **Уголки рамки при активации** — `canBecomeKey = false`, `canBecomeMain = false` в `FloatingPanelWindow`
- **Текст не виден на светлой теме** — `NSColor.white` → `NSColor.labelColor` (adaptive)

### Новые фичи
- **Liquid Glass** (macOS 26) — `GlassPanel: View` с `.glassEffect(in: RoundedRectangle(...))`, фолбэк `NSVisualEffectView`
- **Удаление файлов** — right-click контекст меню: отдельный файл + Remove All
- **Bottom bar** — trash слева, счётчик файлов по центру ("1 file" / "N files"), manage справа
- **Manage mode** — список: QLThumbnail 32×32 + усечённое имя + красная кнопка удаления
- **Manage scroll** — не перекрывает close button (top = `closeButtonInset = 38`)
- **Центрирование стопки** — `overlapView.top = closeButtonInset`, зона от y=38 до y=240

### Архитектура
- `URLButton: NSButton` с `fileURL: URL` для identify-кнопок в manage mode
- `bottomBarHeight = 40`, `closeButtonInset = 38`, `cornerRadius = 20` — константы класса
- Окно заблокировано: `minSize = maxSize = NSSize(280, 280)`
- `manageStack.alignment = .leading` + явные `trailingAnchor` (нет `.fill` в AppKit NSStackView)

## Уроки

- `NSStackView.alignment` — тип `NSLayoutConstraint.Attribute`, нет `.fill` (UIKit only)
- `CALayer.backgroundColor` не динамический → `viewDidChangeEffectiveAppearance()` для смены темы
- `orderFront(nil)` вместо `makeKeyAndOrderFront` чтобы панель не стала key window
