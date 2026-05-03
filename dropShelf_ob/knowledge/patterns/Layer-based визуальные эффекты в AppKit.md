---
tags: [pattern, calayer, nsvisualeffectview, appkit, ui]
date: 2026-05-03
---

# Layer-based визуальные эффекты в AppKit

Как в DropShelf реализован стеклянный тёмный фон панели.

## Схема слоёв

```
DropTargetView (NSView)
└── NSVisualEffectView   ← blur за окном
    └── CALayer (darkOverlay)  ← тёмное затемнение α=0.25
```

## NSVisualEffectView — blur-материал

```swift
let visualEffect = NSVisualEffectView(frame: view.bounds)
visualEffect.material = .popover        // материал как у popover
visualEffect.blendingMode = .behindWindow  // blur за окном приложения
visualEffect.state = .active            // всегда активен (не только при фокусе)
visualEffect.wantsLayer = true
visualEffect.layer?.cornerRadius = cornerRadius
```

**Материалы**: `.popover`, `.sidebar`, `.hudWindow`, `.titlebar`, `.menu`...  
`.popover` — светлый полупрозрачный, хорошо читаемый на любом фоне.

## CALayer overlay — кастомное затемнение

```swift
let darkOverlay = CALayer()
darkOverlay.backgroundColor = NSColor(white: 0.1, alpha: 0.25).cgColor
darkOverlay.frame = view.bounds
darkOverlay.cornerRadius = cornerRadius
darkOverlay.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
visualEffect.layer?.addSublayer(darkOverlay)
```

CALayer добавляется **внутрь** NSVisualEffectView, поверх blur-эффекта. Даёт тёмный оттенок без потери blur.

## Скругление углов окна

Скругление применяется к layer вьюхи, а не к самому NSPanel:
```swift
visualEffect.layer?.cornerRadius = cornerRadius  // 20pt
darkOverlay.cornerRadius = cornerRadius
```

Само окно (`FloatingPanelWindow`) имеет `backgroundColor = .clear` и `isOpaque = false` — позволяет corner radius быть видимым.

## Тени для FileItemView

```swift
// В FileItemView.imageView:
imageView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.35).cgColor
imageView.layer?.shadowOpacity = 1
imageView.layer?.shadowRadius = 6
imageView.layer?.shadowOffset = .zero

// В OverlapStackView.layout():
v.layer?.shadowOpacity = isTop ? 0.4 : 0.25
v.layer?.zPosition = CGFloat(i)
```

`zPosition` важен — без него слои рисуются в порядке добавления, а не в нужном порядке стопки.

## Связи

- [[Архитектура приложения]]
- [[NSPanel выбран вместо NSWindow]]
