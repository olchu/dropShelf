import Cocoa

class FloatingPanelWindow: NSPanel {
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        // Окно поверх обычных окон, но не поверх других floating окон
        self.level = .statusBar
        
        // Окно не активируется при клике
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        
        // Прозрачный фон
        self.isOpaque = false
        self.backgroundColor = .clear
        
        // Показывать тень
        self.hasShadow = true
        
        // Окно можно перемещать кликая по любой области
        self.isMovableByWindowBackground = true
    }
    
    // Позволяет окну стать ключевым для приёма событий
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}
