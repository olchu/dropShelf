import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var floatingWindow: FloatingPanelWindow?
    var shelfViewController: ShelfViewController?
    var dragDetector: DragDetector?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSLog("⭐️ applicationDidFinishLaunching called!")
        print("🚀 App started!")
        NSLog("🚀 App started with NSLog!")
        
        // Убираем иконку из Dock - приложение работает только в статус-баре
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // Создаём иконку в статус-баре
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        print("📍 Status item created: \(statusItem != nil)")
        
        guard let statusItem = statusItem else {
            print("❌ Failed to create status item")
            return
        }
        
        if let button = statusItem.button {
            print("✅ Button exists")
            button.title = "📦 DropShelf"
            button.action = #selector(toggleWindow)
            button.target = self
        } else {
            print("❌ Button is nil!")
        }
        
        // Создаём плавающее окно
        let windowSize = NSSize(width: 400, height: 200)
        let screenFrame = NSScreen.main?.frame ?? .zero
        let windowRect = NSRect(
            x: (screenFrame.width - windowSize.width) / 2,
            y: screenFrame.height - windowSize.height - 100,
            width: windowSize.width,
            height: windowSize.height
        )
        
        floatingWindow = FloatingPanelWindow(
            contentRect: windowRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        print("🪟 Window created")
        
        // Создаём контроллер для содержимого окна
        shelfViewController = ShelfViewController()
        floatingWindow?.contentViewController = shelfViewController
        
        print("📋 ViewController set")
        
        // Настраиваем детектор перетаскивания
        dragDetector = DragDetector()
        dragDetector?.onShakeDetected = { [weak self] in
            print("🤝 Shake detected!")
            self?.showWindow()
        }
        dragDetector?.startMonitoring()
        
        print("👂 Drag detector started")
        
        // Скрываем окно по умолчанию
        floatingWindow?.orderOut(nil)
        
        print("✅ Setup complete!")
    }
    
    @objc func toggleWindow() {
        print("🖱 Toggle window clicked")
        guard let window = floatingWindow else {
            print("❌ Window is nil")
            return
        }
        
        if window.isVisible {
            window.orderOut(nil)
            print("👋 Window hidden")
        } else {
            showWindow()
        }
    }
    
    func showWindow() {
        print("👁 Showing window")
        floatingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        dragDetector?.stopMonitoring()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
