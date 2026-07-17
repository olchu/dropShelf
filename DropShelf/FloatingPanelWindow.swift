import Cocoa

extension Notification.Name {
    static let floatingPanelDidHide = Notification.Name("floatingPanelDidHide")
}

class FloatingPanelWindow: NSPanel {

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
        // У borderless-панели системная тень выглядит как тёмный бордер.
        // Матовость фона создаётся отдельно и от этой настройки не зависит.
        self.hasShadow = false
        
        // Окно можно перемещать кликая по любой области
        self.isMovableByWindowBackground = true
    }
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
