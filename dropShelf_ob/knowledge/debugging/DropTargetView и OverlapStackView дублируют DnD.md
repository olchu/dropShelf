---
tags: [debugging, drag-drop, duplication, dropTargetView]
date: 2026-05-03
---

# DropTargetView и OverlapStackView дублируют DnD

## Проблема

В `ShelfViewController` существуют две независимые DnD-цели:

1. **`DropTargetView`** — фоновая вьюха, покрывает всю панель, регистрирует `.fileURL` и `.URL`
2. **`OverlapStackView`** — поверх неё, тоже регистрирует `.fileURL`

Обе вызывают `onFilesDropped` → `addFile(url:)`. При drop на пустую область срабатывает `DropTargetView`, при drop на стопку — `OverlapStackView`.

## Потенциальные последствия

- Если обе вызовутся для одного drop (маловероятно, но зависит от `hitTest`) — файл добавится дважды
- `ShelfViewController.addFile` имеет защиту: `guard !fileItems.contains(url) else { return }` — дублей в списке не будет
- Но дублирование архитектурное — два места делают одно и то же

## NSLog в DropTargetView (технический долг)

```swift
override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    NSLog("🎯 DropTargetView: Dragging entered!")  // ← убрать
    return .copy
}
```

Debug-вывод в `performDragOperation` на строках 27, 34, 40, 45 — должен быть убран перед релизом.

## Решение

Вариант 1: Убрать `DropTargetView` как DnD-цель, оставить только `OverlapStackView`.  
Вариант 2: Объединить функциональность — `DropTargetView` принимает drop только когда стопка пуста.  
Вариант 3: Оставить как есть — защита от дублей в `addFile` работает.

## Связи

- [[OverlapStackView управляет всем DnD]]
- [[Drag and Drop API в macOS]]
