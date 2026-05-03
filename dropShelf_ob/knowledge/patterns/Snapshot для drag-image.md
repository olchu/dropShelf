---
tags: [pattern, drag-drop, snapshot, nsimage, nsbitmapimagerep]
date: 2026-05-03
---

# Snapshot для drag-image

При групповом drag нужно показать изображение каждого файла «под курсором». DropShelf делает bitmap-снимок каждой `FileItemView`.

## Реализация

```swift
private func snapshot(of view: NSView) -> NSImage {
    let size = view.bounds.size

    // Пробуем стандартный метод кэширования отображения
    let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        ?? NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )!

    view.cacheDisplay(in: view.bounds, to: rep)

    let img = NSImage(size: size)
    img.addRepresentation(rep)
    return img
}
```

## Использование в drag

```swift
let img = snapshot(of: v)
let di = NSDraggingItem(pasteboardWriter: writer)

// Spread-эффект: каждый файл чуть смещён от предыдущего
let spread: CGFloat = 6
let frame = NSRect(
    x: mouse.x - img.size.width/2 + CGFloat(i - count + 1) * spread,
    y: mouse.y - img.size.height/2 + CGFloat(i - count + 1) * (-spread),
    ...
)
di.setDraggingFrame(frame, contents: img)
```

## Почему NSBitmapImageRep

`bitmapImageRepForCachingDisplay` может вернуть `nil` для некоторых конфигураций (layer-backed views без backing store). Fallback — создать `NSBitmapImageRep` вручную с нужными параметрами.

## Связи

- [[Drag and Drop API в macOS]]
- [[OverlapStackView управляет всем DnD]]
