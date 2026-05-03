---
tags: [integration, drag-drop, appkit, nsdragging]
date: 2026-05-03
---

# Drag and Drop API в macOS

AppKit DnD строится на двух протоколах: источник (`NSDraggingSource`) и цель (`NSDraggingDestination`).

## Регистрация типов

```swift
// Принимать файлы через drop:
view.registerForDraggedTypes([.fileURL])

// Или несколько типов:
view.registerForDraggedTypes([.fileURL, .URL])
```

## NSDraggingDestination (приём drop)

Реализован в `DropTargetView` и `OverlapStackView`:

```swift
func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let pb = sender.draggingPasteboard
    guard let urls = pb.readObjects(forClasses: [NSURL.self],
                                    options: [.urlReadingFileURLsOnly: true]) as? [URL]
    else { return false }
    // handle urls
    return true
}
```

**Ключевая опция**: `.urlReadingFileURLsOnly: true` — только файловые URL, не web-ссылки.

## NSDraggingSource (запуск drag)

Реализован в `OverlapStackView` для группового drag всех файлов:

```swift
// 1. Создаём NSDraggingItem для каждого файла
let writer = fileURL as NSURL
let di = NSDraggingItem(pasteboardWriter: writer)
di.setDraggingFrame(frame, contents: snapshotImage)

// 2. Запускаем сессию
let session = beginDraggingSession(with: draggingItems, event: event, source: self)
session.animatesToStartingPositionsOnCancelOrFail = true
session.draggingFormation = .pile  // ← файлы "кучкой"

// 3. NSDraggingSource protocol
func draggingSession(_ session: NSDraggingSession,
                     sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
    [.copy, .move]
}

// 4. Реакция на завершение
func draggingSession(_ session: NSDraggingSession,
                     endedAt screenPoint: NSPoint,
                     operation: NSDragOperation) {
    if !operation.isEmpty { onRemoveAll?() }  // успешный drop → очистить полку
}
```

## hitTest Override (важный трюк)

В `OverlapStackView` переопределён `hitTest`:
```swift
override func hitTest(_ point: NSPoint) -> NSView? { self }
```
Это гарантирует, что все события мыши (включая DnD) всегда идут в `OverlapStackView`, а не в дочерние `FileItemView`. Иначе drop на иконку файла не срабатывал бы.

## DnD Formation

`NSDraggingSession.draggingFormation`:
- `.pile` — файлы в кучке (используется в DropShelf)
- `.list` — вертикальный список
- `.stack` — стопка

## Связи

- [[OverlapStackView управляет всем DnD]]
- [[Архитектура приложения]]
- [[Паттерн глобального мониторинга событий]]
