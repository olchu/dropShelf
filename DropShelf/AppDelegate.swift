import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem?
    var floatingWindow: FloatingPanelWindow?
    var shelfViewController: ShelfViewController?
    var dragDetector: DragDetector?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Приложение только в статус-баре (без иконки в Dock)
        NSApplication.shared.setActivationPolicy(.accessory)

        // Создаём статус-айтем только под иконку
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }

        // Загружаем картинку из Assets (НЕ template)
        let img = NSImage(named: "StatusBarIcon")
            ?? NSImage(named: "statusbar") // если лежит в бандле без Assets
        button.image = img
        button.alternateImage = img            // та же картинка при нажатии
        button.image?.isTemplate = false       // <— ВАЖНО: никакой автоперекраски
        button.imagePosition = .imageOnly
        button.title = ""                      // без текста

        button.target = self
        button.action = #selector(toggleWindow)

        // На всякий случай: уберите любое тонирование
        button.contentTintColor = nil          // не задаём tint вообще

        // ---- Окно панели (как в твоём коде) ----
        let windowSize = NSSize(width: 280, height: 280)
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

        shelfViewController = ShelfViewController()
        floatingWindow?.contentViewController = shelfViewController
        floatingWindow?.orderOut(nil)

        // ---- Детектор перетаскивания (как у тебя) ----
        dragDetector = DragDetector()
        dragDetector?.onShakeDetected = { [weak self] in self?.showWindow() }
        dragDetector?.startMonitoring()
    }

    // MARK: - Actions

    @objc func toggleWindow() {
        guard let window = floatingWindow else { return }
        if window.isVisible {
            window.orderOut(nil)
            updateStatusHighlight(false)
        } else {
            showWindow()
        }
    }

    private func updateStatusHighlight(_ active: Bool) {
        // Подсветка template-иконки, когда окно открыто
        statusItem?.button?.contentTintColor = active ? .controlAccentColor : nil
    }

    func showWindow() {
        guard let window = floatingWindow else { return }
        // Показать под статус-иконкой
        if let btn = statusItem?.button,
           let btnWindow = btn.window {
            let btnInScreen = btnWindow.convertToScreen(btn.convert(btn.bounds, to: nil))
            let origin = NSPoint(
                x: btnInScreen.midX - window.frame.width / 2,
                y: btnInScreen.minY - window.frame.height - 6
            )
            window.setFrameOrigin(origin)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        updateStatusHighlight(true)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        dragDetector?.stopMonitoring()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
