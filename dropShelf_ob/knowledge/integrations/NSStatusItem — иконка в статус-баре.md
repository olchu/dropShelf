---
tags: [integration, statusbar, nsstatusitem, appkit]
date: 2026-05-03
---

# NSStatusItem — иконка в статус-баре

`NSStatusItem` представляет элемент в системном статус-баре macOS (правая часть меню-бара).

## Создание

```swift
statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
```

`squareLength` — квадратный элемент стандартного размера (~22pt).

## Установка иконки (не template)

```swift
let img = NSImage(named: "StatusBarIcon")
    ?? NSImage(named: "statusbar")      // fallback

button.image = img
button.alternateImage = img            // та же иконка при нажатии
button.image?.isTemplate = false       // ВАЖНО: не перекрашивать системой
button.imagePosition = .imageOnly
button.title = ""
button.contentTintColor = nil          // убрать любой tint
```

**Template vs non-template**:
- `isTemplate = true` → система делает иконку чёрной/белой в зависимости от темы, игнорирует цвета
- `isTemplate = false` → цвета иконки сохраняются точно как в ассете

## Подсветка при активном окне

```swift
private func updateStatusHighlight(_ active: Bool) {
    statusItem?.button?.contentTintColor = active ? .controlAccentColor : nil
}
```

При открытом окне панели иконка подсвечивается акцентным цветом.

## Действие при клике

```swift
button.target = self
button.action = #selector(toggleWindow)
```

## Позиционирование окна под иконкой

```swift
func showWindow() {
    if let btn = statusItem?.button,
       let btnWindow = btn.window {
        let btnInScreen = btnWindow.convertToScreen(btn.convert(btn.bounds, to: nil))
        let origin = NSPoint(
            x: btnInScreen.midX - window.frame.width / 2,
            y: btnInScreen.minY - window.frame.height - 6   // 6pt зазор
        )
        window.setFrameOrigin(origin)
    }
}
```

## Связи

- [[Архитектура приложения]]
- [[Сборка и деплой]]
- [[NSPanel выбран вместо NSWindow]]
