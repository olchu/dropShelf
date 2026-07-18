import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem?
    var floatingWindow: FloatingPanelWindow?
    var shelfViewController: ShelfViewController?
    var dragDetector: DragDetector?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        DiagnosticsLogger.shared.startSession()

        // Приложение только в статус-баре (без иконки в Dock)
        NSApplication.shared.setActivationPolicy(.accessory)

        // Создаём статус-айтем только под иконку
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }

        let img = NSImage(named: "statusbar")
        button.image = img
        button.alternateImage = img
        button.image?.isTemplate = true
        button.imagePosition = .imageOnly
        button.title = ""

        button.target = self
        button.action = #selector(handleStatusItemClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

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
        floatingWindow?.minSize = windowSize
        floatingWindow?.maxSize = windowSize
        floatingWindow?.orderOut(nil)

        // ---- Детектор перетаскивания (как у тебя) ----
        dragDetector = DragDetector()
        dragDetector?.onShakeDetected = { [weak self] mouseLocation in
            self?.showWindow(near: mouseLocation)
        }
        dragDetector?.startMonitoring()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidHide),
            name: .floatingPanelDidHide,
            object: nil
        )
    }

    // MARK: - Actions

    @objc func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggleWindow()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let settingsItem = menu.addItem(
            withTitle: "Settings…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        let diagnosticsItem = menu.addItem(
            withTitle: "Open Diagnostics Folder",
            action: #selector(openDiagnosticsFolder),
            keyEquivalent: ""
        )
        diagnosticsItem.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit DropShelf", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func showSettings() {
        DiagnosticsLogger.shared.info("Settings window requested")
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.present()
    }

    @objc private func openDiagnosticsFolder() {
        DiagnosticsLogger.shared.info("Diagnostics folder requested")
        NSWorkspace.shared.open(DiagnosticsLogger.shared.directoryURL)
    }

    @objc func toggleWindow() {
        guard let window = floatingWindow else { return }
        if window.isVisible {
            DiagnosticsLogger.shared.info("Main panel hidden from status item")
            window.orderOut(nil)  // → panelDidHide → updateStatusHighlight(false)
        } else {
            showWindow()
        }
    }

    private func updateStatusHighlight(_ active: Bool) {
        // Template-иконка должна всегда использовать системный цвет строки меню.
        // Не окрашиваем её при открытии панели: controlAccentColor может быть
        // чёрным и делать иконку визуально «активной» не в стиле status bar.
        statusItem?.button?.contentTintColor = nil
    }

    func showWindow(near mouseLocation: CGPoint? = nil) {
        guard let window = floatingWindow else { return }
        let isNewPresentation = !window.isVisible

        if isNewPresentation {
            DiagnosticsLogger.shared.info("Main panel presentation started; nearPointer=\(mouseLocation != nil)")
            shelfViewController?.prepareForWindowPresentation()
        }

        if let point = mouseLocation {
            let w = window.frame.width
            let h = window.frame.height
            let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main
            let screenFrame = screen?.visibleFrame ?? .zero
            let gap = w / 2

            // Пробуем справа, если не помещается — слева
            var x = point.x + gap
            if x + w > screenFrame.maxX {
                x = point.x - w - gap
            }
            x = max(screenFrame.minX, x)

            // Центрируем по вертикали относительно курсора
            var y = point.y - h / 2
            y = max(screenFrame.minY, min(y, screenFrame.maxY - h))

            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            if let btn = statusItem?.button, let btnWindow = btn.window {
                let btnInScreen = btnWindow.convertToScreen(btn.convert(btn.bounds, to: nil))
                let origin = NSPoint(
                    x: btnInScreen.midX - window.frame.width / 2,
                    y: btnInScreen.minY - window.frame.height - 6
                )
                window.setFrameOrigin(origin)
            }
        }

        window.presentAnimated(contentReveal: { [weak self] in
            self?.shelfViewController?.completeWindowPresentation()
        })
        updateStatusHighlight(true)
    }

    @objc private func panelDidHide() {
        DiagnosticsLogger.shared.info("Main panel did hide")
        shelfViewController?.closeThumbnailPanel()
        updateStatusHighlight(false)
        dragDetector?.startMonitoring()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        dragDetector?.stopMonitoring()
        DiagnosticsLogger.shared.finishSession()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
