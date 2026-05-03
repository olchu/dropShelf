---
tags: [home, index]
date: 2026-05-03
---

# DropShelf — База знаний

Floating-панель для macOS: временное хранилище файлов во время работы в Finder.

## Навигация

### Атлас проекта
- [[Архитектура приложения]] — компоненты, слои, поток данных
- [[Стек технологий]] — Swift, AppKit, SwiftUI, фреймворки Apple
- [[Сборка и деплой]] — Xcode, требования, установка

### Знания
- [[Drag and Drop API в macOS]] — NSDraggingSource, NSDraggingDestination
- [[NSStatusItem — иконка в статус-баре]] — управление статус-баром
- [[Mouse Shake Detection]] — глобальный мониторинг событий мыши

### Решения
- [[NSPanel выбран вместо NSWindow]] — почему floating panel
- [[OverlapStackView управляет всем DnD]] — архитектурное решение по drag

### Отладка
- [[CloseButton hitTest bounds vs frame]] — hitTest: frame vs bounds, координатные системы
- [[DropTargetView и OverlapStackView дублируют DnD]] — почему это не проблема
- [[StatusBarIcon не отображается]] — isTemplate и имя ассета

### Паттерны
- [[Паттерн глобального мониторинга событий]]
- [[Layer-based визуальные эффекты в AppKit]]
- [[Snapshot для drag-image]]

### Бизнес
- [[Продуктовая идея DropShelf]] — концепция, аудитория, ценность

## Быстрые ссылки

| Файл | Роль |
|------|------|
| `DropShelfApp.swift` | Точка входа `@main`, подключает AppDelegate |
| `AppDelegate.swift` | Статус-бар, окно, DragDetector |
| `FloatingPanelWindow.swift` | NSPanel поверх всех окон |
| `ShelfViewController.swift` | Контроллер панели с файлами |
| `OverlapStackView.swift` | Стопка карточек, источник DnD |
| `FileItemView.swift` | Превью одного файла |
| `DropTargetView.swift` | Зона приёма drop |
| `CloseButton.swift` | Кнопка закрытия с hover-эффектом |
| `DragDetector.swift` | Детектор встряхивания мыши |
