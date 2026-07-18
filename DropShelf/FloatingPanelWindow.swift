import Cocoa
import QuartzCore

extension Notification.Name {
    static let floatingPanelDidHide = Notification.Name("floatingPanelDidHide")
}

class FloatingPanelWindow: NSPanel {

    private let presentationDuration: TimeInterval = 0.26
    private let contentCornerRadius: CGFloat = 20

    func presentAnimated(contentReveal: @escaping () -> Void = {}) {
        guard !isVisible else {
            orderFront(nil)
            contentReveal()
            return
        }

        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            alphaValue = 1
            orderFront(nil)
            contentReveal()
            return
        }

        contentView?.wantsLayer = true
        let contentLayer = contentView?.layer
        contentLayer?.cornerRadius = contentCornerRadius
        contentLayer?.cornerCurve = .continuous
        contentLayer?.masksToBounds = true

        let restingFrame = frame
        let startingFrame = scaledFrame(restingFrame, by: 0.85)
        let overshootFrame = scaledFrame(restingFrame, by: 1.04)
        let restingSize = restingFrame.size

        // На время анимации разрешаем программно менять размер панели.
        minSize = .zero
        maxSize = overshootFrame.size
        setFrame(startingFrame, display: true)
        alphaValue = 0
        orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = presentationDuration * 0.55
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = presentationDuration * 0.62
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.82, 0.28, 1)
            animator().setFrame(overshootFrame, display: true)
        } completionHandler: { [weak self] in
            guard let self else { return }
            contentReveal()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = self.presentationDuration * 0.38
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.7, 0.35, 1)
                self.animator().setFrame(restingFrame, display: true)
            } completionHandler: { [weak self] in
                self?.alphaValue = 1
                self?.minSize = restingSize
                self?.maxSize = restingSize
            }
        }
    }

    private func scaledFrame(_ frame: NSRect, by scale: CGFloat) -> NSRect {
        let size = NSSize(width: frame.width * scale, height: frame.height * scale)
        return NSRect(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
        NotificationCenter.default.post(name: .floatingPanelDidHide, object: self)
    }
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        // Окно поверх обычных окон, но не поверх других floating окон
        self.level = .statusBar
        
        // Окно не активируется при клике
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        
        // Прозрачный фон
        self.isOpaque = false
        self.backgroundColor = .clear
        // Основная панель всегда использует тёмный материал, чтобы фирменный
        // акцент #FF383C сохранял контраст независимо от темы macOS.
        self.appearance = NSAppearance(named: .darkAqua)
        // У borderless-панели системная тень выглядит как тёмный бордер.
        // Матовость фона создаётся отдельно и от этой настройки не зависит.
        self.hasShadow = false
        
        // Окно можно перемещать кликая по любой области
        self.isMovableByWindowBackground = true
    }
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
